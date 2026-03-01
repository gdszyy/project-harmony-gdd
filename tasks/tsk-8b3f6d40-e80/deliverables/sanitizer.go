// Package logger 提供日志脱敏工具，用于在日志输出前自动掩码敏感信息。
//
// 支持以下脱敏场景：
//   - URL 查询参数中的 token/password/key 等敏感字段
//   - Request Body（JSON）中的 password/email/phone 等敏感字段
//   - Response 中的 JWT Token 截断显示
//   - 可配置的正则表达式脱敏规则
//
// 使用方式：
//
//	sanitizer := logger.NewSanitizer(logger.DefaultSanitizerConfig())
//	sanitizedText := sanitizer.Sanitize(rawText)
//
// 或通过 Gin 中间件自动脱敏：
//
//	r.Use(logger.SanitizeLoggerMiddleware(sanitizer))
package logger

import (
	"encoding/json"
	"net/url"
	"regexp"
	"strings"
	"sync"
)

// SensitiveLevel 定义敏感字段的脱敏级别
type SensitiveLevel int

const (
	// LevelPartialMask 部分掩码：显示前4位 + ****
	LevelPartialMask SensitiveLevel = iota
	// LevelFullMask 完全掩码：替换为 ****
	LevelFullMask
	// LevelTruncate 截断显示：显示前8位 + ...
	LevelTruncate
)

// SanitizeRule 定义一条脱敏规则
type SanitizeRule struct {
	// Name 规则名称（用于日志和调试）
	Name string `json:"name"`
	// Pattern 正则表达式模式
	Pattern string `json:"pattern"`
	// Level 脱敏级别
	Level SensitiveLevel `json:"level"`
	// compiled 编译后的正则表达式（内部使用）
	compiled *regexp.Regexp
}

// SanitizerConfig 定义脱敏器的完整配置
type SanitizerConfig struct {
	// URLParamKeys URL 查询参数中需要脱敏的键名（不区分大小写）
	URLParamKeys []string `json:"url_param_keys"`
	// BodyFieldKeys JSON Body 中需要脱敏的字段名（不区分大小写）
	BodyFieldKeys []string `json:"body_field_keys"`
	// RegexRules 自定义正则表达式脱敏规则
	RegexRules []SanitizeRule `json:"regex_rules"`
	// JWTTruncateLen JWT Token 截断显示长度（默认 16）
	JWTTruncateLen int `json:"jwt_truncate_len"`
}

// Sanitizer 日志脱敏器
type Sanitizer struct {
	config SanitizerConfig
	mu     sync.RWMutex

	// 预编译的正则表达式
	regexRules []*SanitizeRule
	// URL 参数键名集合（小写）
	urlParamSet map[string]bool
	// Body 字段键名集合（小写）
	bodyFieldSet map[string]bool

	// 预编译的通用正则
	jwtRegex   *regexp.Regexp
	emailRegex *regexp.Regexp
	phoneRegex *regexp.Regexp
}

// DefaultSanitizerConfig 返回默认的脱敏配置
func DefaultSanitizerConfig() SanitizerConfig {
	return SanitizerConfig{
		URLParamKeys: []string{
			"token", "access_token", "refresh_token",
			"password", "passwd", "pwd",
			"key", "api_key", "apikey", "secret",
			"authorization",
		},
		BodyFieldKeys: []string{
			"password", "passwd", "pwd", "old_password", "new_password",
			"confirm_password", "password_confirmation",
			"token", "access_token", "refresh_token",
			"api_key", "apikey", "secret", "secret_key",
			"email", "phone", "mobile", "telephone",
			"id_card", "id_number", "ssn",
			"credit_card", "card_number",
		},
		RegexRules: []SanitizeRule{
			{
				Name:    "bearer_token",
				Pattern: `(?i)(Bearer\s+)([A-Za-z0-9\-_\.]+)`,
				Level:   LevelTruncate,
			},
			{
				Name:    "api_key_header",
				Pattern: `(?i)(X-API-Key:\s*)([A-Za-z0-9\-_\.]+)`,
				Level:   LevelPartialMask,
			},
			{
				Name:    "authorization_header",
				Pattern: `(?i)(Authorization:\s*)(.+)`,
				Level:   LevelTruncate,
			},
		},
		JWTTruncateLen: 16,
	}
}

