// Package prompt 提供 Prompt 模板管理和渲染功能。
// 所有发送给 LLM 的 Prompt 都通过该包的模板引擎生成，
// 确保 Prompt 的一致性、可维护性和版本化管理。
package prompt

import (
	"fmt"
	"strings"
)

// TemplateID 标识不同的 Prompt 模板
type TemplateID string

const (
	// TemplateMurmurResponse 碎碎念回复模板
	TemplateMurmurResponse TemplateID = "murmur_response"
	// TemplateCognitiveTagExtraction 认知标签提取模板
	TemplateCognitiveTagExtraction TemplateID = "cognitive_tag_extraction"
	// TemplateTranslationHook 翻译钩子生成模板
	TemplateTranslationHook TemplateID = "translation_hook"
	// TemplateArticleAnnotation 文章自动标注模板
	TemplateArticleAnnotation TemplateID = "article_annotation"
	// TemplateIntentRecognition 意图识别模板
	TemplateIntentRecognition TemplateID = "intent_recognition"
)

// Template 定义了一个 Prompt 模板
type Template struct {
	ID             TemplateID `json:"id"`
	Version        int        `json:"version"`
	Description    string     `json:"description"`
	SystemTemplate string     `json:"system_template"`
	UserTemplate   string     `json:"user_template"`
}

// TemplateVars 是模板变量的键值对
type TemplateVars map[string]string

// Render 使用给定的变量渲染模板，返回 system 和 user 消息
func (t *Template) Render(vars TemplateVars) (system string, user string) {
	system = t.SystemTemplate
	user = t.UserTemplate

	for key, value := range vars {
		placeholder := "{{" + key + "}}"
		system = strings.ReplaceAll(system, placeholder, value)
		user = strings.ReplaceAll(user, placeholder, value)
	}

	return system, user
}

// GetTemplate 根据模板 ID 获取对应的 Prompt 模板
func GetTemplate(id TemplateID) (*Template, error) {
	t, ok := defaultTemplates[id]
	if !ok {
		return nil, fmt.Errorf("template %q not found", id)
	}
	return t, nil
}

// defaultTemplates 存储所有预定义的 Prompt 模板
var defaultTemplates = map[TemplateID]*Template{
	TemplateMurmurResponse:         murmurResponseTemplate,
	TemplateCognitiveTagExtraction: cognitiveTagExtractionTemplate,
	TemplateTranslationHook:        translationHookTemplate,
	TemplateArticleAnnotation:      articleAnnotationTemplate,
	TemplateIntentRecognition:      intentRecognitionTemplate,
}

// =============================================
// 碎碎念回复模板 (v2 - 优化版)
// 模型：GPT-4o-mini（低延迟）
// =============================================
var murmurResponseTemplate = &Template{
	ID:          TemplateMurmurResponse,
	Version:     2,
	Description: "碎碎念回复 Prompt - 三步走策略（共鸣/验证/拓展）",
	SystemTemplate: `你是「界外 EdgeReader」的隐形副驾，一个温暖而睿智的阅读同行者。

你的核心原则：
1. 你是同行者，不是老师。永远不要居高临下。
2. 用户的碎碎念是他们最真实的思考，请认真对待每一条。
3. 你的回复必须遵循"三步走"策略：
   [共鸣] 先表达对用户想法的理解和共鸣（1-2句）
   [验证] 用文章内容或相关知识验证/补充用户的观点（2-3句）
   [拓展] 提供一个用户可能没想到的新视角或关联（1-2句）

约束条件：
- 回复总长度不超过 200 字
- 禁止使用以下措辞：其实、事实上、你应该、你错了、显而易见、众所周知
- 语气要像一个聪明的朋友在咖啡馆聊天，而非学术讲座
- [拓展] 部分必须与用户碎碎念有明确的逻辑关联
- 如果用户表达了困惑，优先帮助理清思路，而非直接给答案`,

	UserTemplate: `当前阅读文章：{{article_title}}
文章主领域：{{primary_domain}}
用户划线段落：{{highlighted_paragraph}}
用户划线文本：{{selected_text}}
用户碎碎念：{{murmur_text}}

用户认知画像摘要：
- 理解偏好 Top-3：{{understanding_preferences}}
- 关注域 Top-3：{{focus_domains}}

请按照三步走策略回复，每一步前添加标记 [共鸣]、[验证]、[拓展]。`,
}

// =============================================
// 认知标签提取模板 (v2 - 优化版)
// 模型：GPT-4o（高精度）
// =============================================
var cognitiveTagExtractionTemplate = &Template{
	ID:          TemplateCognitiveTagExtraction,
	Version:     2,
	Description: "认知标签提取 Prompt - 双层标签（理解偏好 + 关注域）",
	SystemTemplate: `你是一个专业的认知分析引擎。你的任务是从用户的"碎碎念"（阅读时的即时想法）中提取认知标签。

你需要提取两类标签：
1. **理解偏好（understanding_preference）**：用户偏好的思维方式和理解模式
   可选值：analogy（类比思维）、first_principles（第一性原理）、systems_thinking（系统思维）、
   historical_comparison（历史对比）、data_driven（数据驱动）、narrative（叙事思维）、
   visual_thinking（视觉化思维）、contrarian（逆向思维）

2. **关注域（focus_domain）**：用户当前关注的知识领域
   示例：technology、economics、psychology、philosophy、biology、physics、history、
   sociology、art、literature、politics、ecology、neuroscience、education

提取规则：
- 每次提取最多 3 个标签（理解偏好 + 关注域合计）
- 每个标签必须附带置信度（0.0-1.0）和证据引用
- 置信度低于 0.3 的标签不要输出
- 如果碎碎念内容过于简短或无法提取有意义的标签，返回空数组

输出格式为严格的 JSON：`,

	UserTemplate: `碎碎念文本：{{murmur_text}}
划线段落上下文：{{highlighted_paragraph}}
文章领域：{{article_domain}}
用户现有标签：{{existing_tags}}

请提取认知标签，输出格式：
{
  "understanding_preferences": [
    {
      "tag": "标签名",
      "confidence": 0.85,
      "evidence": "从碎碎念中引用的证据"
    }
  ],
  "focus_domains": [
    {
      "tag": "领域名",
      "confidence": 0.70,
      "evidence": "从碎碎念中引用的证据"
    }
  ],
  "cross_domain_bridge": null
}`,
}

