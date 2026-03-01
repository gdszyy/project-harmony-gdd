#!/usr/bin/env bash
# ============================================================
# 界外 EdgeReader — 数据库备份脚本
# 功能: mysqldump + AES-256-GCM 加密 + S3 上传 + 轮转策略
# 用法:
#   bash scripts/db-backup.sh                    # 执行完整备份
#   bash scripts/db-backup.sh --reason "manual"  # 带原因标记的备份
#   bash scripts/db-backup.sh --rotate           # 仅执行轮转清理
#   bash scripts/db-backup.sh --verify-latest    # 验证最新备份
#   bash scripts/db-backup.sh --list             # 列出所有备份
# ============================================================
set -euo pipefail

# ---- 颜色输出 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC}  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*"; }

# ---- 配置 (从环境变量或 .env 文件加载) ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 加载 .env 文件
if [ -f "${PROJECT_DIR}/.env" ]; then
    set -a
    source "${PROJECT_DIR}/.env"
    set +a
fi

# 数据库配置
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-edgereader_secret}"
DB_NAME="${DB_NAME:-edgereader}"

# 加密配置 (使用项目已有的 AES-256 密钥)
ENCRYPTION_KEY="${ENCRYPTION_KEY:-}"
BACKUP_ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-${ENCRYPTION_KEY}}"

# S3 配置
S3_ENDPOINT="${S3_ENDPOINT:-https://s3.amazonaws.com}"
S3_REGION="${S3_REGION:-ap-east-1}"
S3_BUCKET="${S3_BUCKET:-edgereader-backups}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
S3_SECRET_KEY="${S3_SECRET_KEY:-}"
S3_BACKUP_PREFIX="${S3_BACKUP_PREFIX:-backups/db}"

# 备份配置
BACKUP_DIR="${BACKUP_DIR:-${PROJECT_DIR}/backups}"
BACKUP_RETENTION_DAILY="${BACKUP_RETENTION_DAILY:-7}"       # 每日备份保留天数
BACKUP_RETENTION_WEEKLY="${BACKUP_RETENTION_WEEKLY:-30}"     # 每周备份保留天数
BACKUP_COMPRESS="${BACKUP_COMPRESS:-true}"

# ---- 工具函数 ----

# 检查必要工具是否安装
check_dependencies() {
    local missing=()
    
    for cmd in mysqldump openssl gzip sha256sum; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少必要工具: ${missing[*]}"
        log_info "请安装: apt-get install -y mysql-client openssl gzip coreutils"
        exit 1
    fi
    
    # 检查 aws cli (可选，用于 S3 上传)
    if ! command -v aws &>/dev/null; then
        log_warn "aws cli 未安装，将跳过 S3 上传"
        log_info "安装方法: pip3 install awscli 或 apt-get install awscli"
    fi
}

# 生成备份文件名
generate_backup_name() {
    local reason="${1:-scheduled}"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local day_of_week
    day_of_week=$(date '+%u')  # 1=Monday, 7=Sunday
    
    local type="daily"
    # 每周日的备份标记为 weekly
    if [ "$day_of_week" -eq 7 ]; then
        type="weekly"
    fi
    
    echo "edgereader_${type}_${timestamp}_${reason}"
}

