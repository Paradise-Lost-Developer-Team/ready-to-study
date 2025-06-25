#!/bin/bash

# Ready to Study - openSUSE Leap 修復スクリプト

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

echo "🔧 Ready to Study - openSUSE Leap 修復スクリプト"
echo "=============================================="
echo ""

# root権限チェック
if [[ $EUID -ne 0 ]]; then
   log_error "このスクリプトはroot権限で実行してください"
   echo "実行方法: sudo $0"
   exit 1
fi

APP_DIR="/opt/ready-to-study"

# 既存の問題を修復
log_step "権限問題を修復しています..."

# 既存のユーザーを削除して再作成
if id "ready-to-study" &>/dev/null; then
    log_info "既存のユーザーを削除しています..."
    userdel ready-to-study 2>/dev/null || true
fi

# グループが存在する場合は削除
if getent group ready-to-study &>/dev/null; then
    log_info "既存のグループを削除しています..."
    groupdel ready-to-study 2>/dev/null || true
fi

# グループとユーザーを再作成
log_info "グループとユーザーを再作成しています..."
groupadd -r ready-to-study
useradd -r -g ready-to-study -d $APP_DIR -s /bin/false ready-to-study

# ディレクトリの存在確認と作成
log_step "ディレクトリを確認・作成しています..."
mkdir -p $APP_DIR
mkdir -p /var/log/ready-to-study
mkdir -p /var/backups/ready-to-study
mkdir -p $APP_DIR/data

# 権限を段階的に設定
log_step "ファイル権限を設定しています..."
chown -R ready-to-study $APP_DIR
chgrp -R ready-to-study $APP_DIR
chmod -R 755 $APP_DIR
chmod 644 $APP_DIR/*.py 2>/dev/null || true
chmod 755 $APP_DIR/*.sh 2>/dev/null || true

# ログとバックアップディレクトリの権限
chown ready-to-study /var/log/ready-to-study
chgrp ready-to-study /var/log/ready-to-study
chown ready-to-study /var/backups/ready-to-study
chgrp ready-to-study /var/backups/ready-to-study

# systemdサービス設定の修正
log_step "systemdサービスを修正しています..."
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
Environment=PATH=/opt/ready-to-study/venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=/opt/ready-to-study
Environment=STREAMLIT_SERVER_ADDRESS=0.0.0.0
Environment=STREAMLIT_SERVER_PORT=8501
Environment=STREAMLIT_SERVER_HEADLESS=true
Environment=STREAMLIT_BROWSER_GATHER_USAGE_STATS=false
ExecStartPre=/bin/bash -c 'mkdir -p /opt/ready-to-study/data && chown ready-to-study:ready-to-study /opt/ready-to-study/data'
ExecStart=/opt/ready-to-study/venv/bin/streamlit run app.py --server.address=0.0.0.0 --server.port=8501 --server.headless=true
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=10
TimeoutStartSec=60
TimeoutStopSec=30
KillMode=mixed

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

# Python仮想環境の確認・再作成
log_step "Python仮想環境を確認しています..."
if [[ ! -d "$APP_DIR/venv" ]]; then
    log_info "Python仮想環境を作成しています..."
    sudo -u ready-to-study python3 -m venv $APP_DIR/venv
    sudo -u ready-to-study $APP_DIR/venv/bin/pip install --upgrade pip
    
    if [[ -f "$APP_DIR/requirements.txt" ]]; then
        log_info "Pythonパッケージをインストールしています..."
        sudo -u ready-to-study $APP_DIR/venv/bin/pip install -r $APP_DIR/requirements.txt
    fi
else
    log_info "Python仮想環境は既に存在します"
    # 権限を修正
    chown -R ready-to-study:ready-to-study $APP_DIR/venv
fi

# データベースの確認・初期化
log_step "データベースを確認しています..."
if [[ ! -f "$APP_DIR/data/study_app.db" ]]; then
    log_info "データベースを初期化しています..."
    sudo -u ready-to-study $APP_DIR/venv/bin/python $APP_DIR/scripts/init_database.py
else
    log_info "データベースは既に存在します"
    # 権限を修正
    chown ready-to-study:ready-to-study $APP_DIR/data/study_app.db
fi

# systemdの再設定
log_step "systemdサービスを再設定しています..."
systemctl daemon-reload
systemctl enable ready-to-study.service

# openSUSE特有のfirewall設定
log_step "ファイアウォール設定を確認しています..."
if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
    log_info "firewalldでポート8501を開放しています..."
    firewall-cmd --permanent --add-port=8501/tcp || true
    firewall-cmd --reload || true
    log_info "ファイアウォール設定が完了しました"
elif command -v SuSEfirewall2 &> /dev/null; then
    log_info "SuSEfirewall2でポート8501を開放しています..."
    # openSUSE固有のファイアウォール設定
    echo "TCP_PORTS='8501'" >> /etc/sysconfig/SuSEfirewall2
    SuSEfirewall2 restart || true
else
    log_warn "ファイアウォール設定をスキップしました"
fi

# SELinuxが有効な場合の対処（openSUSEでは通常無効）
if command -v getenforce &> /dev/null && [[ "$(getenforce)" == "Enforcing" ]]; then
    log_info "SELinux設定を調整しています..."
    setsebool -P httpd_can_network_connect 1 || true
fi

# 最終確認
log_step "最終確認を実行しています..."
if systemctl start ready-to-study.service; then
    sleep 5
    if systemctl is-active --quiet ready-to-study.service; then
        log_info "✅ サービスが正常に開始されました！"
        
        # ポートの確認
        if netstat -tlnp 2>/dev/null | grep -q ":8501"; then
            log_info "✅ ポート8501でリッスンしています"
        else
            log_warn "⚠️  ポート8501が確認できません"
        fi
        
        log_info "🌐 アクセスURL: http://$(hostname -I | awk '{print $1}'):8501"
    else
        log_error "❌ サービスの開始に失敗しました"
        log_info "ログを確認してください: journalctl -u ready-to-study -f"
    fi
else
    log_error "❌ サービスの開始コマンドが失敗しました"
fi

echo ""
log_info "🎉 修復処理が完了しました！"
echo ""
echo "📋 確認コマンド:"
echo "• サービス状態: sudo systemctl status ready-to-study"
echo "• ログ確認: sudo journalctl -u ready-to-study -f"
echo "• ヘルスチェック: ./health-check.sh"
