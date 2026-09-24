#!/bin/bash
# Backs up all three things that matter: the database, object storage, and
# the configuration.
# Usage: ./backup.sh [output-dir]   Worth putting on a daily cron.
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-./backups}/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
. ./.env

echo "[1/3] Database..."
docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" -d "${POSTGRES_DB:-busabase}" \
  | gzip > "$OUT/database.sql.gz"

echo "[2/3] Object storage..."
# Tar the SeaweedFS volume directly: far faster than pulling objects one by
# one, and it needs no S3 client.
docker run --rm -v busabase-premium_seaweedfs_data:/data:ro -v "$(realpath "$OUT")":/out \
  alpine tar czf /out/storage.tar.gz -C /data . 2>/dev/null

echo "[3/3] Configuration..."
cp .env seaweed-s3.json docker-compose.yml "$OUT/" 2>/dev/null || true

# .env carries secrets, so treat the whole backup as sensitive material.
chmod -R 600 "$OUT"/* 2>/dev/null || true
echo "✅ Backup complete: $OUT ($(du -sh "$OUT" | cut -f1))"
echo "⚠️  Contains the database password and the session signing key. Store it as carefully as production itself."
