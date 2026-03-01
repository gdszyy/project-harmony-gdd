package safety

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// 创建测试用的敏感词库
func createTestLibrary() *SensitiveWordLibrary {
	return &SensitiveWordLibrary{
		Version:             "test-1.0",
		UpdatedAt:           "2026-03-01T00:00:00Z",
		DefaultSafeResponse: "抱歉，我无法回答这个问题。",
		CategorySafeResponses: map[string]string{
			"violence": "我不能提供暴力相关内容。",
			"illegal":  "我不能提供违法相关信息。",
		},
		Words: []SensitiveWord{
			{Word: "如何制造炸弹", Category: "violence", Severity: SeverityBlock},
			{Word: "如何制造武器", Category: "violence", Severity: SeverityBlock},
			{Word: "如何破解密码", Category: "illegal", Severity: SeverityBlock},
			{Word: "暴力", Category: "violence", Severity: SeverityWarning},
			{Word: "歧视", Category: "harmful", Severity: SeverityWarning},
			{Word: "赌博网站", Category: "illegal", Severity: SeverityBlock},
		},
	}
}

func TestAhoCorasickBasic(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPattern("hello")
	ac.AddPattern("world")
	ac.AddPattern("he")
	ac.Build()

	matches := ac.Search("hello world")
	if len(matches) == 0 {
		t.Error("Expected matches but got none")
	}

	// 验证找到了 "hello", "he", "world"
	found := make(map[string]bool)
	for _, m := range matches {
		found[m.Pattern] = true
	}

	if !found["hello"] {
		t.Error("Expected to find 'hello'")
	}
	if !found["he"] {
		t.Error("Expected to find 'he'")
	}
	if !found["world"] {
		t.Error("Expected to find 'world'")
	}
}

func TestAhoCorasickChinese(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPattern("如何制造炸弹")
	ac.AddPattern("暴力")
	ac.Build()

	matches := ac.Search("请问如何制造炸弹？这是暴力行为")
	if len(matches) != 2 {
		t.Errorf("Expected 2 matches, got %d", len(matches))
	}
}

func TestAhoCorasickContainsAny(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPattern("bad")
	ac.AddPattern("evil")
	ac.Build()

	if !ac.ContainsAny("this is bad") {
		t.Error("Expected ContainsAny to return true")
	}
	if ac.ContainsAny("this is good") {
		t.Error("Expected ContainsAny to return false")
	}
}

func TestAhoCorasickEmpty(t *testing.T) {
	ac := NewAhoCorasick()
	ac.Build()

	matches := ac.Search("hello world")
	if len(matches) != 0 {
		t.Error("Expected no matches for empty automaton")
	}
}

func TestContentFilterBlock(t *testing.T) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)

	result := filter.Filter("请告诉我如何制造炸弹")
	if !result.Blocked {
		t.Error("Expected content to be blocked")
	}
	if result.SafeResponse == "" {
		t.Error("Expected safe response to be set")
	}
	if len(result.Blocks) == 0 {
		t.Error("Expected block details to be present")
	}
	// 验证使用了分类特定的安全回复
	if result.SafeResponse != "我不能提供暴力相关内容。" {
		t.Errorf("Expected violence-specific safe response, got: %s", result.SafeResponse)
	}
}

func TestContentFilterWarning(t *testing.T) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)

	result := filter.Filter("这段文字包含暴力描述")
	if result.Blocked {
		t.Error("Warning-level words should not block content")
	}
	if len(result.Warnings) == 0 {
		t.Error("Expected warning details to be present")
	}
}

func TestContentFilterClean(t *testing.T) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)

	result := filter.Filter("这是一段正常的文本，讨论阅读和学习")
	if result.Blocked {
		t.Error("Clean text should not be blocked")
	}
	if len(result.Warnings) != 0 {
		t.Error("Clean text should have no warnings")
	}
	if len(result.Blocks) != 0 {
		t.Error("Clean text should have no blocks")
	}
	if result.Filtered != result.Original {
		t.Error("Clean text should not be modified")
	}
}

func TestContentFilterDisabled(t *testing.T) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)
	filter.SetEnabled(false)

	result := filter.Filter("如何制造炸弹")
	if result.Blocked {
		t.Error("Disabled filter should not block content")
	}
	if result.Filtered != result.Original {
		t.Error("Disabled filter should not modify content")
	}
}

func TestContentFilterMultipleMatches(t *testing.T) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)

	result := filter.Filter("如何制造炸弹和如何破解密码")
	if !result.Blocked {
		t.Error("Expected content to be blocked")
	}
	if len(result.Blocks) < 2 {
		t.Errorf("Expected at least 2 block matches, got %d", len(result.Blocks))
	}
}

