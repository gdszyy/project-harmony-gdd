# EdgeReader 数据库性能基线报告

**版本:** 1.0
**日期:** 2026-03-01
**作者:** Backend Developer (Sprint2-T20)
**数据库:** MySQL 8.0
**引擎:** InnoDB

---

## 1. 概述

本报告对 EdgeReader 数据库 Schema 进行全面的性能基线分析，涵盖所有核心表（users、articles、reading_sessions、cognitive_tags、article_tags）以及 Sprint 2 新增的表（tag_relations、embeddings）。分析包括关键查询的 EXPLAIN 计划、索引覆盖评估、慢查询识别和优化建议。

## 2. 表结构与索引总览

### 2.1 索引清单

| 表名 | 索引名 | 索引列 | 类型 | 用途 |
|------|--------|--------|------|------|
| users | PRIMARY | id | 主键 | 主键查找 |
| users | idx_users_email | email | 唯一 | 邮箱登录查找 |
| users | username | username | 唯一 | 用户名查找 |
| users | idx_users_deleted_at | deleted_at | 普通 | 软删除过滤 |
| articles | PRIMARY | id | 主键 | 主键查找 |
| articles | idx_articles_user_id | user_id | 普通 | 用户文章列表 |
| articles | idx_articles_deleted_at | deleted_at | 普通 | 软删除过滤 |
| cognitive_tags | PRIMARY | id | 主键 | 主键查找 |
| cognitive_tags | idx_cognitive_tags_user_id | user_id | 普通 | 用户标签列表 |
| cognitive_tags | idx_cognitive_tags_name | name | 普通 | 标签名搜索 |
| cognitive_tags | idx_cognitive_tags_deleted_at | deleted_at | 普通 | 软删除过滤 |
| cognitive_tags | idx_cognitive_tags_dimension | dimension | 普通 | 维度过滤 (新增) |
| cognitive_tags | idx_cognitive_tags_source_type | source_type | 普通 | 来源过滤 (新增) |
| cognitive_tags | idx_cognitive_tags_user_dimension | (user_id, dimension) | 复合 | 用户+维度查询 (新增) |
| article_tags | PRIMARY | id | 主键 | 主键查找 |
| article_tags | uk_article_tag | (article_id, tag_id) | 唯一 | 去重约束 |
| article_tags | idx_article_tags_tag_id | tag_id | 普通 | 标签反查文章 |
| tag_relations | PRIMARY | id | 主键 | 主键查找 |
| tag_relations | uk_tag_relation | (source_tag_id, target_tag_id, relation_type) | 唯一 | 去重约束 |
| tag_relations | idx_tag_relations_target | target_tag_id | 普通 | 反向查找 |
| tag_relations | idx_tag_relations_type | relation_type | 普通 | 类型过滤 |
| tag_relations | idx_tag_relations_distance | distance | 普通 | 距离范围查询 |
| tag_relations | idx_tag_relations_source_type | (source_tag_id, relation_type) | 复合 | 图遍历查询 |
| embeddings | PRIMARY | id | 主键 | 主键查找 |
| embeddings | uk_embedding_entity | (entity_type, entity_id, chunk_index, model_name) | 唯一 | 实体去重 |
| embeddings | idx_embeddings_user_id | user_id | 普通 | 用户过滤 |
| embeddings | idx_embeddings_entity_type | entity_type | 普通 | 类型过滤 |
| embeddings | idx_embeddings_model | (model_name, model_version) | 复合 | 模型版本查询 |
| embeddings | idx_embeddings_content_hash | content_hash | 普通 | 内容去重 |
| embeddings | idx_embeddings_qdrant_sync | qdrant_synced_at | 普通 | 迁移状态追踪 |
| embeddings | idx_embeddings_user_type | (user_id, entity_type) | 复合 | 用户+类型查询 |

## 3. 关键查询 EXPLAIN 分析

### 3.1 用户登录查询

```sql
-- Q1: 通过邮箱查找用户
EXPLAIN SELECT * FROM users WHERE email = 'user@example.com' AND deleted_at IS NULL;
```

