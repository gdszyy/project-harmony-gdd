// Package examples 提供翻译钩子案例库和 few-shot 示例选择器。
// 该包管理跨域类比案例的加载、索引和基于标签匹配的检索，
// 为 AI Prompt 提供高质量的 few-shot 示例以提升生成质量。
package examples

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"
)

// HookType 翻译钩子类型
type HookType string

const (
	HookStructuralAnalogy  HookType = "structural_analogy"
	HookMethodTransfer     HookType = "method_transfer"
	HookCounterIntuitive   HookType = "counter_intuitive"
	HookUnderlyingPattern  HookType = "underlying_pattern"
)

// Example 表示一个翻译钩子案例
type Example struct {
	ID            string   `json:"id"`
	HookType      HookType `json:"hook_type"`
	FromDomain    string   `json:"from_domain"`
	ToDomain      string   `json:"to_domain"`
	FromConcept   string   `json:"from_concept"`
	ToConcept     string   `json:"to_concept"`
	HookText      string   `json:"hook_text"`
	BridgeConcept string   `json:"bridge_concept"`
	Tags          []string `json:"tags"`
	QualityScore  float64  `json:"quality_score"`
}

// ExampleDB 案例库的 JSON 文件结构
type ExampleDB struct {
	Version     int        `json:"version"`
	Description string     `json:"description"`
	UpdatedAt   string     `json:"updated_at"`
	Examples    []*Example `json:"examples"`
}

// SelectionCriteria 示例选择条件
type SelectionCriteria struct {
	// UserDomains 用户关注的领域（用于匹配 from_domain）
	UserDomains []string
	// ArticleDomain 推荐文章的领域（用于匹配 to_domain）
	ArticleDomain string
	// PreferredHookType 偏好的钩子类型（可选）
	PreferredHookType HookType
	// MaxResults 最大返回数量
	MaxResults int
	// MinQuality 最低质量分数阈值
	MinQuality float64
}

// ScoredExample 带匹配分数的案例
type ScoredExample struct {
	Example *Example
	Score   float64
}

// Selector 是 few-shot 示例选择器
type Selector struct {
	mu       sync.RWMutex
	examples []*Example
	// 按领域索引的快速查找表
	domainIndex map[string][]*Example
	// 按标签索引的快速查找表
	tagIndex map[string][]*Example
	// 按钩子类型索引
	hookTypeIndex map[HookType][]*Example
}

// NewSelector 创建一个新的示例选择器并加载案例库
func NewSelector() (*Selector, error) {
	s := &Selector{
		domainIndex:   make(map[string][]*Example),
		tagIndex:      make(map[string][]*Example),
		hookTypeIndex: make(map[HookType][]*Example),
	}

	if err := s.loadExamples(); err != nil {
		return nil, fmt.Errorf("failed to load examples: %w", err)
	}

	return s, nil
}