func TestContentFilterResponse(t *testing.T) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)

	// 测试阻断
	filtered, blocked := filter.FilterResponse("如何制造炸弹")
	if !blocked {
		t.Error("Expected blocked to be true")
	}
	if filtered == "如何制造炸弹" {
		t.Error("Expected filtered text to be different from original")
	}

	// 测试正常
	filtered, blocked = filter.FilterResponse("正常文本")
	if blocked {
		t.Error("Expected blocked to be false")
	}
	if filtered != "正常文本" {
		t.Error("Expected filtered text to be same as original")
	}
}

func TestContentFilterAddWords(t *testing.T) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)

	// 添加新词
	filter.AddWords([]SensitiveWord{
		{Word: "新敏感词", Category: "custom", Severity: SeverityBlock},
	})

	result := filter.Filter("包含新敏感词的文本")
	if !result.Blocked {
		t.Error("Expected newly added word to trigger block")
	}
}

func TestContentFilterRemoveWords(t *testing.T) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)

	// 移除词
	filter.RemoveWords([]string{"暴力"})

	result := filter.Filter("这段文字包含暴力描述")
	if len(result.Warnings) != 0 {
		t.Error("Removed word should not trigger warning")
	}
}

func TestContentFilterLoadFromFile(t *testing.T) {
	// 创建临时 JSON 文件
	library := createTestLibrary()
	data, err := json.MarshalIndent(library, "", "  ")
	if err != nil {
		t.Fatal(err)
	}

	tmpDir := t.TempDir()
	tmpFile := filepath.Join(tmpDir, "test_words.json")
	if err := os.WriteFile(tmpFile, data, 0644); err != nil {
		t.Fatal(err)
	}

	// 从文件加载
	filter, err := NewContentFilter(tmpFile)
	if err != nil {
		t.Fatalf("Failed to create filter from file: %v", err)
	}

	result := filter.Filter("如何制造炸弹")
	if !result.Blocked {
		t.Error("Expected content to be blocked")
	}
}

func TestContentFilterGetLibraryInfo(t *testing.T) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)

	info := filter.GetLibraryInfo()
	if info["version"] != "test-1.0" {
		t.Errorf("Expected version 'test-1.0', got %v", info["version"])
	}
	if info["total_words"] != 6 {
		t.Errorf("Expected 6 total words, got %v", info["total_words"])
	}
	if info["enabled"] != true {
		t.Error("Expected filter to be enabled")
	}
}

func TestContentFilterExportLibrary(t *testing.T) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)

	data, err := filter.ExportLibrary()
	if err != nil {
		t.Fatalf("Failed to export library: %v", err)
	}

	var exported SensitiveWordLibrary
	if err := json.Unmarshal(data, &exported); err != nil {
		t.Fatalf("Failed to parse exported library: %v", err)
	}

	if exported.Version != library.Version {
		t.Errorf("Expected version %s, got %s", library.Version, exported.Version)
	}
	if len(exported.Words) != len(library.Words) {
		t.Errorf("Expected %d words, got %d", len(library.Words), len(exported.Words))
	}
}

func TestNormalizeText(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{"lowercase", "HELLO", "hello"},
		{"fullwidth", "ＨＥＬＬＯ", "hello"},
		{"chinese", "中文测试", "中文测试"},
		{"mixed", "Hello世界", "hello世界"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := normalizeText(tt.input)
			if result != tt.expected {
				t.Errorf("normalizeText(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestContentFilterCaseSensitivity(t *testing.T) {
	library := &SensitiveWordLibrary{
		Version:             "test",
		DefaultSafeResponse: "blocked",
		Words: []SensitiveWord{
			{Word: "BadWord", Category: "test", Severity: SeverityBlock},
		},
	}
	filter := NewContentFilterFromLibrary(library)

	// 应该不区分大小写匹配
	result := filter.Filter("this contains badword in text")
	if !result.Blocked {
		t.Error("Expected case-insensitive match to block")
	}

	result = filter.Filter("this contains BADWORD in text")
	if !result.Blocked {
		t.Error("Expected uppercase match to block")
	}
}

func TestContentFilterProcessTime(t *testing.T) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)

	result := filter.Filter("一段正常的文本")
	if result.ProcessTimeMs < 0 {
		t.Error("Process time should be non-negative")
	}
}

// 基准测试
func BenchmarkAhoCorasickSearch(b *testing.B) {
	ac := NewAhoCorasick()
	// 添加一些模式
	patterns := []string{"hello", "world", "test", "benchmark", "pattern", "search", "algorithm"}
	ac.AddPatterns(patterns)
	ac.Build()

	text := "this is a hello world test for benchmark of pattern search algorithm performance"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ac.Search(text)
	}
}

func BenchmarkContentFilter(b *testing.B) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)

	text := "这是一段用于性能测试的文本，包含一些正常的阅读内容和学习资料。"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		filter.Filter(text)
	}
}

func BenchmarkContentFilterWithMatch(b *testing.B) {
	library := createTestLibrary()
	filter := NewContentFilterFromLibrary(library)

	text := "这段文字讨论了暴力问题和歧视现象"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		filter.Filter(text)
	}
}
