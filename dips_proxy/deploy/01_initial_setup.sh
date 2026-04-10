#!/bin/bash
# ============================================
# さくらVPS 初期セットアップ（Debian）
# root で SSH 接続後に実行する
# ============================================
set -euo pipefail

# --- 変数（実行前に変更してください） ---
NEW_USER="deploy"
SSH_PORT=10022

echo "=== 1. システム更新 ==="
apt update && apt upgrade -y

echo "=== 2. 作業ユーザー作成 ==="
if ! id "$NEW_USER" &>/dev/null; then
    adduser --disabled-password --gecos "" "$NEW_USER"
    usermod -aG sudo "$NEW_USER"
    echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$NEW_USER
    echo "ユーザー $NEW_USER を作成しました"
else
    echo "ユーザー $NEW_USER は既に存在します"
fi

echo "=== 3. SSH鍵の設定 ==="
mkdir -p /home/$NEW_USER/.ssh
chmod 700 /home/$NEW_USER/.ssh

echo "※ この後、ローカルPCの公開鍵を貼り付けてください:"
echo "  /home/$NEW_USER/.ssh/authorized_keys"
echo ""
echo "ローカルPCで以下を実行して公開鍵を表示:"
echo "  cat ~/.ssh/id_ed25519.pub"
echo ""
read -p "公開鍵を貼り付けてください: " SSH_PUB_KEY
echo "$SSH_PUB_KEY" > /home/$NEW_USER/.ssh/authorized_keys
chmod 600 /home/$NEW_USER/.ssh/authorized_keys
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh

echo "=== 4. SSH設定の強化 ==="
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
cat > /etc/ssh/sshd_config.d/hardening.conf << 'SSHEOF'
# ポート変更
Port 10022
# rootログイン禁止
PermitRootLogin no
# パスワード認証禁止（鍵認証のみ）
PasswordAuthentication no
# 公開鍵認証を有効化
PubkeyAuthentication yes
SSHEOF

echo "=== 5. ファイアウォール設定 ==="
apt install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT/tcp comment 'SSH'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable
ufw status verbose

echo "=== 6. 必要パッケージのインストール ==="
apt install -y \
    curl \
    git \
    fail2ban \
    unattended-upgrades

# fail2ban 有効化
systemctl enable fail2ban
systemctl start fail2ban

# 自動セキュリティアップデート有効化
dpkg-reconfigure -plow unattended-upgrades || true

echo "=== 7. Docker インストール ==="
curl -fsSL https://get.docker.com | sh
usermod -aG docker $NEW_USER

echo ""
echo "============================================"
echo "  初期セットアップ完了"
echo "============================================"
echo ""
echo "次のステップ:"
echo "  1. SSHを再起動:  systemctl restart sshd"
echo "  2. 【切断せずに】別ターミナルで接続テスト:"
echo "     ssh -p $SSH_PORT $NEW_USER@<VPSのIP>"
echo "  3. 接続できたら、このターミナルを閉じてOK"
echo ""
echo "⚠ 接続テストせずにこのターミナルを閉じないでください！"
echo "  rootログインが無効になっているため、ロックアウトされます"
