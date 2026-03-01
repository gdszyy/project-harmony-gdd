package cache

import (
	"context"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// ──────────────────────────────────────────────────────────────────────────────
// 缓存键生成器测试
// ──────────────────────────────────────────────────────────────────────────────

func TestArticleListKey(t *testing.T) {
	key := ArticleListKey(123, 1, 20, "created_at")
	expected := "cache:articles:list:123:1:20:created_at"
	if key != expected {
		t.Errorf("expected '%s', got '%s'", expected, key)
	}
}

func TestRecommendFeedKey(t *testing.T) {
	key := RecommendFeedKey(456, "abc123", 2)
	expected := "cache:recommend:feed:456:abc123:2"
	if key != expected {
		t.Errorf("expected '%s', got '%s'", expected, key)
	}
}

func TestCognitiveTagKey(t *testing.T) {
	key := CognitiveTagKey(789)
	expected := "cache:cognitive:tags:789"
	if key != expected {
		t.Errorf("expected '%s', got '%s'", expected, key)
	}
}

func TestArticleDetailKey(t *testing.T) {
	key := ArticleDetailKey(100)
	expected := "cache:articles:detail:100"
	if key != expected {
		t.Errorf("expected '%s', got '%s'", expected, key)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// TTL 抖动测试
// ──────────────────────────────────────────────────────────────────────────────

func TestAddJitter(t *testing.T) {
	baseTTL := 5 * time.Minute
	minTTL := time.Duration(float64(baseTTL) * (1 - float64(TTLJitterPercent)/100.0))
	maxTTL := time.Duration(float64(baseTTL) * (1 + float64(TTLJitterPercent)/100.0))

	for i := 0; i < 100; i++ {
		jittered := addJitter(baseTTL)
		if jittered < minTTL || jittered > maxTTL {
			t.Errorf("jittered TTL %v out of range [%v, %v]", jittered, minTTL, maxTTL)
		}
	}
}

func TestAddJitter_Zero(t *testing.T) {
	result := addJitter(0)
	if result != 0 {
		t.Errorf("expected 0 for zero TTL, got %v", result)
	}
}

func TestAddJitter_Negative(t *testing.T) {
	result := addJitter(-1 * time.Second)
	if result != -1*time.Second {
		t.Errorf("expected negative TTL to pass through, got %v", result)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// CacheManager nil client 降级测试
// ──────────────────────────────────────────────────────────────────────────────

func TestCacheManager_NilClient(t *testing.T) {
	cm := NewCacheManager(nil)
	ctx := context.Background()

	// Get 应返回 false, nil
	var dest string
	found, err := cm.Get(ctx, "test", &dest)
	if found || err != nil {
		t.Errorf("nil client Get: expected (false, nil), got (%v, %v)", found, err)
	}

	// Set 应返回 nil
	if err := cm.Set(ctx, "test", "value", time.Minute); err != nil {
		t.Errorf("nil client Set: expected nil, got %v", err)
	}

	// SetNull 应返回 nil
	if err := cm.SetNull(ctx, "test"); err != nil {
		t.Errorf("nil client SetNull: expected nil, got %v", err)
	}

	// Delete 应返回 nil
	if err := cm.Delete(ctx, "test"); err != nil {
		t.Errorf("nil client Delete: expected nil, got %v", err)
	}

	// DeleteByPrefix 应返回 nil
	if err := cm.DeleteByPrefix(ctx, "test:"); err != nil {
		t.Errorf("nil client DeleteByPrefix: expected nil, got %v", err)
	}

	// IsAvailable 应返回 false
	if cm.IsAvailable() {
		t.Error("nil client should not be available")
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// SingleFlight 测试
// ──────────────────────────────────────────────────────────────────────────────

func TestSingleFlightGroup(t *testing.T) {
	sf := newSingleFlightGroup()
	var callCount int32

	var wg sync.WaitGroup
	results := make([]interface{}, 10)
	errors := make([]error, 10)

	// 10 个 goroutine 同时请求同一个 key
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			val, err := sf.Do("same-key", func() (interface{}, error) {
				atomic.AddInt32(&callCount, 1)
				time.Sleep(50 * time.Millisecond) // 模拟耗时操作
				return "result", nil
			})
			results[idx] = val
			errors[idx] = err
		}(i)
	}

	wg.Wait()

	// 应该只执行了一次
	if atomic.LoadInt32(&callCount) != 1 {
		t.Errorf("expected 1 call, got %d", callCount)
	}

	// 所有结果应该相同
	for i := 0; i < 10; i++ {
		if results[i] != "result" {
			t.Errorf("goroutine %d: expected 'result', got '%v'", i, results[i])
		}
		if errors[i] != nil {
			t.Errorf("goroutine %d: unexpected error: %v", i, errors[i])
		}
	}
}

func TestSingleFlightGroup_DifferentKeys(t *testing.T) {
	sf := newSingleFlightGroup()
	var callCount int32

	var wg sync.WaitGroup
	for i := 0; i < 5; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			key := ArticleDetailKey(uint64(idx))
			_, _ = sf.Do(key, func() (interface{}, error) {
				atomic.AddInt32(&callCount, 1)
				time.Sleep(10 * time.Millisecond)
				return idx, nil
			})
		}(i)
	}

	wg.Wait()

	// 不同 key 应该各执行一次
	if atomic.LoadInt32(&callCount) != 5 {
		t.Errorf("expected 5 calls for different keys, got %d", callCount)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// 缓存预热 nil client 测试
// ──────────────────────────────────────────────────────────────────────────────

func TestCacheManager_WarmUp_NilClient(t *testing.T) {
	cm := NewCacheManager(nil)
	ctx := context.Background()

	loaded, err := cm.WarmUp(ctx, time.Minute, func(ctx context.Context) (map[string]interface{}, error) {
		return map[string]interface{}{"key1": "val1"}, nil
	})

	if err != nil {
		t.Errorf("expected nil error, got %v", err)
	}
	if loaded != 0 {
		t.Errorf("expected 0 loaded, got %d", loaded)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// 常量值测试
// ──────────────────────────────────────────────────────────────────────────────

func TestTTLConstants(t *testing.T) {
	if TTLArticleList != 5*time.Minute {
		t.Errorf("TTLArticleList should be 5 minutes")
	}
	if TTLRecommendFeed != 10*time.Minute {
		t.Errorf("TTLRecommendFeed should be 10 minutes")
	}
	if TTLCognitiveTag != 30*time.Minute {
		t.Errorf("TTLCognitiveTag should be 30 minutes")
	}
	if TTLNullPlaceholder != 2*time.Minute {
		t.Errorf("TTLNullPlaceholder should be 2 minutes")
	}
}

func TestPrefixConstants(t *testing.T) {
	prefixes := []string{
		PrefixArticleList,
		PrefixRecommendFeed,
		PrefixCognitiveTag,
		PrefixArticleDetail,
		PrefixNullPlaceholder,
	}

	// 确保所有前缀以 "cache:" 开头
	for _, p := range prefixes {
		if len(p) < 7 || p[:6] != "cache:" {
			t.Errorf("prefix '%s' should start with 'cache:'", p)
		}
	}

	// 确保前缀互不相同
	seen := make(map[string]bool)
	for _, p := range prefixes {
		if seen[p] {
			t.Errorf("duplicate prefix: %s", p)
		}
		seen[p] = true
	}
}
