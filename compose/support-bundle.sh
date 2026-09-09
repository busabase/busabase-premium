#!/bin/bash
# 收集诊断信息打包，供反馈给 Busabase 支持。已脱敏：不含任何密钥。
set -euo pipefail
cd "$(dirname "$0")"
OUT="/tmp/busabase-support-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

docker compose ps > "$OUT/services.txt" 2>&1 || true
docker compose logs --tail 500 > "$OUT/logs.txt" 2>&1 || true
curl -s http://localhost:"${APP_PORT:-3000}"/api/health > "$OUT/health.json" 2>&1 || true
docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -i busabase > "$OUT/images.txt" 2>&1 || true
# 只保留变量名，值一律抹掉
sed 's/=.*/=<redacted>/' .env > "$OUT/env-keys-only.txt" 2>/dev/null || true

tar czf "$OUT.tar.gz" -C "$(dirname "$OUT")" "$(basename "$OUT")" && rm -rf "$OUT"
echo "✅ 支持包: $OUT.tar.gz（已脱敏，可直接发送）"
