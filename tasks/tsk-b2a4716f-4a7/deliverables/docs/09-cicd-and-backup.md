# CI/CD 流水线与数据库备份策略

> **Sprint2-T11** | 关联问题: OPS-P2-1, OPS-P2-2

## 1. 概述

本文档描述 EdgeReader 项目的持续集成/持续部署（CI/CD）流水线设计和数据库自动备份策略。所有配置均基于 GitHub Actions 实现，备份脚本支持独立部署在生产服务器上。

## 2. CI/CD 流水线架构

### 2.1 流水线总览

EdgeReader 的 CI/CD 流水线分为两个主要工作流：

| 工作流 | 触发条件 | 文件 | 功能 |
|--------|----------|------|------|
| CI Pipeline | PR 到 main/develop | `.github/workflows/ci.yml` | 代码检查、测试、构建验证 |
| CD Pipeline | push 到 main | `.github/workflows/cd.yml` | 构建、推送、部署 |
| DB Backup | 每日定时 / 手动 | `.github/workflows/db-backup.yml` | 数据库备份与轮转 |

### 2.2 CI Pipeline（PR 检查）

当开发者提交 Pull Request 时，CI 流水线自动执行以下检查：

```
PR 提交
  ├── lint-backend (golangci-lint)
  │     └── test-backend (go test + coverage)
  ├── lint-frontend (ESLint + TypeCheck)
  │     └── test-frontend (Vitest)
  └── docker-build-scan (并行)
        ├── server: Docker Build + Trivy Scan
        └── web: Docker Build + Trivy Scan
  └── ci-summary (汇总)
```

**Job 详细说明：**

**后端代码检查（golangci-lint）**：使用 `.golangci.yml` 配置文件，启用 errcheck、gosimple、govet、staticcheck、gosec 等 15+ 个 linter，超时时间 5 分钟。

**前端代码检查（ESLint + TypeCheck）**：执行 `pnpm lint` 和 `vue-tsc --noEmit`，确保代码风格一致和类型安全。

**后端自动化测试**：启动 MySQL 8.0 和 Redis 7 服务容器，执行 `go test ./... -v -race -coverprofile=coverage.out`，自动在 PR 评论中发布覆盖率报告。

**前端自动化测试**：执行 `pnpm vitest run --coverage`，生成前端测试覆盖率报告。

**Docker 镜像构建与安全扫描**：并行构建 server 和 web 两个 Docker 镜像，使用 Trivy 扫描 CRITICAL 和 HIGH 级别漏洞，扫描结果自动发布到 PR 评论。

### 2.3 CD Pipeline（main 分支部署）

当 PR 合并到 main 分支后，CD 流水线自动执行：

```
main push
  └── test (完整测试套件)
        └── build-and-push (并行)
              ├── server → ghcr.io
              └── web → ghcr.io
              └── security-scan (Trivy SARIF → GitHub Security)
                    └── deploy (SSH 部署)
                          └── post-deploy-backup (部署后备份)
```

**镜像标签策略**：每次构建生成三个标签 — `latest`、Git SHA 短哈希、时间戳（`YYYYMMDD-HHmmss`）。

**部署方式**：通过 SSH 连接生产服务器，执行 `docker compose pull` 和 `docker compose up -d` 实现滚动更新。部署后自动触发数据库备份。

### 2.4 所需 GitHub Secrets 和 Variables

| 名称 | 类型 | 说明 |
|------|------|------|
| `GITHUB_TOKEN` | Secret (自动) | GitHub 自动提供，用于 GHCR 推送 |
| `DEPLOY_SSH_KEY` | Secret | 生产服务器 SSH 私钥 |
| `DEPLOY_HOST` | Variable | 生产服务器地址 |
| `DEPLOY_USER` | Variable | SSH 用户名 |
| `DEPLOY_PORT` | Variable | SSH 端口（默认 22） |
| `DEPLOY_PATH` | Variable | 项目部署路径（默认 `/opt/edgereader`） |
| `PRODUCTION_URL` | Variable | 生产环境 URL |

## 3. 数据库备份策略

### 3.1 备份架构

```
定时触发 (cron / GitHub Actions)
  └── db-backup.sh
        ├── [1] mysqldump 导出（单事务、完整备份）
        ├── [2] gzip -9 压缩
        ├── [3] AES-256-GCM 加密
        ├── [4] SHA-256 校验和生成
        └── [5] S3 上传
```

### 3.2 备份脚本

| 脚本 | 路径 | 功能 |
|------|------|------|
| `db-backup.sh` | `scripts/db-backup.sh` | 备份、轮转、验证、列表 |
| `db-restore.sh` | `scripts/db-restore.sh` | 从加密备份恢复数据库 |
| `crontab-backup` | `scripts/crontab-backup` | Crontab 定时任务配置 |

