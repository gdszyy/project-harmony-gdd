-- Migration: 006_performance_indexes
-- Description: Add performance optimization indexes identified in the
--              database performance baseline analysis.
-- Created: 2026-03-01
-- Sprint: Sprint2-T20
-- Reference: server/docs/database_performance_baseline.md

-- ============================================================
-- SQ-1: Optimize user article list sorting
-- Eliminates filesort for: SELECT ... FROM articles
--   WHERE user_id = ? AND deleted_at IS NULL ORDER BY created_at DESC
-- ============================================================
ALTER TABLE articles
    ADD INDEX idx_articles_user_created (user_id, deleted_at, created_at DESC);

-- ============================================================
-- SQ-2: Optimize tag-to-article reverse lookup sorting
-- Eliminates filesort for: SELECT ... FROM article_tags
--   WHERE tag_id = ? ORDER BY relevance_score DESC
-- ============================================================
ALTER TABLE article_tags
    ADD INDEX idx_article_tags_tag_relevance (tag_id, relevance_score DESC);

-- ============================================================
-- SQ-5: Add fulltext index for tag name search
-- Optimizes: SELECT ... FROM cognitive_tags WHERE name LIKE '%keyword%'
-- ============================================================
ALTER TABLE cognitive_tags
    ADD FULLTEXT INDEX ft_cognitive_tags_name (name);

-- ============================================================
-- Supplementary: Optimize reading session time-range queries
-- Optimizes: SELECT ... FROM reading_sessions
--   WHERE user_id = ? ORDER BY start_time DESC
-- ============================================================
ALTER TABLE reading_sessions
    ADD INDEX idx_reading_sessions_user_time (user_id, start_time DESC);

-- ============================================================
-- Rollback script (commented out for reference)
-- ============================================================
-- ALTER TABLE articles DROP INDEX idx_articles_user_created;
-- ALTER TABLE article_tags DROP INDEX idx_article_tags_tag_relevance;
-- ALTER TABLE cognitive_tags DROP INDEX ft_cognitive_tags_name;
-- ALTER TABLE reading_sessions DROP INDEX idx_reading_sessions_user_time;
