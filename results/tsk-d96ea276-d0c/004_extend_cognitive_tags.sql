-- Migration: 004_extend_cognitive_tags
-- Description: Extend cognitive_tags table with dimension, decay_rate, source_type fields;
--              Create tag_relations table for inter-tag relationships
-- Created: 2026-03-01
-- Sprint: Sprint2-T20 (Epic-2 铺垫)
-- Backward Compatibility: All new columns are nullable or have defaults,
--                          existing queries remain unaffected.

-- ============================================================
-- Part 1: Extend cognitive_tags table
-- ============================================================

-- Add dimension field: categorizes tags into semantic dimensions
-- Values: topic (主题), concept (概念), entity (实体), sentiment (情感), skill (技能)
ALTER TABLE cognitive_tags
    ADD COLUMN dimension VARCHAR(32) DEFAULT 'topic'
    COMMENT '标签维度分类: topic/concept/entity/sentiment/skill'
    AFTER weight;

-- Add decay_rate field: controls how quickly the tag weight decays over time
-- Range: 0.0 (no decay) to 1.0 (fastest decay), default 0.1
ALTER TABLE cognitive_tags
    ADD COLUMN decay_rate FLOAT DEFAULT 0.1
    COMMENT '标签权重时间衰减速率 (0.0=不衰减, 1.0=最快衰减)'
    AFTER dimension;

-- Add source_type field: indicates how the tag was created
-- Values: manual (用户手动), auto_extract (自动提取), ai_suggest (AI推荐)
ALTER TABLE cognitive_tags
    ADD COLUMN source_type VARCHAR(32) DEFAULT 'manual'
    COMMENT '标签来源类型: manual/auto_extract/ai_suggest'
    AFTER decay_rate;

-- Add composite index for dimension-based queries
ALTER TABLE cognitive_tags
    ADD INDEX idx_cognitive_tags_dimension (dimension);

-- Add composite index for source_type filtering
ALTER TABLE cognitive_tags
    ADD INDEX idx_cognitive_tags_source_type (source_type);

-- Add composite index for user + dimension queries (common access pattern)
ALTER TABLE cognitive_tags
    ADD INDEX idx_cognitive_tags_user_dimension (user_id, dimension);

-- ============================================================
-- Part 2: Create tag_relations table
-- ============================================================

-- tag_relations stores directed relationships between cognitive tags.
-- This enables building a knowledge graph of tag associations.
-- relation_type examples:
--   - 'parent_child': hierarchical relationship
--   - 'synonym': semantic equivalence
--   - 'related': general association
--   - 'contrast': opposing concepts
--   - 'prerequisite': learning dependency

CREATE TABLE IF NOT EXISTS tag_relations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    -- Source tag (from)
    source_tag_id BIGINT UNSIGNED NOT NULL
        COMMENT '源标签ID',

    -- Target tag (to)
    target_tag_id BIGINT UNSIGNED NOT NULL
        COMMENT '目标标签ID',

    -- Relationship type
    relation_type VARCHAR(32) NOT NULL DEFAULT 'related'
        COMMENT '关系类型: parent_child/synonym/related/contrast/prerequisite',

    -- Semantic distance / similarity strength (0.0 = identical, 1.0 = unrelated)
    distance FLOAT DEFAULT 0.5
        COMMENT '语义距离 (0.0=完全相同, 1.0=完全无关)',

    -- Confidence score of this relationship (0.0 to 1.0)
    confidence FLOAT DEFAULT 1.0
        COMMENT '关系置信度 (0.0-1.0)',

    -- Metadata JSON for extensibility
    metadata JSON DEFAULT NULL
        COMMENT '扩展元数据 (JSON格式)',

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Prevent duplicate relationships between same tag pair with same type
    UNIQUE KEY uk_tag_relation (source_tag_id, target_tag_id, relation_type),

    -- Index for reverse lookups
    INDEX idx_tag_relations_target (target_tag_id),

    -- Index for relation_type filtering
    INDEX idx_tag_relations_type (relation_type),

    -- Index for distance-based queries (find closely related tags)
    INDEX idx_tag_relations_distance (distance),

    -- Composite index for graph traversal queries
    INDEX idx_tag_relations_source_type (source_tag_id, relation_type),

    -- Foreign keys
    FOREIGN KEY (source_tag_id) REFERENCES cognitive_tags(id) ON DELETE CASCADE,
    FOREIGN KEY (target_tag_id) REFERENCES cognitive_tags(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='标签间关联关系表 - 支持知识图谱构建';

-- ============================================================
-- Part 3: Rollback script (commented out for reference)
-- ============================================================

-- To rollback this migration:
-- ALTER TABLE cognitive_tags DROP INDEX idx_cognitive_tags_user_dimension;
-- ALTER TABLE cognitive_tags DROP INDEX idx_cognitive_tags_source_type;
-- ALTER TABLE cognitive_tags DROP INDEX idx_cognitive_tags_dimension;
-- ALTER TABLE cognitive_tags DROP COLUMN source_type;
-- ALTER TABLE cognitive_tags DROP COLUMN decay_rate;
-- ALTER TABLE cognitive_tags DROP COLUMN dimension;
-- DROP TABLE IF EXISTS tag_relations;
