# server/internal/ai/embedding/service.go 函数索引

> 自动生成于 2026-05-08 | 总行数: 416 | 函数数: 25 | 语言: go
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `SearchRequest` | struct | `SearchRequest()` |  |
| `SearchResult` | struct | `SearchResult()` |  |
| `UpsertRequest` | struct | `UpsertRequest()` |  |
| `VectorStore` | interface | `VectorStore()` |  |
| `EmbeddingProvider` | interface | `EmbeddingProvider()` |  |
| `Service` | struct | `Service()` |  |
| `NewService` | function | `NewService(provider EmbeddingProvider, store VectorStore)` |  |
| `SetSecondaryStore` | function | `SetSecondaryStore(store VectorStore)` |  |
| `EmbedAndStore` | function | `EmbedAndStore(ctx context.Context, entityType string, entityID uint64, userID uint64, text string)` |  |
| `EmbedChunkedAndStore` | function | `EmbedChunkedAndStore(ctx context.Context, entityType string, entityID uint64, userID uint64, chunks []string)` |  |
| `FindSimilar` | function | `FindSimilar(ctx context.Context, text string, userID uint64, entityType string, topK int, minSimilarity float64)` |  |
| `FindSimilarByVector` | function | `FindSimilarByVector(ctx context.Context, queryVector []float64, userID uint64, entityType string, topK int, minSimilarity float64)` |  |
| `DeleteEmbedding` | function | `DeleteEmbedding(ctx context.Context, entityType string, entityID uint64)` |  |
| `Health` | function | `Health(ctx context.Context)` |  |
| `MySQLVectorStore` | struct | `MySQLVectorStore()` |  |
| `NewMySQLVectorStore` | function | `NewMySQLVectorStore(db interface{})` |  |
| `CosineSimilarity` | function | `CosineSimilarity(a, b []float64)` |  |
| `VectorNorm` | function | `VectorNorm(v []float64)` |  |
| `QdrantConfig` | struct | `QdrantConfig()` |  |
| `DefaultQdrantConfig` | function | `DefaultQdrantConfig()` |  |
| `QdrantVectorStore` | struct | `QdrantVectorStore()` |  |
| `NewQdrantVectorStore` | function | `NewQdrantVectorStore(config QdrantConfig)` |  |
| `MigrationProgress` | struct | `MigrationProgress()` |  |
| `MigrationService` | struct | `MigrationService()` |  |
| `NewMigrationService` | function | `NewMigrationService(mysqlStore, qdrantStore VectorStore, batchSize int)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" server/internal/ai/embedding/service.go
```
