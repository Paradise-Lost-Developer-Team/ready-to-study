#!/bin/bash

# Ready to Study - openSUSE Leap完全デプロイメントスクリプト

set -e

# 色付きログ関数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo "🚀 Ready to Study - openSUSE Leap 完全デプロイメント"
echo "=================================================="
echo ""

# 必要な情報の収集
log_step "デプロイメント設定"
read -p "ドメイン名を入力してください (例: study.example.com): " DOMAIN
read -p "管理者メールアドレスを入力してください: " EMAIL
read -p "PostgreSQLのパスワードを設定してください: " -s DB_PASSWORD
echo ""

if [[ -z "$DOMAIN" || -z "$EMAIL" || -z "$DB_PASSWORD" ]]; then
    log_error "必要な情報がすべて入力されていません"
    exit 1
fi

# 確認
echo ""
log_info "デプロイメント設定確認:"
echo "• ドメイン: $DOMAIN"
echo "• 管理者メール: $EMAIL"
echo "• データベースパスワード: [設定済み]"
echo ""
read -p "この設定でデプロイを続行しますか？ (y/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log_warn "デプロイメントをキャンセルしました"
    exit 0
fi

echo ""
log_step "デプロイメントを開始します..."

# 1. システムのセットアップ
log_step "1/7 システムセットアップ"
chmod +x deployment/setup-opensuse.sh
./deployment/setup-opensuse.sh

# 2. 環境設定の更新
log_step "2/7 環境設定の更新"
sed -i "s/your-secret-key-here/$(openssl rand -hex 32)/" deployment/.env.production
sed -i "s/password/$DB_PASSWORD/" deployment/.env.production

# 3. systemdサービスの設定
log_step "3/7 systemdサービス設定"
chmod +x deployment/setup-systemd.sh
sudo ./deployment/setup-systemd.sh

# 4. Nginxの設定
log_step "4/7 Nginx設定"
chmod +x deployment/setup-nginx.sh
sudo ./deployment/setup-nginx.sh

# Nginx設定でドメインを更新
sudo sed -i "s/your-domain.com/$DOMAIN/g" /etc/nginx/sites-available/ready-to-study
sudo systemctl reload nginx

# 5. SSL証明書の設定
log_step "5/7 SSL証明書設定"
chmod +x deployment/setup-ssl.sh
echo -e "$DOMAIN\n$EMAIL" | sudo ./deployment/setup-ssl.sh

# 6. バックアップの設定
log_step "6/7 バックアップ設定"
chmod +x deployment/backup.sh
sudo cp deployment/backup.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/backup.sh

# 毎日3時にバックアップを実行
(sudo crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/backup.sh") | sudo crontab -

# 7. 監視の設定
log_step "7/7 監視設定"
chmod +x deployment/monitor.sh
sudo cp deployment/monitor.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/monitor.sh

# 監視用のメール設定
sudo sed -i "s/admin@your-domain.com/$EMAIL/" /usr/local/bin/monitor.sh

# 5分間隔での監視設定
sudo /usr/local/bin/monitor.sh install-cron

# データベースの初期化
log_step "データベース初期化"
sudo -u ready-to-study python3 /opt/ready-to-study/scripts/init_database.py

# サービスの最終確認
log_step "サービス状態確認"
sleep 5
sudo systemctl status ready-to-study --no-pager
sudo systemctl status nginx --no-pager

# 接続テスト
log_step "接続テスト"
if curl -k -s "https://$DOMAIN" > /dev/null; then
    log_info "✅ HTTPS接続テスト成功"
else
    log_warn "⚠️ HTTPS接続テストに失敗（DNSが伝播していない可能性があります）"
fi

echo ""
echo "🎉 デプロイメントが完了しました！"
echo "=================================================="
echo ""
log_info "アクセス情報:"
echo "• アプリケーションURL: https://$DOMAIN"
echo "• 管理者メール: $EMAIL"
echo ""
log_info "管理コマンド:"
echo "• サービス状態確認: sudo systemctl status ready-to-study"
echo "• ログ確認: sudo journalctl -u ready-to-study -f"
echo "• バックアップ実行: sudo /usr/local/bin/backup.sh"
echo "• 監視実行: sudo /usr/local/bin/monitor.sh"
echo ""
log_info "設定ファイル:"
echo "• アプリ設定: /opt/ready-to-study/.env"
echo "• Nginx設定: /etc/nginx/sites-available/ready-to-study"
echo "• SSL証明書: /etc/letsencrypt/live/$DOMAIN/"
echo ""
log_warn "セキュリティ注意事項:"
echo "• データベースパスワードを安全に保管してください"
echo "• 定期的にシステムアップデートを実行してください"
echo "• ログファイルを定期的に確認してください"
