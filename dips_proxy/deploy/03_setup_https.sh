#!/bin/bash
# ============================================
# HTTPS (Let's Encrypt + Caddy) セットアップ
# deploy ユーザーで実行する
# ============================================
set -euo pipefail

# --- 変数（実行前に変更してください） ---
DOMAIN="dips.dronepeak.jp"

echo "=== 1. Caddy インストール ==="
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy

echo "=== 2. Caddyfile 設定 ==="
sudo tee /etc/caddy/Caddyfile > /dev/null << EOF
$DOMAIN {
    reverse_proxy localhost:8000

    header {
        # セキュリティヘッダー
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    log {
        output file /var/log/caddy/access.log
    }
}
EOF

echo "=== 3. Caddy 起動 ==="
sudo systemctl enable caddy
sudo systemctl restart caddy

echo ""
echo "============================================"
echo "  HTTPS セットアップ完了"
echo "============================================"
echo ""
echo "DNS設定:"
echo "  $DOMAIN → $(curl -s ifconfig.me) (Aレコード)"
echo ""
echo "確認:"
echo "  curl https://$DOMAIN/health"
echo ""
echo "⚠ DNS設定後、Let's Encrypt 証明書が自動取得されます（数分かかります）"
