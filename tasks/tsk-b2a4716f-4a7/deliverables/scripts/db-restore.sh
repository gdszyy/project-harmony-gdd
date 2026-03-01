#!/usr/bin/env bash
# ============================================================
# 界外 EdgeReader — 数据库恢复脚本
# 功能: 从加密备份文件恢复数据库
# 用法:
#   bash scripts/db-restore.sh <备份文件.enc>           # 从本地文件恢复
#   bash scripts/db-restore.sh --from-s3 <备份名称>      # 从 S3 下载并恢复
#   bash scripts/db-restore.sh --latest                  # 恢复最新备份
#   bash scripts/db-restore.sh --dry-run <备份文件.enc>  # 仅解密验证，不执行恢复
# ============================================================
set -euo pipefail

# ---- 颜色输出 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*"; }

# ---- 配置 ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 加载 .env
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

# 加密配置
ENCRYPTION_KEY="${ENCRYPTION_KEY:-}"
BACKUP_ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-${ENCRYPTION_KEY}}"

# S3 配置
S3_ENDPOINT="${S3_ENDPOINT:-https://s3.amazonaws.com}"
S3_REGION="${S3_REGION:-ap-east-1}"
S3_BUCKET="${S3_BUCKET:-edgereader-backups}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
S3_SECRET_KEY="${S3_SECRET_KEY:-}"
S3_BACKUP_PREFIX="${S3_BACKUP_PREFIX:-backups/db}"

# 备份目录
BACKUP_DIR="${BACKUP_DIR:-${PROJECT_DIR}/backups}"

# ---- 工具函数 ----

check_dependencies() {
    local missing=()
    for cmd in mysql openssl gzip sha256sum; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少必要工具: ${missing[*]}"
        exit 1
    fi
}

# AES-256-GCM 解密
decrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local key="$3"
    
    if [ -z "$key" ]; then
        log_error "解密密钥未配置"
        return 1
    fi
    
    if [ ${#key} -ne 64 ]; then
        log_error "解密密钥长度错误: 期望 64 字符十六进制字符串"
        return 1
    fi
    
    log_info "解密备份文件..."
    
    # 读取 IV (前 24 字符 = 12 字节十六进制)
    local iv
    iv=$(head -c 24 "$input_file")
    
    # 提取加密数据 (跳过前 24 字节的 IV)
    local temp_encrypted
    temp_encrypted=$(mktemp)
    tail -c +25 "$input_file" > "$temp_encrypted"
    
    # 尝试 AES-256-GCM 解密
    openssl enc -aes-256-gcm -d \
        -in "$temp_encrypted" \
        -K "$key" \
        -iv "$iv" \
        -nosalt \
        -out "$output_file" 2>/dev/null || {
        log_warn "AES-256-GCM 解密失败，尝试 AES-256-CBC 模式..."
        rm -f "$temp_encrypted"
        
        # 回退到 AES-256-CBC 解密
        # 读取 HMAC (前 64 字符)
        local stored_hmac
        stored_hmac=$(head -c 64 "$input_file")
        
        # 提取加密数据
        local temp_cbc
        temp_cbc=$(mktemp)
        tail -c +65 "$input_file" > "$temp_cbc"
        
        # 验证 HMAC
        local computed_hmac
        computed_hmac=$(openssl dgst -sha256 -hmac "$key" -hex "$temp_cbc" | awk '{print $NF}')
        
        if [ "$stored_hmac" != "$computed_hmac" ]; then
            log_error "HMAC 验证失败！文件可能已被篡改"
            rm -f "$temp_cbc"
            return 1
        fi
        log_ok "HMAC 验证通过"
        
        # CBC 解密
        openssl enc -aes-256-cbc -d \
            -in "$temp_cbc" \
            -K "$key" \
            -salt \
            -pbkdf2 \
            -out "$output_file"
        
        rm -f "$temp_cbc"
        log_ok "AES-256-CBC 解密完成"
        return 0
    }
    
    rm -f "$temp_encrypted"
    log_ok "AES-256-GCM 解密完成"
}

# 从 S3 下载备份
download_from_s3() {
    local backup_name="$1"
    local output_dir="$2"
    
    if ! command -v aws &>/dev/null; then
        log_error "aws cli 未安装"
        return 1
    fi
    
    if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ]; then
        log_error "S3 凭证未配置"
        return 1
    fi
    
    log_info "从 S3 下载备份: ${backup_name}"
    
    AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
    aws s3 cp "s3://${S3_BUCKET}/${S3_BACKUP_PREFIX}/${backup_name}/" \
        "$output_dir/" \
        --endpoint-url "$S3_ENDPOINT" \
        --region "$S3_REGION" \
        --recursive \
        --no-progress
    
    log_ok "S3 下载完成"
}

