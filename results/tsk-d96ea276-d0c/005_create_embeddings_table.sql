-- Migration: 005_create_embeddings_table
-- Description: Create embeddings table for vector storage and similarity search.
--              Supports 1536-dimensional vectors (OpenAI text-embedding-3-small).
--              Designed for MySQL-based temporary cosine similarity with a clear
--              migration path to Qdrant vector database.
-- Created: 2026-03-01
-- Sprint: Sprint2-T20 (Epic-2 铺垫)

-- ============================================================
-- Part 1: Create embeddings table
-- ============================================================

-- Design Rationale:
-- 1. Vectors are stored as JSON arrays in MySQL for simplicity and portability.
--    JSON type provides validation and allows MySQL 8.0 JSON functions.
-- 2. The entity_type + entity_id pattern allows embedding any entity type
--    (articles, tags, text chunks) without foreign key constraints.
-- 3. model_name tracks which embedding model generated the vector,
--    enabling gradual model upgrades without data loss.
-- 4. vector_norm is pre-computed to speed up cosine similarity calculations.
-- 5. When migrating to Qdrant, this table serves as the source of truth
--    for initial data loading, then becomes a metadata/audit table.

CREATE TABLE IF NOT EXISTS embeddings (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    -- Polymorphic entity reference
    -- entity_type: 'article', 'cognitive_tag', 'text_chunk'
    entity_type VARCHAR(32) NOT NULL
        COMMENT '实体类型: article/cognitive_tag/text_chunk',

    entity_id BIGINT UNSIGNED NOT NULL
        COMMENT '实体ID (对应各表的主键)',

    -- User ownership for data isolation
    user_id BIGINT UNSIGNED NOT NULL
        COMMENT '所属用户ID',

    -- Vector data (1536 dimensions for text-embedding-3-small)
    -- Stored as JSON array: [0.0123, -0.0456, ...]
    vector JSON NOT NULL
        COMMENT '嵌入向量 (JSON数组, 1536维)',

    -- Pre-computed L2 norm for cosine similarity optimization
    -- norm = sqrt(sum(v[i]^2))
    vector_norm DOUBLE NOT NULL DEFAULT 0.0
        COMMENT '向量L2范数 (预计算, 用于余弦相似度加速)',

    -- Vector dimensions (for validation)
    dimensions INT UNSIGNED NOT NULL DEFAULT 1536
        COMMENT '向量维度数',

    -- Embedding model identifier
    model_name VARCHAR(64) NOT NULL DEFAULT 'text-embedding-3-small'
        COMMENT '生成向量的模型名称',

    -- Model version for tracking upgrades
    model_version VARCHAR(32) DEFAULT 'v1'
        COMMENT '模型版本',

    -- Content hash for deduplication (MD5 of the source text)
    content_hash VARCHAR(64) DEFAULT NULL
        COMMENT '源文本MD5哈希 (用于去重)',

    -- Text chunk information (for chunked articles)
    chunk_index INT UNSIGNED DEFAULT 0
        COMMENT '文本块索引 (用于分块文章)',

    chunk_text TEXT DEFAULT NULL
        COMMENT '文本块原文 (可选, 用于调试和展示)',

    -- Qdrant migration tracking
    -- NULL = not synced, timestamp = last sync time
    qdrant_synced_at TIMESTAMP NULL DEFAULT NULL
        COMMENT 'Qdrant同步时间 (NULL=未同步)',

    qdrant_point_id VARCHAR(64) DEFAULT NULL
        COMMENT 'Qdrant中的Point ID (UUID格式)',

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- ============================================================
    -- Indexes
    -- ============================================================

    -- Primary lookup: find embedding for a specific entity
    UNIQUE KEY uk_embedding_entity (entity_type, entity_id, chunk_index, model_name),

    -- User-scoped queries
    INDEX idx_embeddings_user_id (user_id),

    -- Entity type filtering
    INDEX idx_embeddings_entity_type (entity_type),

    -- Model-based queries (for batch re-embedding during model upgrades)
    INDEX idx_embeddings_model (model_name, model_version),

    -- Content deduplication
    INDEX idx_embeddings_content_hash (content_hash),

    -- Qdrant sync status tracking
    INDEX idx_embeddings_qdrant_sync (qdrant_synced_at),

    -- User + entity type composite (common query pattern)
    INDEX idx_embeddings_user_type (user_id, entity_type),

    -- Foreign key
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='语义嵌入向量表 - 支持MySQL余弦相似度计算和Qdrant迁移';

-- ============================================================
-- Part 2: Helper stored procedure for cosine similarity
-- ============================================================

-- Note: This is a temporary solution for MySQL-based vector search.
-- For production workloads with >100K vectors, migrate to Qdrant.
-- 
-- MySQL JSON functions are used to extract vector components.
-- The cosine similarity formula:
--   cos(A, B) = (A · B) / (||A|| * ||B||)
-- where A · B = sum(A[i] * B[i])
--
-- Pre-computed vector_norm eliminates the need to recalculate ||A|| each time.

DELIMITER //

-- find_similar_embeddings: Find top-N most similar embeddings to a query vector.
-- Parameters:
--   p_query_vector: JSON array of the query vector
--   p_query_norm: L2 norm of the query vector
--   p_user_id: User ID for data isolation
--   p_entity_type: Entity type filter (or NULL for all types)
--   p_limit: Maximum number of results
--   p_min_similarity: Minimum cosine similarity threshold (0.0 to 1.0)
CREATE PROCEDURE find_similar_embeddings(
    IN p_query_vector JSON,
    IN p_query_norm DOUBLE,
    IN p_user_id BIGINT UNSIGNED,
    IN p_entity_type VARCHAR(32),
    IN p_limit INT,
    IN p_min_similarity DOUBLE
)
BEGIN
    -- Use a generated column approach for dot product calculation.
    -- For each stored vector, compute: sum(query[i] * stored[i]) / (query_norm * stored_norm)
    -- 
    -- MySQL 8.0 JSON_TABLE is used to unnest the vector arrays for dot product.
    -- This is O(n*d) where n=number of embeddings, d=dimensions.
    -- Acceptable for <10K vectors; use Qdrant for larger datasets.
    
    SET @query_vec = p_query_vector;
    SET @query_norm = p_query_norm;
    
    SELECT 
        e.id,
        e.entity_type,
        e.entity_id,
        e.chunk_index,
        e.chunk_text,
        -- Cosine similarity via dot product / (norm_a * norm_b)
        (
            SELECT SUM(qv.val * ev.val)
            FROM JSON_TABLE(@query_vec, '$[*]' COLUMNS(
                idx FOR ORDINALITY,
                val DOUBLE PATH '$'
            )) AS qv
            INNER JOIN JSON_TABLE(e.vector, '$[*]' COLUMNS(
                idx FOR ORDINALITY,
                val DOUBLE PATH '$'
            )) AS ev ON qv.idx = ev.idx
        ) / (@query_norm * e.vector_norm) AS similarity
    FROM embeddings e
    WHERE e.user_id = p_user_id
        AND (p_entity_type IS NULL OR e.entity_type = p_entity_type)
        AND e.vector_norm > 0
    HAVING similarity >= p_min_similarity
    ORDER BY similarity DESC
    LIMIT p_limit;
END //

DELIMITER ;

-- ============================================================
-- Part 3: Rollback script (commented out for reference)
-- ============================================================

-- To rollback this migration:
-- DROP PROCEDURE IF EXISTS find_similar_embeddings;
-- DROP TABLE IF EXISTS embeddings;
