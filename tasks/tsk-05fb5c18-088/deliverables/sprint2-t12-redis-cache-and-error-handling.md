# Sprint2-T12: Redis 缓存层设计与错误处理精细化

> **任务编号**: tsk-05fb5c18-088  
> **关联问题**: BE-P2-1 (Redis缓存层), BE-P2-2 (错误处理精细化)  
> **优先级**: P2  
> **状态**: 已完成  

---

## 一、交付物概览

| 文件路径 | 说明 | 行数 |
|---------|------|------|
| `server/pkg/errors/errors.go` | 统一错误包：业务错误码体系 + API 错误响应 + 错误处理中间件 | ~280 |
| `server/pkg/errors/errors_test.go` | 错误包单元测试（18 个测试用例） | ~230 |
| `server/pkg/cache/redis.go` | Redis 缓存工具包：缓存管理器 + 穿透/击穿/雪崩防护 | ~420 |
| `server/pkg/cache/redis_test.go` | 缓存包单元测试（13 个测试用例） | ~220 |

---

## 二、统一错误码体系 (`server/pkg/errors/`)

### 2.1 设计原则

统一错误包遵循以下设计原则：

- **类型安全**：所有业务错误通过 `BizError` 类型表达，携带错误码、消息和可选详情
- **错误链支持**：使用 `fmt.Errorf("%w", err)` 风格包装，保留完整错误链
- **Go 标准兼容**：支持 Go 1.13+ `errors.Is` / `errors.As` 进行错误判断
- **统一响应格式**：API 错误响应统一为 `{code, message, details, timestamp}`

### 2.2 错误码分段

| 分段 | 范围 | 说明 | 示例 |
|------|------|------|------|
| **1xxx** | 1001-1010 | 认证与授权 | `ErrUnauthorized(1001)`, `ErrTokenExpired(1002)`, `ErrRateLimited(1007)` |
| **2xxx** | 2001-2010 | 文章与内容 | `ErrArticleNotFound(2001)`, `ErrInvalidParam(2006)`, `ErrMaliciousInput(2009)` |
| **3xxx** | 3001-3006 | AI 服务 | `ErrAITimeout(3001)`, `ErrAIProviderUnavailable(3003)`, `ErrAICostLimitExceeded(3005)` |
| **4xxx** | 4001-4007 | 系统与基础设施 | `ErrInternal(4001)`, `ErrDBFailed(4002)`, `ErrCacheFailed(4003)` |

### 2.3 使用方式

```go
// 1. 直接返回预定义错误
return nil, errors.ErrArticleNotFound

// 2. 携带详情
return nil, errors.ErrInvalidParam.WithDetails("field 'email' is required")

// 3. 包装底层错误（保留错误链）
return nil, errors.ErrDBFailed.WithCause(dbErr)

// 4. 同时设置详情和底层错误
return nil, errors.ErrAITimeout.Wrap(httpErr, "调用 OpenAI 超时")

// 5. 在 handler 中统一响应
errors.RespondError(c, err)        // 自动提取 BizError 信息
errors.RespondSuccess(c, data)     // 统一成功响应

// 6. 使用中间件自动处理
router.Use(errors.ErrorHandlerMiddleware(debugMode))
// handler 中只需: c.Error(err)
```

### 2.4 API 响应格式

**成功响应：**
```json
{
  "code": 0,
  "message": "success",
  "data": { ... },
  "timestamp": 1709280000000
}
```

**错误响应：**
```json
{
  "code": 2001,
  "message": "文章不存在",
  "details": "article_id=123 not found in database",
  "timestamp": 1709280000000
}
```

---

## 三、Redis 缓存层 (`server/pkg/cache/`)

### 3.1 架构设计

缓存层以 `CacheManager` 为核心，提供以下能力：

```
┌─────────────────────────────────────────────────┐
│                  CacheManager                    │
├─────────────────────────────────────────────────┤
│  基础操作: Get / Set / SetNull / Delete          │
│  批量操作: DeleteByPrefix (SCAN + DEL)           │
│  高级操作: GetOrLoad (穿透+击穿+雪崩防护)         │
│  失效策略: InvalidateArticleCache / ...          │
│  预热机制: WarmUp                                │
│  健康检查: HealthCheck / IsAvailable             │
├─────────────────────────────────────────────────┤
│  内置防护:                                       │
│  ├── 穿透防护: 空值缓存 (nullPlaceholder)         │
│  ├── 击穿防护: singleflight 合并并发请求          │
│  └── 雪崩防护: TTL 随机抖动 (±20%)               │
└─────────────────────────────────────────────────┘
```

### 3.2 缓存策略

