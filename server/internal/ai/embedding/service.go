package embedding

import (
	"context"
	"crypto/md5"
	"fmt"
	"math"
	"time"
)

// ============================================================
// Vector Store Interface (abstraction for MySQL → Qdrant migration)
// ============================================================

// SearchRequest defines the parameters for a similarity search.
type SearchRequest struct {
	// QueryVector is the embedding vector to search against.
	QueryVector []float64

	// UserID restricts results to a specific user's data.
	UserID uint64

	// EntityType filters results by entity type (empty = all types).
	EntityType string

	// TopK is the maximum number of results to return.
	TopK int

	// MinSimilarity is the minimum cosine similarity threshold (0.0 to 1.0).
	MinSimilarity float64
}

// SearchResult represents a single similarity search result.
type SearchResult struct {
	// EmbeddingID is the database ID of the matching embedding.
	EmbeddingID uint64 `json:"embedding_id"`

	// EntityType is the type of the matched entity.
	EntityType string `json:"entity_type"`

	// EntityID is the ID of the matched entity.
	EntityID uint64 `json:"entity_id"`

	// ChunkIndex is the chunk index for chunked entities.
	ChunkIndex uint `json:"chunk_index"`

	// ChunkText is the optional text content of the chunk.
	ChunkText string `json:"chunk_text,omitempty"`

	// Similarity is the cosine similarity score (0.0 to 1.0).
	Similarity float64 `json:"similarity"`
}

// UpsertRequest defines the parameters for upserting an embedding.
type UpsertRequest struct {
	EntityType   string
	EntityID     uint64
	UserID       uint64
	Vector       []float64
	ModelName    string
	ModelVersion string
	ChunkIndex   uint
	ChunkText    string
	ContentHash  string
}

// VectorStore defines the abstract interface for vector storage and retrieval.
// This interface supports both MySQL-based and Qdrant-based implementations,
// enabling a smooth migration path.
//
// Implementation Notes:
//   - MySQLVectorStore: Uses JSON columns and SQL-based cosine similarity.
//     Suitable for development and small datasets (<10K vectors).
//   - QdrantVectorStore: Uses Qdrant's native HNSW index for ANN search.
//     Required for production workloads with >10K vectors.
//
// Migration Strategy:
//  1. Start with MySQLVectorStore (Phase 1)
//  2. Deploy Qdrant alongside MySQL (Phase 2)
//  3. Dual-write to both stores during migration (Phase 2)
//  4. Switch reads to Qdrant, keep MySQL as audit log (Phase 3)
//  5. Optionally remove MySQL vector data (Phase 4)
type VectorStore interface {
	// Upsert inserts or updates an embedding vector.
	Upsert(ctx context.Context, req *UpsertRequest) error

	// Search performs a similarity search and returns the top-K results.
	Search(ctx context.Context, req *SearchRequest) ([]SearchResult, error)

	// Delete removes an embedding by entity reference.
	Delete(ctx context.Context, entityType string, entityID uint64) error

	// BatchUpsert inserts or updates multiple embeddings in a single operation.
	BatchUpsert(ctx context.Context, reqs []*UpsertRequest) error

	// GetByEntity retrieves the embedding for a specific entity.
	GetByEntity(ctx context.Context, entityType string, entityID uint64) ([]float64, error)

	// Health checks the health of the vector store backend.
	Health(ctx context.Context) error
}

// ============================================================
// Embedding Service (orchestrates embedding generation and storage)
// ============================================================

// EmbeddingProvider defines the interface for generating embeddings from text.
// This abstracts the embedding model (e.g., OpenAI, local model).
type EmbeddingProvider interface {
	// Embed generates an embedding vector for the given text.
	Embed(ctx context.Context, text string) ([]float64, error)

	// EmbedBatch generates embedding vectors for multiple texts.
	EmbedBatch(ctx context.Context, texts []string) ([][]float64, error)

	// ModelName returns the name of the embedding model.
	ModelName() string

	// ModelVersion returns the version of the embedding model.
	ModelVersion() string

	// Dimensions returns the output vector dimensions.
	Dimensions() int
}

// Service orchestrates embedding generation, storage, and retrieval.
// It coordinates between the EmbeddingProvider (model) and VectorStore (storage).
type Service struct {
	provider EmbeddingProvider
	store    VectorStore

	// Optional: secondary store for dual-write during migration
	secondaryStore VectorStore
}

// NewService creates a new embedding service.
func NewService(provider EmbeddingProvider, store VectorStore) *Service {
	return &Service{
		provider: provider,
		store:    store,
	}
}

// SetSecondaryStore sets a secondary vector store for dual-write during migration.
// When set, all write operations are performed on both stores.
func (s *Service) SetSecondaryStore(store VectorStore) {
	s.secondaryStore = store
}

