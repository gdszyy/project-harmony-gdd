# Sprint2-T11: CI/CD 流水线与自动化备份

## 任务概述

为 EdgeReader 项目建立完整的 CI/CD 流水线和数据库自动备份策略。

**关联问题**: OPS-P2-1, OPS-P2-2

## 交付物清单

### CI/CD 流水线 (OPS-P2-1)

| 文件 | 说明 |
|------|------|
| `deliverables/.github/workflows/ci.yml` | CI 流水线 — PR 检查（golangci-lint + ESLint + go test + vitest + Docker build + Trivy scan） |
| `deliverables/.github/workflows/cd.yml` | CD 流水线 — main 分支部署（构建 + GHCR 推送 + SSH 部署 + 部署后备份） |
| `deliverables/.github/workflows/db-backup.yml` | 数据库定时备份 GitHub Actions 工作流 |
| `deliverables/.golangci.yml` | golangci-lint 配置（15+ linter 规则） |

### 数据库备份 (OPS-P2-2)

| 文件 | 说明 |
|------|------|
| `deliverables/scripts/db-backup.sh` | 备份脚本 — mysqldump + AES-256-GCM 加密 + S3 上传 + 轮转策略 |
| `deliverables/scripts/db-restore.sh` | 恢复脚本 — 解密 + 验证 + 恢复（支持 dry-run） |
| `deliverables/scripts/crontab-backup` | Crontab 定时任务配置 |

### 文档

| 文件 | 说明 |
|------|------|
| `deliverables/docs/09-cicd-and-backup.md` | 完整的 CI/CD 和备份策略文档 |

## 已提交到 edge-reader 仓库

以下文件已成功推送到 `gdszyy/edge-reader` 的 main 分支：
- `.golangci.yml`
- `scripts/db-backup.sh`
- `scripts/db-restore.sh`
- `scripts/crontab-backup`
- `docs/09-cicd-and-backup.md`

**注意**：`.github/workflows/` 目录下的工作流文件因 GitHub App Token 缺少 `workflows` 权限，无法通过自动化推送。这些文件保存在本仓库的 `deliverables/` 目录中，需要仓库 owner 手动复制到 edge-reader 仓库。

## 技术要点

1. **CI Pipeline**: 6 个并行/串行 Job，包含代码检查、测试、Docker 构建和安全扫描
2. **CD Pipeline**: 自动化部署到生产环境，包含镜像推送和 SSH 部署
3. **备份加密**: 使用 AES-256-GCM（与项目 `server/pkg/encryption` 保持一致）
4. **轮转策略**: 每日备份保留 7 天 + 每周备份保留 30 天
5. **恢复脚本**: 支持本地/S3 恢复，dry-run 验证模式，交互确认
