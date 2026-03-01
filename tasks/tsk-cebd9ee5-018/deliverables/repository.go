package starmap

import (
	"fmt"
	"time"

	"gorm.io/gorm"
)

// Repository 提供认知星图的数据访问层
type Repository struct {
	db *gorm.DB
}

// NewRepository 创建 Repository 实例
func NewRepository(db *gorm.DB) *Repository {
	return &Repository{db: db}
}

// GetUserTags 获取用户的所有认知标签
func (r *Repository) GetUserTags(userID uint64) ([]UserCognitiveTag, error) {
	var tags []UserCognitiveTag
	err := r.db.Where("user_id = ?", userID).
		Order("weight DESC").
		Find(&tags).Error
	if err != nil {
		return nil, fmt.Errorf("query user tags: %w", err)
	}
	return tags, nil
}

// GetUserTagsInTimeRange 获取指定时间范围内的用户认知标签
func (r *Repository) GetUserTagsInTimeRange(userID uint64, since, until uint64) ([]UserCognitiveTag, error) {
	var tags []UserCognitiveTag
	err := r.db.Where("user_id = ? AND first_detected_at <= ? AND last_reinforced_at >= ?",
		userID, until, since).
		Order("weight DESC").
		Find(&tags).Error
	if err != nil {
		return nil, fmt.Errorf("query user tags in range: %w", err)
	}
	return tags, nil
}

// GetUserTagsByDimension 按维度获取用户标签
func (r *Repository) GetUserTagsByDimension(userID uint64, dimension string) ([]UserCognitiveTag, error) {
	var tags []UserCognitiveTag
	err := r.db.Where("user_id = ? AND tag_dimension = ?", userID, dimension).
		Order("weight DESC").
		Find(&tags).Error
	if err != nil {
		return nil, fmt.Errorf("query user tags by dimension: %w", err)
	}
	return tags, nil
}

// GetUserReadingDays 获取用户阅读天数（基于标签活跃时间估算）
func (r *Repository) GetUserReadingDays(userID uint64) (int, error) {
	var result struct {
		MinDate uint64
		MaxDate uint64
	}
	err := r.db.Model(&UserCognitiveTag{}).
		Select("MIN(first_detected_at) as min_date, MAX(last_reinforced_at) as max_date").
		Where("user_id = ?", userID).
		Scan(&result).Error
	if err != nil {
		return 0, fmt.Errorf("query reading days: %w", err)
	}
	if result.MinDate == 0 || result.MaxDate == 0 {
		return 0, nil
	}
	days := int((result.MaxDate - result.MinDate) / (24 * 3600 * 1000))
	if days < 1 {
		days = 1
	}
	return days, nil
}

// GetRecentTags 获取最近 N 天新增或强化的标签
func (r *Repository) GetRecentTags(userID uint64, days int) ([]UserCognitiveTag, error) {
	since := uint64(time.Now().Add(-time.Duration(days) * 24 * time.Hour).UnixMilli())
	var tags []UserCognitiveTag
	err := r.db.Where("user_id = ? AND last_reinforced_at >= ?", userID, since).
		Order("last_reinforced_at DESC").
		Find(&tags).Error
	if err != nil {
		return nil, fmt.Errorf("query recent tags: %w", err)
	}
	return tags, nil
}

// CreateShare 创建分享记录
func (r *Repository) CreateShare(share *StarmapShare) error {
	return r.db.Create(share).Error
}

// GetShareByID 根据分享 ID 获取分享记录
func (r *Repository) GetShareByID(shareID string) (*StarmapShare, error) {
	var share StarmapShare
	err := r.db.Where("share_id = ?", shareID).First(&share).Error
	if err != nil {
		return nil, fmt.Errorf("query share: %w", err)
	}
	return &share, nil
}

// IncrementShareViewCount 增加分享浏览次数
func (r *Repository) IncrementShareViewCount(shareID string) error {
	return r.db.Model(&StarmapShare{}).
		Where("share_id = ?", shareID).
		UpdateColumn("view_count", gorm.Expr("view_count + 1")).
		Error
}