# ---- 核心恢复流程 ----

do_restore() {
    local encrypted_file="$1"
    local dry_run="${2:-false}"
    
    log_info "============================================="
    log_info "开始数据库恢复"
    log_info "  备份文件: ${encrypted_file}"
    log_info "  目标数据库: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
    log_info "  模式: $([ "$dry_run" = "true" ] && echo "仅验证 (dry-run)" || echo "完整恢复")"
    log_info "============================================="
    
    check_dependencies
    
    # 验证文件存在
    if [ ! -f "$encrypted_file" ]; then
        log_error "备份文件不存在: ${encrypted_file}"
        return 1
    fi
    
    # Step 1: 验证校验和
    local checksum_file="${encrypted_file}.sha256"
    if [ -f "$checksum_file" ]; then
        log_info "[1/5] 验证文件完整性..."
        local expected actual
        expected=$(cat "$checksum_file")
        actual=$(sha256sum "$encrypted_file" | awk '{print $1}')
        if [ "$expected" = "$actual" ]; then
            log_ok "SHA-256 校验通过"
        else
            log_error "SHA-256 校验失败！文件可能已损坏"
            log_error "  期望: ${expected}"
            log_error "  实际: ${actual}"
            return 1
        fi
    else
        log_warn "[1/5] 未找到校验和文件，跳过完整性验证"
    fi
    
    # Step 2: 解密
    log_info "[2/5] 解密备份文件..."
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT
    
    local compressed_file="${temp_dir}/backup.sql.gz"
    
    if [ -n "$BACKUP_ENCRYPTION_KEY" ]; then
        decrypt_file "$encrypted_file" "$compressed_file" "$BACKUP_ENCRYPTION_KEY"
    else
        log_warn "加密密钥未配置，假设文件未加密"
        cp "$encrypted_file" "$compressed_file"
    fi
    
    # Step 3: 解压
    log_info "[3/5] 解压备份文件..."
    local sql_file="${temp_dir}/backup.sql"
    
    # 检测是否为 gzip 格式
    if file "$compressed_file" | grep -q "gzip"; then
        gzip -d -c "$compressed_file" > "$sql_file"
    else
        # 可能未压缩
        mv "$compressed_file" "$sql_file"
    fi
    
    local sql_size
    sql_size=$(stat -c%s "$sql_file" 2>/dev/null || stat -f%z "$sql_file" 2>/dev/null)
    log_ok "解压完成 ($(numfmt --to=iec-i --suffix=B "$sql_size" 2>/dev/null || echo "${sql_size} bytes"))"
    
    # Step 4: 验证 SQL 内容
    log_info "[4/5] 验证 SQL 内容..."
    local table_count
    table_count=$(grep -c "CREATE TABLE" "$sql_file" || echo "0")
    local has_drop_db
    has_drop_db=$(grep -c "DROP DATABASE" "$sql_file" || echo "0")
    
    log_info "  SQL 文件包含 ${table_count} 个 CREATE TABLE 语句"
    log_info "  包含 DROP DATABASE: $([ "$has_drop_db" -gt 0 ] && echo "是" || echo "否")"
    
    # 显示前几行
    log_info "  SQL 文件头部:"
    head -5 "$sql_file" | while IFS= read -r line; do
        log_info "    ${line}"
    done
    
    if [ "$dry_run" = "true" ]; then
        log_ok "============================================="
        log_ok "Dry-run 验证完成！备份文件可以正常解密和解压"
        log_info "  SQL 大小: $(numfmt --to=iec-i --suffix=B "$sql_size" 2>/dev/null || echo "${sql_size} bytes")"
        log_info "  表数量: ${table_count}"
        log_ok "============================================="
        return 0
    fi
    
    # Step 5: 恢复到数据库
    log_warn "============================================="
    log_warn "⚠️  即将恢复数据库，这将覆盖现有数据！"
    log_warn "  目标: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
    log_warn "============================================="
    
    # 交互模式下询问确认
    if [ -t 0 ]; then
        echo -n "确认恢复? (输入 'yes' 继续): "
        read -r confirm
        if [ "$confirm" != "yes" ]; then
            log_info "已取消恢复"
            return 0
        fi
    fi
    
    log_info "[5/5] 恢复数据库..."
    local restore_start
    restore_start=$(date +%s)
    
    mysql \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --user="$DB_USER" \
        --password="$DB_PASSWORD" \
        --default-character-set=utf8mb4 \
        < "$sql_file"
    
    local restore_end
    restore_end=$(date +%s)
    local restore_duration=$((restore_end - restore_start))
    
    log_ok "============================================="
    log_ok "数据库恢复完成！"
    log_info "  耗时: ${restore_duration}s"
    log_info "  数据库: ${DB_NAME}"
    log_ok "============================================="
    
    # 验证恢复结果
    log_info "验证恢复结果..."
    local restored_tables
    restored_tables=$(mysql \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --user="$DB_USER" \
        --password="$DB_PASSWORD" \
        --database="$DB_NAME" \
        -N -e "SHOW TABLES;" 2>/dev/null | wc -l)
    
    log_ok "恢复后数据库包含 ${restored_tables} 个表"
}

