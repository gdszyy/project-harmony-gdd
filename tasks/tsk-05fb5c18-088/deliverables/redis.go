// Package cache 提供 Redis 缓存连接和高级缓存操作功能。
//
// 功能特性:
//   - 基础 Redis 连接管理
//   - 通用缓存 Get/Set/Delete 操作
//   - 按前缀批量清除（用于写操作后失效相关缓存）
//   - 缓存穿透防护（空值缓存 + 短 TTL）
//   - 缓存击穿防护（singleflight 合并并发请求）
//   - 缓存雪崩防护（TTL 随机抖动）
//   - 预定义的业务缓存键和 TTL 策略
package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"

	"github.com/gdszyy/edge-reader/server/internal/config"
)

// ──────────────────────────────────────────────────────────────────────────────
// 常量与配置
// ──────────────────────────────────────────────────────────────────────────────

// 缓存键前缀
const (
	// PrefixArticleList 文章列表缓存前缀（按用户维度）
	PrefixArticleList = "cache:articles:list:"
	// PrefixRecommendFeed 推荐流缓存前缀（按用户+标签维度）
	PrefixRecommendFeed = "cache:recommend:feed:"
	// PrefixCognitiveTag 认知标签查询缓存前缀
	PrefixCognitiveTag = "cache:cognitive:tags:"
	// PrefixArticleDetail 文章详情缓存前缀
	PrefixArticleDetail = "cache:articles:detail:"
	// PrefixNullPlaceholder 空值占位符前缀（防穿透）
	PrefixNullPlaceholder = "cache:null:"
)

// 缓存 TTL 策略
const (
	// TTLArticleList 文章列表缓存 TTL: 5 分钟
	TTLArticleList = 5 * time.Minute
	// TTLRecommendFeed 推荐流缓存 TTL: 10 分钟
	TTLRecommendFeed = 10 * time.Minute
	// TTLCognitiveTag 认知标签查询缓存 TTL: 30 分钟
	TTLCognitiveTag = 30 * time.Minute
	// TTLArticleDetail 文章详情缓存 TTL: 15 分钟
	TTLArticleDetail = 15 * time.Minute
	// TTLNullPlaceholder 空值占位符 TTL: 2 分钟（防穿透，短 TTL 避免长期占用）
	TTLNullPlaceholder = 2 * time.Minute
	// TTLJitterPercent TTL 随机抖动百分比（防雪崩）
	TTLJitterPercent = 20
)

// nullPlaceholder 空值占位符标记，用于缓存穿透防护
const nullPlaceholder = "__NULL__"

// ──────────────────────────────────────────────────────────────────────────────
// RedisClient 全局实例
// ──────────────────────────────────────────────────────────────────────────────

// RedisClient 全局 Redis 客户端实例
var RedisClient *redis.Client

// ──────────────────────────────────────────────────────────────────────────────
// CacheManager 缓存管理器
// ──────────────────────────────────────────────────────────────────────────────

// CacheManager 提供高级缓存操作，内置穿透/击穿/雪崩防护。
type CacheManager struct {
	client *redis.Client
	sf     *singleFlightGroup
}

// singleFlightGroup 简化版 singleflight，防止缓存击穿。
// 当多个 goroutine 同时请求同一个 key 时，只有一个会真正执行数据加载，
// 其余 goroutine 等待并复用结果。
type singleFlightGroup struct {
	mu sync.Mutex
	m  map[string]*call
}

type call struct {
	wg  sync.WaitGroup
	val interface{}
	err error
}

func newSingleFlightGroup() *singleFlightGroup {
	return &singleFlightGroup{
		m: make(map[string]*call),
	}
}

// Do 执行 singleflight 调用。
func (g *singleFlightGroup) Do(key string, fn func() (interface{}, error)) (interface{}, error) {
	g.mu.Lock()
	if c, ok := g.m[key]; ok {
		g.mu.Unlock()
		c.wg.Wait()
		return c.val, c.err
	}
	c := &call{}
	c.wg.Add(1)
	g.m[key] = c
	g.mu.Unlock()

	c.val, c.err = fn()
	c.wg.Done()

	g.mu.Lock()
	delete(g.m, key)
	g.mu.Unlock()

	return c.val, c.err
}

// ──────────────────────────────────────────────────────────────────────────────
// 初始化
// ──────────────────────────────────────────────────────────────────────────────

