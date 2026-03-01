// Package safety 提供 AI 内容安全过滤功能。
//
// ContentFilter 是 AI 生成内容的安全审查组件，集成到 AI Engine
// 的响应管道中，对 AI 生成的文本进行敏感词检测和分级处理。
//
// 核心特性：
//   - 可配置的 JSON 敏感词库，支持热更新
//   - 基于 Aho-Corasick 算法的高效多模式匹配
//   - 分级处理：警告级（记录日志）和阻断级（替换为安全回复）
//   - 线程安全，支持并发调用
//
// 使用方式：
//
//	filter, err := safety.NewContentFilter("sensitive_words.json")
//	result := filter.Filter(aiResponse)
//	if result.Blocked {
//	    // 使用安全回复替换原始内容
//	    response = result.SafeResponse
//	}
package safety

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"sync"
	"time"
	"unicode"
)

// SeverityLevel 定义敏感词的严重级别
type SeverityLevel string

const (
	// SeverityWarning 警告级别：记录日志但不阻断
	SeverityWarning SeverityLevel = "warning"
	// SeverityBlock 阻断级别：替换为安全回复
	SeverityBlock SeverityLevel = "block"
)

// SensitiveWord 定义一个敏感词条目
type SensitiveWord struct {
	// Word 敏感词文本
	Word string `json:"word"`
	// Category 分类（如 "政治"、"暴力"、"色情"、"广告" 等）
	Category string `json:"category"`
	// Severity 严重级别
	Severity SeverityLevel `json:"severity"`
}

// SensitiveWordLibrary 定义敏感词库的 JSON 结构
type SensitiveWordLibrary struct {
	// Version 词库版本
	Version string `json:"version"`
	// UpdatedAt 最后更新时间
	UpdatedAt string `json:"updated_at"`
	// DefaultSafeResponse 默认安全回复
	DefaultSafeResponse string `json:"default_safe_response"`
	// CategorySafeResponses 按分类的安全回复
	CategorySafeResponses map[string]string `json:"category_safe_responses"`
	// Words 敏感词列表
	Words []SensitiveWord `json:"words"`
}

// FilterResult 过滤结果
type FilterResult struct {
	// Original 原始文本
	Original string `json:"original"`
	// Filtered 过滤后的文本（如果被阻断则为安全回复）
	Filtered string `json:"filtered"`
	// Blocked 是否被阻断
	Blocked bool `json:"blocked"`
	// SafeResponse 安全回复（仅在 Blocked=true 时有值）
	SafeResponse string `json:"safe_response,omitempty"`
	// Warnings 警告级别的匹配列表
	Warnings []MatchDetail `json:"warnings,omitempty"`
	// Blocks 阻断级别的匹配列表
	Blocks []MatchDetail `json:"blocks,omitempty"`
	// ProcessTimeMs 处理耗时（毫秒）
	ProcessTimeMs int64 `json:"process_time_ms"`
}

// MatchDetail 匹配详情
type MatchDetail struct {
	// Word 匹配到的敏感词
	Word string `json:"word"`
	// Category 分类
	Category string `json:"category"`
	// Severity 严重级别
	Severity SeverityLevel `json:"severity"`
	// Position 在文本中的位置
	Position int `json:"position"`
}

// ContentFilter AI 内容安全过滤器
type ContentFilter struct {
	mu sync.RWMutex

	// library 当前加载的敏感词库
	library *SensitiveWordLibrary

	// warningAC 警告级别的 Aho-Corasick 自动机
	warningAC *AhoCorasick
	// blockAC 阻断级别的 Aho-Corasick 自动机
	blockAC *AhoCorasick

	// warningWords 警告级别敏感词映射（索引 -> 词条目）
	warningWords map[int]*SensitiveWord
	// blockWords 阻断级别敏感词映射（索引 -> 词条目）
	blockWords map[int]*SensitiveWord

	// defaultSafeResponse 默认安全回复
	defaultSafeResponse string
	// categorySafeResponses 按分类的安全回复
	categorySafeResponses map[string]string

	// enabled 是否启用过滤
	enabled bool
}

// NewContentFilter 从 JSON 文件创建内容过滤器
// 如果文件不存在或解析失败，返回错误
func NewContentFilter(libraryPath string) (*ContentFilter, error) {
	cf := &ContentFilter{
		enabled:               true,
		defaultSafeResponse:   "抱歉，我无法回答这个问题。请换一个话题继续我们的对话。",
		categorySafeResponses: make(map[string]string),
	}

	if libraryPath != "" {
		if err := cf.LoadLibrary(libraryPath); err != nil {
			return nil, fmt.Errorf("failed to load sensitive word library: %w", err)
		}
	}

	return cf, nil
}

