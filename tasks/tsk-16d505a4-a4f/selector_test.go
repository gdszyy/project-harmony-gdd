package examples

import (
	"testing"
)

func TestNewSelector(t *testing.T) {
	s, err := NewSelector()
	if err != nil {
		t.Fatalf("NewSelector() error: %v", err)
	}

	count := s.GetExampleCount()
	if count < 20 {
		t.Errorf("Expected at least 20 examples, got %d", count)
	}
	t.Logf("Loaded %d examples", count)
}

func TestSelectByDomain(t *testing.T) {
	s, err := NewSelector()
	if err != nil {
		t.Fatalf("NewSelector() error: %v", err)
	}

	criteria := SelectionCriteria{
		UserDomains:   []string{"biology", "ecology"},
		ArticleDomain: "computer_science",
		MaxResults:    3,
		MinQuality:    0.80,
	}

	results := s.Select(criteria)
	if len(results) == 0 {
		t.Error("Expected at least one result for biology->computer_science query")
	}

	t.Logf("Selected %d examples for biology->computer_science:", len(results))
	for _, ex := range results {
		t.Logf("  - [%s] %s -> %s: %s", ex.HookType, ex.FromDomain, ex.ToDomain, ex.HookText[:50])
	}
}

func TestSelectByHookType(t *testing.T) {
	s, err := NewSelector()
	if err != nil {
		t.Fatalf("NewSelector() error: %v", err)
	}

	criteria := SelectionCriteria{
		UserDomains:       []string{"physics"},
		ArticleDomain:     "economics",
		PreferredHookType: HookMethodTransfer,
		MaxResults:        3,
		MinQuality:        0.80,
	}

	results := s.Select(criteria)
	if len(results) == 0 {
		t.Error("Expected at least one result for physics->economics with method_transfer")
	}

	t.Logf("Selected %d examples for physics->economics (method_transfer preferred):", len(results))
	for _, ex := range results {
		t.Logf("  - [%s] %s -> %s (score: %.2f)", ex.HookType, ex.FromDomain, ex.ToDomain, ex.QualityScore)
	}
}

func TestSelectDiversity(t *testing.T) {
	s, err := NewSelector()
	if err != nil {
		t.Fatalf("NewSelector() error: %v", err)
	}

	criteria := SelectionCriteria{
		UserDomains:   []string{"psychology", "neuroscience", "biology"},
		ArticleDomain: "computer_science",
		MaxResults:    5,
		MinQuality:    0.80,
	}

	results := s.Select(criteria)

	// 检查类型多样性
	typeCount := make(map[HookType]int)
	for _, ex := range results {
		typeCount[ex.HookType]++
	}

	for ht, count := range typeCount {
		if count > 2 {
			t.Errorf("Hook type %s appeared %d times (max 2 for diversity)", ht, count)
		}
	}

	t.Logf("Selected %d examples with %d distinct hook types", len(results), len(typeCount))
}

func TestFormatAsPromptExamples(t *testing.T) {
	examples := []*Example{
		{
			ID:            "test-1",
			HookType:      HookStructuralAnalogy,
			FromDomain:    "biology",
			ToDomain:      "computer_science",
			FromConcept:   "蚁群信息素通信",
			ToConcept:     "分布式路由算法",
			HookText:      "蚂蚁用信息素找到最短觅食路径的方式，和互联网数据包寻找最优传输路线的算法，共享同一套数学模型。",
			BridgeConcept: "正反馈+挥发的去中心化优化",
		},
	}

	formatted := FormatAsPromptExamples(examples)
	if formatted == "" {
		t.Error("FormatAsPromptExamples returned empty string")
	}

	if !contains(formatted, "结构类比") {
		t.Error("Expected formatted output to contain hook type label")
	}

	if !contains(formatted, "蚂蚁用信息素") {
		t.Error("Expected formatted output to contain hook text")
	}

	t.Logf("Formatted output:\n%s", formatted)
}

func TestGetDomains(t *testing.T) {
	s, err := NewSelector()
	if err != nil {
		t.Fatalf("NewSelector() error: %v", err)
	}

	domains := s.GetDomains()
	if len(domains) < 10 {
		t.Errorf("Expected at least 10 domains, got %d", len(domains))
	}

	t.Logf("Domains: %v", domains)
}

func TestEmptySelection(t *testing.T) {
	s, err := NewSelector()
	if err != nil {
		t.Fatalf("NewSelector() error: %v", err)
	}

	// 使用不存在的领域
	criteria := SelectionCriteria{
		UserDomains:   []string{"nonexistent_domain_xyz"},
		ArticleDomain: "another_nonexistent_domain",
		MaxResults:    3,
		MinQuality:    0.99, // 极高的质量阈值
	}

	results := s.Select(criteria)
	// 即使没有完美匹配，也应该返回一些结果（基于质量分数）
	t.Logf("Results for non-matching criteria: %d", len(results))
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsHelper(s, substr))
}

func containsHelper(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