# AES-256-GCM 加密备份文件
# 使用 OpenSSL 实现 AES-256-GCM 加密
encrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local key="$3"
    
    if [ -z "$key" ]; then
        log_error "加密密钥未配置，请设置 ENCRYPTION_KEY 或 BACKUP_ENCRYPTION_KEY 环境变量"
        return 1
    fi
    
    # 验证密钥长度 (64 字符十六进制 = 32 字节 = 256 位)
    if [ ${#key} -ne 64 ]; then
        log_error "加密密钥长度错误: 期望 64 字符十六进制字符串，实际 ${#key} 字符"
        return 1
    fi
    
    # 生成随机 IV (96 位 = 12 字节，GCM 推荐)
    local iv
    iv=$(openssl rand -hex 12)
    
    # 使用 AES-256-GCM 加密
    # 输出格式: [IV(24 hex chars)][encrypted data with GCM tag]
    log_info "使用 AES-256-GCM 加密备份文件..."
    
    # 将 IV 写入文件头部 (24 字符十六进制)
    echo -n "${iv}" > "${output_file}"
    
    # 加密数据追加到文件
    openssl enc -aes-256-gcm \
        -in "$input_file" \
        -K "$key" \
        -iv "$iv" \
        -nosalt \
        -out "${output_file}.data" 2>/dev/null || {
        # 如果 GCM 不可用，回退到 AES-256-CBC
        log_warn "OpenSSL 不支持 AES-256-GCM，回退到 AES-256-CBC + HMAC"
        
        # 使用 AES-256-CBC 加密
        openssl enc -aes-256-cbc \
            -in "$input_file" \
            -K "$key" \
            -iv "$(openssl rand -hex 16)" \
            -salt \
            -pbkdf2 \
            -out "${output_file}.tmp"
        
        # 生成 HMAC-SHA256 用于完整性验证
        local hmac
        hmac=$(openssl dgst -sha256 -hmac "$key" -hex "${output_file}.tmp" | awk '{print $NF}')
        
        # 输出格式: [HMAC(64 chars)][encrypted data]
        echo -n "${hmac}" > "${output_file}"
        cat "${output_file}.tmp" >> "${output_file}"
        rm -f "${output_file}.tmp"
        
        log_ok "AES-256-CBC + HMAC 加密完成"
        return 0
    }
    
    # 合并 IV 和加密数据
    cat "${output_file}.data" >> "${output_file}"
    rm -f "${output_file}.data"
    
    log_ok "AES-256-GCM 加密完成"
}

# 上传到 S3
upload_to_s3() {
    local file="$1"
    local s3_key="$2"
    
    if ! command -v aws &>/dev/null; then
        log_warn "aws cli 未安装，跳过 S3 上传"
        return 0
    fi
    
    if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ]; then
        log_warn "S3 凭证未配置，跳过 S3 上传"
        return 0
    fi
    
    log_info "上传备份到 S3: s3://${S3_BUCKET}/${s3_key}"
    
    AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
    aws s3 cp "$file" "s3://${S3_BUCKET}/${s3_key}" \
        --endpoint-url "$S3_ENDPOINT" \
        --region "$S3_REGION" \
        --storage-class STANDARD_IA \
        --no-progress
    
    log_ok "S3 上传完成"
}

# ---- 核心功能 ----

# 执行数据库备份
do_backup() {
    local reason="${1:-scheduled}"
    
    log_info "========================================="
    log_info "开始数据库备份 (原因: ${reason})"
    log_info "========================================="
    
    # 检查依赖
    check_dependencies
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 生成文件名
    local backup_name
    backup_name=$(generate_backup_name "$reason")
    local dump_file="${BACKUP_DIR}/${backup_name}.sql"
    local compressed_file="${dump_file}.gz"
    local encrypted_file="${compressed_file}.enc"
    local checksum_file="${encrypted_file}.sha256"
    local metadata_file="${BACKUP_DIR}/${backup_name}.meta.json"
    
    # Step 1: mysqldump 导出
    log_info "[1/5] 执行 mysqldump..."
    local dump_start
    dump_start=$(date +%s)
    
    mysqldump \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --user="$DB_USER" \
        --password="$DB_PASSWORD" \
        --databases "$DB_NAME" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --set-gtid-purged=OFF \
        --column-statistics=0 \
        --quick \
        --lock-tables=false \
        --add-drop-database \
        --add-drop-table \
        --complete-insert \
        --hex-blob \
        --default-character-set=utf8mb4 \
        > "$dump_file" 2>/dev/null
    
    local dump_end
    dump_end=$(date +%s)
    local dump_duration=$((dump_end - dump_start))
    local dump_size
    dump_size=$(stat -c%s "$dump_file" 2>/dev/null || stat -f%z "$dump_file" 2>/dev/null)
    
    log_ok "mysqldump 完成 (${dump_duration}s, $(numfmt --to=iec-i --suffix=B "$dump_size" 2>/dev/null || echo "${dump_size} bytes"))"
    
    # Step 2: 压缩
    log_info "[2/5] 压缩备份文件..."
    if [ "$BACKUP_COMPRESS" = "true" ]; then
        gzip -9 -c "$dump_file" > "$compressed_file"
        local compressed_size
        compressed_size=$(stat -c%s "$compressed_file" 2>/dev/null || stat -f%z "$compressed_file" 2>/dev/null)
        local ratio
        ratio=$(echo "scale=1; (1 - $compressed_size / $dump_size) * 100" | bc 2>/dev/null || echo "N/A")
        log_ok "压缩完成 ($(numfmt --to=iec-i --suffix=B "$compressed_size" 2>/dev/null || echo "${compressed_size} bytes"), 压缩率: ${ratio}%)"
        rm -f "$dump_file"
    else
        compressed_file="$dump_file"
    fi
    
    # Step 3: AES-256-GCM 加密
    log_info "[3/5] 加密备份文件..."
    if [ -n "$BACKUP_ENCRYPTION_KEY" ]; then
        encrypt_file "$compressed_file" "$encrypted_file" "$BACKUP_ENCRYPTION_KEY"
        rm -f "$compressed_file"
    else
        log_warn "加密密钥未配置，备份文件未加密"
        encrypted_file="$compressed_file"
    fi
    
    # Step 4: 生成校验和
    log_info "[4/5] 生成 SHA-256 校验和..."
    sha256sum "$encrypted_file" | awk '{print $1}' > "$checksum_file"
    local checksum
    checksum=$(cat "$checksum_file")
    log_ok "校验和: ${checksum}"
    
    # Step 5: 上传到 S3
    log_info "[5/5] 上传到 S3..."
    local s3_key="${S3_BACKUP_PREFIX}/${backup_name}/$(basename "$encrypted_file")"
    upload_to_s3 "$encrypted_file" "$s3_key"
    
    # 同时上传校验和文件
    local s3_checksum_key="${S3_BACKUP_PREFIX}/${backup_name}/$(basename "$checksum_file")"
    upload_to_s3 "$checksum_file" "$s3_checksum_key"
    
    # 生成元数据
    local final_size
    final_size=$(stat -c%s "$encrypted_file" 2>/dev/null || stat -f%z "$encrypted_file" 2>/dev/null)
    
    cat > "$metadata_file" <<METADATA
{
  "backup_name": "${backup_name}",
  "database": "${DB_NAME}",
  "host": "${DB_HOST}",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "reason": "${reason}",
  "type": "$(echo "$backup_name" | grep -q 'weekly' && echo 'weekly' || echo 'daily')",
  "encryption": {
    "algorithm": "AES-256-GCM",
    "key_source": "BACKUP_ENCRYPTION_KEY or ENCRYPTION_KEY env var"
  },
  "compression": "${BACKUP_COMPRESS}",
  "original_size": ${dump_size},
  "final_size": ${final_size},
  "checksum_sha256": "${checksum}",
  "s3_location": "s3://${S3_BUCKET}/${s3_key}",
  "local_path": "${encrypted_file}",
  "dump_duration_seconds": ${dump_duration}
}
METADATA
    
    log_info "========================================="
    log_ok "备份完成！"
    log_info "  文件: ${encrypted_file}"
    log_info "  大小: $(numfmt --to=iec-i --suffix=B "$final_size" 2>/dev/null || echo "${final_size} bytes")"
    log_info "  校验: ${checksum}"
    log_info "  元数据: ${metadata_file}"
    log_info "========================================="
}