# ---- 主入口 ----
main() {
    local action="restore"
    local target=""
    local dry_run="false"
    local from_s3=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --from-s3)
                from_s3="$2"
                shift 2
                ;;
            --latest)
                action="latest"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --help|-h)
                echo "用法: $0 [选项] [备份文件]"
                echo ""
                echo "选项:"
                echo "  <备份文件.enc>           从本地加密文件恢复"
                echo "  --from-s3 <备份名称>     从 S3 下载并恢复"
                echo "  --latest                 恢复最新的本地备份"
                echo "  --dry-run                仅解密验证，不执行恢复"
                echo "  --help                   显示帮助信息"
                echo ""
                echo "环境变量:"
                echo "  DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME"
                echo "  ENCRYPTION_KEY 或 BACKUP_ENCRYPTION_KEY"
                echo "  S3_ENDPOINT, S3_REGION, S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY"
                echo ""
                echo "示例:"
                echo "  # 从本地文件恢复"
                echo "  $0 backups/edgereader_daily_20260301_100000_scheduled.sql.gz.enc"
                echo ""
                echo "  # 仅验证备份文件"
                echo "  $0 --dry-run backups/edgereader_daily_20260301_100000_scheduled.sql.gz.enc"
                echo ""
                echo "  # 恢复最新备份"
                echo "  $0 --latest"
                echo ""
                echo "  # 从 S3 下载并恢复"
                echo "  $0 --from-s3 edgereader_daily_20260301_100000_scheduled"
                exit 0
                ;;
            -*)
                log_error "未知选项: $1"
                exit 1
                ;;
            *)
                target="$1"
                shift
                ;;
        esac
    done
    
    # 从 S3 下载
    if [ -n "$from_s3" ]; then
        local download_dir="${BACKUP_DIR}/s3_download"
        mkdir -p "$download_dir"
        download_from_s3 "$from_s3" "$download_dir"
        target=$(ls -t "${download_dir}"/*.enc 2>/dev/null | head -1)
        if [ -z "$target" ]; then
            log_error "S3 下载后未找到加密备份文件"
            exit 1
        fi
    fi
    
    # 查找最新备份
    if [ "$action" = "latest" ]; then
        target=$(ls -t "${BACKUP_DIR}"/*.enc 2>/dev/null | head -1)
        if [ -z "$target" ]; then
            log_error "未找到本地备份文件"
            exit 1
        fi
        log_info "使用最新备份: ${target}"
    fi
    
    # 验证目标
    if [ -z "$target" ]; then
        log_error "请指定备份文件路径"
        echo "使用 --help 查看帮助信息"
        exit 1
    fi
    
    do_restore "$target" "$dry_run"
}

main "$@"
