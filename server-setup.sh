#!/bin/bash

# Ready to Study - openSUSE Leap サーバーセットアップマスター

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo "🐧 Ready to Study - openSUSE Leap サーバーセットアップ"
echo "=================================================="
echo ""

# 権限確認
if [[ $EUID -eq 0 ]]; then
   log_error "このスクリプトはrootユーザーで実行しないでください"
   exit 1
fi

# sudo権限確認
if ! sudo -n true 2>/dev/null; then
    log_info "sudo権限が必要です。パスワードを入力してください。"
    sudo -v
fi

# システム情報表示
log_info "システム情報:"
echo "• OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')"
echo "• Kernel: $(uname -r)"
echo "• Architecture: $(uname -m)"
echo "• Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "• Disk: $(df -h / | tail -1 | awk '{print $4}') free"
echo ""

# セットアップタイプの選択
log_step "セットアップタイプを選択してください:"
echo "1) 完全自動セットアップ (推奨)"
echo "2) 手動ステップバイステップ"
echo "3) Dockerベースのセットアップ"
echo ""
read -p "選択してください (1-3): " SETUP_TYPE

case $SETUP_TYPE in
    1)
        log_info "完全自動セットアップを開始します..."
        ./deployment/deploy.sh
        ;;
    2)
        log_info "手動セットアップを開始します..."
        manual_setup
        ;;
    3)
        log_info "Dockerセットアップを開始します..."
        docker_setup
        ;;
    *)
        log_error "無効な選択です"
        exit 1
        ;;
esac

manual_setup() {
    log_step "手動セットアップモード"
    echo ""
    
    # ステップ1: 基本セットアップ
    log_step "ステップ 1/6: 基本システムセットアップ"
    read -p "実行しますか？ (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        chmod +x deployment/setup-opensuse.sh
        ./deployment/setup-opensuse.sh
    fi
    
    # ステップ2: systemdサービス
    log_step "ステップ 2/6: systemdサービス設定"
    read -p "実行しますか？ (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        chmod +x deployment/setup-systemd.sh
        sudo ./deployment/setup-systemd.sh
    fi
    
    # ステップ3: Nginx設定
    log_step "ステップ 3/6: Nginx設定"
    read -p "実行しますか？ (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        chmod +x deployment/setup-nginx.sh
        sudo ./deployment/setup-nginx.sh
    fi
    
    # ステップ4: SSL証明書
    log_step "ステップ 4/6: SSL証明書設定"
    read -p "実行しますか？ (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        chmod +x deployment/setup-ssl.sh
        sudo ./deployment/setup-ssl.sh
    fi
    
    # ステップ5: データベース初期化
    log_step "ステップ 5/6: データベース初期化"
    read -p "実行しますか？ (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo -u ready-to-study python3 /opt/ready-to-study/scripts/init_database.py
    fi
    
    # ステップ6: 監視設定
    log_step "ステップ 6/6: 監視設定"
    read -p "実行しますか？ (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        chmod +x deployment/monitor.sh
        sudo ./deployment/monitor.sh
    fi
    
    log_info "✅ 手動セットアップが完了しました！"
}

docker_setup() {
    log_step "Dockerセットアップモード"
    
    # Dockerのインストール確認
    if ! command -v docker &> /dev/null; then
        log_info "Dockerをインストールしています..."
        sudo zypper install -y docker docker-compose
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker $USER
        
        log_warn "Dockerグループに追加されました。ログアウト/ログインが必要です。"
        log_info "または以下のコマンドを実行してください:"
        echo "newgrp docker"
        exit 0
    fi
    
    # Docker Composeでセットアップ
    log_info "Docker Composeでアプリケーションを起動しています..."
    chmod +x deployment/docker-compose.yml
    
    # 環境変数の設定
    read -p "ドメイン名を入力してください: " DOMAIN
    read -p "データベースパスワードを設定してください: " -s DB_PASSWORD
    echo ""
    
    # .envファイルの作成
    cat > deployment/.env << EOF
DOMAIN=$DOMAIN
DB_PASSWORD=$DB_PASSWORD
POSTGRES_PASSWORD=$DB_PASSWORD
EOF
    
    cd deployment
    docker-compose up -d
    
    log_info "✅ Dockerセットアップが完了しました！"
    log_info "アプリケーションURL: http://$DOMAIN"
}

# 実行権限の設定
chmod +x deployment/*.sh

# 完了メッセージ
echo ""
log_info "🎉 Ready to Study サーバーセットアップが完了しました！"
echo ""
echo "📋 次のコマンドでサービスを管理できます:"
echo "• サービス状態確認: sudo systemctl status ready-to-study"
echo "• ログ確認: sudo journalctl -u ready-to-study -f"
echo "• 設定ファイル: /opt/ready-to-study/.env"
echo "• ログファイル: /var/log/ready-to-study/"
echo ""
echo "🌐 アクセス情報:"
echo "• HTTP: http://[サーバーIP]"
echo "• HTTPS: https://[ドメイン名] (SSL設定後)"
echo ""
echo "🔧 トラブルシューティング:"
echo "• ./deployment/monitor.sh でシステム状態を確認"
echo "• ./deployment/backup.sh でデータをバックアップ"
