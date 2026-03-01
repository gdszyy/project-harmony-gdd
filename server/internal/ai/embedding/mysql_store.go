package embedding

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"time"

	"gorm.io/gorm"
)

// mysqlEmbedding maps to the embeddings table for GORM operations.
type mysqlEmbedding struct {
	ID             uint64     `gorm:"primaryKey;autoIncrement"`
	EntityType     string     `gorm:"type:varchar(32);not null"`
	EntityID       uint64     `gorm:"not null"`
	UserID         uint64     `gorm:"not null"`
	Vector         []byte     `gorm:"type:json;not null"` // stored as JSON bytes
	VectorNorm     float64    `gorm:"type:double;not null;default:0.0"`
	Dimensions     uint       `gorm:"not null;default:1536"`
	ModelName      string     `gorm:"type:varchar(64);not null;default:'text-embedding-3-small'"`
	ModelVersion   string     `gorm:"type:varchar(32);default:'v1'"`
	ContentHash    *string    `gorm:"type:varchar(64)"`
	ChunkIndex     uint       `gorm:"default:0"`
	ChunkText      *string    `gorm:"type:text"`
	QdrantSyncedAt *time.Time `gorm:"column:qdrant_synced_at"`
	QdrantPointID  *string    `gorm:"type:varchar(64)"`
	CreatedAt      time.Time  `gorm:"autoCreateTime"`
	UpdatedAt      time.Time  `gorm:"autoUpdateTime"`
}

func (mysqlEmbedding) TableName() string {
	return "embeddings"
}

// MySQLStore implements VectorStore using MySQL with GORM.
// This provides a working vector search implementation suitable for
// development and small-scale deployments.
type MySQLStore struct {
	db *gorm.DB
}

// NewMySQLStore creates a new MySQL-based vector store with GORM.
func NewMySQLStore(db *gorm.DB) *MySQLStore {
	return &MySQLStore{db: db}
}

// Upsert inserts or updates an embedding vector in MySQL.
func (s *MySQLStore) Upsert(ctx context.Context, req *UpsertRequest) error {
	vectorJSON, err := json.Marshal(req.Vector)
	if err != nil {
		return fmt.Errorf("failed to marshal vector: %w", err)
	}

	norm := VectorNorm(req.Vector)

	var contentHash *string
	if req.ContentHash != "" {
		contentHash = &req.ContentHash
	}

	var chunkText *string
	if req.ChunkText != "" {
		chunkText = &req.ChunkText
	}

	emb := mysqlEmbedding{
		EntityType:   req.EntityType,
		EntityID:     req.EntityID,
		UserID:       req.UserID,
		Vector:       vectorJSON,
		VectorNorm:   norm,
		Dimensions:   uint(len(req.Vector)),
		ModelName:    req.ModelName,
		ModelVersion: req.ModelVersion,
		ContentHash:  contentHash,
		ChunkIndex:   req.ChunkIndex,
		ChunkText:    chunkText,
	}

	// Use ON DUPLICATE KEY UPDATE for upsert
	result := s.db.WithContext(ctx).
		Where("entity_type = ? AND entity_id = ? AND chunk_index = ? AND model_name = ?",
			req.EntityType, req.EntityID, req.ChunkIndex, req.ModelName).
		Assign(map[string]interface{}{
			"vector":        vectorJSON,
			"vector_norm":   norm,
			"dimensions":    uint(len(req.Vector)),
			"model_version": req.ModelVersion,
			"content_hash":  contentHash,
			"chunk_text":    chunkText,
			"user_id":       req.UserID,
		}).
		FirstOrCreate(&emb)

	if result.Error != nil {
		return fmt.Errorf("failed to upsert embedding: %w", result.Error)
	}

	return nil
}

// Search performs a cosine similarity search in MySQL.
// This implementation loads vectors into memory and computes similarity in Go,
// which is more efficient than the stored procedure for moderate datasets.
func (s *MySQLStore) Search(ctx context.Context, req *SearchRequest) ([]SearchResult, error) {
	if len(req.QueryVector) == 0 {
		return nil, fmt.Errorf("query vector is empty")
	}

	// Build query
	query := s.db.WithContext(ctx).
		Table("embeddings").
		Select("id, entity_type, entity_id, chunk_index, chunk_text, vector, vector_norm").
		Where("user_id = ? AND vector_norm > 0", req.UserID)

	if req.EntityType != "" {
		query = query.Where("entity_type = ?", req.EntityType)
	}

	// Load candidate embeddings
	var candidates []mysqlEmbedding
	if err := query.Find(&candidates).Error; err != nil {
		return nil, fmt.Errorf("failed to query embeddings: %w", err)
	}

	// Compute cosine similarity for each candidate
	queryNorm := VectorNorm(req.QueryVector)
	if queryNorm == 0 {
		return nil, fmt.Errorf("query vector has zero norm")
	}

	type scoredResult struct {
		SearchResult
		score float64
	}

	var results []scoredResult
	for _, cand := range candidates {
		// Parse stored vector
		var storedVector []float64
		if err := json.Unmarshal(cand.Vector, &storedVector); err != nil {
			continue // Skip malformed vectors
		}

		// Compute dot product
		if len(storedVector) != len(req.QueryVector) {
			continue // Skip dimension mismatches
		}

		var dotProduct float64
		for i := range req.QueryVector {
			dotProduct += req.QueryVector[i] * storedVector[i]
		}

		similarity := dotProduct / (queryNorm * cand.VectorNorm)

		if similarity >= req.MinSimilarity {
			chunkText := ""
			if cand.ChunkText != nil {
				chunkText = *cand.ChunkText
			}
			results = append(results, scoredResult{
				SearchResult: SearchResult{
					EmbeddingID: cand.ID,
					EntityType:  cand.EntityType,
					EntityID:    cand.EntityID,
					ChunkIndex:  cand.ChunkIndex,
					ChunkText:   chunkText,
					Similarity:  similarity,
				},
				score: similarity,
			})
		}
	}

	// Sort by similarity descending
	sort.Slice(results, func(i, j int) bool {
		return results[i].score > results[j].score
	})

	// Limit to top-K
	topK := req.TopK
	if topK <= 0 {
		topK = 10
	}
	if len(results) > topK {
		results = results[:topK]
	}

	// Convert to output format
	output := make([]SearchResult, len(results))
	for i, r := range results {
		output[i] = r.SearchResult
	}

	return output, nil
}