// NewContentFilterFromLibrary 从 SensitiveWordLibrary 结构直接创建过滤器
func NewContentFilterFromLibrary(library *SensitiveWordLibrary) *ContentFilter {
	cf := &ContentFilter{
		enabled:               true,
		defaultSafeResponse:   "抱歉，我无法回答这个问题。请换一个话题继续我们的对话。",
		categorySafeResponses: make(map[string]string),
	}

	cf.applyLibrary(library)
	return cf
}

// LoadLibrary 从 JSON 文件加载敏感词库
func (cf *ContentFilter) LoadLibrary(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read library file: %w", err)
	}

	var library SensitiveWordLibrary
	if err := json.Unmarshal(data, &library); err != nil {
		return fmt.Errorf("failed to parse library JSON: %w", err)
	}

	cf.mu.Lock()
	defer cf.mu.Unlock()

	cf.applyLibrary(&library)

	log.Printf("[ContentFilter] Loaded sensitive word library v%s with %d words",
		library.Version, len(library.Words))

	return nil
}

// UpdateLibrary 动态更新敏感词库（线程安全）
func (cf *ContentFilter) UpdateLibrary(library *SensitiveWordLibrary) {
	cf.mu.Lock()
	defer cf.mu.Unlock()

	cf.applyLibrary(library)

	log.Printf("[ContentFilter] Updated sensitive word library v%s with %d words",
		library.Version, len(library.Words))
}

// AddWords 动态添加敏感词（不影响现有词库）
func (cf *ContentFilter) AddWords(words []SensitiveWord) {
	cf.mu.Lock()
	defer cf.mu.Unlock()

	if cf.library == nil {
		cf.library = &SensitiveWordLibrary{
			Version:   "dynamic",
			UpdatedAt: time.Now().Format(time.RFC3339),
			Words:     words,
		}
	} else {
		cf.library.Words = append(cf.library.Words, words...)
	}

	// 重建自动机
	cf.applyLibrary(cf.library)
}

// RemoveWords 动态移除敏感词
func (cf *ContentFilter) RemoveWords(wordsToRemove []string) {
	cf.mu.Lock()
	defer cf.mu.Unlock()

	if cf.library == nil {
		return
	}

	removeSet := make(map[string]bool)
	for _, w := range wordsToRemove {
		removeSet[strings.ToLower(w)] = true
	}

	var remaining []SensitiveWord
	for _, w := range cf.library.Words {
		if !removeSet[strings.ToLower(w.Word)] {
			remaining = append(remaining, w)
		}
	}

	cf.library.Words = remaining
	cf.applyLibrary(cf.library)
}

// Filter 对文本进行安全过滤
// 返回 FilterResult 包含过滤结果和匹配详情
func (cf *ContentFilter) Filter(text string) *FilterResult {
	start := time.Now()

	result := &FilterResult{
		Original:      text,
		Filtered:      text,
		Blocked:       false,
		ProcessTimeMs: 0,
	}

	cf.mu.RLock()
	defer cf.mu.RUnlock()

	if !cf.enabled {
		result.ProcessTimeMs = time.Since(start).Milliseconds()
		return result
	}

	// 将文本转为小写进行匹配（保留原始文本用于返回）
	lowerText := normalizeText(text)

	// 1. 检查阻断级别
	if cf.blockAC != nil && cf.blockAC.PatternCount() > 0 {
		blockMatches := cf.blockAC.Search(lowerText)
		if len(blockMatches) > 0 {
			result.Blocked = true
			for _, m := range blockMatches {
				word := cf.blockWords[m.PatternIndex]
				detail := MatchDetail{
					Word:     m.Pattern,
					Category: word.Category,
					Severity: SeverityBlock,
					Position: m.Position,
				}
				result.Blocks = append(result.Blocks, detail)
			}

			// 确定安全回复
			result.SafeResponse = cf.getSafeResponse(result.Blocks)
			result.Filtered = result.SafeResponse

			// 记录阻断日志
			log.Printf("[ContentFilter] BLOCKED: detected %d block-level words, categories: %s",
				len(result.Blocks), cf.getCategories(result.Blocks))
		}
	}

	// 2. 检查警告级别（即使已阻断也记录）
	if cf.warningAC != nil && cf.warningAC.PatternCount() > 0 {
		warningMatches := cf.warningAC.Search(lowerText)
		if len(warningMatches) > 0 {
			for _, m := range warningMatches {
				word := cf.warningWords[m.PatternIndex]
				detail := MatchDetail{
					Word:     m.Pattern,
					Category: word.Category,
					Severity: SeverityWarning,
					Position: m.Position,
				}
				result.Warnings = append(result.Warnings, detail)
			}

			// 记录警告日志
			log.Printf("[ContentFilter] WARNING: detected %d warning-level words, categories: %s",
				len(result.Warnings), cf.getCategories(result.Warnings))
		}
	}

	result.ProcessTimeMs = time.Since(start).Milliseconds()
	return result
}

