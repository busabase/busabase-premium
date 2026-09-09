#!/bin/bash
# 一次性初始化：生成 .env 与 seaweed-s3.json，密钥随机且两处自动保持一致。
#
# 存在的理由是消除一个真实的踩坑点：S3 凭据同时被 .env(应用侧) 和
# seaweed-s3.json(存储侧) 使用，手工填两遍极易漏改一处，症状是应用启动正常
# 但所有附件上传失败——排查成本远高于此脚本的价值。
set -euo pipefail
cd "$(dirname "$0")"

[ -f .env ] && { echo "❌ .env 已存在，不覆盖。如需重来请先备份并删除。"; exit 1; }

gen() { openssl rand -hex "${1:-24}"; }
PG_PW=$(gen 24); S3_KEY="busabase"; S3_SECRET=$(gen 24); AUTH=$(gen 32)

read -rp "访问地址 (如 https://busabase.company.internal): " APP_URL
APP_URL=${APP_URL:-http://localhost:3000}
read -rp "管理员邮箱: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}

# 对象存储的对外地址与 APP_URL 同主机。localhost 在 app 容器里指容器自己，
# 用它签名会让每次上传 ECONNREFUSED，所以这里直接拦下来而不是让它悄悄坏掉。
S3_HOST=$(printf '%s' "$APP_URL" | sed -E 's#^[a-z]+://##; s#[:/].*$##')
if [ "$S3_HOST" = "localhost" ] || [ "$S3_HOST" = "127.0.0.1" ]; then
  echo "❌ 访问地址不能用 localhost/127.0.0.1：app 容器会把它解析成自己，附件上传必然失败。"
  echo "   请填服务器的真实主机名或 IP，例如 https://busabase.company.internal 或 http://192.168.1.10:3000"
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

# 同一对凭据写进存储侧配置，杜绝两处不一致
# 两个身份：
#   - 带凭据的那个，应用用它签名读写；
#   - anonymous 只读，限定在 busabase 这个 bucket 内。
#
# 为什么需要 anonymous：附件的 publicUrl 会被直接嵌进文档内容交给浏览器，
# 浏览器手上没有凭据。没有这条，上传能成功而每张图都显示不出来（403）。
# 这与云版资源桶的姿态一致——安全性来自 key 不可猜（随机 nanoid + 空间 id），
# 而不是来自"读不到"。不放开 List，所以无法枚举；写入仍然必须签名。
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

echo "✅ 已生成 .env 与 seaweed-s3.json（密钥随机，两处一致）"
echo "   下一步: docker compose up -d"