**预期执行计划:**

| id | select_type | table | type | possible_keys | key | key_len | ref | rows | Extra |
|----|-------------|-------|------|---------------|-----|---------|-----|------|-------|
| 1 | SIMPLE | users | const | idx_users_email | idx_users_email | 1022 | const | 1 | Using where |

**分析:** 使用唯一索引 `idx_users_email` 进行等值查找，时间复杂度 O(1)。`deleted_at IS NULL` 条件通过 `Using where` 在索引查找后过滤。**性能评级: 优秀。**

### 3.2 用户文章列表查询

```sql
-- Q2: 获取用户的文章列表（分页）
EXPLAIN SELECT id, title, source_type, word_count, created_at
FROM articles
WHERE user_id = 123 AND deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 20 OFFSET 0;
```

**预期执行计划:**

| id | select_type | table | type | possible_keys | key | key_len | ref | rows | Extra |
|----|-------------|-------|------|---------------|-----|---------|-----|------|-------|
| 1 | SIMPLE | articles | ref | idx_articles_user_id | idx_articles_user_id | 8 | const | ~100 | Using where; Using filesort |

**分析:** 使用 `idx_articles_user_id` 索引定位用户的文章，但 `ORDER BY created_at DESC` 需要 filesort。当用户文章数量较多时（>1000），filesort 可能成为瓶颈。

**优化建议:** 创建复合索引 `(user_id, deleted_at, created_at DESC)` 以消除 filesort。

```sql
-- 推荐索引
ALTER TABLE articles ADD INDEX idx_articles_user_created (user_id, deleted_at, created_at DESC);
```

### 3.3 文章标签关联查询

```sql
-- Q3: 获取文章的所有标签（带标签详情）
EXPLAIN SELECT ct.id, ct.name, ct.dimension, ct.weight, at.relevance_score
FROM article_tags at
JOIN cognitive_tags ct ON ct.id = at.tag_id
WHERE at.article_id = 456 AND ct.deleted_at IS NULL;
```

**预期执行计划:**

| id | select_type | table | type | possible_keys | key | key_len | ref | rows | Extra |
|----|-------------|-------|------|---------------|-----|---------|-----|------|-------|
| 1 | SIMPLE | at | ref | uk_article_tag | uk_article_tag | 8 | const | ~5 | - |
| 1 | SIMPLE | ct | eq_ref | PRIMARY | PRIMARY | 8 | at.tag_id | 1 | Using where |

**分析:** 利用 `uk_article_tag` 的前缀索引定位关联记录，然后通过主键 JOIN 获取标签详情。**性能评级: 优秀。**

### 3.4 标签反查文章

```sql
-- Q4: 查找包含特定标签的所有文章
EXPLAIN SELECT a.id, a.title, at.relevance_score
FROM article_tags at
JOIN articles a ON a.id = at.article_id
WHERE at.tag_id = 789 AND a.deleted_at IS NULL
ORDER BY at.relevance_score DESC
LIMIT 20;
```

**预期执行计划:**

| id | select_type | table | type | possible_keys | key | key_len | ref | rows | Extra |
|----|-------------|-------|------|---------------|-----|---------|-----|------|-------|
| 1 | SIMPLE | at | ref | idx_article_tags_tag_id | idx_article_tags_tag_id | 8 | const | ~50 | Using filesort |
| 1 | SIMPLE | a | eq_ref | PRIMARY | PRIMARY | 8 | at.article_id | 1 | Using where |

**分析:** 使用 `idx_article_tags_tag_id` 定位关联记录，但 `ORDER BY relevance_score DESC` 需要 filesort。

**优化建议:** 创建复合索引 `(tag_id, relevance_score DESC)` 以消除 filesort。

```sql
-- 推荐索引
ALTER TABLE article_tags ADD INDEX idx_article_tags_tag_relevance (tag_id, relevance_score DESC);
```

### 3.5 用户标签维度查询（Sprint 2 新增）

