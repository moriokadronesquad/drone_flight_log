#!/bin/bash
# ============================================
# DIPS Proxy デプロイスクリプト
# deploy ユーザーで実行する
# ============================================
set -euo pipefail

APP_DIR="/opt/dips-proxy"

echo "=== 1. アプリディレクトリ作成 ==="
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

echo "=== 2. ファイル配置 ==="
# ローカルから scp で転送済みの前提
if [ ! -f "$APP_DIR/docker-compose.yml" ]; then
    echo "エラー: $APP_DIR にファイルが配置されていません"
    echo ""
    echo "ローカルPCから以下を実行してファイルを転送してください:"
    echo "  scp -P 10022 -r dips_proxy/ deploy@<VPSのIP>:/opt/dips-proxy/"
    exit 1
fi

echo "=== 3. .env ファイル確認 ==="
if [ ! -f "$APP_DIR/.env" ]; then
    echo ".env ファイルを作成してください:"
    echo "  cp $APP_DIR/.env.example $APP_DIR/.env"
    echo "  nano $APP_DIR/.env"
    echo ""
    echo "必須項目:"
    echo "  - DIPS_CLIENT_ID"
    echo "  - DIPS_CLIENT_SECRET"
    echo "  - APP_SECRET_KEY (ランダム文字列)"
    echo "  - TOKEN_ENCRYPTION_KEY (Fernet key)"
    echo ""
    echo "Fernet key 生成:"
    echo "  python3 -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\""
    exit 1
fi

echo "=== 4. Docker Compose 起動 ==="
cd $APP_DIR
docker compose up -d --build

echo "=== 5. ヘルスチェック ==="
sleep 3
if curl -sf http://localhost:8000/health > /dev/null; then
    echo "✓ DIPS Proxy は正常に起動しています"
    curl -s http://localhost:8000/health | python3 -m json.tool
else
    echo "✗ 起動に失敗しました。ログを確認してください:"
    echo "  docker compose logs"
fi