// FilterResponse 过滤 AI 响应（便捷方法，用于集成到 AI Engine 管道）
// 返回过滤后的文本和是否被阻断
func (cf *ContentFilter) FilterResponse(response string) (string, bool) {
	result := cf.Filter(response)
	return result.Filtered, result.Blocked
}

// SetEnabled 启用或禁用过滤器
func (cf *ContentFilter) SetEnabled(enabled bool) {
	cf.mu.Lock()
	defer cf.mu.Unlock()
	cf.enabled = enabled
}

// IsEnabled 返回过滤器是否启用
func (cf *ContentFilter) IsEnabled() bool {
	cf.mu.RLock()
	defer cf.mu.RUnlock()
	return cf.enabled
}

// GetLibraryInfo 返回当前词库信息
func (cf *ContentFilter) GetLibraryInfo() map[string]interface{} {
	cf.mu.RLock()
	defer cf.mu.RUnlock()

	info := map[string]interface{}{
		"enabled": cf.enabled,
	}

	if cf.library != nil {
		info["version"] = cf.library.Version
		info["updated_at"] = cf.library.UpdatedAt
		info["total_words"] = len(cf.library.Words)
		info["warning_words"] = len(cf.warningWords)
		info["block_words"] = len(cf.blockWords)

		// 统计各分类数量
		categories := make(map[string]int)
		for _, w := range cf.library.Words {
			categories[w.Category]++
		}
		info["categories"] = categories
	}

	return info
}

// ExportLibrary 导出当前词库为 JSON
func (cf *ContentFilter) ExportLibrary() ([]byte, error) {
	cf.mu.RLock()
	defer cf.mu.RUnlock()

	if cf.library == nil {
		return json.Marshal(&SensitiveWordLibrary{
			Version:   "empty",
			UpdatedAt: time.Now().Format(time.RFC3339),
			Words:     []SensitiveWord{},
		})
	}

	return json.MarshalIndent(cf.library, "", "  ")
}

// ---- 内部方法 ----

// applyLibrary 应用敏感词库（调用者需持有写锁）
func (cf *ContentFilter) applyLibrary(library *SensitiveWordLibrary) {
	cf.library = library

	// 设置安全回复
	if library.DefaultSafeResponse != "" {
		cf.defaultSafeResponse = library.DefaultSafeResponse
	}
	if library.CategorySafeResponses != nil {
		cf.categorySafeResponses = library.CategorySafeResponses
	}

	// 分离警告和阻断级别的词
	cf.warningAC = NewAhoCorasick()
	cf.blockAC = NewAhoCorasick()
	cf.warningWords = make(map[int]*SensitiveWord)
	cf.blockWords = make(map[int]*SensitiveWord)

	warningIdx := 0
	blockIdx := 0

	for i := range library.Words {
		word := &library.Words[i]
		normalizedWord := normalizeText(word.Word)

		switch word.Severity {
		case SeverityBlock:
			cf.blockAC.AddPattern(normalizedWord)
			cf.blockWords[blockIdx] = word
			blockIdx++
		case SeverityWarning:
			cf.warningAC.AddPattern(normalizedWord)
			cf.warningWords[warningIdx] = word
			warningIdx++
		default:
			// 默认为警告级别
			cf.warningAC.AddPattern(normalizedWord)
			cf.warningWords[warningIdx] = word
			warningIdx++
		}
	}

	// 构建自动机
	cf.warningAC.Build()
	cf.blockAC.Build()
}

// getSafeResponse 根据匹配结果获取安全回复
func (cf *ContentFilter) getSafeResponse(blocks []MatchDetail) string {
	if len(blocks) > 0 {
		// 优先使用分类特定的安全回复
		category := blocks[0].Category
		if resp, ok := cf.categorySafeResponses[category]; ok {
			return resp
		}
	}
	return cf.defaultSafeResponse
}

// getCategories 获取匹配结果中的所有分类
func (cf *ContentFilter) getCategories(details []MatchDetail) string {
	categories := make(map[string]bool)
	for _, d := range details {
		categories[d.Category] = true
	}

	var cats []string
	for c := range categories {
		cats = append(cats, c)
	}
	return strings.Join(cats, ", ")
}

// normalizeText 对文本进行标准化处理（小写化、去除特殊字符干扰）
func normalizeText(text string) string {
	var sb strings.Builder
	sb.Grow(len(text))

	for _, r := range text {
		// 全角转半角
		if r >= 0xFF01 && r <= 0xFF5E {
			r = r - 0xFEE0
		}
		// 转小写
		r = unicode.ToLower(r)
		sb.WriteRune(r)
	}

	return sb.String()
}
