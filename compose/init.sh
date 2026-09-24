#!/bin/bash
# One-time setup: writes .env and seaweed-s3.json with random secrets that
# already agree with each other.
#
# This script exists to remove one specific trap. The object-storage
# credentials are read from two places — .env by the app, seaweed-s3.json by
# the storage service — and they have to match. Filling both in by hand and
# missing one is the most common self-inflicted failure here, and its symptom
# is misleading: the app starts, signs you in, and then every attachment
# upload fails.
set -euo pipefail
cd "$(dirname "$0")"

[ -f .env ] && { echo "❌ .env already exists; not overwriting. Back it up and remove it to start over."; exit 1; }

gen() { openssl rand -hex "${1:-24}"; }
PG_PW=$(gen 24); S3_KEY="busabase"; S3_SECRET=$(gen 24); AUTH=$(gen 32)

read -rp "Address users will visit (e.g. https://busabase.company.internal): " APP_URL
APP_URL=${APP_URL:-http://localhost:3000}
read -rp "Administrator email: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}

# Object storage is published on the same host as APP_URL. Inside the app
# container, localhost resolves to the container itself, so signing URLs
# against it makes every upload fail with ECONNREFUSED. Refuse it here rather
# than letting it break quietly later.
S3_HOST=$(printf '%s' "$APP_URL" | sed -E 's#^[a-z]+://##; s#[:/].*$##')
if [ "$S3_HOST" = "localhost" ] || [ "$S3_HOST" = "127.0.0.1" ]; then
  echo "❌ The address cannot be localhost/127.0.0.1: the app container resolves it to itself, so attachment uploads are guaranteed to fail."
  echo "   Use the server's real hostname or IP — for example https://busabase.company.internal or http://192.168.1.10:3000"
  exit 1
fi

sed -e "s|^APP_URL=.*|APP_URL=${APP_URL}|" \
    -e "s|^S3_PUBLIC_HOST=.*|S3_PUBLIC_HOST=${S3_HOST}|" \
    -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${PG_PW}|" \
    -e "s|^S3_ACCESS_KEY=.*|S3_ACCESS_KEY=${S3_KEY}|" \
    -e "s|^S3_SECRET_KEY=.*|S3_SECRET_KEY=${S3_SECRET}|" \
    -e "s|^BETTER_AUTH_SECRET=.*|BETTER_AUTH_SECRET=${AUTH}|" \
    -e "s|^SYSTEM_ADMIN_EMAIL=.*|SYSTEM_ADMIN_EMAIL=${ADMIN_EMAIL}|" \
    .env.example > .env
chmod 600 .env

# The same credentials go into the storage-side config, so the two cannot drift.
#
# Two identities:
#   - the one with credentials, which the app uses to sign reads and writes;
#   - `anonymous`, read-only and scoped to the busabase bucket.
#
# Why anonymous is needed: an attachment's public URL is embedded directly in
# document content and fetched by a browser that holds no credentials. Without
# it, uploads succeed and every image renders as 403.
# This matches how the hosted product's asset bucket behaves — security comes
# from keys being unguessable (a random nanoid plus the space id), not from the
# bucket being unreadable. List is not granted, so nothing can be enumerated,
# and writes still require a signature.
cat > seaweed-s3.json <<JSON
{
  "identities": [
    {
      "name": "${S3_KEY}",
      "credentials": [{ "accessKey": "${S3_KEY}", "secretKey": "${S3_SECRET}" }],
      "actions": ["Admin", "Read", "Write", "List", "Tagging"]
    },
    {
      "name": "anonymous",
      "actions": ["Read:busabase"]
    }
  ]
}
JSON
chmod 600 seaweed-s3.json

echo "✅ Wrote .env and seaweed-s3.json (random secrets, matching on both sides)"
echo "   Next: docker compose up -d"
