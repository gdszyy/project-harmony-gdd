# EdgeReader Server

EdgeReader 后端服务 - 智能阅读辅助系统

## 目录结构

```
server/
├── cmd/                              # 应用入口
├── internal/
│   ├── ai/
│   │   ├── embedding/
│   │   │   ├── service.go            # 嵌入服务接口 (VectorStore抽象)
│   │   │   └── mysql_store.go        # MySQL向量存储实现
│   │   └── graph/
│   │       └── adjacency.go          # 标签知识图谱邻接表
│   ├── database/
│   │   └── database.go               # 数据库连接和配置
│   └── models/
│       ├── base.go                   # 基础模型 (User, Article, ReadingSession)
│       ├── cognitive_tag.go          # 认知标签模型 (含Sprint2扩展)
│       └── embedding.go             # 嵌入向量模型
├── migrations/
│   ├── 001_create_users.sql          # 用户表
│   ├── 002_create_articles.sql       # 文章表 + 阅读记录表
│   ├── 003_create_cognitive_tags.sql # 认知标签表 + 关联表
│   ├── 004_extend_cognitive_tags.sql # Sprint2: 标签扩展 + tag_relations
│   ├── 005_create_embeddings_table.sql # Sprint2: 向量嵌入表
│   └── 006_performance_indexes.sql   # 性能优化索引
├── docs/
│   └── database_performance_baseline.md # 数据库性能基线报告
├── go.mod
└── README.md
```

## Sprint 2 交付物 (T20)

### 1. 认知标签 Schema 扩展
- **迁移脚本:** `migrations/004_extend_cognitive_tags.sql`
- **GORM 模型:** `internal/models/cognitive_tag.go`
- **新增字段:** dimension, decay_rate, source_type
- **新增表:** tag_relations (标签关联关系)
- **向下兼容:** 所有新字段有默认值，不影响现有查询

### 2. 向量检索数据模型
- **迁移脚本:** `migrations/005_create_embeddings_table.sql`
- **GORM 模型:** `internal/models/embedding.go`
- **服务接口:** `internal/ai/embedding/service.go`
- **MySQL 实现:** `internal/ai/embedding/mysql_store.go`
- **特性:** 支持 MySQL→Qdrant 平滑迁移的双写架构

### 3. 数据库性能基线
- **报告:** `docs/database_performance_baseline.md`
- **优化索引:** `migrations/006_performance_indexes.sql`
- **覆盖:** 8 个关键查询的 EXPLAIN 分析，5 个慢查询识别

## 技术规格

- **数据库:** MySQL 8.0 (InnoDB)
- **ORM:** GORM v1.25
- **向量维度:** 1536 (OpenAI text-embedding-3-small)
- **Go 版本:** 1.21+