| 业务场景 | 缓存键格式 | TTL | 维度 |
|---------|-----------|-----|------|
| 文章列表 | `cache:articles:list:{userID}:{page}:{pageSize}:{sortBy}` | 5 分钟 | 用户 |
| 推荐流 | `cache:recommend:feed:{userID}:{tagHash}:{page}` | 10 分钟 | 用户+标签 |
| 认知标签 | `cache:cognitive:tags:{userID}` | 30 分钟 | 用户 |
| 文章详情 | `cache:articles:detail:{articleID}` | 15 分钟 | 文章 |
| 空值占位 | `cache:null:{key}` | 2 分钟 | - |

### 3.3 缓存失效策略

写操作触发的自动缓存清除：

| 写操作 | 清除范围 | 方法 |
|--------|---------|------|
| 创建/更新/删除文章 | 文章详情 + 所有文章列表 + 推荐流 | `InvalidateArticleCache(articleID)` |
| 更新阅读进度/添加标注 | 该用户的文章列表 + 推荐流 | `InvalidateUserArticleCache(userID)` |
| 更新认知标签 | 该用户的认知标签缓存 | `InvalidateCognitiveTagCache(userID)` |
| 紧急全量清除 | 所有业务缓存 | `InvalidateAllCache()` |

### 3.4 三大防护机制

**缓存穿透防护**：当数据源确认数据不存在时，写入空值占位符 `__NULL__`（TTL 2分钟），避免恶意请求反复穿透到数据库。

**缓存击穿防护**：通过内置的 `singleflight` 机制，当多个 goroutine 同时请求同一个缓存 key 时，只有一个会真正执行数据加载，其余等待并复用结果。

**缓存雪崩防护**：所有 TTL 自动添加 ±20% 的随机抖动，避免大量缓存在同一时刻过期导致数据库压力骤增。

### 3.5 使用示例

```go
// 初始化
cm := cache.NewCacheManager(redisClient)

// 带防护的缓存查询
var articles []Article
key := cache.ArticleListKey(userID, page, pageSize, "created_at")
found, err := cm.GetOrLoad(ctx, key, &articles, cache.TTLArticleList,
    func(ctx context.Context) (interface{}, bool, error) {
        result, err := repo.ListArticles(ctx, userID, page, pageSize)
        if err != nil {
            return nil, false, err
        }
        return result, len(result) > 0, nil
    })

// 写操作后自动清除缓存
_ = cm.InvalidateArticleCache(ctx, articleID)
```

### 3.6 优雅降级

当 Redis 不可用时（client 为 nil），`CacheManager` 的所有操作会优雅降级：
- `Get` 返回 `(false, nil)`，触发回源查询
- `Set` / `Delete` 等写操作静默成功
- `IsAvailable()` 返回 `false`

---

## 四、测试覆盖

### 4.1 errors 包测试（18 个用例）

- `BizError` 基础功能：Error(), Unwrap(), Is(), As()
- 错误包装：WithDetails(), WithCause(), Wrap()
- 辅助函数：IsBizError(), GetCode(), GetHTTPStatus(), WrapErr()
- 错误码范围验证：确保各分段错误码在正确范围内
- API 响应：RespondError(), RespondSuccess()
- 错误链深度测试：多层 fmt.Errorf 包装后的 errors.As 查找
- 中间件测试：ErrorHandlerMiddleware 正常和无错误场景

### 4.2 cache 包测试（13 个用例）

- 缓存键生成器：ArticleListKey, RecommendFeedKey, CognitiveTagKey, ArticleDetailKey
- TTL 抖动：正常值、零值、负值边界测试
- nil client 降级：Get, Set, SetNull, Delete, DeleteByPrefix, IsAvailable
- singleflight：相同 key 合并、不同 key 独立执行
- 预热降级：nil client 下的 WarmUp
- 常量验证：TTL 值和前缀唯一性

---

## 五、与现有代码的兼容性

本次交付与现有代码完全兼容：

1. **`server/pkg/cache/redis.go`**：在原有 `InitRedis()` 基础上增强，保持 `RedisClient` 全局变量不变，新增 `CacheManager` 作为高级缓存操作入口
2. **`server/pkg/errors/errors.go`**：新增独立包，不修改现有 `server/pkg/response/response.go`，后续可逐步迁移
3. **`server/pkg/response/response.go`**：现有错误码常量保留不变，新的 `errors` 包提供更完整的错误码体系，两者可并存

### 迁移建议

后续可逐步将 handler 中的错误处理迁移到新的 `errors` 包：

```go
// 旧方式
response.Error(c, http.StatusNotFound, response.ErrCodeArticleNotFound, "文章不存在")

// 新方式
errors.RespondError(c, errors.ErrArticleNotFound)
```
