// Package handler 提供 API 请求处理函数
package handler

import (
	"math"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gdszyy/edge-reader/server/pkg/response"
	"gorm.io/gorm"
)

// ============================================================
// 数据模型
// ============================================================

// FeedbackType 反馈类型枚举
type FeedbackType string

const (
	FeedbackNotInterested FeedbackType = "not_interested"
	FeedbackTooEasy       FeedbackType = "too_easy"
	FeedbackTooHard       FeedbackType = "too_hard"
	FeedbackSeenBefore    FeedbackType = "seen_before"
)

// RecommendationFeedback 推荐反馈数据模型
// 记录用户对推荐内容的负反馈，用于调整推荐权重
type RecommendationFeedback struct {
	ID                uint64       `gorm:"primaryKey;autoIncrement;column:id" json:"id"`
	UserID            uint64       `gorm:"not null;index:idx_user_feedback;index:idx_user_article;column:user_id" json:"user_id"`
	RecommendationID  uint64       `gorm:"not null;index:idx_recommendation;column:recommendation_id" json:"recommendation_id"`
	ArticleID         uint64       `gorm:"not null;index:idx_user_article;column:article_id" json:"article_id"`
	FeedbackType      FeedbackType `gorm:"not null;type:enum('not_interested','too_easy','too_hard','seen_before');column:feedback_type" json:"feedback_type"`
	// 文章关联的标签快照（反馈时冻结，用于后续权重调整追溯）
	ArticleTags       string       `gorm:"type:json;column:article_tags" json:"article_tags,omitempty"`
	// 反馈时的推荐上下文（如推荐位置、推荐分数等）
	RecommendContext  string       `gorm:"type:json;column:recommend_context" json:"recommend_context,omitempty"`
	// 权重调整是否已执行
	WeightAdjusted    bool         `gorm:"not null;default:false;column:weight_adjusted" json:"weight_adjusted"`
	CreatedAt         uint64       `gorm:"not null;column:created_at" json:"created_at"`
}

// TableName 指定表名
func (RecommendationFeedback) TableName() string {
	return "recommendation_feedbacks"
}

// ============================================================
// 请求/响应结构体
// ============================================================

// SubmitFeedbackRequest 提交反馈请求
type SubmitFeedbackRequest struct {
	FeedbackType FeedbackType `json:"feedback_type" binding:"required"`
}

// FeedbackResponse 反馈响应
type FeedbackResponse struct {
	ID               uint64       `json:"id"`
	RecommendationID uint64       `json:"recommendation_id"`
	FeedbackType     FeedbackType `json:"feedback_type"`
	WeightAdjusted   bool         `json:"weight_adjusted"`
	Message          string       `json:"message"`
}

// ============================================================
// Handler
// ============================================================

// FeedbackHandler 推荐反馈 API 处理器
type FeedbackHandler struct {
	db *gorm.DB
}

// NewFeedbackHandler 创建反馈处理器实例
func NewFeedbackHandler(db *gorm.DB) *FeedbackHandler {
	return &FeedbackHandler{db: db}
}

// SubmitFeedback 提交推荐反馈
// POST /api/v1/recommendations/:id/feedback
//
// 处理流程：
// 1. 验证反馈类型合法性
// 2. 检查是否重复反馈
// 3. 记录反馈到数据库
// 4. 异步调整用户认知标签权重
// 5. 返回反馈结果
func (h *FeedbackHandler) SubmitFeedback(c *gin.Context) {
	// 获取推荐 ID
	recommendationIDStr := c.Param("id")
	recommendationID, err := strconv.ParseUint(recommendationIDStr, 10, 64)
	if err != nil {
		response.Error(c, http.StatusBadRequest, 40001, "无效的推荐 ID")
		return
	}

	// 获取用户 ID（从 JWT 中间件注入）
	userID, exists := c.Get("user_id")
	if !exists {
		response.Error(c, http.StatusUnauthorized, 40101, "未认证")
		return
	}
	uid, ok := userID.(uint64)
	if !ok {
		// 尝试其他类型转换
		switch v := userID.(type) {
		case float64:
			uid = uint64(v)
		case int64:
			uid = uint64(v)
		case int:
			uid = uint64(v)
		default:
			response.Error(c, http.StatusInternalServerError, 50001, "用户 ID 类型错误")
			return
		}
	}

	// 解析请求体
	var req SubmitFeedbackRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, 40002, "请求参数错误", err.Error())
		return
	}

	// 验证反馈类型
	if !isValidFeedbackType(req.FeedbackType) {
		response.Error(c, http.StatusBadRequest, 40003,
			"无效的反馈类型，支持: not_interested, too_easy, too_hard, seen_before")
		return
	}

	// 检查是否已对该推荐提交过反馈
	var existingCount int64
	h.db.Model(&RecommendationFeedback{}).
		Where("user_id = ? AND recommendation_id = ?", uid, recommendationID).
		Count(&existingCount)
	if existingCount > 0 {
		response.Error(c, http.StatusConflict, 40901, "已对该推荐提交过反馈")
		return
	}

	// 创建反馈记录
	now := uint64(time.Now().UnixMilli())
	feedback := RecommendationFeedback{
		UserID:           uid,
		RecommendationID: recommendationID,
		ArticleID:        recommendationID, // MVP 阶段 recommendation_id 等同 article_id
		FeedbackType:     req.FeedbackType,
		WeightAdjusted:   false,
		CreatedAt:        now,
	}

	if err := h.db.Create(&feedback).Error; err != nil {
		response.Error(c, http.StatusInternalServerError, 50002, "反馈保存失败", err.Error())
		return
	}

	// 异步调整认知标签权重
	go h.adjustCognitiveWeights(uid, feedback.ArticleID, req.FeedbackType, feedback.ID)

	response.Success(c, FeedbackResponse{
		ID:               feedback.ID,
		RecommendationID: recommendationID,
		FeedbackType:     req.FeedbackType,
		WeightAdjusted:   false,
		Message:          getFeedbackMessage(req.FeedbackType),
	})
}

