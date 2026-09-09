#!/bin/bash
# 备份三件套：数据库 + 对象存储 + 配置。
# 用法: ./backup.sh [输出目录]   建议配 cron 每日执行。
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-./backups}/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
. ./.env

echo "[1/3] 数据库..."
docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" -d "${POSTGRES_DB:-busabase}" \
  | gzip > "$OUT/database.sql.gz"

echo "[2/3] 对象存储..."
# 直接打包 SeaweedFS 数据卷，比逐个对象拉取快得多，也不依赖 S3 客户端
docker run --rm -v busabase-premium_seaweedfs_data:/data:ro -v "$(realpath "$OUT")":/out \
  alpine tar czf /out/storage.tar.gz -C /data . 2>/dev/null

echo "[3/3] 配置..."
cp .env seaweed-s3.json docker-compose.yml "$OUT/" 2>/dev/null || true

# .env 含密钥，整份备份必须按机密材料对待
chmod -R 600 "$OUT"/* 2>/dev/null || true
echo "✅ 备份完成: $OUT ($(du -sh "$OUT" | cut -f1))"
echo "⚠️  备份含数据库密码与会话密钥，请与生产同等级别保管。"