// NewSanitizer 根据配置创建脱敏器实例
func NewSanitizer(config SanitizerConfig) *Sanitizer {
	s := &Sanitizer{
		config:       config,
		urlParamSet:  make(map[string]bool),
		bodyFieldSet: make(map[string]bool),
	}

	// 构建 URL 参数键名集合
	for _, key := range config.URLParamKeys {
		s.urlParamSet[strings.ToLower(key)] = true
	}

	// 构建 Body 字段键名集合
	for _, key := range config.BodyFieldKeys {
		s.bodyFieldSet[strings.ToLower(key)] = true
	}

	// 编译正则规则
	for i := range config.RegexRules {
		rule := &config.RegexRules[i]
		compiled, err := regexp.Compile(rule.Pattern)
		if err != nil {
			continue // 跳过无效的正则表达式
		}
		rule.compiled = compiled
		s.regexRules = append(s.regexRules, rule)
	}

	// 预编译通用正则
	// JWT Token 格式: eyXXX.eyXXX.XXXXX
	s.jwtRegex = regexp.MustCompile(`eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+`)
	// Email 格式
	s.emailRegex = regexp.MustCompile(`[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}`)
	// 中国手机号格式
	s.phoneRegex = regexp.MustCompile(`(?:^|[^0-9])(1[3-9]\d{9})(?:[^0-9]|$)`)

	if config.JWTTruncateLen <= 0 {
		s.config.JWTTruncateLen = 16
	}

	return s
}

// Sanitize 对文本进行全面脱敏处理
func (s *Sanitizer) Sanitize(text string) string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := text

	// 1. 应用自定义正则规则
	result = s.applyRegexRules(result)

	// 2. 脱敏 JWT Token
	result = s.sanitizeJWT(result)

	// 3. 脱敏 Email
	result = s.sanitizeEmail(result)

	// 4. 脱敏手机号
	result = s.sanitizePhone(result)

	return result
}

// SanitizeURL 对 URL 中的查询参数进行脱敏
func (s *Sanitizer) SanitizeURL(rawURL string) string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	// 尝试解析 URL
	parsedURL, err := url.Parse(rawURL)
	if err != nil {
		// 解析失败，回退到通用脱敏
		return s.Sanitize(rawURL)
	}

	// 脱敏查询参数
	query := parsedURL.Query()
	modified := false
	for key := range query {
		if s.isSensitiveURLParam(key) {
			values := query[key]
			for i, v := range values {
				values[i] = maskValue(v, LevelPartialMask)
			}
			query[key] = values
			modified = true
		}
	}

	if modified {
		parsedURL.RawQuery = query.Encode()
	}

	return parsedURL.String()
}

// SanitizeJSON 对 JSON 字符串中的敏感字段进行脱敏
func (s *Sanitizer) SanitizeJSON(jsonStr string) string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var data interface{}
	if err := json.Unmarshal([]byte(jsonStr), &data); err != nil {
		// 不是合法 JSON，回退到通用脱敏
		return s.Sanitize(jsonStr)
	}

	sanitized := s.sanitizeJSONValue(data)
	result, err := json.Marshal(sanitized)
	if err != nil {
		return s.Sanitize(jsonStr)
	}

	return string(result)
}

// SanitizeHeaders 对 HTTP 头部进行脱敏
func (s *Sanitizer) SanitizeHeaders(headers map[string][]string) map[string][]string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	sanitized := make(map[string][]string)
	sensitiveHeaders := map[string]bool{
		"authorization":   true,
		"x-api-key":       true,
		"cookie":          true,
		"set-cookie":      true,
		"x-auth-token":    true,
		"proxy-authorization": true,
	}

	for key, values := range headers {
		lowerKey := strings.ToLower(key)
		if sensitiveHeaders[lowerKey] {
			masked := make([]string, len(values))
			for i, v := range values {
				masked[i] = maskValue(v, LevelTruncate)
			}
			sanitized[key] = masked
		} else {
			sanitized[key] = values
		}
	}

	return sanitized
}

// UpdateConfig 动态更新脱敏配置（线程安全）
func (s *Sanitizer) UpdateConfig(config SanitizerConfig) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.config = config

	// 重建键名集合
	s.urlParamSet = make(map[string]bool)
	for _, key := range config.URLParamKeys {
		s.urlParamSet[strings.ToLower(key)] = true
	}

	s.bodyFieldSet = make(map[string]bool)
	for _, key := range config.BodyFieldKeys {
		s.bodyFieldSet[strings.ToLower(key)] = true
	}

	// 重新编译正则规则
	s.regexRules = nil
	for i := range config.RegexRules {
		rule := &config.RegexRules[i]
		compiled, err := regexp.Compile(rule.Pattern)
		if err != nil {
			continue
		}
		rule.compiled = compiled
		s.regexRules = append(s.regexRules, rule)
	}

	if config.JWTTruncateLen > 0 {
		s.config.JWTTruncateLen = config.JWTTruncateLen
	}
}

// ---- 内部方法 ----