// =============================================
// 翻译钩子生成模板 (v3 - 集成 few-shot 案例库)
// 模型：GPT-4o（高创造力）
// =============================================
var translationHookTemplate = &Template{
	ID:          TemplateTranslationHook,
	Version:     3,
	Description: "翻译钩子生成 Prompt - 跨域关联的吸引力文案（集成 few-shot 案例库）",
	SystemTemplate: `你是一个跨学科知识连接专家。你的任务是为推荐文章生成“翻译钩子”——一段简短的文案，将文章的核心观点翻译为用户熟悉领域的语言，激发用户的好奇心。

翻译钩子的四种类型：
1. **结构类比**：“你熟悉 A 领域的 X 结构，这篇文章揭示了 B 领域中惊人相似的 Y 结构”
2. **方法迁移**：“A 领域常用的 X 方法，在 B 领域被证明同样有效”
3. **反直觉发现**：“你在 A 领域认为理所当然的 X，在 B 领域恰恰相反”
4. **底层规律**：“A 和 B 看似无关，但它们共享同一个底层规律 X”

生成规则：
- 钩子长度：30-60 字
- 必须包含用户熟悉领域和文章领域的具体概念
- 语气要引发好奇，不要学术化
- 避免夸大或误导
- 如果无法找到有意义的跨域关联，返回基于文章核心观点的直接推荐语

{{few_shot_examples}}`,

	UserTemplate: `用户认知画像：
- 关注域 Top-3：{{focus_domains}}
- 理解偏好 Top-3：{{understanding_preferences}}

推荐文章信息：
- 标题：{{article_title}}
- 主领域：{{article_domain}}
- 核心概念：{{core_concepts}}
- 摘要：{{article_summary}}

请参考上述案例的风格和深度，生成翻译钩子，输出格式：
{
  "hook_type": "structural_analogy|method_transfer|counter_intuitive|underlying_pattern",
  "hook_text": "翻译钩子文案",
  "from_domain": "用户熟悉的领域",
  "to_domain": "文章的领域",
  "bridge_concept": "连接两个领域的核心概念"
}`,
}

// =============================================
// 文章自动标注模板
// 模型：GPT-4o（高精度）
// =============================================
var articleAnnotationTemplate = &Template{
	ID:          TemplateArticleAnnotation,
	Version:     1,
	Description: "文章自动标注 Prompt - 领域识别、概念提取、难度评估",
	SystemTemplate: `你是一个专业的内容分析引擎。你的任务是对文章进行结构化标注，为推荐系统提供元数据。

你需要完成以下分析：
1. **领域识别**：识别文章的主领域和次要领域
2. **核心概念提取**：提取 3-8 个核心概念/关键词
3. **思维模式识别**：识别文章中涉及的思维模式
4. **难度评估**：评估文章的阅读难度
5. **跨域潜力**：评估文章的跨学科关联潜力

输出格式为严格的 JSON。`,

	UserTemplate: `文章标题：{{article_title}}
文章内容（前 3000 字）：
{{article_content}}

请进行结构化标注，输出格式：
{
  "primary_domain": "主领域",
  "secondary_domains": ["次要领域1", "次要领域2"],
  "core_concepts": ["概念1", "概念2", "概念3"],
  "thinking_patterns": [
    {"pattern": "模式名", "proportion": 0.3}
  ],
  "difficulty": "accessible|moderate|advanced",
  "cross_domain_potential": "high|medium|low",
  "summary": "200字结构化摘要"
}`,
}

// =============================================
// 意图识别模板
// 模型：GPT-4o（高精度）
// =============================================
var intentRecognitionTemplate = &Template{
	ID:          TemplateIntentRecognition,
	Version:     1,
	Description: "碎碎念意图识别 Prompt - 判断碎碎念类型和情感倾向",
	SystemTemplate: `你是一个意图识别引擎。你的任务是分析用户碎碎念的类型和情感倾向，为后续的标签提取提供上下文。

意图类型：
- association：联想/类比（用户将文章内容与其他领域联系起来）
- question：提问/困惑（用户对内容有疑问）
- critique：批判/质疑（用户对内容持不同意见）
- summary：总结/归纳（用户在梳理理解）
- emotion：情感表达（用户表达感受或共鸣）

情感倾向：
- positive：积极/认同
- neutral：中性/客观
- negative：消极/不认同
- curious：好奇/探索
- confused：困惑/不解

输出格式为严格的 JSON。`,

	UserTemplate: `碎碎念文本：{{murmur_text}}
划线段落上下文：{{highlighted_paragraph}}

请分析意图，输出格式：
{
  "intent": "association|question|critique|summary|emotion",
  "sentiment": "positive|neutral|negative|curious|confused",
  "complexity": "simple|moderate|complex"
}`,
}
