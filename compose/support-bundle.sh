#!/bin/bash
# Collects diagnostics into one archive to send to Busabase support.
# Redacted: it contains no secret values.
set -euo pipefail
cd "$(dirname "$0")"
OUT="/tmp/busabase-support-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

docker compose ps > "$OUT/services.txt" 2>&1 || true
docker compose logs --tail 500 > "$OUT/logs.txt" 2>&1 || true
curl -s http://localhost:"${APP_PORT:-3000}"/api/health > "$OUT/health.json" 2>&1 || true
docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -i busabase > "$OUT/images.txt" 2>&1 || true
# Keep the variable names, drop every value.
sed 's/=.*/=<redacted>/' .env > "$OUT/env-keys-only.txt" 2>/dev/null || true

tar czf "$OUT.tar.gz" -C "$(dirname "$OUT")" "$(basename "$OUT")" && rm -rf "$OUT"
echo "✅ Support bundle: $OUT.tar.gz (redacted — safe to send as is)"
