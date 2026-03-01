# EdgeReader 数据库 Schema 设计文档

## 版本历史

| 版本 | 日期 | 描述 |
|------|------|------|
| 1.0 | 2026-02-15 | 初始 Schema 设计 |
| 1.1 | 2026-03-01 | Sprint2-T20: 认知标签扩展 + 向量检索铺垫 |

## 1. 概述

EdgeReader 是一个智能阅读辅助系统，通过认知标签（Cognitive Tags）对用户的阅读内容进行语义标注和关联分析。本文档定义了系统的核心数据库 Schema。

## 2. 核心表结构

### 2.1 用户表 (users)

```sql
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(64) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    avatar_url VARCHAR(512) DEFAULT '',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_users_email (email),
    INDEX idx_users_deleted_at (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.2 文章表 (articles)

```sql
CREATE TABLE articles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(512) NOT NULL,
    content LONGTEXT,
    source_url VARCHAR(2048) DEFAULT '',
    source_type ENUM('web', 'pdf', 'epub', 'manual') DEFAULT 'web',
    word_count INT UNSIGNED DEFAULT 0,
    reading_time_minutes INT UNSIGNED DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_articles_user_id (user_id),
    INDEX idx_articles_deleted_at (deleted_at),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.3 认知标签表 (cognitive_tags) — 初始版本

```sql
CREATE TABLE cognitive_tags (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    description TEXT DEFAULT '',
    weight FLOAT DEFAULT 1.0,
    user_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_cognitive_tags_user_id (user_id),
    INDEX idx_cognitive_tags_name (name),
    INDEX idx_cognitive_tags_deleted_at (deleted_at),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.4 文章-标签关联表 (article_tags)

```sql
CREATE TABLE article_tags (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    article_id BIGINT UNSIGNED NOT NULL,
    tag_id BIGINT UNSIGNED NOT NULL,
    relevance_score FLOAT DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_article_tag (article_id, tag_id),
    INDEX idx_article_tags_tag_id (tag_id),
    FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES cognitive_tags(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.5 阅读记录表 (reading_sessions)

```sql
CREATE TABLE reading_sessions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    article_id BIGINT UNSIGNED NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NULL,
    progress_percent FLOAT DEFAULT 0.0,
    notes TEXT DEFAULT '',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_reading_sessions_user_id (user_id),
    INDEX idx_reading_sessions_article_id (article_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

## 3. 迁移脚本索引

| 编号 | 文件名 | 描述 |
|------|--------|------|
| 001 | 001_create_users.sql | 创建用户表 |
| 002 | 002_create_articles.sql | 创建文章表和阅读记录表 |
| 003 | 003_create_cognitive_tags.sql | 创建认知标签表和关联表 |
| 004 | 004_extend_cognitive_tags.sql | 扩展认知标签 (dimension/decay_rate/source_type + tag_relations) |
| 005 | 005_create_embeddings_table.sql | 创建向量嵌入表 |

## 4. 扩展说明 (Sprint 2)

### 4.1 认知标签扩展 (004)
- 新增 `dimension` 字段：标签维度分类（topic/concept/entity/sentiment/skill）
- 新增 `decay_rate` 字段：标签权重随时间的衰减速率
- 新增 `source_type` 字段：标签来源类型（manual/auto_extract/ai_suggest）
- 新增 `tag_relations` 表：存储标签间的关联关系和语义距离

### 4.2 向量检索铺垫 (005)
- 新增 `embeddings` 表：存储文章和标签的 1536 维语义向量
- 支持基于 MySQL 的临时余弦相似度计算
- 接口设计支持未来平滑迁移到 Qdrant 向量数据库