// loadExamples 从 JSON 文件加载案例库
func (s *Selector) loadExamples() error {
	// 获取当前文件所在目录
	_, currentFile, _, ok := runtime.Caller(0)
	if !ok {
		return fmt.Errorf("failed to get current file path")
	}
	dir := filepath.Dir(currentFile)
	jsonPath := filepath.Join(dir, "translation_hooks.json")

	data, err := os.ReadFile(jsonPath)
	if err != nil {
		return fmt.Errorf("failed to read examples file: %w", err)
	}

	var db ExampleDB
	if err := json.Unmarshal(data, &db); err != nil {
		return fmt.Errorf("failed to parse examples JSON: %w", err)
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	s.examples = db.Examples
	s.buildIndices()

	return nil
}

// buildIndices 构建快速查找索引
func (s *Selector) buildIndices() {
	s.domainIndex = make(map[string][]*Example)
	s.tagIndex = make(map[string][]*Example)
	s.hookTypeIndex = make(map[HookType][]*Example)

	for _, ex := range s.examples {
		// 领域索引（from 和 to 都索引）
		fromKey := strings.ToLower(ex.FromDomain)
		toKey := strings.ToLower(ex.ToDomain)
		s.domainIndex[fromKey] = append(s.domainIndex[fromKey], ex)
		s.domainIndex[toKey] = append(s.domainIndex[toKey], ex)

		// 标签索引
		for _, tag := range ex.Tags {
			tagKey := strings.ToLower(tag)
			s.tagIndex[tagKey] = append(s.tagIndex[tagKey], ex)
		}

		// 钩子类型索引
		s.hookTypeIndex[ex.HookType] = append(s.hookTypeIndex[ex.HookType], ex)
	}
}

// Select 根据条件选择最匹配的 few-shot 示例
func (s *Selector) Select(criteria SelectionCriteria) []*Example {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if criteria.MaxResults <= 0 {
		criteria.MaxResults = 3
	}
	if criteria.MinQuality <= 0 {
		criteria.MinQuality = 0.80
	}

	// 为每个案例计算匹配分数
	scored := make([]ScoredExample, 0, len(s.examples))
	for _, ex := range s.examples {
		if ex.QualityScore < criteria.MinQuality {
			continue
		}

		score := s.calculateMatchScore(ex, criteria)
		if score > 0 {
			scored = append(scored, ScoredExample{
				Example: ex,
				Score:   score,
			})
		}
	}

	// 按分数降序排列
	sort.Slice(scored, func(i, j int) bool {
		return scored[i].Score > scored[j].Score
	})

	// 选择 top-N，同时确保类型多样性
	result := s.diverseSelect(scored, criteria.MaxResults)
	return result
}

// calculateMatchScore 计算案例与选择条件的匹配分数
func (s *Selector) calculateMatchScore(ex *Example, criteria SelectionCriteria) float64 {
	var score float64

	// 1. 领域匹配分数（权重 0.4）
	domainScore := 0.0
	fromDomain := strings.ToLower(ex.FromDomain)
	toDomain := strings.ToLower(ex.ToDomain)

	for _, userDomain := range criteria.UserDomains {
		ud := strings.ToLower(userDomain)
		if ud == fromDomain {
			domainScore += 0.5 // 用户领域匹配 from_domain（理想情况）
		}
		if ud == toDomain {
			domainScore += 0.2 // 用户领域匹配 to_domain（次优）
		}
	}

	articleDomain := strings.ToLower(criteria.ArticleDomain)
	if articleDomain != "" {
		if articleDomain == toDomain {
			domainScore += 0.5 // 文章领域匹配 to_domain（理想情况）
		}
		if articleDomain == fromDomain {
			domainScore += 0.2 // 文章领域匹配 from_domain（次优）
		}
	}

	// 归一化领域分数
	domainScore = math.Min(domainScore, 1.0)
	score += domainScore * 0.4

	// 2. 标签重叠分数（权重 0.25）
	tagScore := 0.0
	allCriteriaTags := append(criteria.UserDomains, criteria.ArticleDomain)
	for _, tag := range ex.Tags {
		tagLower := strings.ToLower(tag)
		for _, ct := range allCriteriaTags {
			if strings.ToLower(ct) == tagLower {
				tagScore += 0.25
			}
		}
	}
	tagScore = math.Min(tagScore, 1.0)
	score += tagScore * 0.25

	// 3. 钩子类型偏好（权重 0.15）
	if criteria.PreferredHookType != "" && ex.HookType == criteria.PreferredHookType {
		score += 0.15
	} else {
		score += 0.05 // 基础分
	}

	// 4. 质量分数（权重 0.2）
	score += ex.QualityScore * 0.2

	return score
}

// diverseSelect 在保证多样性的前提下选择示例
func (s *Selector) diverseSelect(scored []ScoredExample, maxResults int) []*Example {
	if len(scored) == 0 {
		return nil
	}

	result := make([]*Example, 0, maxResults)
	usedTypes := make(map[HookType]int)
	usedDomains := make(map[string]int)

	for _, se := range scored {
		if len(result) >= maxResults {
			break
		}

		ex := se.Example

		// 惩罚已使用的类型和领域（鼓励多样性）
		typeCount := usedTypes[ex.HookType]
		domainCount := usedDomains[strings.ToLower(ex.FromDomain)] + usedDomains[strings.ToLower(ex.ToDomain)]

		// 如果同类型已经有2个以上，跳过
		if typeCount >= 2 {
			continue
		}
		// 如果同领域已经有2个以上，跳过
		if domainCount >= 2 {
			continue
		}

		result = append(result, ex)
		usedTypes[ex.HookType]++
		usedDomains[strings.ToLower(ex.FromDomain)]++
		usedDomains[strings.ToLower(ex.ToDomain)]++
	}

	return result
}

// FormatAsPromptExamples 将选中的案例格式化为 Prompt 中的 few-shot 示例文本
func FormatAsPromptExamples(examples []*Example) string {
	if len(examples) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("以下是一些高质量的跨域类比案例，请参考它们的风格和深度：\n\n")

	for i, ex := range examples {
		sb.WriteString(fmt.Sprintf("案例 %d（%s → %s，%s）：\n", i+1, ex.FromDomain, ex.ToDomain, hookTypeLabel(ex.HookType)))
		sb.WriteString(fmt.Sprintf("钩子文案：%s\n", ex.HookText))
		sb.WriteString(fmt.Sprintf("桥接概念：%s\n", ex.BridgeConcept))
		if i < len(examples)-1 {
			sb.WriteString("\n")
		}
	}

	return sb.String()
}

// hookTypeLabel 返回钩子类型的中文标签
func hookTypeLabel(ht HookType) string {
	switch ht {
	case HookStructuralAnalogy:
		return "结构类比"
	case HookMethodTransfer:
		return "方法迁移"
	case HookCounterIntuitive:
		return "反直觉发现"
	case HookUnderlyingPattern:
		return "底层规律"
	default:
		return string(ht)
	}
}

// GetAllExamples 返回所有案例（用于调试和管理）
func (s *Selector) GetAllExamples() []*Example {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]*Example, len(s.examples))
	copy(result, s.examples)
	return result
}

// GetExampleCount 返回案例总数
func (s *Selector) GetExampleCount() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return len(s.examples)
}

// GetDomains 返回所有涉及的领域
func (s *Selector) GetDomains() []string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	domains := make(map[string]bool)
	for d := range s.domainIndex {
		domains[d] = true
	}

	result := make([]string, 0, len(domains))
	for d := range domains {
		result = append(result, d)
	}
	sort.Strings(result)
	return result
}
