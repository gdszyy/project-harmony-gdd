// Package safety 提供 AI 内容安全过滤功能。
//
// 本文件实现了 Aho-Corasick 多模式字符串匹配算法，用于高效检测
// AI 生成内容中的敏感词。相比逐词正则匹配，Aho-Corasick 算法
// 可以在 O(n + m + z) 时间内完成匹配（n 为文本长度，m 为模式总长度，
// z 为匹配数），适合大规模敏感词库场景。
package safety

// acNode 表示 Aho-Corasick 自动机中的一个节点
type acNode struct {
	children map[rune]*acNode // 子节点映射
	fail     *acNode          // 失败指针
	output   []int            // 匹配到的模式索引列表
	depth    int              // 节点深度（用于确定匹配长度）
}

// AhoCorasick 实现了 Aho-Corasick 多模式匹配自动机
type AhoCorasick struct {
	root     *acNode  // 根节点
	patterns []string // 所有模式字符串
	built    bool     // 是否已构建失败指针
}

// ACMatch 表示一次匹配结果
type ACMatch struct {
	// PatternIndex 匹配到的模式在模式列表中的索引
	PatternIndex int
	// Pattern 匹配到的模式字符串
	Pattern string
	// Position 匹配在文本中的起始位置（rune 索引）
	Position int
}

// NewAhoCorasick 创建一个新的 Aho-Corasick 自动机
func NewAhoCorasick() *AhoCorasick {
	return &AhoCorasick{
		root: &acNode{
			children: make(map[rune]*acNode),
		},
	}
}

// AddPattern 向自动机中添加一个模式字符串
func (ac *AhoCorasick) AddPattern(pattern string) {
	ac.patterns = append(ac.patterns, pattern)
	idx := len(ac.patterns) - 1

	node := ac.root
	for _, ch := range pattern {
		if _, ok := node.children[ch]; !ok {
			node.children[ch] = &acNode{
				children: make(map[rune]*acNode),
				depth:    node.depth + 1,
			}
		}
		node = node.children[ch]
	}
	node.output = append(node.output, idx)
	ac.built = false
}

// AddPatterns 批量添加模式字符串
func (ac *AhoCorasick) AddPatterns(patterns []string) {
	for _, p := range patterns {
		ac.AddPattern(p)
	}
}

// Build 构建失败指针（BFS 方式）
// 必须在所有模式添加完成后调用，且在 Search 之前调用
func (ac *AhoCorasick) Build() {
	queue := make([]*acNode, 0)

	// 第一层节点的失败指针指向根节点
	for _, child := range ac.root.children {
		child.fail = ac.root
		queue = append(queue, child)
	}

	// BFS 构建失败指针
	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]

		for ch, child := range current.children {
			queue = append(queue, child)

			// 沿失败指针链查找
			failNode := current.fail
			for failNode != nil {
				if next, ok := failNode.children[ch]; ok {
					child.fail = next
					break
				}
				failNode = failNode.fail
			}
			if child.fail == nil {
				child.fail = ac.root
			}

			// 合并输出（继承失败指针链上的所有匹配）
			if child.fail != nil && len(child.fail.output) > 0 {
				child.output = append(child.output, child.fail.output...)
			}
		}
	}

	ac.built = true
}

// Search 在文本中搜索所有匹配的模式
// 返回所有匹配结果的列表
func (ac *AhoCorasick) Search(text string) []ACMatch {
	if !ac.built {
		ac.Build()
	}

	var matches []ACMatch
	node := ac.root
	runes := []rune(text)

	for i, ch := range runes {
		// 沿失败指针链查找可以匹配当前字符的节点
		for node != ac.root {
			if _, ok := node.children[ch]; ok {
				break
			}
			node = node.fail
		}

		if next, ok := node.children[ch]; ok {
			node = next
		}

		// 收集当前节点的所有匹配
		if len(node.output) > 0 {
			for _, patIdx := range node.output {
				pattern := ac.patterns[patIdx]
				patternRunes := []rune(pattern)
				startPos := i - len(patternRunes) + 1
				matches = append(matches, ACMatch{
					PatternIndex: patIdx,
					Pattern:      pattern,
					Position:     startPos,
				})
			}
		}
	}

	return matches
}

// ContainsAny 检查文本中是否包含任何模式
// 比 Search 更高效，因为找到第一个匹配就立即返回
func (ac *AhoCorasick) ContainsAny(text string) bool {
	if !ac.built {
		ac.Build()
	}

	node := ac.root

	for _, ch := range text {
		for node != ac.root {
			if _, ok := node.children[ch]; ok {
				break
			}
			node = node.fail
		}

		if next, ok := node.children[ch]; ok {
			node = next
		}

		if len(node.output) > 0 {
			return true
		}
	}

	return false
}

// PatternCount 返回已添加的模式数量
func (ac *AhoCorasick) PatternCount() int {
	return len(ac.patterns)
}