// GetUserFeedbacks 获取用户的反馈历史
// GET /api/v1/recommendations/feedbacks
func (h *FeedbackHandler) GetUserFeedbacks(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		response.Error(c, http.StatusUnauthorized, 40101, "未认证")
		return
	}
	uid := parseUserID(userID)

	var feedbacks []RecommendationFeedback
	if err := h.db.Where("user_id = ?", uid).
		Order("created_at DESC").
		Limit(100).
		Find(&feedbacks).Error; err != nil {
		response.Error(c, http.StatusInternalServerError, 50003, "查询反馈失败", err.Error())
		return
	}

	response.Success(c, feedbacks)
}

// ============================================================
// 权重调整逻辑
// ============================================================

// adjustCognitiveWeights 根据负反馈调整用户认知标签权重
//
// 调整策略：
// - not_interested: 降低相关领域标签权重 30%
// - too_easy:       降低相关领域标签权重 20%，提升难度偏好
// - too_hard:       降低相关领域标签权重 10%，降低难度偏好
// - seen_before:    降低相关领域标签权重 15%，标记为已知内容
func (h *FeedbackHandler) adjustCognitiveWeights(
	userID uint64,
	articleID uint64,
	feedbackType FeedbackType,
	feedbackID uint64,
) {
	// 获取文章关联的标签（从 featured-hooks 数据或文章元数据）
	articleTags := h.getArticleTags(articleID)
	if len(articleTags) == 0 {
		return
	}

	// 根据反馈类型确定权重调整因子
	decayFactor := getDecayFactor(feedbackType)

	// 批量更新用户认知标签权重
	for _, tagName := range articleTags {
		h.db.Exec(`
			UPDATE cognitive_tags 
			SET weight = GREATEST(0.0100, weight * ?),
			    evidence_count = evidence_count + 1,
			    last_reinforced_at = ?,
			    updated_at = ?
			WHERE user_id = ? AND tag_name = ?
		`, decayFactor, time.Now().UnixMilli(), time.Now().UnixMilli(), userID, tagName)
	}

	// 标记反馈的权重调整已完成
	h.db.Model(&RecommendationFeedback{}).
		Where("id = ?", feedbackID).
		Update("weight_adjusted", true)
}