// EmbedAndStore generates an embedding for the given text and stores it.
func (s *Service) EmbedAndStore(ctx context.Context, entityType string, entityID uint64, userID uint64, text string) error {
	// Generate embedding
	vector, err := s.provider.Embed(ctx, text)
	if err != nil {
		return fmt.Errorf("failed to generate embedding: %w", err)
	}

	// Compute content hash for deduplication
	hash := fmt.Sprintf("%x", md5.Sum([]byte(text)))

	req := &UpsertRequest{
		EntityType:   entityType,
		EntityID:     entityID,
		UserID:       userID,
		Vector:       vector,
		ModelName:    s.provider.ModelName(),
		ModelVersion: s.provider.ModelVersion(),
		ChunkIndex:   0,
		ChunkText:    text,
		ContentHash:  hash,
	}

	// Primary store
	if err := s.store.Upsert(ctx, req); err != nil {
		return fmt.Errorf("failed to store embedding in primary store: %w", err)
	}

	// Secondary store (dual-write for migration)
	if s.secondaryStore != nil {
		if err := s.secondaryStore.Upsert(ctx, req); err != nil {
			// Log but don't fail - secondary store is best-effort during migration
			fmt.Printf("WARNING: failed to store embedding in secondary store: %v\n", err)
		}
	}

	return nil
}

// EmbedChunkedAndStore generates embeddings for chunked text and stores them.
// This is used for long articles that need to be split into chunks.
func (s *Service) EmbedChunkedAndStore(ctx context.Context, entityType string, entityID uint64, userID uint64, chunks []string) error {
	// Generate embeddings in batch
	vectors, err := s.provider.EmbedBatch(ctx, chunks)
	if err != nil {
		return fmt.Errorf("failed to generate batch embeddings: %w", err)
	}

	reqs := make([]*UpsertRequest, len(chunks))
	for i, chunk := range chunks {
		hash := fmt.Sprintf("%x", md5.Sum([]byte(chunk)))
		reqs[i] = &UpsertRequest{
			EntityType:   entityType,
			EntityID:     entityID,
			UserID:       userID,
			Vector:       vectors[i],
			ModelName:    s.provider.ModelName(),
			ModelVersion: s.provider.ModelVersion(),
			ChunkIndex:   uint(i),
			ChunkText:    chunk,
			ContentHash:  hash,
		}
	}

	// Primary store
	if err := s.store.BatchUpsert(ctx, reqs); err != nil {
		return fmt.Errorf("failed to batch store embeddings in primary store: %w", err)
	}

	// Secondary store (dual-write)
	if s.secondaryStore != nil {
		if err := s.secondaryStore.BatchUpsert(ctx, reqs); err != nil {
			fmt.Printf("WARNING: failed to batch store embeddings in secondary store: %v\n", err)
		}
	}

	return nil
}

// FindSimilar performs a similarity search against the vector store.
func (s *Service) FindSimilar(ctx context.Context, text string, userID uint64, entityType string, topK int, minSimilarity float64) ([]SearchResult, error) {
	// Generate query embedding
	queryVector, err := s.provider.Embed(ctx, text)
	if err != nil {
		return nil, fmt.Errorf("failed to generate query embedding: %w", err)
	}

	return s.FindSimilarByVector(ctx, queryVector, userID, entityType, topK, minSimilarity)
}

// FindSimilarByVector performs a similarity search using a pre-computed vector.
func (s *Service) FindSimilarByVector(ctx context.Context, queryVector []float64, userID uint64, entityType string, topK int, minSimilarity float64) ([]SearchResult, error) {
	req := &SearchRequest{
		QueryVector:   queryVector,
		UserID:        userID,
		EntityType:    entityType,
		TopK:          topK,
		MinSimilarity: minSimilarity,
	}

	return s.store.Search(ctx, req)
}

// DeleteEmbedding removes an embedding from all stores.
func (s *Service) DeleteEmbedding(ctx context.Context, entityType string, entityID uint64) error {
	if err := s.store.Delete(ctx, entityType, entityID); err != nil {
		return fmt.Errorf("failed to delete from primary store: %w", err)
	}
	if s.secondaryStore != nil {
		if err := s.secondaryStore.Delete(ctx, entityType, entityID); err != nil {
			fmt.Printf("WARNING: failed to delete from secondary store: %v\n", err)
		}
	}
	return nil
}

// Health checks the health of all configured stores.
func (s *Service) Health(ctx context.Context) map[string]error {
	result := make(map[string]error)
	result["primary"] = s.store.Health(ctx)
	if s.secondaryStore != nil {
		result["secondary"] = s.secondaryStore.Health(ctx)
	}
	return result
}