// Delete removes embeddings for a specific entity.
func (s *MySQLStore) Delete(ctx context.Context, entityType string, entityID uint64) error {
	result := s.db.WithContext(ctx).
		Where("entity_type = ? AND entity_id = ?", entityType, entityID).
		Delete(&mysqlEmbedding{})

	if result.Error != nil {
		return fmt.Errorf("failed to delete embeddings: %w", result.Error)
	}

	return nil
}

// BatchUpsert inserts or updates multiple embeddings in a transaction.
func (s *MySQLStore) BatchUpsert(ctx context.Context, reqs []*UpsertRequest) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for _, req := range reqs {
			vectorJSON, err := json.Marshal(req.Vector)
			if err != nil {
				return fmt.Errorf("failed to marshal vector for entity %s/%d: %w",
					req.EntityType, req.EntityID, err)
			}

			norm := VectorNorm(req.Vector)

			var contentHash *string
			if req.ContentHash != "" {
				contentHash = &req.ContentHash
			}

			var chunkText *string
			if req.ChunkText != "" {
				chunkText = &req.ChunkText
			}

			emb := mysqlEmbedding{
				EntityType:   req.EntityType,
				EntityID:     req.EntityID,
				UserID:       req.UserID,
				Vector:       vectorJSON,
				VectorNorm:   norm,
				Dimensions:   uint(len(req.Vector)),
				ModelName:    req.ModelName,
				ModelVersion: req.ModelVersion,
				ContentHash:  contentHash,
				ChunkIndex:   req.ChunkIndex,
				ChunkText:    chunkText,
			}

			result := tx.
				Where("entity_type = ? AND entity_id = ? AND chunk_index = ? AND model_name = ?",
					req.EntityType, req.EntityID, req.ChunkIndex, req.ModelName).
				Assign(map[string]interface{}{
					"vector":        vectorJSON,
					"vector_norm":   norm,
					"dimensions":    uint(len(req.Vector)),
					"model_version": req.ModelVersion,
					"content_hash":  contentHash,
					"chunk_text":    chunkText,
					"user_id":       req.UserID,
				}).
				FirstOrCreate(&emb)

			if result.Error != nil {
				return fmt.Errorf("failed to upsert embedding for entity %s/%d: %w",
					req.EntityType, req.EntityID, result.Error)
			}
		}
		return nil
	})
}

// GetByEntity retrieves the embedding vector for a specific entity.
func (s *MySQLStore) GetByEntity(ctx context.Context, entityType string, entityID uint64) ([]float64, error) {
	var emb mysqlEmbedding
	result := s.db.WithContext(ctx).
		Where("entity_type = ? AND entity_id = ? AND chunk_index = 0", entityType, entityID).
		First(&emb)

	if result.Error != nil {
		return nil, fmt.Errorf("embedding not found for %s/%d: %w", entityType, entityID, result.Error)
	}

	var vector []float64
	if err := json.Unmarshal(emb.Vector, &vector); err != nil {
		return nil, fmt.Errorf("failed to unmarshal vector: %w", err)
	}

	return vector, nil
}

// Health checks the MySQL connection health.
func (s *MySQLStore) Health(ctx context.Context) error {
	sqlDB, err := s.db.DB()
	if err != nil {
		return fmt.Errorf("failed to get underlying DB: %w", err)
	}
	return sqlDB.PingContext(ctx)
}

// GetUnsyncedEmbeddings returns embeddings that haven't been synced to Qdrant.
// Used by the migration service.
func (s *MySQLStore) GetUnsyncedEmbeddings(ctx context.Context, batchSize int) ([]mysqlEmbedding, error) {
	var embeddings []mysqlEmbedding
	result := s.db.WithContext(ctx).
		Where("qdrant_synced_at IS NULL").
		Order("id ASC").
		Limit(batchSize).
		Find(&embeddings)

	if result.Error != nil {
		return nil, fmt.Errorf("failed to query unsynced embeddings: %w", result.Error)
	}

	return embeddings, nil
}

// MarkAsSynced marks an embedding as synced to Qdrant.
func (s *MySQLStore) MarkAsSynced(ctx context.Context, embeddingID uint64, qdrantPointID string) error {
	now := time.Now()
	result := s.db.WithContext(ctx).
		Model(&mysqlEmbedding{}).
		Where("id = ?", embeddingID).
		Updates(map[string]interface{}{
			"qdrant_synced_at": now,
			"qdrant_point_id":  qdrantPointID,
		})

	if result.Error != nil {
		return fmt.Errorf("failed to mark embedding as synced: %w", result.Error)
	}

	return nil
}
