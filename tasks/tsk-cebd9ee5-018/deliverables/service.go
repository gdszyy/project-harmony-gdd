package starmap

import (
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"github.com/gdszyy/edge-reader/server/internal/ai/graph"
)

// Service 提供认知星图的业务逻辑
type Service struct {
	repo  *Repository
	graph graph.AdjacencyGraph
}

// NewService 创建 Service 实例
func NewService(repo *Repository, g graph.AdjacencyGraph) *Service {
	return &Service{
		repo:  repo,
		graph: g,
	}
}

// GetStarmap 获取用户的完整认知星图数据
func (s *Service) GetStarmap(userID uint64, userName, avatarURL string) (*StarmapResponse, error) {
	// 1. 获取用户所有认知标签
	tags, err := s.repo.GetUserTags(userID)
	if err != nil {
		return nil, fmt.Errorf("get user tags: %w", err)
	}

	// 2. 构建当前快照
	currentSnapshot := s.buildSnapshot(tags, "当前", NowMillis())

	// 3. 构建时间线快照（最近 8 周，每周一个快照）
	timeline := s.buildTimeline(userID, 8)

	// 4. 生成认知摘要
	summary := s.buildSummary(tags, userID)

	return &StarmapResponse{
		UserID:          userID,
		UserName:        userName,
		AvatarURL:       avatarURL,
		CurrentSnapshot: currentSnapshot,
		Timeline:        timeline,
		Summary:         summary,
		GeneratedAt:     NowMillis(),
	}, nil
}

// buildSnapshot 从标签列表构建星图快照
func (s *Service) buildSnapshot(tags []UserCognitiveTag, label string, timestamp uint64) StarmapSnapshot {
	nodes := make([]StarmapNode, 0, len(tags))
	for _, tag := range tags {
		// 应用时间衰减
		decayedWeight := s.applyDecay(tag.Weight, tag.DecayRate, tag.LastReinforcedAt)
		nodes = append(nodes, StarmapNode{
			ID:               tag.TagName,
			TagName:          tag.TagName,
			TagDisplayName:   tag.TagDisplayName,
			Dimension:        tag.TagDimension,
			Weight:           decayedWeight,
			Confidence:       tag.Confidence,
			EvidenceCount:    tag.EvidenceCount,
			FirstDetectedAt:  tag.FirstDetectedAt,
			LastReinforcedAt: tag.LastReinforcedAt,
			DecayRate:        tag.DecayRate,
		})
	}

	// 构建连线
	edges := s.buildEdges(nodes)

	return StarmapSnapshot{
		Timestamp: timestamp,
		Label:     label,
		Nodes:     nodes,
		Edges:     edges,
	}
}

// buildEdges 根据标签关系构建连线
func (s *Service) buildEdges(nodes []StarmapNode) []StarmapEdge {
	edges := make([]StarmapEdge, 0)

	// 1. 同维度内的标签连接（基于权重相似性）
	byDimension := make(map[string][]StarmapNode)
	for _, node := range nodes {
		byDimension[node.Dimension] = append(byDimension[node.Dimension], node)
	}

	for _, dimNodes := range byDimension {
		for i := 0; i < len(dimNodes); i++ {
			for j := i + 1; j < len(dimNodes); j++ {
				weightDiff := math.Abs(dimNodes[i].Weight - dimNodes[j].Weight)
				if weightDiff < 0.4 {
					edges = append(edges, StarmapEdge{
						Source:   dimNodes[i].ID,
						Target:   dimNodes[j].ID,
						Distance: 0.2 + weightDiff,
						Type:     "same_dimension",
					})
				}
			}
		}
	}

	// 2. 跨维度关联（使用邻接图的认知距离）
	if s.graph != nil {
		for i := 0; i < len(nodes); i++ {
			for j := i + 1; j < len(nodes); j++ {
				if nodes[i].Dimension == nodes[j].Dimension {
					continue
				}
				dist, err := s.graph.GetDistance(nodes[i].TagName, nodes[j].TagName)
				if err == nil && dist < 0.5 {
					edges = append(edges, StarmapEdge{
						Source:   nodes[i].ID,
						Target:   nodes[j].ID,
						Distance: dist,
						Type:     "cross_dimension",
					})
				}
			}
		}
	}

	// 3. 限制连线数量，避免过于密集
	if len(edges) > len(nodes)*3 {
		sort.Slice(edges, func(i, j int) bool {
			return edges[i].Distance < edges[j].Distance
		})
		edges = edges[:len(nodes)*3]
	}

	return edges
}

