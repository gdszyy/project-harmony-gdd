package prompt

import (
	"strings"

	"github.com/gdszyy/edge-reader/server/internal/ai/examples"
)

// HookPromptBuilder 翻译钩子 Prompt 构建器，集成 few-shot 案例选择
type HookPromptBuilder struct {
	selector *examples.Selector
}

// NewHookPromptBuilder 创建翻译钩子 Prompt 构建器
func NewHookPromptBuilder() (*HookPromptBuilder, error) {
	selector, err := examples.NewSelector()
	if err != nil {
		return nil, err
	}
	return &HookPromptBuilder{selector: selector}, nil
}

// BuildTranslationHookPrompt 构建带 few-shot 示例的翻译钩子 Prompt
// 参数：
//   - userDomains: 用户关注的领域列表
//   - articleDomain: 文章的主领域
//   - vars: 其他模板变量
//
// 返回 system prompt 和 user prompt
func (b *HookPromptBuilder) BuildTranslationHookPrompt(
	userDomains []string,
	articleDomain string,
	vars TemplateVars,
) (string, string, error) {
	// 1. 获取翻译钩子模板
	tmpl, err := GetTemplate(TemplateTranslationHook)
	if err != nil {
		return "", "", err
	}

	// 2. 使用 few-shot 选择器选择最相关的案例
	criteria := examples.SelectionCriteria{
		UserDomains:   userDomains,
		ArticleDomain: articleDomain,
		MaxResults:    3,
		MinQuality:    0.85,
	}

	selectedExamples := b.selector.Select(criteria)

	// 3. 格式化 few-shot 示例
	fewShotText := examples.FormatAsPromptExamples(selectedExamples)

	// 4. 注入 few-shot 示例到模板变量
	if vars == nil {
		vars = make(TemplateVars)
	}
	vars["few_shot_examples"] = fewShotText

	// 5. 渲染模板
	system, user := tmpl.Render(vars)

	return system, user, nil
}

// BuildTranslationHookPromptWithType 构建带指定钩子类型偏好的翻译钩子 Prompt
func (b *HookPromptBuilder) BuildTranslationHookPromptWithType(
	userDomains []string,
	articleDomain string,
	preferredType examples.HookType,
	vars TemplateVars,
) (string, string, error) {
	tmpl, err := GetTemplate(TemplateTranslationHook)
	if err != nil {
		return "", "", err
	}

	criteria := examples.SelectionCriteria{
		UserDomains:       userDomains,
		ArticleDomain:     articleDomain,
		PreferredHookType: preferredType,
		MaxResults:        3,
		MinQuality:        0.85,
	}

	selectedExamples := b.selector.Select(criteria)
	fewShotText := examples.FormatAsPromptExamples(selectedExamples)

	if vars == nil {
		vars = make(TemplateVars)
	}
	vars["few_shot_examples"] = fewShotText

	system, user := tmpl.Render(vars)
	return system, user, nil
}

// GetExampleStats 获取案例库统计信息
func (b *HookPromptBuilder) GetExampleStats() map[string]interface{} {
	allExamples := b.selector.GetAllExamples()
	domains := b.selector.GetDomains()

	// 统计各类型数量
	typeCounts := make(map[string]int)
	for _, ex := range allExamples {
		typeCounts[string(ex.HookType)]++
	}

	// 统计平均质量分数
	var totalQuality float64
	for _, ex := range allExamples {
		totalQuality += ex.QualityScore
	}
	avgQuality := 0.0
	if len(allExamples) > 0 {
		avgQuality = totalQuality / float64(len(allExamples))
	}

	return map[string]interface{}{
		"total_examples":     len(allExamples),
		"total_domains":      len(domains),
		"domains":            strings.Join(domains, ", "),
		"type_distribution":  typeCounts,
		"average_quality":    avgQuality,
	}
}
