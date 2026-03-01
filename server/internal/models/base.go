package models

import (
	"time"

	"gorm.io/gorm"
)

// BaseModel provides common fields for all models.
// Compatible with GORM's soft delete and timestamp conventions.
type BaseModel struct {
	ID        uint64         `gorm:"primaryKey;autoIncrement" json:"id"`
	CreatedAt time.Time      `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt time.Time      `gorm:"autoUpdateTime" json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"deleted_at,omitempty"`
}

// User represents a registered user in the EdgeReader system.
type User struct {
	BaseModel
	Username     string `gorm:"type:varchar(64);uniqueIndex;not null" json:"username"`
	Email        string `gorm:"type:varchar(255);uniqueIndex;not null" json:"email"`
	PasswordHash string `gorm:"type:varchar(255);not null" json:"-"`
	AvatarURL    string `gorm:"type:varchar(512);default:''" json:"avatar_url"`

	// Associations
	Articles      []Article      `gorm:"foreignKey:UserID" json:"articles,omitempty"`
	CognitiveTags []CognitiveTag `gorm:"foreignKey:UserID" json:"cognitive_tags,omitempty"`
}

func (User) TableName() string {
	return "users"
}

// Article represents a reading article stored by a user.
type Article struct {
	BaseModel
	UserID             uint64 `gorm:"not null;index:idx_articles_user_id" json:"user_id"`
	Title              string `gorm:"type:varchar(512);not null" json:"title"`
	Content            string `gorm:"type:longtext" json:"content,omitempty"`
	SourceURL          string `gorm:"type:varchar(2048);default:''" json:"source_url"`
	SourceType         string `gorm:"type:enum('web','pdf','epub','manual');default:'web'" json:"source_type"`
	WordCount          uint   `gorm:"default:0" json:"word_count"`
	ReadingTimeMinutes uint   `gorm:"default:0" json:"reading_time_minutes"`

	// Associations
	User User          `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Tags []ArticleTag  `gorm:"foreignKey:ArticleID" json:"tags,omitempty"`
}

func (Article) TableName() string {
	return "articles"
}

// ReadingSession tracks a user's reading activity on an article.
type ReadingSession struct {
	ID              uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID          uint64    `gorm:"not null;index:idx_reading_sessions_user_id" json:"user_id"`
	ArticleID       uint64    `gorm:"not null;index:idx_reading_sessions_article_id" json:"article_id"`
	StartTime       time.Time `gorm:"not null" json:"start_time"`
	EndTime         *time.Time `json:"end_time,omitempty"`
	ProgressPercent float64   `gorm:"default:0.0" json:"progress_percent"`
	Notes           string    `gorm:"type:text;default:''" json:"notes"`
	CreatedAt       time.Time `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt       time.Time `gorm:"autoUpdateTime" json:"updated_at"`

	// Associations
	User    User    `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Article Article `gorm:"foreignKey:ArticleID" json:"article,omitempty"`
}

func (ReadingSession) TableName() string {
	return "reading_sessions"
}