### 3.3 备份命令

```bash
# 执行完整备份
bash scripts/db-backup.sh

# 带原因标记的备份（如部署前）
bash scripts/db-backup.sh --reason "pre-deploy"

# 执行轮转清理
bash scripts/db-backup.sh --rotate

# 验证最新备份完整性
bash scripts/db-backup.sh --verify-latest

# 列出所有备份
bash scripts/db-backup.sh --list
```

### 3.4 加密方案

备份文件使用 **AES-256-GCM** 加密，与项目已有的 `server/pkg/encryption` 工具包保持一致。加密密钥来源于环境变量 `BACKUP_ENCRYPTION_KEY` 或 `ENCRYPTION_KEY`。

加密流程：
1. 生成 96 位随机 IV（12 字节）
2. 使用 AES-256-GCM 模式加密压缩后的 SQL 文件
3. 输出格式：`[IV (24 hex chars)][GCM encrypted data + auth tag]`
4. 如果 OpenSSL 版本不支持 GCM，自动回退到 AES-256-CBC + HMAC-SHA256

### 3.5 轮转策略

| 备份类型 | 频率 | 保留时间 | 标识 |
|----------|------|----------|------|
| 每日备份 | 每天 UTC 02:00 | 7 天 | `edgereader_daily_*` |
| 每周备份 | 每周日 UTC 02:00 | 30 天 | `edgereader_weekly_*` |

轮转清理在每天 UTC 03:00 自动执行，同时清理本地文件和 S3 远程文件。

### 3.6 恢复流程

```bash
# 从本地文件恢复
bash scripts/db-restore.sh backups/edgereader_daily_20260301_100000_scheduled.sql.gz.enc

# 仅验证备份（不执行恢复）
bash scripts/db-restore.sh --dry-run backups/edgereader_daily_20260301_100000_scheduled.sql.gz.enc

# 恢复最新备份
bash scripts/db-restore.sh --latest

# 从 S3 下载并恢复
bash scripts/db-restore.sh --from-s3 edgereader_daily_20260301_100000_scheduled
```

恢复流程：
1. SHA-256 校验和验证文件完整性
2. AES-256-GCM 解密（自动检测加密模式）
3. gzip 解压
4. 验证 SQL 内容（表数量、DROP DATABASE 语句等）
5. 交互确认后执行 `mysql` 导入
6. 验证恢复结果（表数量检查）

### 3.7 所需环境变量

```bash
# 数据库
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=<密码>
DB_NAME=edgereader

# 加密
ENCRYPTION_KEY=<64字符十六进制密钥>
# 或使用独立的备份加密密钥
BACKUP_ENCRYPTION_KEY=<64字符十六进制密钥>

# S3 存储
S3_ENDPOINT=https://s3.amazonaws.com
S3_REGION=ap-east-1
S3_BUCKET=edgereader-backups
S3_ACCESS_KEY=<Access Key>
S3_SECRET_KEY=<Secret Key>

# 备份配置（可选）
BACKUP_DIR=/opt/edgereader/backups
BACKUP_RETENTION_DAILY=7
BACKUP_RETENTION_WEEKLY=30
```

### 3.8 部署 Crontab

```bash
# 方法一：直接安装
crontab scripts/crontab-backup

# 方法二：追加到现有 crontab
(crontab -l 2>/dev/null; cat scripts/crontab-backup) | crontab -

# 创建日志目录
sudo mkdir -p /var/log/edgereader
sudo chown $(whoami) /var/log/edgereader
```

## 4. 安全考虑

**CI/CD 安全**：所有敏感信息通过 GitHub Secrets 管理，不在代码中硬编码。Docker 镜像使用非 root 用户运行，Trivy 扫描确保无已知高危漏洞。PR 并发控制防止资源竞争。

**备份安全**：备份文件全程加密存储，加密密钥不包含在备份文件中。SHA-256 校验和防止文件篡改。S3 上传使用 STANDARD_IA 存储类降低成本。恢复前强制交互确认，防止误操作。

## 5. 文件清单

```
.github/workflows/
├── ci.yml              # CI 流水线（PR 检查）
├── cd.yml              # CD 流水线（main 分支部署）
└── db-backup.yml       # 数据库定时备份工作流

.golangci.yml           # golangci-lint 配置

scripts/
├── db-backup.sh        # 数据库备份脚本
├── db-restore.sh       # 数据库恢复脚本
├── crontab-backup      # Crontab 定时任务配置
└── init-db.sh          # 数据库初始化脚本（已有）

docs/
└── 09-cicd-and-backup.md  # 本文档
```
