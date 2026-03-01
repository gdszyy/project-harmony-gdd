// Package starmap 提供认知星图的数据模型和业务逻辑。
// [Sprint2-T19] 认知星图完整可视化与社交分享卡片
package starmap

import (
	"time"
)

// =============================================
// 数据库模型
// =============================================

// UserCognitiveTag 对应数据库表 user_cognitive_tags
type UserCognitiveTag struct {
	ID               uint64  `gorm:"primaryKey;autoIncrement;column:id" json:"id"`
	UserID           uint64  `gorm:"not null;index:idx_user_weight;column:user_id" json:"user_id"`
	TagDimension     string  `gorm:"not null;type:varchar(50);column:tag_dimension" json:"tag_dimension"`
	TagName          string  `gorm:"not null;type:varchar(100);column:tag_name" json:"tag_name"`
	TagDisplayName   string  `gorm:"type:varchar(200);column:tag_display_name" json:"tag_display_name"`
	Weight           float64 `gorm:"not null;default:0.5;type:decimal(5,4);column:weight" json:"weight"`
	Confidence       float64 `gorm:"not null;default:0.1;type:decimal(5,4);column:confidence" json:"confidence"`
	EvidenceCount    uint    `gorm:"not null;default:0;column:evidence_count" json:"evidence_count"`
	FirstDetectedAt  uint64  `gorm:"not null;column:first_detected_at" json:"first_detected_at"`
	LastReinforcedAt uint64  `gorm:"not null;column:last_reinforced_at" json:"last_reinforced_at"`
	DecayRate        float64 `gorm:"not null;default:0.01;type:decimal(5,4);column:decay_rate" json:"decay_rate"`
	CreatedAt        uint64  `gorm:"not null;column:created_at;autoCreateTime:milli" json:"created_at"`
	UpdatedAt        uint64  `gorm:"not null;column:updated_at;autoUpdateTime:milli" json:"updated_at"`
}

// TableName 指定表名
func (UserCognitiveTag) TableName() string {
	return "user_cognitive_tags"
}

// StarmapShare 分享记录表
type StarmapShare struct {
	ID        uint64  `gorm:"primaryKey;autoIncrement;column:id" json:"id"`
	UserID    uint64  `gorm:"not null;index:idx_user_id;column:user_id" json:"user_id"`
	ShareID   string  `gorm:"not null;uniqueIndex;type:varchar(36);column:share_id" json:"share_id"`
	Theme     string  `gorm:"not null;type:varchar(20);column:theme" json:"theme"`
	SnapshotData string `gorm:"not null;type:longtext;column:snapshot_data" json:"snapshot_data"`
	ExpiresAt uint64  `gorm:"not null;column:expires_at" json:"expires_at"`
	ViewCount uint    `gorm:"not null;default:0;column:view_count" json:"view_count"`
	CreatedAt uint64  `gorm:"not null;column:created_at;autoCreateTime:milli" json:"created_at"`
}

// TableName 指定表名
func (StarmapShare) TableName() string {
	return "starmap_shares"
}

// =============================================
// API 响应模型
// =============================================

// StarmapNode 星图节点（API 响应用）
type StarmapNode struct {
	ID               string  `json:"id"`
	TagName          string  `json:"tagName"`
	TagDisplayName   string  `json:"tagDisplayName"`
	Dimension        string  `json:"dimension"`
	Weight           float64 `json:"weight"`
	Confidence       float64 `json:"confidence"`
	EvidenceCount    uint    `json:"evidenceCount"`
	FirstDetectedAt  uint64  `json:"firstDetectedAt"`
	LastReinforcedAt uint64  `json:"lastReinforcedAt"`
	DecayRate        float64 `json:"decayRate"`
}

// StarmapEdge 星图连线（API 响应用）
type StarmapEdge struct {
	Source   string  `json:"source"`
	Target   string  `json:"target"`
	Distance float64 `json:"distance"`
	Type     string  `json:"type"` // same_dimension, cross_dimension, adjacency
}

// StarmapSnapshot 星图时间快照
type StarmapSnapshot struct {
	Timestamp uint64        `json:"timestamp"`
	Label     string        `json:"label"`
	Nodes     []StarmapNode `json:"nodes"`
	Edges     []StarmapEdge `json:"edges"`
}

// CognitiveSummary 认知画像摘要
type CognitiveSummary struct {
	TotalTags         int      `json:"totalTags"`
	TopDimension      string   `json:"topDimension"`
	TopDimensionLabel string   `json:"topDimensionLabel"`
	DominantTraits    []string `json:"dominantTraits"`
	RecentGrowth      []string `json:"recentGrowth"`
	ReadingDays       int      `json:"readingDays"`
	InsightText       string   `json:"insightText"`
}

// StarmapResponse GET /api/v1/users/{id}/starmap 响应
type StarmapResponse struct {
	UserID          uint64            `json:"userId"`
	UserName        string            `json:"userName"`
	AvatarURL       string            `json:"avatarUrl"`
	CurrentSnapshot StarmapSnapshot   `json:"currentSnapshot"`
	Timeline        []StarmapSnapshot `json:"timeline"`
	Summary         CognitiveSummary  `json:"summary"`
	GeneratedAt     uint64            `json:"generatedAt"`
}

// ShareRequest POST /api/v1/starmap/share 请求
type ShareRequest struct {
	Theme           string `json:"theme" binding:"required,oneof=cosmos aurora sunset ocean minimal"`
	IncludeTimeline bool   `json:"includeTimeline"`
	Message         string `json:"message"`
}

// ShareResponse POST /api/v1/starmap/share 响应
type ShareResponse struct {
	ShareID   string `json:"shareId"`
	ShareURL  string `json:"shareUrl"`
	QRCodeURL string `json:"qrCodeUrl"`
	ExpiresAt uint64 `json:"expiresAt"`
}

// =============================================
// 辅助方法
// =============================================

// DimensionDisplayName 返回维度的中文显示名
func DimensionDisplayName(dim string) string {
	switch dim {
	case "understanding_preference":
		return "理解偏好"
	case "focus_domain":
		return "关注域"
	case "emotional_tendency":
		return "情绪倾向"
	case "thinking_pattern":
		return "思维方式"
	default:
		return dim
	}
}

// NowMillis 返回当前时间的毫秒时间戳
func NowMillis() uint64 {
	return uint64(time.Now().UnixMilli())
}