// isSensitiveURLParam 判断 URL 参数键名是否为敏感字段
func (s *Sanitizer) isSensitiveURLParam(key string) bool {
	return s.urlParamSet[strings.ToLower(key)]
}

// isSensitiveBodyField 判断 JSON 字段名是否为敏感字段
func (s *Sanitizer) isSensitiveBodyField(key string) bool {
	return s.bodyFieldSet[strings.ToLower(key)]
}

// applyRegexRules 应用自定义正则脱敏规则
func (s *Sanitizer) applyRegexRules(text string) string {
	result := text
	for _, rule := range s.regexRules {
		if rule.compiled == nil {
			continue
		}
		result = rule.compiled.ReplaceAllStringFunc(result, func(match string) string {
			submatches := rule.compiled.FindStringSubmatch(match)
			if len(submatches) >= 3 {
				// 保留前缀（如 "Bearer "），掩码后续内容
				prefix := submatches[1]
				sensitive := submatches[2]
				return prefix + maskValue(sensitive, rule.Level)
			}
			return maskValue(match, rule.Level)
		})
	}
	return result
}

// sanitizeJWT 脱敏 JWT Token
func (s *Sanitizer) sanitizeJWT(text string) string {
	return s.jwtRegex.ReplaceAllStringFunc(text, func(match string) string {
		truncLen := s.config.JWTTruncateLen
		if len(match) <= truncLen {
			return match
		}
		return match[:truncLen] + "...[REDACTED]"
	})
}

// sanitizeEmail 脱敏 Email 地址
func (s *Sanitizer) sanitizeEmail(text string) string {
	return s.emailRegex.ReplaceAllStringFunc(text, func(match string) string {
		parts := strings.SplitN(match, "@", 2)
		if len(parts) != 2 {
			return maskValue(match, LevelFullMask)
		}
		local := parts[0]
		domain := parts[1]
		if len(local) <= 2 {
			return local + "***@" + domain
		}
		return local[:2] + "***@" + domain
	})
}

// sanitizePhone 脱敏手机号
func (s *Sanitizer) sanitizePhone(text string) string {
	return s.phoneRegex.ReplaceAllStringFunc(text, func(match string) string {
		// 提取纯数字部分
		digits := ""
		prefix := ""
		suffix := ""
		for i, c := range match {
			if c >= '0' && c <= '9' {
				if digits == "" {
					prefix = match[:i]
				}
				digits += string(c)
			} else if digits != "" {
				suffix = match[i:]
				break
			}
		}
		if len(digits) == 11 {
			return prefix + digits[:3] + "****" + digits[7:] + suffix
		}
		return match
	})
}

// sanitizeJSONValue 递归脱敏 JSON 值
func (s *Sanitizer) sanitizeJSONValue(v interface{}) interface{} {
	switch val := v.(type) {
	case map[string]interface{}:
		result := make(map[string]interface{})
		for key, value := range val {
			if s.isSensitiveBodyField(key) {
				switch sv := value.(type) {
				case string:
					result[key] = maskValue(sv, s.getLevelForField(key))
				default:
					result[key] = "****"
				}
			} else {
				result[key] = s.sanitizeJSONValue(value)
			}
		}
		return result
	case []interface{}:
		result := make([]interface{}, len(val))
		for i, item := range val {
			result[i] = s.sanitizeJSONValue(item)
		}
		return result
	default:
		return v
	}
}

// getLevelForField 根据字段名返回合适的脱敏级别
func (s *Sanitizer) getLevelForField(field string) SensitiveLevel {
	lowerField := strings.ToLower(field)
	switch {
	case strings.Contains(lowerField, "token"):
		return LevelTruncate
	case strings.Contains(lowerField, "password") || strings.Contains(lowerField, "passwd") ||
		strings.Contains(lowerField, "pwd") || strings.Contains(lowerField, "secret"):
		return LevelFullMask
	case strings.Contains(lowerField, "email"):
		return LevelPartialMask
	case strings.Contains(lowerField, "phone") || strings.Contains(lowerField, "mobile"):
		return LevelPartialMask
	case strings.Contains(lowerField, "key"):
		return LevelPartialMask
	default:
		return LevelPartialMask
	}
}

// maskValue 根据脱敏级别对值进行掩码处理
func maskValue(value string, level SensitiveLevel) string {
	if value == "" {
		return value
	}

	switch level {
	case LevelPartialMask:
		// 显示前4位 + ****
		if len(value) <= 4 {
			return "****"
		}
		return value[:4] + "****"
	case LevelFullMask:
		// 完全掩码
		return "****"
	case LevelTruncate:
		// 显示前8位 + ...
		if len(value) <= 8 {
			return "****"
		}
		return value[:8] + "..."
	default:
		return "****"
	}
}
