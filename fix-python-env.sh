#!/bin/bash

# Ready to Study - Python環境緊急修復スクリプト

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

echo "🔧 Ready to Study - Python環境緊急修復"
echo "======================================"
echo ""

# root権限チェック
if [[ $EUID -ne 0 ]]; then
   log_error "このスクリプトはroot権限で実行してください"
   echo "実行方法: sudo $0"
   exit 1
fi

APP_DIR="/opt/ready-to-study"

# サービス停止
log_step "サービスを停止しています..."
systemctl stop ready-to-study.service || true

# Python3の確認とバージョンチェック
log_step "Python環境を確認しています..."
if ! command -v python3 &> /dev/null; then
    log_error "Python3がインストールされていません"
    log_info "Python3をインストールしています..."
    zypper install -y python3 python3-pip python3-venv
fi

# Pythonバージョンの確認
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

log_info "現在のPythonバージョン: $PYTHON_VERSION"

# Python 3.8以上が必要（Streamlit 1.28.0の要件）
if [[ $PYTHON_MAJOR -lt 3 ]] || [[ $PYTHON_MAJOR -eq 3 && $PYTHON_MINOR -lt 8 ]]; then
    log_warn "⚠️  Python $PYTHON_VERSION は古すぎます（Streamlitには3.8以上が必要）"
    log_step "新しいPythonバージョンをインストールしています..."
    
    # openSUSE Leap用のPythonアップグレード
    zypper refresh
    
    # 利用可能なPythonパッケージを確認
    log_info "利用可能なPythonパッケージを確認しています..."
    zypper search python3 | grep "^i\|^v" | head -10
    
    # Python 3.9以上を試行
    for py_version in python39 python310 python311 python38; do
        log_info "Python パッケージ $py_version を試行しています..."
        if zypper install -y $py_version ${py_version}-pip ${py_version}-venv 2>/dev/null; then
            log_info "✅ $py_version のインストールに成功しました"
            
            # シンボリックリンクの更新
            if [[ -f "/usr/bin/${py_version}" ]]; then
                update-alternatives --install /usr/bin/python3 python3 /usr/bin/${py_version} 1
                log_info "python3 コマンドを $py_version に更新しました"
                break
            fi
        else
            log_warn "$py_version のインストールに失敗しました"
        fi
    done
    
    # 再度バージョン確認
    NEW_PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    log_info "アップグレード後のPythonバージョン: $NEW_PYTHON_VERSION"
    
    # まだ古い場合は手動ビルドを提案
    NEW_PYTHON_MAJOR=$(echo $NEW_PYTHON_VERSION | cut -d. -f1)
    NEW_PYTHON_MINOR=$(echo $NEW_PYTHON_VERSION | cut -d. -f2)
    
    if [[ $NEW_PYTHON_MAJOR -lt 3 ]] || [[ $NEW_PYTHON_MAJOR -eq 3 && $NEW_PYTHON_MINOR -lt 8 ]]; then
        log_error "❌ Python 3.8以上のインストールに失敗しました"
        log_info "💡 手動解決方法:"
        echo "1. ソースからPython 3.9をビルド:"
        echo "   zypper install -y gcc make zlib-devel openssl-devel readline-devel sqlite3-devel"
        echo "   wget https://www.python.org/ftp/python/3.9.18/Python-3.9.18.tgz"
        echo "   tar xzf Python-3.9.18.tgz && cd Python-3.9.18"
        echo "   ./configure --enable-optimizations --prefix=/usr/local"
        echo "   make -j\$(nproc) && make altinstall"
        echo "   ln -sf /usr/local/bin/python3.9 /usr/bin/python3"
        echo ""
        echo "2. または、openSUSE Tumbleweedリポジトリを追加:"
        echo "   zypper ar https://download.opensuse.org/tumbleweed/repo/oss/ tumbleweed"
        echo "   zypper install python3"
        exit 1
    fi
else
    log_info "✅ Python $PYTHON_VERSION は要件を満たしています"
fi

# Pythonバージョン確認
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
REQUIRED_VERSION="3.8"

log_info "現在のPythonバージョン: $(python3 --version)"