// ============================================================
// MySQL Vector Store Implementation
// ============================================================

// MySQLVectorStore implements VectorStore using MySQL JSON columns
// and SQL-based cosine similarity calculation.
//
// Performance Characteristics:
//   - Upsert: O(1) per vector
//   - Search: O(n*d) where n=total vectors, d=dimensions
//   - Suitable for: <10K vectors per user
//   - Limitation: Full table scan for similarity search (no ANN index)
type MySQLVectorStore struct {
	// db is the GORM database connection.
	// Using interface{} to avoid import cycle with gorm package.
	db interface{}
}

// NewMySQLVectorStore creates a new MySQL-based vector store.
func NewMySQLVectorStore(db interface{}) *MySQLVectorStore {
	return &MySQLVectorStore{db: db}
}

// CosineSimilarity computes cosine similarity between two vectors in Go.
// This is used as a fallback when MySQL stored procedure is not available.
func CosineSimilarity(a, b []float64) (float64, error) {
	if len(a) != len(b) {
		return 0, fmt.Errorf("dimension mismatch: %d vs %d", len(a), len(b))
	}

	var dotProduct, normA, normB float64
	for i := range a {
		dotProduct += a[i] * b[i]
		normA += a[i] * a[i]
		normB += b[i] * b[i]
	}

	normA = math.Sqrt(normA)
	normB = math.Sqrt(normB)

	if normA == 0 || normB == 0 {
		return 0, nil
	}

	return dotProduct / (normA * normB), nil
}

// VectorNorm computes the L2 norm of a vector.
func VectorNorm(v []float64) float64 {
	var sum float64
	for _, val := range v {
		sum += val * val
	}
	return math.Sqrt(sum)
}

// ============================================================
// Qdrant Vector Store Interface (placeholder for Phase 2)
// ============================================================

// QdrantConfig holds configuration for connecting to a Qdrant instance.
type QdrantConfig struct {
	// Host is the Qdrant server hostname.
	Host string `json:"host" yaml:"host"`

	// Port is the Qdrant gRPC port (default: 6334).
	Port int `json:"port" yaml:"port"`

	// CollectionName is the Qdrant collection to use.
	CollectionName string `json:"collection_name" yaml:"collection_name"`

	// APIKey is the optional API key for authentication.
	APIKey string `json:"api_key" yaml:"api_key"`

	// UseTLS enables TLS for the connection.
	UseTLS bool `json:"use_tls" yaml:"use_tls"`
}

// DefaultQdrantConfig returns the default Qdrant configuration.
func DefaultQdrantConfig() QdrantConfig {
	return QdrantConfig{
		Host:           "localhost",
		Port:           6334,
		CollectionName: "edgereader_embeddings",
		UseTLS:         false,
	}
}

// QdrantVectorStore is a placeholder for the Qdrant-based vector store.
// This will be implemented in Epic-2 Phase 2.
//
// Implementation Plan:
//  1. Use qdrant-go client library
//  2. Create collection with HNSW index (cosine distance)
//  3. Map entity_type and user_id as payload filters
//  4. Implement batch upsert with configurable batch size
//  5. Support filtered search with payload conditions
type QdrantVectorStore struct {
	config QdrantConfig
}

// NewQdrantVectorStore creates a new Qdrant-based vector store.
// Note: This is a placeholder. Full implementation in Epic-2 Phase 2.
func NewQdrantVectorStore(config QdrantConfig) *QdrantVectorStore {
	return &QdrantVectorStore{config: config}
}

// ============================================================
// Migration Utilities
// ============================================================

// MigrationProgress tracks the progress of MySQL → Qdrant data migration.
type MigrationProgress struct {
	TotalEmbeddings  int64     `json:"total_embeddings"`
	SyncedEmbeddings int64     `json:"synced_embeddings"`
	FailedEmbeddings int64     `json:"failed_embeddings"`
	StartedAt        time.Time `json:"started_at"`
	LastSyncedAt     time.Time `json:"last_synced_at"`
	IsComplete       bool      `json:"is_complete"`
}

// MigrationService handles the data migration from MySQL to Qdrant.
// It reads embeddings from MySQL in batches and writes them to Qdrant,
// tracking sync status via the qdrant_synced_at column.
type MigrationService struct {
	mysqlStore  VectorStore
	qdrantStore VectorStore
	batchSize   int
}

// NewMigrationService creates a new migration service.
func NewMigrationService(mysqlStore, qdrantStore VectorStore, batchSize int) *MigrationService {
	if batchSize <= 0 {
		batchSize = 100
	}
	return &MigrationService{
		mysqlStore:  mysqlStore,
		qdrantStore: qdrantStore,
		batchSize:   batchSize,
	}
}