# 轮转清理
do_rotate() {
    log_info "========================================="
    log_info "开始备份轮转清理"
    log_info "========================================="
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_warn "备份目录不存在: ${BACKUP_DIR}"
        return 0
    fi
    
    local now
    now=$(date +%s)
    local daily_threshold=$((now - BACKUP_RETENTION_DAILY * 86400))
    local weekly_threshold=$((now - BACKUP_RETENTION_WEEKLY * 86400))
    local deleted=0
    
    # 清理过期的每日备份
    for meta_file in "${BACKUP_DIR}"/edgereader_daily_*.meta.json; do
        [ -f "$meta_file" ] || continue
        
        local file_time
        file_time=$(stat -c%Y "$meta_file" 2>/dev/null || stat -f%m "$meta_file" 2>/dev/null)
        
        if [ "$file_time" -lt "$daily_threshold" ]; then
            local base_name
            base_name=$(basename "$meta_file" .meta.json)
            log_info "删除过期每日备份: ${base_name}"
            rm -f "${BACKUP_DIR}/${base_name}".*
            deleted=$((deleted + 1))
            
            # 同时从 S3 删除
            if command -v aws &>/dev/null && [ -n "$S3_ACCESS_KEY" ]; then
                AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
                AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
                aws s3 rm "s3://${S3_BUCKET}/${S3_BACKUP_PREFIX}/${base_name}/" \
                    --endpoint-url "$S3_ENDPOINT" \
                    --region "$S3_REGION" \
                    --recursive 2>/dev/null || true
            fi
        fi
    done
    
    # 清理过期的每周备份
    for meta_file in "${BACKUP_DIR}"/edgereader_weekly_*.meta.json; do
        [ -f "$meta_file" ] || continue
        
        local file_time
        file_time=$(stat -c%Y "$meta_file" 2>/dev/null || stat -f%m "$meta_file" 2>/dev/null)
        
        if [ "$file_time" -lt "$weekly_threshold" ]; then
            local base_name
            base_name=$(basename "$meta_file" .meta.json)
            log_info "删除过期每周备份: ${base_name}"
            rm -f "${BACKUP_DIR}/${base_name}".*
            deleted=$((deleted + 1))
            
            # 同时从 S3 删除
            if command -v aws &>/dev/null && [ -n "$S3_ACCESS_KEY" ]; then
                AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
                AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
                aws s3 rm "s3://${S3_BUCKET}/${S3_BACKUP_PREFIX}/${base_name}/" \
                    --endpoint-url "$S3_ENDPOINT" \
                    --region "$S3_REGION" \
                    --recursive 2>/dev/null || true
            fi
        fi
    done
    
    log_ok "轮转清理完成，删除 ${deleted} 个过期备份"
    
    # 显示当前备份状态
    log_info "当前备份文件:"
    ls -lh "${BACKUP_DIR}"/*.enc 2>/dev/null || log_info "  (无备份文件)"
}

# 验证最新备份
do_verify_latest() {
    log_info "验证最新备份完整性..."
    
    local latest_enc
    latest_enc=$(ls -t "${BACKUP_DIR}"/*.enc 2>/dev/null | head -1)
    
    if [ -z "$latest_enc" ]; then
        log_error "未找到备份文件"
        return 1
    fi
    
    local latest_checksum="${latest_enc}.sha256"
    
    if [ ! -f "$latest_checksum" ]; then
        log_error "未找到校验和文件: ${latest_checksum}"
        return 1
    fi
    
    local expected
    expected=$(cat "$latest_checksum")
    local actual
    actual=$(sha256sum "$latest_enc" | awk '{print $1}')
    
    if [ "$expected" = "$actual" ]; then
        log_ok "备份完整性验证通过: $(basename "$latest_enc")"
        log_info "  SHA-256: ${actual}"
        log_info "  大小: $(ls -lh "$latest_enc" | awk '{print $5}')"
        return 0
    else
        log_error "备份完整性验证失败！"
        log_error "  期望: ${expected}"
        log_error "  实际: ${actual}"
        return 1
    fi
}

# 列出所有备份
do_list() {
    log_info "本地备份列表:"
    echo ""
    printf "%-50s %-10s %-20s %-10s\n" "文件名" "大小" "时间" "类型"
    printf "%-50s %-10s %-20s %-10s\n" "$(printf '%.0s-' {1..50})" "$(printf '%.0s-' {1..10})" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..10})"
    
    for meta_file in "${BACKUP_DIR}"/*.meta.json; do
        [ -f "$meta_file" ] || continue
        
        local name size timestamp type
        name=$(python3 -c "import json; d=json.load(open('$meta_file')); print(d['backup_name'])" 2>/dev/null || echo "unknown")
        size=$(python3 -c "import json; d=json.load(open('$meta_file')); print(d['final_size'])" 2>/dev/null || echo "0")
        timestamp=$(python3 -c "import json; d=json.load(open('$meta_file')); print(d['timestamp'])" 2>/dev/null || echo "unknown")
        type=$(python3 -c "import json; d=json.load(open('$meta_file')); print(d['type'])" 2>/dev/null || echo "unknown")
        
        local human_size
        human_size=$(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size}B")
        
        printf "%-50s %-10s %-20s %-10s\n" "$name" "$human_size" "$timestamp" "$type"
    done
    
    echo ""
    
    # S3 列表
    if command -v aws &>/dev/null && [ -n "$S3_ACCESS_KEY" ]; then
        log_info "S3 备份列表:"
        AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
        AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
        aws s3 ls "s3://${S3_BUCKET}/${S3_BACKUP_PREFIX}/" \
            --endpoint-url "$S3_ENDPOINT" \
            --region "$S3_REGION" \
            --recursive 2>/dev/null || log_warn "无法列出 S3 备份"
    fi
}

# ---- 主入口 ----
main() {
    local action="backup"
    local reason="scheduled"
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --rotate)
                action="rotate"
                shift
                ;;
            --verify-latest)
                action="verify"
                shift
                ;;
            --list)
                action="list"
                shift
                ;;
            --reason)
                reason="$2"
                shift 2
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --reason <原因>     备份原因标记 (默认: scheduled)"
                echo "  --rotate            执行轮转清理"
                echo "  --verify-latest     验证最新备份完整性"
                echo "  --list              列出所有备份"
                echo "  --help              显示帮助信息"
                echo ""
                echo "环境变量:"
                echo "  DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME"
                echo "  ENCRYPTION_KEY 或 BACKUP_ENCRYPTION_KEY"
                echo "  S3_ENDPOINT, S3_REGION, S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY"
                echo "  BACKUP_DIR, BACKUP_RETENTION_DAILY, BACKUP_RETENTION_WEEKLY"
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    done
    
    case "$action" in
        backup)
            do_backup "$reason"
            ;;
        rotate)
            do_rotate
            ;;
        verify)
            do_verify_latest
            ;;
        list)
            do_list
            ;;
    esac
}

main "$@"