# バージョン比較関数
version_compare() {
    if [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]]; then
        return 1  # $1 < $2
    else
        return 0  # $1 >= $2
    fi
}

# Python 3.8以上が必要
if ! version_compare "$PYTHON_VERSION" "$REQUIRED_VERSION"; then
    log_warn "⚠️  Python $PYTHON_VERSION は古すぎます（Streamlit 1.28.0には3.8以上が必要）"
    log_step "新しいPythonをインストールしています..."
    
    # openSUSE Leapでの新しいPythonインストール
    log_info "パッケージリポジトリを更新しています..."
    zypper refresh
    
    # Python 3.9以上を試行
    if zypper se python39 | grep -q python39; then
        log_info "Python 3.9をインストールしています..."
        zypper install -y python39 python39-pip python39-venv python39-devel
        
        # python3のリンクを更新
        if [[ -f /usr/bin/python3.9 ]]; then
            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 100
            log_info "✅ Python 3.9をデフォルトに設定しました"
        fi
    elif zypper se python38 | grep -q python38; then
        log_info "Python 3.8をインストールしています..."
        zypper install -y python38 python38-pip python38-venv python38-devel
        
        # python3のリンクを更新
        if [[ -f /usr/bin/python3.8 ]]; then
            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 100
            log_info "✅ Python 3.8をデフォルトに設定しました"
        fi
    else
        log_info "標準リポジトリから最新のPython3をインストールしています..."
        zypper install -y python3 python3-pip python3-venv python3-devel
        
        # 開発ツールも追加
        zypper install -y gcc gcc-c++ make
    fi
    
    # 再度バージョン確認
    log_info "更新後のPythonバージョン: $(python3 --version)"
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
    
    if ! version_compare "$PYTHON_VERSION" "$REQUIRED_VERSION"; then
        log_error "❌ Pythonのアップグレードに失敗しました"
        log_info "手動でPython 3.8以上をインストールしてください:"
        log_info "1. zypper ar https://download.opensuse.org/repositories/devel:/languages:/python/openSUSE_Leap_15.3/ python"
        log_info "2. zypper refresh"
        log_info "3. zypper install python39 python39-pip python39-venv"
        exit 1
    fi
else
    log_info "✅ Python $PYTHON_VERSION は要件を満たしています"
fi

# 仮想環境を完全に削除して再作成
log_step "Python仮想環境を再作成しています..."
if [[ -d "$APP_DIR/venv" ]]; then
    log_info "既存の仮想環境を削除しています..."
    rm -rf "$APP_DIR/venv"
fi

# ready-to-studyユーザーで仮想環境を作成
log_info "新しい仮想環境を作成しています..."
sudo -u ready-to-study python3 -m venv "$APP_DIR/venv"

# 仮想環境の確認
if [[ ! -f "$APP_DIR/venv/bin/python" ]]; then
    log_error "仮想環境の作成に失敗しました"
    exit 1
fi

# pipのアップグレード
log_step "pipをアップグレードしています..."
sudo -u ready-to-study "$APP_DIR/venv/bin/python" -m pip install --upgrade pip

# 基本パッケージを段階的にインストール
log_step "基本パッケージをインストールしています..."

# 1. 基本依存関係
sudo -u ready-to-study "$APP_DIR/venv/bin/pip" install wheel setuptools

# 2. 数値計算ライブラリ
sudo -u ready-to-study "$APP_DIR/venv/bin/pip" install numpy==1.24.0

# 3. pandas
sudo -u ready-to-study "$APP_DIR/venv/bin/pip" install pandas==2.1.0

# 4. 可視化ライブラリ
sudo -u ready-to-study "$APP_DIR/venv/bin/pip" install matplotlib==3.7.0
sudo -u ready-to-study "$APP_DIR/venv/bin/pip" install seaborn==0.12.0
sudo -u ready-to-study "$APP_DIR/venv/bin/pip" install plotly==5.15.0

# 5. Streamlit（最重要）
log_step "Streamlitをインストールしています..."
sudo -u ready-to-study "$APP_DIR/venv/bin/pip" install streamlit==1.28.0

