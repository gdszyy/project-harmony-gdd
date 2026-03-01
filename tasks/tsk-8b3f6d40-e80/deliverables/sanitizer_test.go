package logger

import (
	"testing"
)

func TestMaskValue(t *testing.T) {
	tests := []struct {
		name     string
		value    string
		level    SensitiveLevel
		expected string
	}{
		{"partial_mask_long", "abcdefghij", LevelPartialMask, "abcd****"},
		{"partial_mask_short", "abc", LevelPartialMask, "****"},
		{"partial_mask_exact4", "abcd", LevelPartialMask, "****"},
		{"full_mask", "mysecretpassword", LevelFullMask, "****"},
		{"truncate_long", "eyJhbGciOiJIUzI1NiJ9.payload.signature", LevelTruncate, "eyJhbGci..."},
		{"truncate_short", "short", LevelTruncate, "****"},
		{"empty_string", "", LevelPartialMask, ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := maskValue(tt.value, tt.level)
			if result != tt.expected {
				t.Errorf("maskValue(%q, %d) = %q, want %q", tt.value, tt.level, result, tt.expected)
			}
		})
	}
}

func TestSanitizeURL(t *testing.T) {
	s := NewSanitizer(DefaultSanitizerConfig())

	tests := []struct {
		name     string
		url      string
		contains string // 期望结果中包含的字符串
		notContains string // 期望结果中不包含的字符串
	}{
		{
			name:        "token_in_url",
			url:         "/api/v1/auth?token=eyJhbGciOiJIUzI1NiJ9.payload.sig",
			contains:    "%2A%2A%2A%2A", // URL-encoded ****
			notContains: "payload",
		},
		{
			name:        "password_in_url",
			url:         "/api/v1/login?password=mysecretpassword",
			contains:    "%2A%2A%2A%2A", // URL-encoded ****
			notContains: "mysecretpassword",
		},
		{
			name:        "api_key_in_url",
			url:         "/api/v1/data?api_key=sk-1234567890abcdef",
			contains:    "%2A%2A%2A%2A", // URL-encoded ****
			notContains: "1234567890abcdef",
		},
		{
			name:     "normal_url_unchanged",
			url:      "/api/v1/articles?page=1&limit=20",
			contains: "page=1",
		},
		{
			name:     "no_query_params",
			url:      "/api/v1/health",
			contains: "/api/v1/health",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := s.SanitizeURL(tt.url)
			if tt.contains != "" && !containsStr(result, tt.contains) {
				t.Errorf("SanitizeURL(%q) = %q, expected to contain %q", tt.url, result, tt.contains)
			}
			if tt.notContains != "" && containsStr(result, tt.notContains) {
				t.Errorf("SanitizeURL(%q) = %q, expected NOT to contain %q", tt.url, result, tt.notContains)
			}
		})
	}
}

func TestSanitizeJSON(t *testing.T) {
	s := NewSanitizer(DefaultSanitizerConfig())

	tests := []struct {
		name        string
		json        string
		notContains string
	}{
		{
			name:        "password_field",
			json:        `{"username":"john","password":"secret123"}`,
			notContains: "secret123",
		},
		{
			name:        "email_field",
			json:        `{"email":"john@example.com","name":"John"}`,
			notContains: "john@example.com",
		},
		{
			name:        "nested_sensitive",
			json:        `{"user":{"email":"test@test.com","password":"pass123"}}`,
			notContains: "pass123",
		},
		{
			name:        "token_field",
			json:        `{"access_token":"eyJhbGciOiJIUzI1NiJ9.payload.signature"}`,
			notContains: "signature",
		},
		{
			name:        "phone_field",
			json:        `{"phone":"13812345678","name":"test"}`,
			notContains: "13812345678",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := s.SanitizeJSON(tt.json)
			if containsStr(result, tt.notContains) {
				t.Errorf("SanitizeJSON(%q) = %q, expected NOT to contain %q", tt.json, result, tt.notContains)
			}
		})
	}
}

