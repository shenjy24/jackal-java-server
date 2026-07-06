#!/bin/bash
set -eo pipefail

# ------------------- 配置区域 -------------------
CONTAINER_NAME="${CONTAINER_NAME:-iotdb}"
IOTDB_IMAGE="${IOTDB_IMAGE:-apache/iotdb:2.0.6-standalone}"
IOTDB_HOST="${IOTDB_HOST:-127.0.0.1}"
IOTDB_PORT="${IOTDB_PORT:-6667}"
IOTDB_USER="${IOTDB_USER:-root}"
IOTDB_PASSWORD="${IOTDB_PASSWORD:-root}"
IOTDB_DATABASE="${IOTDB_DATABASE:-template}"
BACKUP_ROOT="${BACKUP_ROOT:-./backup}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

# ------------------- 运行变量 -------------------
DATE_SUFFIX=$(date +"%Y%m%d_%H%M%S")
END_TIME_MS=$(date +%s%3N)
EXPORT_DIR="${BACKUP_ROOT}/iotdb_export_${DATE_SUFFIX}"
EXPORT_DATA_DIR="${EXPORT_DIR}/data"
BACKUP_FILE="${BACKUP_ROOT}/iotdb_backup_${DATE_SUFFIX}.tsfile.tar.gz"
MANIFEST_FILE="${BACKUP_ROOT}/iotdb_backup_${DATE_SUFFIX}.manifest"
LOG_FILE="${BACKUP_ROOT}/backup.log"

# ------------------- 辅助函数 -------------------
log_info()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]  $1" | tee -a "${LOG_FILE}"; }
log_error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "${LOG_FILE}"; }

cleanup_current_backup() {
    rm -rf "${EXPORT_DIR}"
    rm -f "${BACKUP_FILE}" "${MANIFEST_FILE}"
}

# ------------------- 前置检查 -------------------
mkdir -p "${BACKUP_ROOT}" "${EXPORT_DATA_DIR}"

if ! command -v docker >/dev/null 2>&1; then
    log_error "未找到 docker 命令，备份终止"
    cleanup_current_backup
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_error "容器 ${CONTAINER_NAME} 未运行，备份终止"
    cleanup_current_backup
    exit 1
fi

# ------------------- 在线导出 -------------------
log_info "--------------------------------------------------"
log_info "开始在线导出 IoTDB，数据库: ${IOTDB_DATABASE}，结束时间水位: ${END_TIME_MS}"
log_info "IoTDB 服务不会停止，导出目录: ${EXPORT_DATA_DIR}"

if docker run --rm \
    --network "container:${CONTAINER_NAME}" \
    -v "$(pwd)/${BACKUP_ROOT}:/backup" \
    "${IOTDB_IMAGE}" \
    /iotdb/tools/export-data.sh \
        -ft tsfile \
        -sql_dialect table \
        -h "${IOTDB_HOST}" \
        -p "${IOTDB_PORT}" \
        -u "${IOTDB_USER}" \
        -pw "${IOTDB_PASSWORD}" \
        -db "${IOTDB_DATABASE}" \
        -start_time 0 \
        -end_time "${END_TIME_MS}" \
        -t "/backup/iotdb_export_${DATE_SUFFIX}/data"; then

    log_info "在线导出完成，开始压缩备份文件"
else
    log_error "在线导出失败，请检查 IoTDB 容器状态、账号密码或数据库名"
    cleanup_current_backup
    exit 1
fi

# ------------------- 压缩与校验 -------------------
if tar -czf "${BACKUP_FILE}" -C "${EXPORT_DIR}" data; then
    if ! gzip -t "${BACKUP_FILE}" 2>/dev/null; then
        log_error "文件校验失败，备份可能已损坏"
        cleanup_current_backup
        exit 1
    fi
else
    log_error "备份压缩失败"
    cleanup_current_backup
    exit 1
fi

BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | awk '{print $1}')

cat > "${MANIFEST_FILE}" <<EOF
status=success
backup_type=online_export
format=tsfile
sql_dialect=table
database=${IOTDB_DATABASE}
container_name=${CONTAINER_NAME}
iotdb_image=${IOTDB_IMAGE}
iotdb_host=${IOTDB_HOST}
iotdb_port=${IOTDB_PORT}
start_time_ms=0
end_time_ms=${END_TIME_MS}
backup_file=$(basename "${BACKUP_FILE}")
backup_size=${BACKUP_SIZE}
created_at=$(date +'%Y-%m-%d %H:%M:%S')
EOF

rm -rf "${EXPORT_DIR}"

log_info "备份成功，文件: ${BACKUP_FILE}，大小: ${BACKUP_SIZE}"
log_info "备份元数据: ${MANIFEST_FILE}"

# ------------------- 清理过期备份 -------------------
log_info "清理 ${RETENTION_DAYS} 天前的旧备份..."
find "${BACKUP_ROOT}" -maxdepth 1 -name "iotdb_backup_*.tsfile.tar.gz" -type f -mtime "+${RETENTION_DAYS}" -delete
find "${BACKUP_ROOT}" -maxdepth 1 -name "iotdb_backup_*.manifest" -type f -mtime "+${RETENTION_DAYS}" -delete
log_info "清理完成"

# ------------------- 日志轮转 -------------------
tail -n 1000 "${LOG_FILE}" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "${LOG_FILE}"

log_info "备份任务完成"
log_info "--------------------------------------------------"
