#!/bin/bash

# fix-python-env-v2.sh - Python環境修復スクリプト（改良版）
# openSUSE Leap での Python 3.8+ 環境を確実に構築

set -euo pipefail

# 色付きログ関数
log_info() { echo -e "\e[32m[INFO]\e[0m $1"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
log_step() { echo -e "\e[36m[STEP]\e[0m $1"; }

# 設定値
APP_DIR="/opt/ready-to-study"
VENV_PATH="$APP_DIR/venv"
SERVICE_NAME="ready-to-study"

# root権限チェック
if [[ $EUID -ne 0 ]]; then
    log_error "このスクリプトはroot権限で実行してください"
    exit 1
fi

echo "🔧 Ready to Study - Python環境修復スクリプト v2"
echo "================================================"

# サービス停止
log_step "サービスを停止しています..."
systemctl stop $SERVICE_NAME.service 2>/dev/null || true

# 1. Pythonバージョン確認と必要に応じてアップグレード
log_step "1/7: Python環境を確認・アップグレード"

check_python_version() {
    local python_cmd="$1"
    if command -v "$python_cmd" &>/dev/null; then
        local version=$($python_cmd --version 2>&1 | awk '{print $2}')
        local major=$(echo "$version" | cut -d. -f1)
        local minor=$(echo "$version" | cut -d. -f2)
        
        echo "$version"
        
        if [[ $major -eq 3 && $minor -ge 8 ]]; then
            return 0  # OK
        else
            return 1  # 古い
        fi
    else
        return 2  # 存在しない
    fi
}

# Python3の確認（pyenv環境を回避）
log_info "Python3の確認中..."

# pyenv環境の検出と警告
if [[ -n "$PYENV_ROOT" ]] || [[ -d "$HOME/.pyenv" ]]; then
    log_warn "⚠️  pyenv環境が検出されました"
    log_info "システムレベルのPythonを使用することを推奨します"
    
    # pyenvを一時的に無効化
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    unset PYENV_ROOT
    unset PYENV_VERSION
fi

# システムPythonの確認
if ! command -v python3 &>/dev/null || ! check_python_version "python3" >/dev/null; then
    log_warn "適切なシステムPython3が見つかりません。インストールを開始します..."
    
    # パッケージ更新
    zypper refresh
    
    # まずは標準のpython3を試行
    zypper install -y python3 python3-pip python3-venv python3-devel
    
    # バージョン再確認
    if ! check_python_version "python3" >/dev/null; then
        log_info "より新しいPythonバージョンを探しています..."
        
# 利用可能なPythonバージョンを確認（Python 3.8-3.11を推奨）
        for py_ver in python311 python310 python39 python38; do
            log_info "Python パッケージ $py_ver を確認中..."
            if zypper se "$py_ver" | grep -q "^i\|^v"; then
                log_info "$py_ver をインストール中..."
                if zypper install -y "$py_ver" "${py_ver}-pip" "${py_ver}-venv" "${py_ver}-devel" 2>/dev/null; then
                    # シンボリックリンクの更新
                    if [[ -f "/usr/bin/${py_ver}" ]]; then
                        update-alternatives --install /usr/bin/python3 python3 "/usr/bin/${py_ver}" 100
                        log_info "✅ $py_ver を python3 として設定しました"
                        break
                    fi
                fi
            fi
        done
    fi
    
    # 最終確認
    PYTHON_VERSION=$(check_python_version "python3")
    if [[ $? -eq 0 ]]; then
        log_info "✅ Python $PYTHON_VERSION - 要件を満たしています"
    else
        log_error "❌ Python 3.8以上のインストールに失敗しました"
        log_info "💡 手動解決方法:"
        cat << 'EOL'
1. 外部リポジトリを追加してPython 3.9をインストール:
   zypper ar https://download.opensuse.org/repositories/devel:/languages:/python/openSUSE_Leap_15.4/ python-repo
   zypper refresh
   zypper install python39 python39-pip python39-venv

2. または、ソースからビルド:
   zypper install -y gcc make zlib-devel openssl-devel readline-devel sqlite3-devel libffi-devel
   wget https://www.python.org/ftp/python/3.9.18/Python-3.9.18.tgz
   tar xzf Python-3.9.18.tgz && cd Python-3.9.18
   ./configure --enable-optimizations --prefix=/usr/local
   make -j$(nproc) && make altinstall
   ln -sf /usr/local/bin/python3.9 /usr/bin/python3
EOL
        exit 1
    fi
else
    PYTHON_VERSION=$(check_python_version "python3")
    log_info "✅ Python $PYTHON_VERSION - 要件を満たしています"
fi

# 2. 必要パッケージのインストール
log_step "2/7: 必要なシステムパッケージをインストール"
zypper install -y gcc gcc-c++ make sqlite3-devel zlib-devel openssl-devel readline-devel libffi-devel

# 3. 仮想環境の完全再作成
log_step "3/7: 仮想環境を完全再作成"
if [[ -d "$VENV_PATH" ]]; then
    log_info "既存の仮想環境を削除..."
    rm -rf "$VENV_PATH"
fi

log_info "新しい仮想環境を作成..."
python3 -m venv "$VENV_PATH"
if [[ ! -f "$VENV_PATH/bin/python" ]]; then
    log_error "仮想環境の作成に失敗しました"
    exit 1
fi

# 4. pipのアップグレード
log_step "4/7: pipをアップグレード"
"$VENV_PATH/bin/python" -m pip install --upgrade pip

# 5. 依存関係の段階的インストール
log_step "5/7: 依存関係を段階的にインストール"

install_package() {
    local package="$1"
    local description="$2"
    
    log_info "インストール中: $description ($package)"
    if "$VENV_PATH/bin/pip" install "$package"; then
        log_info "✅ $package - インストール完了"
        return 0
    else
        log_warn "⚠️  $package - インストール失敗"
        return 1
    fi
}

# 基盤パッケージ
install_package "wheel" "Wheel（ビルドツール）"
install_package "setuptools" "Setuptools（パッケージツール）"

# Python バージョンの確認と適切なパッケージバージョンの選択
PYTHON_VERSION_NUM=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
log_info "使用するPythonバージョン: $PYTHON_VERSION_NUM"

# Python 3.13の場合は、より新しいバージョンが必要
if [[ "$PYTHON_VERSION_NUM" == "3.13" ]]; then
    log_warn "Python 3.13検出 - 最新の互換バージョンを使用します"
    
    # 数値計算ライブラリ（Python 3.13対応バージョン）
    install_package "numpy>=1.24.0" "NumPy（数値計算・3.13対応）"
    install_package "pandas>=2.1.4" "Pandas（データ処理・3.13対応）"
    
    # 可視化ライブラリ
    install_package "matplotlib>=3.8.0" "Matplotlib（グラフ描画）"
    install_package "plotly>=5.17.0" "Plotly（インタラクティブグラフ）"
    install_package "altair>=5.1.0" "Altair（統計的可視化）"
    
elif [[ "$PYTHON_VERSION_NUM" == "3.12" ]]; then
    log_info "Python 3.12用の安定バージョンを使用します"
    
    # 数値計算ライブラリ（Python 3.12対応バージョン）
    install_package "numpy>=1.24.0,<2.0" "NumPy（数値計算・3.12対応）"
    install_package "pandas>=2.1.0,<2.2" "Pandas（データ処理・3.12対応）"
    
    # 可視化ライブラリ
    install_package "matplotlib>=3.7.0,<3.9" "Matplotlib（グラフ描画）"
    install_package "plotly>=5.15.0,<6.0" "Plotly（インタラクティブグラフ）"
    install_package "altair>=5.0.0,<6.0" "Altair（統計的可視化）"
    
else
    log_info "Python 3.8-3.11用の安定バージョンを使用します"
    
    # 数値計算ライブラリ（安定バージョン）
    install_package "numpy==1.24.0" "NumPy（数値計算）"
    install_package "pandas==2.1.0" "Pandas（データ処理）"
    
    # 可視化ライブラリ
    install_package "matplotlib==3.7.0" "Matplotlib（グラフ描画）"
    install_package "plotly==5.15.0" "Plotly（インタラクティブグラフ）"
    install_package "altair==5.0.1" "Altair（統計的可視化）"
fi

# Streamlit
log_info "🎯 Streamlit 1.28.0 をインストール中..."
if install_package "streamlit==1.28.0" "Streamlit（Webアプリフレームワーク）"; then
    log_info "✅ Streamlit インストール完了"
else
    log_error "❌ Streamlit インストール失敗"
    exit 1
fi

# その他の依存関係
install_package "python-dateutil" "DateUtil（日付処理）"
install_package "python-dotenv" "DotEnv（環境変数）"

# 6. インストール状況の確認
log_step "6/7: インストール状況を確認"

log_info "インストールされたパッケージ:"
"$VENV_PATH/bin/pip" list | grep -E "(streamlit|numpy|pandas|matplotlib|plotly|altair)" || true

# Streamlitの動作確認
log_info "Streamlitの動作確認..."
if "$VENV_PATH/bin/python" -c "import streamlit; print('✅ Streamlit version:', streamlit.__version__)" 2>/dev/null; then
    log_info "✅ Streamlitは正常に動作します"
else
    log_error "❌ Streamlitのインポートに失敗"
    "$VENV_PATH/bin/python" -c "import streamlit" 2>&1 || true
    exit 1
fi

# 7. サービス設定の更新
log_step "7/7: systemdサービスを更新"

# ready-to-study ユーザーの確認・作成
if ! id "ready-to-study" &>/dev/null; then
    log_info "ready-to-study ユーザーを作成..."
    useradd -r -s /bin/false -d "$APP_DIR" -c "Ready to Study Service" ready-to-study
fi

# 権限設定
chown -R ready-to-study:ready-to-study "$APP_DIR"
chmod +x "$VENV_PATH/bin/streamlit"

# データディレクトリの確保
mkdir -p "$APP_DIR/data"
chown ready-to-study:ready-to-study "$APP_DIR/data"

# systemdサービスファイルの更新
cat > "/etc/systemd/system/$SERVICE_NAME.service" << 'EOF'
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
Environment=STREAMLIT_LOGGER_LEVEL=info

# 起動前チェック
ExecStartPre=/bin/bash -c 'test -f /opt/ready-to-study/venv/bin/streamlit'
ExecStartPre=/bin/bash -c 'test -f /opt/ready-to-study/app.py'
ExecStartPre=/bin/bash -c 'mkdir -p /opt/ready-to-study/data'

# メイン起動コマンド
ExecStart=/opt/ready-to-study/venv/bin/streamlit run app.py --server.address=0.0.0.0 --server.port=8501 --server.headless=true

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
ReadWritePaths=/opt/ready-to-study/data /tmp

# リソース制限
LimitNOFILE=65536
MemoryMax=2G

# ログ設定
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ready-to-study

[Install]
WantedBy=multi-user.target
EOF

# systemdリロード
systemctl daemon-reload

# データベース初期化
if [[ -f "$APP_DIR/scripts/init_database.py" && ! -f "$APP_DIR/data/study_app.db" ]]; then
    log_info "データベースを初期化..."
    sudo -u ready-to-study "$VENV_PATH/bin/python" "$APP_DIR/scripts/init_database.py"
fi

echo ""
echo "🎉 Python環境修復が完了しました！"
echo "================================="
echo ""
echo "📋 次のステップ:"
echo "1. サービスを開始: sudo systemctl start $SERVICE_NAME"
echo "2. 自動起動を有効: sudo systemctl enable $SERVICE_NAME"
echo "3. 状態確認: sudo systemctl status $SERVICE_NAME"
echo "4. ログ確認: sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "🌐 アプリケーション:"
echo "• URL: http://$(hostname -I | awk '{print $1}'):8501"
echo "• Streamlit: $($VENV_PATH/bin/streamlit version | head -1)"
echo "• Python: $(python3 --version)"
echo ""
echo "🛠️  トラブルシューティング:"
echo "• 全体診断: sudo bash health-check.sh"
echo "• クイック修復: sudo bash quick-fix.sh"

# 最終テスト（オプション）
echo ""
read -p "今すぐサービスをテスト開始しますか？ (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_step "サービステストを開始..."
    
    systemctl start "$SERVICE_NAME"
    sleep 15
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "✅ サービスが正常に起動しました！"
        
        # ポート確認
        if netstat -tlnp 2>/dev/null | grep -q ":8501" || ss -tlnp 2>/dev/null | grep -q ":8501"; then
            log_info "✅ ポート8501でリッスン中"
            log_info "🌐 アクセス: http://$(hostname -I | awk '{print $1}'):8501"
        else
            log_warn "⚠️  ポート8501がまだ準備中です"
        fi
        
        # 自動起動の有効化
        systemctl enable "$SERVICE_NAME"
        log_info "✅ 自動起動を有効にしました"
    else
        log_error "❌ サービス起動に失敗しました"
        log_info "詳細: sudo journalctl -u $SERVICE_NAME -n 20"
    fi
fi