func TestSanitizeJWT(t *testing.T) {
	s := NewSanitizer(DefaultSanitizerConfig())

	jwt := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
	result := s.Sanitize(jwt)

	if result == jwt {
		t.Error("JWT should be sanitized but was returned unchanged")
	}
	if !containsStr(result, "...[REDACTED]") {
		t.Errorf("Sanitized JWT should contain '...[REDACTED]', got: %s", result)
	}
}

func TestSanitizeEmail(t *testing.T) {
	s := NewSanitizer(DefaultSanitizerConfig())

	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{"normal_email", "user john@example.com logged in", "user jo***@example.com logged in"},
		{"short_local", "a@test.com", "a***@test.com"},
		{"no_email", "no email here", "no email here"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := s.Sanitize(tt.input)
			if result != tt.expected {
				t.Errorf("Sanitize(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestSanitizePhone(t *testing.T) {
	s := NewSanitizer(DefaultSanitizerConfig())

	tests := []struct {
		name        string
		input       string
		notContains string
		contains    string
	}{
		{
			name:        "chinese_phone",
			input:       "phone: 13812345678 end",
			notContains: "13812345678",
			contains:    "138****5678",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := s.Sanitize(tt.input)
			if tt.notContains != "" && containsStr(result, tt.notContains) {
				t.Errorf("Sanitize(%q) = %q, expected NOT to contain %q", tt.input, result, tt.notContains)
			}
			if tt.contains != "" && !containsStr(result, tt.contains) {
				t.Errorf("Sanitize(%q) = %q, expected to contain %q", tt.input, result, tt.contains)
			}
		})
	}
}

func TestSanitizeBearerToken(t *testing.T) {
	s := NewSanitizer(DefaultSanitizerConfig())

	input := "Authorization: Bearer sk-1234567890abcdefghijklmnop"
	result := s.Sanitize(input)

	if containsStr(result, "abcdefghijklmnop") {
		t.Errorf("Bearer token should be sanitized, got: %s", result)
	}
}

func TestSanitizeHeaders(t *testing.T) {
	s := NewSanitizer(DefaultSanitizerConfig())

	headers := map[string][]string{
		"Authorization": {"Bearer eyJhbGciOiJIUzI1NiJ9.payload.signature"},
		"X-API-Key":     {"sk-1234567890abcdef"},
		"Content-Type":  {"application/json"},
	}

	result := s.SanitizeHeaders(headers)

	// Authorization should be masked
	if result["Authorization"][0] == headers["Authorization"][0] {
		t.Error("Authorization header should be sanitized")
	}

	// X-API-Key should be masked
	if result["X-API-Key"][0] == headers["X-API-Key"][0] {
		t.Error("X-API-Key header should be sanitized")
	}

	// Content-Type should remain unchanged
	if result["Content-Type"][0] != "application/json" {
		t.Error("Content-Type header should not be modified")
	}
}

func TestUpdateConfig(t *testing.T) {
	s := NewSanitizer(DefaultSanitizerConfig())

	// 添加自定义敏感字段
	newConfig := DefaultSanitizerConfig()
	newConfig.BodyFieldKeys = append(newConfig.BodyFieldKeys, "custom_secret")

	s.UpdateConfig(newConfig)

	// 测试新字段是否生效
	result := s.SanitizeJSON(`{"custom_secret":"my-secret-value"}`)
	if containsStr(result, "my-secret-value") {
		t.Error("custom_secret should be sanitized after config update")
	}
}

func TestInvalidJSON(t *testing.T) {
	s := NewSanitizer(DefaultSanitizerConfig())

	// 非法 JSON 应回退到通用脱敏
	result := s.SanitizeJSON("this is not json with john@example.com")
	if containsStr(result, "john@example.com") {
		t.Error("Email in invalid JSON should still be sanitized")
	}
}

func TestEmptyInput(t *testing.T) {
	s := NewSanitizer(DefaultSanitizerConfig())

	if s.Sanitize("") != "" {
		t.Error("Empty string should return empty string")
	}
	if s.SanitizeURL("") != "" {
		t.Error("Empty URL should return empty string")
	}
	if s.SanitizeJSON("") != "" {
		t.Error("Empty JSON should return empty string")
	}
}

// containsStr 辅助函数：检查字符串是否包含子串
func containsStr(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(substr) == 0 || findSubstr(s, substr))
}

func findSubstr(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