```sql
-- Q5: 获取用户特定维度的标签
EXPLAIN SELECT id, name, weight, decay_rate, source_type
FROM cognitive_tags
WHERE user_id = 123 AND dimension = 'concept' AND deleted_at IS NULL
ORDER BY weight DESC;
```

**预期执行计划:**

| id | select_type | table | type | possible_keys | key | key_len | ref | rows | Extra |
|----|-------------|-------|------|---------------|-----|---------|-----|------|-------|
| 1 | SIMPLE | cognitive_tags | ref | idx_cognitive_tags_user_dimension | idx_cognitive_tags_user_dimension | 138 | const,const | ~20 | Using where; Using filesort |

**分析:** 使用复合索引 `idx_cognitive_tags_user_dimension` 高效定位用户特定维度的标签。filesort 仅在少量结果上执行，影响可忽略。**性能评级: 良好。**

### 3.6 标签关系图遍历（Sprint 2 新增）

```sql
-- Q6: 获取标签的直接关联（一跳邻居）
EXPLAIN SELECT tr.target_tag_id, tr.relation_type, tr.distance, tr.confidence,
       ct.name, ct.dimension
FROM tag_relations tr
JOIN cognitive_tags ct ON ct.id = tr.target_tag_id
WHERE tr.source_tag_id = 100 AND tr.distance <= 0.5
  AND ct.deleted_at IS NULL;
```

**预期执行计划:**

| id | select_type | table | type | possible_keys | key | key_len | ref | rows | Extra |
|----|-------------|-------|------|---------------|-----|---------|-----|------|-------|
| 1 | SIMPLE | tr | ref | uk_tag_relation,idx_tag_relations_source_type | idx_tag_relations_source_type | 8 | const | ~10 | Using where |
| 1 | SIMPLE | ct | eq_ref | PRIMARY | PRIMARY | 8 | tr.target_tag_id | 1 | Using where |

**分析:** 使用 `idx_tag_relations_source_type` 的前缀定位源标签的关系，distance 过滤在索引查找后进行。**性能评级: 良好。**

### 3.7 向量相似度搜索（Sprint 2 新增）

```sql
-- Q7: 基于MySQL的向量相似度搜索（应用层实现）
-- 注意: 实际的余弦相似度计算在Go应用层完成
EXPLAIN SELECT id, entity_type, entity_id, chunk_index, chunk_text, vector, vector_norm
FROM embeddings
WHERE user_id = 123 AND entity_type = 'article' AND vector_norm > 0;
```

**预期执行计划:**

| id | select_type | table | type | possible_keys | key | key_len | ref | rows | Extra |
|----|-------------|-------|------|---------------|-----|---------|-----|------|-------|
| 1 | SIMPLE | embeddings | ref | idx_embeddings_user_type | idx_embeddings_user_type | 138 | const,const | ~500 | Using where |

**分析:** 使用复合索引 `idx_embeddings_user_type` 高效过滤用户和实体类型。向量数据通过全行读取加载到应用层进行余弦相似度计算。

**性能瓶颈:** 当向量数量超过 10,000 时，全量加载和计算将成为性能瓶颈。此时应迁移到 Qdrant 向量数据库。

**优化建议:**
1. 短期: 在应用层实现向量缓存（LRU Cache）
2. 中期: 使用 MySQL 存储过程减少数据传输
3. 长期: 迁移到 Qdrant 使用 HNSW 索引实现 ANN 搜索

### 3.8 Qdrant 迁移状态查询

```sql
-- Q8: 查找未同步到Qdrant的嵌入
EXPLAIN SELECT id, entity_type, entity_id, vector
FROM embeddings
WHERE qdrant_synced_at IS NULL
ORDER BY id ASC
LIMIT 100;
```

**预期执行计划:**

| id | select_type | table | type | possible_keys | key | key_len | ref | rows | Extra |
|----|-------------|-------|------|---------------|-----|---------|-----|------|-------|
| 1 | SIMPLE | embeddings | ref | idx_embeddings_qdrant_sync | idx_embeddings_qdrant_sync | 5 | const | ~100 | Using where |

