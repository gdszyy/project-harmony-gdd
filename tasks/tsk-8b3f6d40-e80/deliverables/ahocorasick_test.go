package safety

import (
	"testing"
)

func TestAhoCorasickSinglePattern(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPattern("test")
	ac.Build()

	matches := ac.Search("this is a test string")
	if len(matches) != 1 {
		t.Errorf("Expected 1 match, got %d", len(matches))
	}
	if matches[0].Pattern != "test" {
		t.Errorf("Expected pattern 'test', got '%s'", matches[0].Pattern)
	}
	if matches[0].Position != 10 {
		t.Errorf("Expected position 10, got %d", matches[0].Position)
	}
}

func TestAhoCorasickMultiplePatterns(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPatterns([]string{"he", "she", "his", "hers"})
	ac.Build()

	matches := ac.Search("ushers")
	found := make(map[string]bool)
	for _, m := range matches {
		found[m.Pattern] = true
	}

	// "she", "he", "hers" should be found in "ushers"
	if !found["she"] {
		t.Error("Expected to find 'she'")
	}
	if !found["he"] {
		t.Error("Expected to find 'he'")
	}
	if !found["hers"] {
		t.Error("Expected to find 'hers'")
	}
}

func TestAhoCorasickOverlapping(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPatterns([]string{"abc", "bcd", "cde"})
	ac.Build()

	matches := ac.Search("abcde")
	if len(matches) != 3 {
		t.Errorf("Expected 3 matches, got %d", len(matches))
	}
}

func TestAhoCorasickNoMatch(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPattern("xyz")
	ac.Build()

	matches := ac.Search("hello world")
	if len(matches) != 0 {
		t.Errorf("Expected 0 matches, got %d", len(matches))
	}
}

func TestAhoCorasickEmptyText(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPattern("test")
	ac.Build()

	matches := ac.Search("")
	if len(matches) != 0 {
		t.Errorf("Expected 0 matches for empty text, got %d", len(matches))
	}
}

func TestAhoCorasickUnicode(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPattern("你好")
	ac.AddPattern("世界")
	ac.Build()

	matches := ac.Search("你好世界")
	if len(matches) != 2 {
		t.Errorf("Expected 2 matches, got %d", len(matches))
	}
}

func TestAhoCorasickDuplicatePatterns(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPattern("test")
	ac.AddPattern("test")
	ac.Build()

	matches := ac.Search("test")
	// 两个相同的模式都应该被匹配
	if len(matches) != 2 {
		t.Errorf("Expected 2 matches for duplicate patterns, got %d", len(matches))
	}
}

func TestAhoCorasickPatternCount(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPattern("a")
	ac.AddPattern("b")
	ac.AddPattern("c")

	if ac.PatternCount() != 3 {
		t.Errorf("Expected pattern count 3, got %d", ac.PatternCount())
	}
}

func TestAhoCorasickAutoBuild(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPattern("test")
	// 不手动调用 Build()，Search 应自动构建

	matches := ac.Search("this is a test")
	if len(matches) != 1 {
		t.Errorf("Expected 1 match with auto-build, got %d", len(matches))
	}
}

func TestAhoCorasickLongText(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPattern("needle")
	ac.Build()

	// 生成长文本
	text := ""
	for i := 0; i < 1000; i++ {
		text += "haystack "
	}
	text += "needle"
	text += " more haystack"

	matches := ac.Search(text)
	if len(matches) != 1 {
		t.Errorf("Expected 1 match in long text, got %d", len(matches))
	}
}

func TestAhoCorasickSubstringPatterns(t *testing.T) {
	ac := NewAhoCorasick()
	ac.AddPattern("a")
	ac.AddPattern("ab")
	ac.AddPattern("abc")
	ac.Build()

	matches := ac.Search("abc")
	found := make(map[string]bool)
	for _, m := range matches {
		found[m.Pattern] = true
	}

	if !found["a"] {
		t.Error("Expected to find 'a'")
	}
	if !found["ab"] {
		t.Error("Expected to find 'ab'")
	}
	if !found["abc"] {
		t.Error("Expected to find 'abc'")
	}
}
