package models

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"time"
)

// EmbeddingDimensions is the default vector dimension for text-embedding-3-small.
const EmbeddingDimensions = 1536

// EntityType defines the type of entity that an embedding represents.
type EntityType string

const (
	EntityArticle      EntityType = "article"
	EntityCognitiveTag EntityType = "cognitive_tag"
	EntityTextChunk    EntityType = "text_chunk"
)

// Vector represents a float64 slice that can be stored as JSON in MySQL.
type Vector []float64

// Value implements the driver.Valuer interface for database serialization.
func (v Vector) Value() (driver.Value, error) {
	if v == nil {
		return nil, nil
	}
	return json.Marshal(v)
}

// Scan implements the sql.Scanner interface for database deserialization.
func (v *Vector) Scan(value interface{}) error {
	if value == nil {
		*v = nil
		return nil
	}
	bytes, ok := value.([]byte)
	if !ok {
		return errors.New("Vector.Scan: unsupported type")
	}
	return json.Unmarshal(bytes, v)
}

// Norm calculates the L2 norm (Euclidean length) of the vector.
func (v Vector) Norm() float64 {
	var sum float64
	for _, val := range v {
		sum += val * val
	}
	return math.Sqrt(sum)
}

// DotProduct calculates the dot product of two vectors.
func (v Vector) DotProduct(other Vector) (float64, error) {
	if len(v) != len(other) {
		return 0, fmt.Errorf("dimension mismatch: %d vs %d", len(v), len(other))
	}
	var sum float64
	for i := range v {
		sum += v[i] * other[i]
	}
	return sum, nil
}

// CosineSimilarity calculates the cosine similarity between two vectors.
// Returns a value between -1.0 and 1.0.
func (v Vector) CosineSimilarity(other Vector) (float64, error) {
	dot, err := v.DotProduct(other)
	if err != nil {
		return 0, err
	}
	normA := v.Norm()
	normB := other.Norm()
	if normA == 0 || normB == 0 {
		return 0, nil
	}
	return dot / (normA * normB), nil
}

// Embedding represents a semantic vector embedding stored in the database.
//
// Design Principles:
//   - Polymorphic entity reference (entity_type + entity_id) avoids rigid FK constraints
//   - Pre-computed vector_norm accelerates cosine similarity calculations
//   - Qdrant sync fields enable gradual migration without downtime
//   - Content hash enables deduplication of identical text inputs
type Embedding struct {
	ID           uint64     `gorm:"primaryKey;autoIncrement" json:"id"`
	EntityType   EntityType `gorm:"type:varchar(32);not null;uniqueIndex:uk_embedding_entity;index:idx_embeddings_entity_type;index:idx_embeddings_user_type" json:"entity_type"`
	EntityID     uint64     `gorm:"not null;uniqueIndex:uk_embedding_entity" json:"entity_id"`
	UserID       uint64     `gorm:"not null;index:idx_embeddings_user_id;index:idx_embeddings_user_type" json:"user_id"`
	Vector       Vector     `gorm:"type:json;not null" json:"vector"`
	VectorNorm   float64    `gorm:"type:double;not null;default:0.0" json:"vector_norm"`
	Dimensions   uint       `gorm:"not null;default:1536" json:"dimensions"`
	ModelName    string     `gorm:"type:varchar(64);not null;default:'text-embedding-3-small';uniqueIndex:uk_embedding_entity;index:idx_embeddings_model" json:"model_name"`
	ModelVersion string     `gorm:"type:varchar(32);default:'v1';index:idx_embeddings_model" json:"model_version"`
	ContentHash  *string    `gorm:"type:varchar(64);index:idx_embeddings_content_hash" json:"content_hash,omitempty"`
	ChunkIndex   uint       `gorm:"default:0;uniqueIndex:uk_embedding_entity" json:"chunk_index"`
	ChunkText    *string    `gorm:"type:text" json:"chunk_text,omitempty"`

	// Qdrant migration tracking
	QdrantSyncedAt *time.Time `gorm:"index:idx_embeddings_qdrant_sync" json:"qdrant_synced_at,omitempty"`
	QdrantPointID  *string    `gorm:"type:varchar(64)" json:"qdrant_point_id,omitempty"`

	// Timestamps
	CreatedAt time.Time `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updated_at"`

	// Associations (no FK constraint, polymorphic)
	User User `gorm:"foreignKey:UserID" json:"user,omitempty"`
}

func (Embedding) TableName() string {
	return "embeddings"
}

// BeforeCreate validates the embedding before insertion.
func (e *Embedding) BeforeCreate(tx interface{}) error {
	// Validate vector dimensions
	if len(e.Vector) != int(e.Dimensions) {
		return fmt.Errorf("vector dimension mismatch: expected %d, got %d", e.Dimensions, len(e.Vector))
	}
	// Pre-compute vector norm
	e.VectorNorm = e.Vector.Norm()
	return nil
}

// SimilarityResult represents a search result with similarity score.
type SimilarityResult struct {
	EmbeddingID uint64     `json:"embedding_id"`
	EntityType  EntityType `json:"entity_type"`
	EntityID    uint64     `json:"entity_id"`
	ChunkIndex  uint       `json:"chunk_index"`
	ChunkText   *string    `json:"chunk_text,omitempty"`
	Similarity  float64    `json:"similarity"`
}