// InitRedis 初始化 Redis 连接。
func InitRedis(cfg config.RedisConfig) (*redis.Client, error) {
	client := redis.NewClient(&redis.Options{
		Addr:         fmt.Sprintf("%s:%d", cfg.Host, cfg.Port),
		Password:     cfg.Password,
		DB:           cfg.DB,
		PoolSize:     20,
		MinIdleConns: 5,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %w", err)
	}

	log.Println("Redis connection established successfully")
	RedisClient = client
	return client, nil
}

// NewCacheManager 创建一个新的 CacheManager 实例。
// 如果 client 为 nil，所有缓存操作将优雅降级（直接回源）。
func NewCacheManager(client *redis.Client) *CacheManager {
	return &CacheManager{
		client: client,
		sf:     newSingleFlightGroup(),
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// 基础操作
// ──────────────────────────────────────────────────────────────────────────────

// Get 从缓存获取值并反序列化到 dest。
// 返回 (found, error)：found=true 表示命中缓存，found=false 表示未命中。
// 如果缓存中存储的是空值占位符（防穿透），dest 不会被修改，但 found=true。
func (cm *CacheManager) Get(ctx context.Context, key string, dest interface{}) (bool, error) {
	if cm.client == nil {
		return false, nil
	}

	val, err := cm.client.Get(ctx, key).Result()
	if err == redis.Nil {
		return false, nil
	}
	if err != nil {
		log.Printf("[CACHE] Get error for key=%s: %v", key, err)
		return false, fmt.Errorf("cache get failed: %w", err)
	}

	// 检查是否为空值占位符（防穿透）
	if val == nullPlaceholder {
		return true, nil // 命中空值缓存，dest 不修改
	}

	if err := json.Unmarshal([]byte(val), dest); err != nil {
		log.Printf("[CACHE] Unmarshal error for key=%s: %v", key, err)
		// 反序列化失败，删除脏缓存
		_ = cm.client.Del(ctx, key)
		return false, fmt.Errorf("cache unmarshal failed: %w", err)
	}

	return true, nil
}

// Set 将值序列化后存入缓存，TTL 会自动添加随机抖动以防雪崩。
func (cm *CacheManager) Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	if cm.client == nil {
		return nil
	}

	data, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("cache marshal failed: %w", err)
	}

	jitteredTTL := addJitter(ttl)
	if err := cm.client.Set(ctx, key, data, jitteredTTL).Err(); err != nil {
		log.Printf("[CACHE] Set error for key=%s: %v", key, err)
		return fmt.Errorf("cache set failed: %w", err)
	}

	return nil
}

// SetNull 存储空值占位符，用于缓存穿透防护。
// 当数据源确认数据不存在时调用，避免反复穿透到数据库。
func (cm *CacheManager) SetNull(ctx context.Context, key string) error {
	if cm.client == nil {
		return nil
	}

	if err := cm.client.Set(ctx, key, nullPlaceholder, TTLNullPlaceholder).Err(); err != nil {
		log.Printf("[CACHE] SetNull error for key=%s: %v", key, err)
		return fmt.Errorf("cache set null failed: %w", err)
	}

	return nil
}

// Delete 删除指定的缓存键。
func (cm *CacheManager) Delete(ctx context.Context, keys ...string) error {
	if cm.client == nil || len(keys) == 0 {
		return nil
	}

	if err := cm.client.Del(ctx, keys...).Err(); err != nil {
		log.Printf("[CACHE] Delete error for keys=%v: %v", keys, err)
		return fmt.Errorf("cache delete failed: %w", err)
	}

	return nil
}

// DeleteByPrefix 按前缀批量删除缓存键。
// 使用 SCAN 命令避免阻塞 Redis（不使用 KEYS 命令）。
// 这是写操作后自动清除相关缓存的核心方法。
func (cm *CacheManager) DeleteByPrefix(ctx context.Context, prefix string) error {
	if cm.client == nil {
		return nil
	}

	var cursor uint64
	var totalDeleted int64

	for {
		keys, nextCursor, err := cm.client.Scan(ctx, cursor, prefix+"*", 100).Result()
		if err != nil {
			log.Printf("[CACHE] Scan error for prefix=%s: %v", prefix, err)
			return fmt.Errorf("cache scan failed: %w", err)
		}

		if len(keys) > 0 {
			deleted, err := cm.client.Del(ctx, keys...).Result()
			if err != nil {
				log.Printf("[CACHE] Batch delete error: %v", err)
			}
			totalDeleted += deleted
		}

		cursor = nextCursor
		if cursor == 0 {
			break
		}
	}

	if totalDeleted > 0 {
		log.Printf("[CACHE] Deleted %d keys with prefix=%s", totalDeleted, prefix)
	}

	return nil
}

// ──────────────────────────────────────────────────────────────────────────────
// 高级操作：带穿透/击穿防护的缓存查询
// ──────────────────────────────────────────────────────────────────────────────

// LoadFunc 数据加载函数类型。
// 当缓存未命中时，CacheManager 会调用此函数从数据源加载数据。
// 返回 (data, found, error)：
//   - found=true: 数据存在，data 为有效值
//   - found=false: 数据不存在（将触发空值缓存防穿透）
type LoadFunc func(ctx context.Context) (interface{}, bool, error)

// GetOrLoad 带穿透/击穿防护的缓存查询。
//
// 执行流程:
//  1. 尝试从缓存获取
//  2. 缓存命中 → 直接返回（包括空值占位符）
//  3. 缓存未命中 → 通过 singleflight 合并并发请求（防击穿）
//  4. 数据源返回数据 → 写入缓存并返回
//  5. 数据源确认不存在 → 写入空值占位符（防穿透）
//
// dest 必须是指针类型，用于接收反序列化后的数据。
func (cm *CacheManager) GetOrLoad(ctx context.Context, key string, dest interface{}, ttl time.Duration, loader LoadFunc) (bool, error) {
	// 1. 尝试从缓存获取
	found, err := cm.Get(ctx, key, dest)
	if err != nil {
		// 缓存读取失败，降级到直接加载
		log.Printf("[CACHE] Get failed, fallback to loader: %v", err)
	} else if found {
		return true, nil
	}

	// 2. 缓存未命中，通过 singleflight 防击穿
	result, err := cm.sf.Do(key, func() (interface{}, error) {
		// 双重检查：在获得锁后再次检查缓存
		found2, err2 := cm.Get(ctx, key, dest)
		if err2 == nil && found2 {
			return dest, nil
		}

		// 从数据源加载
		data, exists, loadErr := loader(ctx)
		if loadErr != nil {
			return nil, loadErr
		}

		if !exists {
			// 数据不存在，写入空值占位符防穿透
			_ = cm.SetNull(ctx, key)
			return nil, nil
		}

		// 写入缓存（TTL 自动抖动防雪崩）
		_ = cm.Set(ctx, key, data, ttl)
		return data, nil
	})

	if err != nil {
		return false, err
	}

	if result == nil {
		return false, nil // 数据不存在
	}

	// 将结果反序列化到 dest
	data, marshalErr := json.Marshal(result)
	if marshalErr != nil {
		return false, fmt.Errorf("marshal result failed: %w", marshalErr)
	}
	if unmarshalErr := json.Unmarshal(data, dest); unmarshalErr != nil {
		return false, fmt.Errorf("unmarshal result failed: %w", unmarshalErr)
	}

	return true, nil
}

// ──────────────────────────────────────────────────────────────────────────────
// 业务缓存键生成器
// ──────────────────────────────────────────────────────────────────────────────

// ArticleListKey 生成文章列表缓存键（按用户维度）。
// 格式: cache:articles:list:{userID}:{page}:{pageSize}:{sortBy}
func ArticleListKey(userID uint64, page, pageSize int, sortBy string) string {
	return fmt.Sprintf("%s%d:%d:%d:%s", PrefixArticleList, userID, page, pageSize, sortBy)
}

// RecommendFeedKey 生成推荐流缓存键（按用户+标签维度）。
// 格式: cache:recommend:feed:{userID}:{tagHash}:{page}
func RecommendFeedKey(userID uint64, tagHash string, page int) string {
	return fmt.Sprintf("%s%d:%s:%d", PrefixRecommendFeed, userID, tagHash, page)
}

// CognitiveTagKey 生成认知标签查询缓存键。
// 格式: cache:cognitive:tags:{userID}
func CognitiveTagKey(userID uint64) string {
	return fmt.Sprintf("%s%d", PrefixCognitiveTag, userID)
}

// ArticleDetailKey 生成文章详情缓存键。
// 格式: cache:articles:detail:{articleID}
func ArticleDetailKey(articleID uint64) string {
	return fmt.Sprintf("%s%d", PrefixArticleDetail, articleID)
}

// ──────────────────────────────────────────────────────────────────────────────
// 写操作缓存失效策略
// ──────────────────────────────────────────────────────────────────────────────

// InvalidateArticleCache 文章写操作后清除相关缓存。
// 清除范围：文章列表缓存 + 文章详情缓存 + 推荐流缓存。
func (cm *CacheManager) InvalidateArticleCache(ctx context.Context, articleID uint64) error {
	var errs []error

	// 清除文章详情缓存
	if err := cm.Delete(ctx, ArticleDetailKey(articleID)); err != nil {
		errs = append(errs, fmt.Errorf("invalidate article detail: %w", err))
	}

	// 清除所有文章列表缓存（因为列表可能包含该文章）
	if err := cm.DeleteByPrefix(ctx, PrefixArticleList); err != nil {
		errs = append(errs, fmt.Errorf("invalidate article list: %w", err))
	}

	// 清除推荐流缓存（推荐结果可能包含该文章）
	if err := cm.DeleteByPrefix(ctx, PrefixRecommendFeed); err != nil {
		errs = append(errs, fmt.Errorf("invalidate recommend feed: %w", err))
	}

	if len(errs) > 0 {
		return fmt.Errorf("partial cache invalidation failure: %v", errs)
	}
	return nil
}

// InvalidateUserArticleCache 用户维度的文章缓存失效。
// 当用户的阅读行为改变时调用（如更新阅读进度、添加标注）。
func (cm *CacheManager) InvalidateUserArticleCache(ctx context.Context, userID uint64) error {
	var errs []error

	// 清除该用户的文章列表缓存
	userPrefix := fmt.Sprintf("%s%d:", PrefixArticleList, userID)
	if err := cm.DeleteByPrefix(ctx, userPrefix); err != nil {
		errs = append(errs, fmt.Errorf("invalidate user article list: %w", err))
	}

	// 清除该用户的推荐流缓存
	userFeedPrefix := fmt.Sprintf("%s%d:", PrefixRecommendFeed, userID)
	if err := cm.DeleteByPrefix(ctx, userFeedPrefix); err != nil {
		errs = append(errs, fmt.Errorf("invalidate user recommend feed: %w", err))
	}

	if len(errs) > 0 {
		return fmt.Errorf("partial cache invalidation failure: %v", errs)
	}
	return nil
}

// InvalidateCognitiveTagCache 认知标签写操作后清除缓存。
func (cm *CacheManager) InvalidateCognitiveTagCache(ctx context.Context, userID uint64) error {
	return cm.Delete(ctx, CognitiveTagKey(userID))
}

// InvalidateAllCache 清除所有业务缓存（慎用，仅用于紧急情况）。
func (cm *CacheManager) InvalidateAllCache(ctx context.Context) error {
	var errs []error

	prefixes := []string{
		PrefixArticleList,
		PrefixRecommendFeed,
		PrefixCognitiveTag,
		PrefixArticleDetail,
		PrefixNullPlaceholder,
	}

	for _, prefix := range prefixes {
		if err := cm.DeleteByPrefix(ctx, prefix); err != nil {
			errs = append(errs, err)
		}
	}

	if len(errs) > 0 {
		return fmt.Errorf("partial cache invalidation failure: %v", errs)
	}
	return nil
}

// ──────────────────────────────────────────────────────────────────────────────
// 缓存预热
// ──────────────────────────────────────────────────────────────────────────────

// WarmUpFunc 缓存预热数据加载函数。
// 返回 (key, data) 对的列表。
type WarmUpFunc func(ctx context.Context) (map[string]interface{}, error)

// WarmUp 批量预热缓存。
// 适合在服务启动时或定时任务中调用，预加载热点数据。
func (cm *CacheManager) WarmUp(ctx context.Context, ttl time.Duration, loader WarmUpFunc) (int, error) {
	if cm.client == nil {
		return 0, nil
	}

	data, err := loader(ctx)
	if err != nil {
		return 0, fmt.Errorf("warm up loader failed: %w", err)
	}

	loaded := 0
	for key, value := range data {
		if setErr := cm.Set(ctx, key, value, ttl); setErr != nil {
			log.Printf("[CACHE] WarmUp set error for key=%s: %v", key, setErr)
			continue
		}
		loaded++
	}

	log.Printf("[CACHE] WarmUp completed: %d/%d keys loaded", loaded, len(data))
	return loaded, nil
}

// ──────────────────────────────────────────────────────────────────────────────
// 健康检查
// ──────────────────────────────────────────────────────────────────────────────

// HealthCheck 检查 Redis 连接是否正常。
func (cm *CacheManager) HealthCheck(ctx context.Context) error {
	if cm.client == nil {
		return fmt.Errorf("redis client is nil")
	}
	return cm.client.Ping(ctx).Err()
}

// IsAvailable 返回缓存是否可用（非阻塞检查）。
func (cm *CacheManager) IsAvailable() bool {
	return cm.client != nil
}

// ──────────────────────────────────────────────────────────────────────────────
// 内部工具函数
// ──────────────────────────────────────────────────────────────────────────────

// addJitter 为 TTL 添加随机抖动，防止大量缓存同时过期导致雪崩。
// 抖动范围: [TTL * (1 - jitter%), TTL * (1 + jitter%)]
func addJitter(ttl time.Duration) time.Duration {
	if ttl <= 0 {
		return ttl
	}
	jitter := float64(ttl) * float64(TTLJitterPercent) / 100.0
	delta := rand.Int63n(int64(2*jitter)) - int64(jitter)
	result := time.Duration(int64(ttl) + delta)
	if result <= 0 {
		return ttl // 安全兜底
	}
	return result
}