**分析:** 使用 `idx_embeddings_qdrant_sync` 索引高效定位未同步记录。**性能评级: 优秀。**

## 4. 慢查询识别与优化

### 4.1 已识别的潜在慢查询

| 编号 | 查询场景 | 预期耗时 | 瓶颈原因 | 优化方案 | 优先级 |
|------|----------|----------|----------|----------|--------|
| SQ-1 | 用户文章列表排序 | >100ms (>1000篇) | filesort on created_at | 添加复合索引 (user_id, deleted_at, created_at) | 高 |
| SQ-2 | 标签反查文章排序 | >50ms (>100关联) | filesort on relevance_score | 添加复合索引 (tag_id, relevance_score) | 中 |
| SQ-3 | 向量相似度全量搜索 | >500ms (>10K向量) | 全表扫描+应用层计算 | 迁移到Qdrant | 中(Phase 2) |
| SQ-4 | 多跳标签关系遍历 | >200ms (>3跳) | 递归JOIN | 应用层BFS + 缓存 | 低 |
| SQ-5 | 全文搜索标签名 | >100ms (>10K标签) | LIKE '%keyword%' | 添加全文索引 | 低 |

### 4.2 推荐新增索引

```sql
-- 索引优化脚本 (可作为 006_performance_indexes.sql 迁移脚本)

-- SQ-1: 优化用户文章列表排序
ALTER TABLE articles
    ADD INDEX idx_articles_user_created (user_id, deleted_at, created_at DESC);

-- SQ-2: 优化标签反查文章排序
ALTER TABLE article_tags
    ADD INDEX idx_article_tags_tag_relevance (tag_id, relevance_score DESC);

-- SQ-5: 添加标签名全文索引
ALTER TABLE cognitive_tags
    ADD FULLTEXT INDEX ft_cognitive_tags_name (name);

-- 补充: 阅读记录的时间范围查询优化
ALTER TABLE reading_sessions
    ADD INDEX idx_reading_sessions_user_time (user_id, start_time DESC);
```

## 5. 数据量估算与容量规划

### 5.1 预期数据规模

| 表名 | 1年预估行数 | 单行大小 | 预估总大小 | 增长速率 |
|------|------------|----------|-----------|----------|
| users | 10,000 | ~500B | ~5MB | 线性 |
| articles | 500,000 | ~10KB | ~5GB | 线性 |
| cognitive_tags | 200,000 | ~300B | ~60MB | 线性 |
| article_tags | 2,000,000 | ~50B | ~100MB | 线性 |
| reading_sessions | 5,000,000 | ~200B | ~1GB | 线性 |
| tag_relations | 500,000 | ~150B | ~75MB | 超线性 |
| embeddings | 1,000,000 | ~12KB | ~12GB | 线性 |

### 5.2 embeddings 表特殊考量

embeddings 表由于存储 1536 维向量（JSON 格式约 12KB/行），是数据量最大的表。关键考量：

1. **存储优化:** JSON 格式的向量存储效率约为二进制格式的 3 倍。如果存储成为瓶颈，可考虑使用 BLOB 存储二进制向量。
2. **查询优化:** 向量相似度搜索是 O(n*d) 复杂度，当 n > 10K 时应迁移到 Qdrant。
3. **索引大小:** JSON 列不参与 B-Tree 索引，不会影响索引性能。
4. **备份策略:** 建议对 embeddings 表使用增量备份，避免全量备份的 I/O 压力。

## 6. 性能基线指标

### 6.1 查询延迟基线 (目标值)

