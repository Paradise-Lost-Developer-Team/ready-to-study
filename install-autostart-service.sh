#!/bin/bash

# Ready to Study - openSUSE Leap 自動起動サービス登録スクリプト

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

echo "🐧 Ready to Study - openSUSE Leap 自動起動サービス登録"
echo "=================================================="
echo ""

# root権限チェック
if [[ $EUID -ne 0 ]]; then
   log_error "このスクリプトはroot権限で実行してください"
   echo "実行方法: sudo $0"
   exit 1
fi

# 現在のディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/opt/ready-to-study"

log_step "環境情報の確認"
echo "• スクリプト実行場所: $SCRIPT_DIR"
echo "• アプリケーション配置先: $APP_DIR"
echo "• OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')"
echo ""

# アプリケーション用ユーザーの作成
log_step "アプリケーション用ユーザーの作成"
if id "ready-to-study" &>/dev/null; then
    log_info "ユーザー 'ready-to-study' は既に存在します"
else
    useradd -r -d /opt/ready-to-study -s /bin/false ready-to-study
    log_info "ユーザー 'ready-to-study' を作成しました"
fi

# アプリケーションディレクトリの作成と権限設定
log_step "アプリケーションディレクトリの設定"
mkdir -p $APP_DIR
mkdir -p /var/log/ready-to-study
mkdir -p /var/backups/ready-to-study

# アプリケーションファイルのコピー
log_info "アプリケーションファイルをコピーしています..."
cp -r "$SCRIPT_DIR/"* $APP_DIR/
chown -R ready-to-study:ready-to-study $APP_DIR
chown ready-to-study:ready-to-study /var/log/ready-to-study
chown ready-to-study:ready-to-study /var/backups/ready-to-study

# Python仮想環境の作成
log_step "Python仮想環境の作成"
if [[ ! -d "$APP_DIR/venv" ]]; then
    log_info "Python仮想環境を作成しています..."
    sudo -u ready-to-study python3 -m venv $APP_DIR/venv
    sudo -u ready-to-study $APP_DIR/venv/bin/pip install --upgrade pip
    
    # requirements.txtが存在する場合はインストール
    if [[ -f "$APP_DIR/requirements.txt" ]]; then
        log_info "Pythonパッケージをインストールしています..."
        sudo -u ready-to-study $APP_DIR/venv/bin/pip install -r $APP_DIR/requirements.txt
    fi
else
    log_info "Python仮想環境は既に存在します"
fi

# データベースの初期化
log_step "データベースの初期化"
if [[ ! -f "$APP_DIR/data/study_app.db" ]]; then
    log_info "データベースを初期化しています..."
    sudo -u ready-to-study mkdir -p $APP_DIR/data
    sudo -u ready-to-study $APP_DIR/venv/bin/python $APP_DIR/scripts/init_database.py
else
    log_info "データベースは既に存在します"
fi

# systemdサービスファイルの作成
log_step "systemdサービスファイルの作成"
cat > /etc/systemd/system/ready-to-study.service << 'EOF'
[Unit]
Description=Ready to Study - 高校生学習支援アプリ
Documentation=https://github.com/yourusername/ready-to-study
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ready-to-study
Group=ready-to-study
WorkingDirectory=/opt/ready-to-study
Environment=PATH=/opt/ready-to-study/venv/bin
Environment=PYTHONPATH=/opt/ready-to-study
Environment=STREAMLIT_SERVER_ADDRESS=0.0.0.0
Environment=STREAMLIT_SERVER_PORT=8501
Environment=STREAMLIT_SERVER_HEADLESS=true
Environment=STREAMLIT_BROWSER_GATHER_USAGE_STATS=false
ExecStart=/opt/ready-to-study/venv/bin/streamlit run app.py --server.address 0.0.0.0 --server.port 8501 --server.headless true
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=10
TimeoutStartSec=60
TimeoutStopSec=30

# セキュリティ設定
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/ready-to-study/data /var/log/ready-to-study /tmp

# リソース制限
LimitNOFILE=65536
LimitNPROC=4096
MemoryMax=2G
CPUQuota=200%

# ログ設定
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ready-to-study

[Install]
WantedBy=multi-user.target
EOF

log_info "systemdサービスファイルを作成しました: /etc/systemd/system/ready-to-study.service"

# systemdの設定
log_step "systemdサービスの設定"
systemctl daemon-reload
systemctl enable ready-to-study.service

log_info "ready-to-study サービスを自動起動に設定しました"

# ファイアウォール設定（firewalldがある場合）
log_step "ファイアウォール設定"
if systemctl is-active --quiet firewalld; then
    log_info "firewalldが検出されました。ポート8501を開放します..."
    firewall-cmd --permanent --add-port=8501/tcp
    firewall-cmd --reload
    log_info "ポート8501を開放しました"
else
    log_warn "firewalldが無効です。必要に応じて手動でポート8501を開放してください"
fi

# サービスの開始
log_step "サービスの開始"
read -p "サービスを今すぐ開始しますか？ (y/N): " START_NOW

if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
    systemctl start ready-to-study.service
    sleep 3
    
    # サービス状態の確認
    if systemctl is-active --quiet ready-to-study.service; then
        log_info "✅ サービスが正常に開始されました！"
    else
        log_error "❌ サービスの開始に失敗しました"
        log_info "ログを確認してください: journalctl -u ready-to-study -f"
        exit 1
    fi
else
    log_info "サービスは次回起動時に自動開始されます"
fi

# 完了メッセージ
echo ""
log_info "🎉 Ready to Study の自動起動設定が完了しました！"
echo ""
echo "📋 サービス管理コマンド:"
echo "• 開始:     sudo systemctl start ready-to-study"
echo "• 停止:     sudo systemctl stop ready-to-study"
echo "• 再起動:   sudo systemctl restart ready-to-study"
echo "• 状態確認: sudo systemctl status ready-to-study"
echo "• ログ確認: sudo journalctl -u ready-to-study -f"
echo "• 自動起動無効: sudo systemctl disable ready-to-study"
echo ""
echo "🌐 アクセス情報:"
echo "• ローカル: http://localhost:8501"
echo "• ネットワーク: http://$(hostname -I | awk '{print $1}'):8501"
echo ""
echo "📁 重要なパス:"
echo "• アプリケーション: /opt/ready-to-study/"
echo "• ログファイル: /var/log/ready-to-study/"
echo "• データベース: /opt/ready-to-study/data/study_app.db"
echo "• 設定ファイル: /opt/ready-to-study/.env"