// getArticleTags 获取文章关联的标签列表
// MVP 阶段使用硬编码映射，后续从数据库读取
func (h *FeedbackHandler) getArticleTags(articleID uint64) []string {
	// 从 featured-hooks 的 targetTags 映射
	tagMapping := map[uint64][]string{
		101: {"analogy", "systems_thinking", "technology"},
		102: {"psychology", "economics", "daily_life"},
		103: {"analogy", "design", "systems_thinking"},
		104: {"psychology", "cognitive_science", "social"},
		105: {"economics", "physics", "pattern_recognition"},
		106: {"technology", "biology", "analogy"},
		107: {"economics", "politics", "game_theory"},
		108: {"management", "psychology", "contrarian"},
		109: {"philosophy", "physics", "creativity"},
		110: {"urban_planning", "biology", "scaling_laws"},
		111: {"linguistics", "cognitive_science", "philosophy"},
		112: {"ai", "biology", "technology"},
		113: {"design", "philosophy", "culture"},
		114: {"history", "economics", "pattern_recognition"},
		115: {"neuroscience", "psychology", "health"},
		// 扩充内容标签
		201: {"philosophy", "psychology", "existentialism", "social"},
		202: {"philosophy", "ethics", "neuroscience", "contrarian"},
		203: {"philosophy", "eastern_philosophy", "technology", "metaphysics"},
		204: {"philosophy", "linguistics", "family", "communication"},
		205: {"philosophy", "existentialism", "personal_growth", "physics"},
		206: {"philosophy", "sociology", "technology", "privacy"},
		207: {"philosophy", "stoicism", "psychology", "business"},
		208: {"philosophy", "politics", "economics", "justice"},
		209: {"psychology", "behavioral_economics", "daily_life", "self_control"},
		210: {"psychology", "relationships", "development", "attachment"},
		211: {"psychology", "sociology", "power", "ethics"},
		212: {"psychology", "flow", "gaming", "productivity"},
		213: {"psychology", "behavioral_economics", "daily_life", "cognitive_bias"},
		214: {"psychology", "mythology", "literature", "culture"},
		215: {"sociology", "network_science", "career", "social_media"},
		216: {"sociology", "urban_planning", "criminology", "social_norms"},
		217: {"sociology", "philosophy", "consumerism", "semiotics"},
		218: {"sociology", "media", "algorithm", "democracy"},
		219: {"sociology", "network_science", "mathematics", "social_media"},
		220: {"art", "aesthetics", "visual_arts", "cubism"},
		221: {"art", "film", "narrative", "cognitive_science"},
		222: {"art", "music", "neuroscience", "emotion"},
		223: {"art", "architecture", "psychology", "spatial"},
		224: {"art", "photography", "philosophy", "visual_culture"},
		225: {"art", "philosophy", "contemporary_art", "aesthetics"},
		226: {"science_history", "philosophy", "paradigm_shift", "methodology"},
		227: {"science_history", "biology", "gender", "justice"},
		228: {"science_history", "chemistry", "philosophy", "contrarian"},
		229: {"science_history", "physics", "creativity", "thought_experiment"},
		230: {"science_history", "medicine", "serendipity", "innovation"},
		231: {"anthropology", "culture", "food", "classification"},
		232: {"anthropology", "economics", "gift_economy", "reciprocity"},
		233: {"anthropology", "psychology", "ritual", "evolution"},
		234: {"mathematics", "philosophy", "logic", "computer_science"},
		235: {"mathematics", "aesthetics", "biology", "myth_busting"},
		236: {"mathematics", "philosophy", "logic", "infinity"},
		237: {"media", "philosophy", "technology", "mcluhan"},
		238: {"media", "biology", "culture", "meme"},
		239: {"ecology", "systems_thinking", "environment", "trophic_cascade"},
		240: {"ecology", "philosophy", "earth_science", "gaia"},
	}

	if tags, ok := tagMapping[articleID]; ok {
		return tags
	}
	return nil
}

// ============================================================
// 辅助函数
// ============================================================

// isValidFeedbackType 验证反馈类型是否合法
func isValidFeedbackType(ft FeedbackType) bool {
	switch ft {
	case FeedbackNotInterested, FeedbackTooEasy, FeedbackTooHard, FeedbackSeenBefore:
		return true
	}
	return false
}

// getDecayFactor 根据反馈类型返回权重衰减因子
// 返回值为乘法因子，如 0.7 表示权重降低 30%
func getDecayFactor(ft FeedbackType) float64 {
	switch ft {
	case FeedbackNotInterested:
		return 0.70 // 降低 30%
	case FeedbackTooEasy:
		return 0.80 // 降低 20%
	case FeedbackTooHard:
		return 0.90 // 降低 10%
	case FeedbackSeenBefore:
		return 0.85 // 降低 15%
	default:
		return 1.0
	}
}

// getFeedbackMessage 根据反馈类型返回用户友好的确认消息
func getFeedbackMessage(ft FeedbackType) string {
	switch ft {
	case FeedbackNotInterested:
		return "已记录，将减少类似推荐"
	case FeedbackTooEasy:
		return "已记录，将推荐更有深度的内容"
	case FeedbackTooHard:
		return "已记录，将推荐更易理解的内容"
	case FeedbackSeenBefore:
		return "已记录，将避免重复推荐"
	default:
		return "反馈已记录"
	}
}

// parseUserID 安全地解析用户 ID
func parseUserID(v interface{}) uint64 {
	switch id := v.(type) {
	case uint64:
		return id
	case float64:
		return uint64(id)
	case int64:
		return uint64(id)
	case int:
		return uint64(id)
	default:
		return 0
	}
}

// clampWeight 将权重限制在 [min, max] 范围内
func clampWeight(weight, min, max float64) float64 {
	return math.Max(min, math.Min(max, weight))
}
