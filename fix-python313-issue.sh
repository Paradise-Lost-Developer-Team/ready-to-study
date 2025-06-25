#!/bin/bash

# fix-python313-issue.sh - Python 3.13 互換性問題対応スクリプト
# pandas 2.1.0 と Python 3.13 の互換性問題を解決（Python 3.8へダウングレード）

set -euo pipefail

# 色付きログ関数
log_info() { echo -e "\e[32m[INFO]\e[0m $1"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
log_step() { echo -e "\e[36m[STEP]\e[0m $1"; }

# 設定
APP_DIR="/opt/ready-to-study"
VENV_PATH="$APP_DIR/venv"

# root権限チェック
if [[ $EUID -ne 0 ]]; then
    log_error "このスクリプトはroot権限で実行してください"
    exit 1
fi

echo "🔧 Python 3.13 互換性問題対応"
echo "================================"

# 現在のPython環境確認
log_step "1/4: 現在のPython環境を確認"

if [[ -f "$VENV_PATH/bin/python" ]]; then
    CURRENT_VERSION=$("$VENV_PATH/bin/python" --version 2>&1 | awk '{print $2}')
    log_info "仮想環境Pythonバージョン: $CURRENT_VERSION"
    
    MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
    MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
    
    if [[ $MAJOR -eq 3 && $MINOR -ge 13 ]]; then
        log_warn "Python $CURRENT_VERSION は pandas との互換性問題があります"
        log_info "Python 3.8にダウングレードします"
        NEEDS_DOWNGRADE=true
    elif [[ $MAJOR -eq 3 && $MINOR -ge 12 ]]; then
        log_warn "Python $CURRENT_VERSION は一部パッケージで問題が発生する可能性があります"
        log_info "安定したPython 3.8にダウングレードします"
        NEEDS_DOWNGRADE=true
    else
        log_info "Python $CURRENT_VERSION は問題ありません"
        NEEDS_DOWNGRADE=false
    fi
else
    log_error "仮想環境が見つかりません: $VENV_PATH"
    exit 1
fi

if [[ "$NEEDS_DOWNGRADE" == "false" ]]; then
    log_info "✅ Python環境に問題はありません"
    exit 0
fi

# サービス停止
log_step "2/4: サービスを停止"
systemctl stop ready-to-study.service 2>/dev/null || true

# Python 3.8のインストールと設定
log_step "3/4: Python 3.8を設定"

# システムレベルでPython 3.8をインストール
log_info "Python 3.8をインストール中..."
zypper refresh

if zypper install -y python38 python38-pip python38-venv python38-devel; then
    log_info "✅ Python 3.8のインストール完了"
    
    # alternativesでPython 3.8を優先設定
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python38 200
    update-alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip38 200
    
    log_info "Python 3.8をデフォルトに設定しました"
    
    # 新しいバージョン確認
    NEW_VERSION=$(python3 --version 2>&1)
    log_info "新しいPythonバージョン: $NEW_VERSION"
    
else
    log_error "Python 3.8のインストールに失敗しました"
    log_info "代替方法: ソースからコンパイル"
    
    # 必要な開発ツールをインストール
    zypper install -y gcc gcc-c++ make zlib-devel openssl-devel readline-devel sqlite3-devel libffi-devel xz-devel
    
    # Python 3.8.18をソースからビルド
    cd /tmp
    wget https://www.python.org/ftp/python/3.8.18/Python-3.8.18.tgz
    tar xzf Python-3.8.18.tgz
    cd Python-3.8.18
    
    ./configure --enable-optimizations --prefix=/usr/local --enable-shared
    make -j$(nproc)
    make altinstall
    
    # ライブラリパスの設定
    echo '/usr/local/lib' > /etc/ld.so.conf.d/python38.conf
    ldconfig
    
    # シンボリックリンクの作成
    ln -sf /usr/local/bin/python3.8 /usr/bin/python3
    ln -sf /usr/local/bin/pip3.8 /usr/bin/pip3
    
    log_info "✅ Python 3.8をソースからインストール完了"
fi

# 仮想環境の再作成
log_step "4/4: 仮想環境を再作成"

# 古い仮想環境を削除
if [[ -d "$VENV_PATH" ]]; then
    log_info "古い仮想環境を削除中..."
    rm -rf "$VENV_PATH"
fi

# 新しい仮想環境を作成
log_info "Python 3.8で新しい仮想環境を作成中..."
python3 -m venv "$VENV_PATH"

if [[ ! -f "$VENV_PATH/bin/python" ]]; then
    log_error "仮想環境の作成に失敗しました"
    exit 1
fi

# pipのアップグレード
log_info "pipをアップグレード中..."
"$VENV_PATH/bin/python" -m pip install --upgrade pip

# 互換性のあるパッケージバージョンをインストール
log_info "Python 3.8互換パッケージをインストール中..."

# 基盤パッケージ
"$VENV_PATH/bin/pip" install wheel setuptools

# 数値計算ライブラリ（Python 3.8用安定バージョン）
"$VENV_PATH/bin/pip" install "numpy>=1.20.0,<1.25"
"$VENV_PATH/bin/pip" install "pandas>=1.5.0,<2.2"

# 可視化ライブラリ
"$VENV_PATH/bin/pip" install "matplotlib>=3.6.0,<3.8"
"$VENV_PATH/bin/pip" install "plotly>=5.10.0,<5.16"
"$VENV_PATH/bin/pip" install "altair>=4.2.0,<5.1"

# Streamlit（Python 3.8対応バージョン）
"$VENV_PATH/bin/pip" install "streamlit==1.28.0"

# その他の依存関係
"$VENV_PATH/bin/pip" install python-dateutil python-dotenv

# 権限設定
chown -R ready-to-study:ready-to-study "$APP_DIR"

# インストール確認
log_info "インストール結果確認..."
"$VENV_PATH/bin/python" --version
"$VENV_PATH/bin/pip" list | grep -E "(numpy|pandas|streamlit|matplotlib|plotly|altair)"

# Streamlitの動作テスト
if "$VENV_PATH/bin/python" -c "import streamlit; import pandas; import numpy; print('✅ 全パッケージ正常')" 2>/dev/null; then
    log_info "✅ すべてのパッケージが正常に動作します"
else
    log_error "❌ パッケージの動作確認に失敗"
    "$VENV_PATH/bin/python" -c "import streamlit; import pandas; import numpy" 2>&1 || true
    exit 1
fi

echo ""
log_info "🎉 Python環境をPython 3.8に修復完了しました！"
echo ""
echo "📋 次のステップ:"
echo "1. サービス開始: sudo systemctl start ready-to-study"
echo "2. 状態確認: sudo systemctl status ready-to-study"
echo "3. ログ確認: sudo journalctl -u ready-to-study -f"
echo ""
echo "🔍 確認コマンド:"
echo "• Python版確認: $VENV_PATH/bin/python --version"
echo "• パッケージ一覧: $VENV_PATH/bin/pip list"
echo "• Streamlit確認: $VENV_PATH/bin/streamlit version"
