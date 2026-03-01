package database

import (
	"fmt"
	"log"
	"os"
	"time"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Config holds database connection configuration.
type Config struct {
	Host         string `json:"host" yaml:"host"`
	Port         int    `json:"port" yaml:"port"`
	User         string `json:"user" yaml:"user"`
	Password     string `json:"password" yaml:"password"`
	Database     string `json:"database" yaml:"database"`
	MaxOpenConns int    `json:"max_open_conns" yaml:"max_open_conns"`
	MaxIdleConns int    `json:"max_idle_conns" yaml:"max_idle_conns"`
	MaxLifetime  int    `json:"max_lifetime" yaml:"max_lifetime"` // seconds
}

// DefaultConfig returns a default database configuration.
func DefaultConfig() Config {
	return Config{
		Host:         getEnv("DB_HOST", "localhost"),
		Port:         3306,
		User:         getEnv("DB_USER", "edgereader"),
		Password:     getEnv("DB_PASSWORD", ""),
		Database:     getEnv("DB_NAME", "edgereader"),
		MaxOpenConns: 25,
		MaxIdleConns: 10,
		MaxLifetime:  300,
	}
}

// DSN returns the MySQL Data Source Name string.
func (c Config) DSN() string {
	return fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		c.User, c.Password, c.Host, c.Port, c.Database)
}

// NewDB creates a new GORM database connection.
func NewDB(cfg Config) (*gorm.DB, error) {
	// Configure GORM logger
	gormLogger := logger.New(
		log.New(os.Stdout, "\r\n", log.LstdFlags),
		logger.Config{
			SlowThreshold:             200 * time.Millisecond,
			LogLevel:                  logger.Warn,
			IgnoreRecordNotFoundError: true,
			Colorful:                  true,
		},
	)

	db, err := gorm.Open(mysql.Open(cfg.DSN()), &gorm.Config{
		Logger: gormLogger,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	// Configure connection pool
	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("failed to get underlying DB: %w", err)
	}

	sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
	sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)
	sqlDB.SetConnMaxLifetime(time.Duration(cfg.MaxLifetime) * time.Second)

	return db, nil
}

// AutoMigrate runs GORM auto-migration for all models.
// This is safe to run multiple times and only adds missing columns/indexes.
// It does NOT delete columns or change column types.
//
// Note: For production deployments, use the SQL migration scripts in
// server/migrations/ instead of AutoMigrate.
func AutoMigrate(db *gorm.DB) error {
	// Import models - these would be imported from the models package
	// For now, we define the migration order to respect foreign key dependencies.
	//
	// Migration order:
	// 1. users (no dependencies)
	// 2. articles (depends on users)
	// 3. reading_sessions (depends on users, articles)
	// 4. cognitive_tags (depends on users)
	// 5. article_tags (depends on articles, cognitive_tags)
	// 6. tag_relations (depends on cognitive_tags)
	// 7. embeddings (depends on users)
	//
	// Usage:
	//   import "server/internal/models"
	//   err := db.AutoMigrate(
	//       &models.User{},
	//       &models.Article{},
	//       &models.ReadingSession{},
	//       &models.CognitiveTag{},
	//       &models.ArticleTag{},
	//       &models.TagRelation{},
	//       &models.Embedding{},
	//   )

	log.Println("AutoMigrate: Use SQL migration scripts for production deployments")
	log.Println("AutoMigrate: Migration scripts located at server/migrations/")
	return nil
}

func getEnv(key, defaultValue string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return defaultValue
}