| 查询类型 | P50 延迟 | P95 延迟 | P99 延迟 | 备注 |
|----------|----------|----------|----------|------|
| 主键查找 | <1ms | <5ms | <10ms | 所有表 |
| 索引范围查询 | <5ms | <20ms | <50ms | 带索引的 WHERE 条件 |
| JOIN 查询 (2表) | <10ms | <50ms | <100ms | article_tags JOIN |
| 分页查询 | <20ms | <100ms | <200ms | LIMIT/OFFSET |
| 向量搜索 (<1K) | <50ms | <200ms | <500ms | MySQL 应用层计算 |
| 向量搜索 (<10K) | <200ms | <1s | <2s | MySQL 应用层计算 |
| 图遍历 (2跳) | <50ms | <200ms | <500ms | 应用层 BFS |

### 6.2 吞吐量基线 (目标值)

| 操作类型 | 目标 QPS | 并发连接数 | 备注 |
|----------|----------|-----------|------|
| 读操作 (简单查询) | 5,000 | 25 | 连接池上限 |
| 读操作 (JOIN 查询) | 2,000 | 25 | - |
| 写操作 (单行插入) | 1,000 | 10 | - |
| 写操作 (批量插入) | 200 | 5 | 每批 100 行 |
| 向量搜索 | 50 | 5 | MySQL 实现 |

## 7. 监控建议

### 7.1 关键监控指标

1. **慢查询日志:** 设置 `long_query_time = 0.2`（200ms），监控超过阈值的查询。
2. **连接池使用率:** 监控 `Threads_connected / max_connections`，告警阈值 80%。
3. **InnoDB Buffer Pool 命中率:** 目标 >99%，低于 95% 需要增加 buffer pool 大小。
4. **表锁等待:** 监控 `Innodb_row_lock_waits`，识别锁竞争问题。
5. **embeddings 表大小:** 监控表数据和索引大小，超过 10GB 时评估 Qdrant 迁移。

### 7.2 推荐 MySQL 配置

```ini
[mysqld]
# InnoDB Buffer Pool (建议为可用内存的 70%)
innodb_buffer_pool_size = 2G
innodb_buffer_pool_instances = 4

# 慢查询日志
slow_query_log = 1
long_query_time = 0.2
log_queries_not_using_indexes = 1

# 连接池
max_connections = 100
wait_timeout = 300

# JSON 优化
max_allowed_packet = 64M

# 排序缓冲区 (优化 filesort)
sort_buffer_size = 4M
```

## 8. 总结与行动项

### 8.1 当前状态评估

EdgeReader 数据库 Schema 设计整体合理，索引覆盖了大部分常见查询模式。Sprint 2 新增的认知标签扩展和向量检索表设计充分考虑了性能和可扩展性。

### 8.2 优先行动项

| 优先级 | 行动项 | 预期收益 | 实施复杂度 |
|--------|--------|----------|-----------|
| P0 | 添加 `idx_articles_user_created` 复合索引 | 消除文章列表 filesort | 低 |
| P0 | 添加 `idx_article_tags_tag_relevance` 复合索引 | 消除标签反查 filesort | 低 |
| P1 | 配置慢查询日志 | 持续监控性能退化 | 低 |
| P1 | 实现向量缓存 (LRU) | 减少向量搜索延迟 | 中 |
| P2 | 添加标签名全文索引 | 优化模糊搜索 | 低 |
| P2 | 评估 Qdrant 部署 | 支持大规模向量搜索 | 高 |
| P3 | embeddings 表分区 | 优化大表管理 | 中 |

### 8.3 向量搜索性能演进路线

```
Phase 1 (当前): MySQL JSON + Go 应用层计算
  ├── 适用: <10K 向量
  ├── 延迟: 50-500ms
  └── 优势: 零额外基础设施

Phase 2 (Epic-2): MySQL + Qdrant 双写
  ├── 适用: 10K-1M 向量
  ├── 延迟: 5-50ms (Qdrant)
  └── 优势: 平滑迁移，无停机

Phase 3 (未来): Qdrant 主存储 + MySQL 审计
  ├── 适用: >1M 向量
  ├── 延迟: 1-10ms (Qdrant HNSW)
  └── 优势: 最优性能
```

---

*本报告基于 Schema 静态分析和 MySQL 8.0 查询优化器行为预测生成。建议在生产环境部署后，使用实际数据进行基准测试验证。*