// buildTimeline 构建时间线快照
func (s *Service) buildTimeline(userID uint64, weeks int) []StarmapSnapshot {
	snapshots := make([]StarmapSnapshot, 0, weeks)
	now := time.Now()

	for w := weeks - 1; w >= 0; w-- {
		weekEnd := now.Add(-time.Duration(w) * 7 * 24 * time.Hour)
		weekStart := weekEnd.Add(-7 * 24 * time.Hour)

		tags, err := s.repo.GetUserTagsInTimeRange(
			userID,
			uint64(weekStart.UnixMilli()),
			uint64(weekEnd.UnixMilli()),
		)
		if err != nil {
			continue
		}

		if len(tags) == 0 {
			continue
		}

		_, weekNum := weekEnd.ISOWeek()
		label := fmt.Sprintf("%d-W%02d", weekEnd.Year(), weekNum)

		snapshot := s.buildSnapshot(tags, label, uint64(weekEnd.UnixMilli()))
		snapshots = append(snapshots, snapshot)
	}

	return snapshots
}

// buildSummary 生成认知画像摘要
func (s *Service) buildSummary(tags []UserCognitiveTag, userID uint64) CognitiveSummary {
	if len(tags) == 0 {
		return CognitiveSummary{
			TotalTags:   0,
			InsightText: "开始你的阅读之旅，认知宇宙等待被点亮。",
		}
	}

	// 统计各维度标签数
	dimCount := make(map[string]int)
	dimWeightSum := make(map[string]float64)
	for _, tag := range tags {
		dimCount[tag.TagDimension]++
		dimWeightSum[tag.TagDimension] += tag.Weight
	}

	// 找到主导维度
	topDim := ""
	topDimWeight := 0.0
	for dim, wSum := range dimWeightSum {
		if wSum > topDimWeight {
			topDimWeight = wSum
			topDim = dim
		}
	}

	// 提取核心特质（权重最高的 3 个标签）
	dominantTraits := make([]string, 0, 3)
	sortedTags := make([]UserCognitiveTag, len(tags))
	copy(sortedTags, tags)
	sort.Slice(sortedTags, func(i, j int) bool {
		return sortedTags[i].Weight > sortedTags[j].Weight
	})
	for i := 0; i < len(sortedTags) && i < 3; i++ {
		name := sortedTags[i].TagDisplayName
		if name == "" {
			name = sortedTags[i].TagName
		}
		dominantTraits = append(dominantTraits, name)
	}

	// 近期成长（最近 7 天强化的标签）
	recentGrowth := make([]string, 0)
	recentTags, _ := s.repo.GetRecentTags(userID, 7)
	for _, tag := range recentTags {
		if len(recentGrowth) >= 3 {
			break
		}
		name := tag.TagDisplayName
		if name == "" {
			name = tag.TagName
		}
		recentGrowth = append(recentGrowth, name)
	}

	// 阅读天数
	readingDays, _ := s.repo.GetUserReadingDays(userID)

	// 生成洞察文本
	insightText := s.generateInsightText(dominantTraits, topDim, len(tags))

	return CognitiveSummary{
		TotalTags:         len(tags),
		TopDimension:      topDim,
		TopDimensionLabel: DimensionDisplayName(topDim),
		DominantTraits:    dominantTraits,
		RecentGrowth:      recentGrowth,
		ReadingDays:       readingDays,
		InsightText:       insightText,
	}
}

// generateInsightText 生成一句话认知洞察
func (s *Service) generateInsightText(traits []string, topDim string, tagCount int) string {
	if len(traits) == 0 {
		return "你的认知宇宙正在形成，继续探索吧。"
	}

	traitStr := strings.Join(traits, "、")
	dimLabel := DimensionDisplayName(topDim)

	templates := []string{
		fmt.Sprintf("你是一位善于%s的探索者，在「%s」维度展现出独特的认知风格。", traitStr, dimLabel),
		fmt.Sprintf("你的认知星图已点亮 %d 个标签，其中「%s」是你最鲜明的思维特征。", tagCount, traitStr),
		fmt.Sprintf("在%s的引导下，你正在构建一个以「%s」为核心的认知宇宙。", traitStr, dimLabel),
	}

	// 简单的确定性选择（基于标签数量）
	idx := tagCount % len(templates)
	return templates[idx]
}

// applyDecay 应用时间衰减
func (s *Service) applyDecay(weight, decayRate float64, lastReinforcedAt uint64) float64 {
	if lastReinforcedAt == 0 {
		return weight
	}
	daysSince := float64(NowMillis()-lastReinforcedAt) / (24 * 3600 * 1000)
	if daysSince <= 0 {
		return weight
	}
	decayed := weight * math.Exp(-decayRate*daysSince)
	return math.Max(0.01, decayed)
}