# 6. その他の依存関係
sudo -u ready-to-study "$APP_DIR/venv/bin/pip" install python-dateutil==2.8.2
sudo -u ready-to-study "$APP_DIR/venv/bin/pip" install python-dotenv==1.0.0

# Streamlitの確認
log_step "Streamlitのインストールを確認しています..."
if [[ -f "$APP_DIR/venv/bin/streamlit" ]]; then
    log_info "✅ Streamlitが正常にインストールされました"
    
    # バージョン確認
    STREAMLIT_VERSION=$(sudo -u ready-to-study "$APP_DIR/venv/bin/streamlit" version | head -1)
    log_info "Streamlitバージョン: $STREAMLIT_VERSION"
else
    log_error "❌ Streamlitのインストールに失敗しました"
    exit 1
fi

# requirements.txtからの一括インストール（失敗時のフォールバック）
log_step "requirements.txtから残りのパッケージをインストールしています..."
if [[ -f "$APP_DIR/requirements.txt" ]]; then
    sudo -u ready-to-study "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt" || {
        log_warn "一部のパッケージインストールに失敗しましたが、継続します"
    }
fi

# systemdサービスファイルの修正
log_step "systemdサービスファイルを修正しています..."
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
Environment=STREAMLIT_LOGGER_LEVEL=info

# 起動前チェック
ExecStartPre=/bin/bash -c 'test -f /opt/ready-to-study/venv/bin/streamlit || exit 1'
ExecStartPre=/bin/bash -c 'test -f /opt/ready-to-study/app.py || exit 1'
ExecStartPre=/bin/bash -c 'mkdir -p /opt/ready-to-study/data && chown ready-to-study:ready-to-study /opt/ready-to-study/data'

# メイン起動コマンド
ExecStart=/opt/ready-to-study/venv/bin/streamlit run app.py --server.address=0.0.0.0 --server.port=8501 --server.headless=true --logger.level=info

ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=15
TimeoutStartSec=120
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

# データベースの確認・初期化
log_step "データベースを確認しています..."
if [[ ! -f "$APP_DIR/data/study_app.db" ]]; then
    log_info "データベースを初期化しています..."
    sudo -u ready-to-study mkdir -p "$APP_DIR/data"
    sudo -u ready-to-study "$APP_DIR/venv/bin/python" "$APP_DIR/scripts/init_database.py"
fi

# 権限の最終確認
log_step "権限を最終確認しています..."
chown -R ready-to-study:ready-to-study "$APP_DIR"
chmod +x "$APP_DIR/venv/bin/streamlit"

# systemdリロード
systemctl daemon-reload

# サービステスト
log_step "サービスをテストしています..."
if systemctl start ready-to-study.service; then
    sleep 10
    
    if systemctl is-active --quiet ready-to-study.service; then
        log_info "✅ サービスが正常に開始されました！"
        
        # ポート確認
        sleep 5
        if netstat -tlnp 2>/dev/null | grep -q ":8501" || ss -tlnp 2>/dev/null | grep -q ":8501"; then
            log_info "✅ ポート8501でリッスンしています"
            IP_ADDRESS=$(hostname -I | awk '{print $1}')
            log_info "🌐 アクセスURL: http://$IP_ADDRESS:8501"
        else
            log_warn "⚠️  ポート8501がまだ準備中です（少し待ってから確認してください）"
        fi
    else
        log_error "❌ サービスが正常に動作していません"
        log_info "詳細ログ: journalctl -u ready-to-study -n 20"
    fi
else
    log_error "❌ サービスの開始に失敗しました"
    log_info "詳細ログ: journalctl -u ready-to-study -n 20"
fi

echo ""
log_info "🎉 Python環境修復が完了しました！"
echo ""
echo "📋 確認コマンド:"
echo "• サービス状態: sudo systemctl status ready-to-study"
echo "• リアルタイムログ: sudo journalctl -u ready-to-study -f"
echo "• Python環境確認: sudo -u ready-to-study /opt/ready-to-study/venv/bin/python --version"
echo "• Streamlit確認: sudo -u ready-to-study /opt/ready-to-study/venv/bin/streamlit version"
