#!/bin/bash

# fix-python-env-v2-debug.sh - Python環境修復スクリプト（デバッグ版）
# openSUSE Leap での Python 3.8 環境を優先的に構築（最も安定）

# デバッグモード：エラーで停止しない
set -uo pipefail

# 色付きログ関数
log_info() { echo -e "\e[32m[INFO]\e[0m $1"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
log_step() { echo -e "\e[36m[STEP]\e[0m $1"; }
log_debug() { echo -e "\e[35m[DEBUG]\e[0m $1"; }

# 設定値
APP_DIR="/opt/ready-to-study"
VENV_PATH="$APP_DIR/venv"
SERVICE_NAME="ready-to-study"

# root権限チェック
if [[ $EUID -ne 0 ]]; then
    log_error "このスクリプトはroot権限で実行してください"
    exit 1
fi

echo "🔧 Ready to Study - Python環境修復スクリプト v2 (デバッグ版・Python 3.8推奨)"
echo "====================================================================================="

# サービス停止
log_step "サービスを停止しています..."
systemctl stop $SERVICE_NAME.service 2>/dev/null || true

# 1. Pythonバージョン確認と必要に応じてアップグレード
log_step "1/7: Python環境を確認・アップグレード"

check_python_version() {
    local python_cmd="$1"
    log_debug "Pythonコマンド確認: $python_cmd"
    
    if command -v "$python_cmd" &>/dev/null; then
        log_debug "$python_cmd が見つかりました: $(which "$python_cmd")"
        local version
        if version=$($python_cmd --version 2>&1); then
            log_debug "バージョン取得成功: $version"
            version=$(echo "$version" | awk '{print $2}')
            local major minor
            major=$(echo "$version" | cut -d. -f1)
            minor=$(echo "$version" | cut -d. -f2)
            
            log_debug "メジャー: $major, マイナー: $minor"
            echo "$version"
            
            # Python 3.8を推奨とする（最も安定）
            if [[ $major -eq 3 && $minor -eq 8 ]]; then
                return 0  # 最適
            elif [[ $major -eq 3 && $minor -ge 8 && $minor -le 11 ]]; then
                return 1  # 利用可能だが3.8が推奨
            else
                return 2  # 古すぎるまたは新しすぎる
            fi
        else
            log_debug "バージョン取得に失敗"
            echo "ERROR_VERSION"
            return 3  # バージョン取得エラー
        fi
    else
        log_debug "$python_cmd が見つかりません"
        echo "NOT_FOUND"
        return 3  # 存在しない
    fi
}

# Python3の確認（pyenv環境を回避）
log_info "Python3の確認中..."

# デバッグ: 現在の環境変数を確認
log_debug "HOME=${HOME:-未設定}"
log_debug "PATH=$PATH"

# pyenv環境の検出と警告（未定義変数に対応）
log_info "pyenv環境をチェック中..."
PYENV_DETECTED=false

if [[ -n "${PYENV_ROOT:-}" ]]; then
    log_warn "⚠️  PYENV_ROOT環境変数が設定されています: $PYENV_ROOT"
    PYENV_DETECTED=true
fi

if [[ -d "${HOME:-/root}/.pyenv" ]]; then
    log_warn "⚠️  pyenvディレクトリが検出されました: ${HOME:-/root}/.pyenv"
    PYENV_DETECTED=true
fi

if [[ "$PYENV_DETECTED" == "true" ]]; then
    log_warn "⚠️  pyenv環境が検出されました"
    log_info "システムレベルのPythonを使用することを推奨します"
    
    # pyenvを一時的に無効化
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    unset PYENV_ROOT 2>/dev/null || true
    unset PYENV_VERSION 2>/dev/null || true
    log_info "✅ pyenv環境を無効化しました"
else
    log_info "✅ pyenv環境は検出されませんでした"
fi

# システムPythonの確認とPython 3.8の優先インストール
log_info "Python3コマンドの存在確認..."
if ! command -v python3 &>/dev/null; then
    log_warn "python3コマンドが見つかりません"
    PYTHON_VERSION="NOTFOUND"
    PYTHON_STATUS=3
else
    log_info "python3コマンドが見つかりました: $(which python3)"
    PYTHON_VERSION=$(check_python_version "python3")
    PYTHON_STATUS=$?
    log_info "Python バージョン: $PYTHON_VERSION (ステータス: $PYTHON_STATUS)"
fi

if [[ $PYTHON_STATUS -eq 0 ]]; then
    log_info "✅ Python $PYTHON_VERSION (3.8) - 最適なバージョンです"
    NEEDS_PYTHON38=false
elif [[ $PYTHON_STATUS -eq 1 ]]; then
    log_warn "Python $PYTHON_VERSION は利用可能ですが、Python 3.8を推奨します"
    log_info "Python 3.8へのダウングレード/アップグレードを実行します"
    NEEDS_PYTHON38=true
elif [[ $PYTHON_STATUS -eq 2 ]]; then
    log_warn "Python $PYTHON_VERSION は古いまたは新しすぎます。Python 3.8をインストールします"
    NEEDS_PYTHON38=true
else
    log_warn "適切なPython3が見つかりません（バージョン: $PYTHON_VERSION）。Python 3.8をインストールします"
    NEEDS_PYTHON38=true
fi

log_info "NEEDS_PYTHON38=${NEEDS_PYTHON38}"

if [[ "${NEEDS_PYTHON38:-false}" == "true" ]]; then
    log_step "Python 3.8をインストール中..."
    
    # パッケージ更新
    log_info "パッケージリストを更新中..."
    if zypper refresh; then
        log_info "✅ パッケージリスト更新完了"
    else
        log_warn "⚠️  パッケージリスト更新に失敗（続行します）"
    fi
    
    # Python 3.8を最優先でインストール
    log_info "Python 3.8パッケージをインストール中..."
    if zypper install -y python38 python38-pip python38-venv python38-devel; then
        log_info "✅ Python 3.8のパッケージインストール完了"
        
        # alternativesでPython 3.8を最高優先度に設定
        if update-alternatives --install /usr/bin/python3 python3 /usr/bin/python38 300; then
            log_info "✅ python3のalternatives設定完了"
        fi
        
        if update-alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip38 300; then
            log_info "✅ pip3のalternatives設定完了"
        fi
        
        log_info "✅ Python 3.8をデフォルトに設定しました"
        
    else
        log_warn "Python 3.8パッケージのインストールに失敗。他のバージョンを試行..."
        
        # フォールバック: 他のPythonバージョンを試行（3.8が最優先）
        for py_ver in python39 python310 python311; do
            log_info "Python パッケージ $py_ver を確認中..."
            if zypper se "$py_ver" | grep -q "^i\|^v"; then
                log_info "$py_ver をインストール中..."
                if zypper install -y "$py_ver" "${py_ver}-pip" "${py_ver}-venv" "${py_ver}-devel" 2>/dev/null; then
                    # シンボリックリンクの更新（3.8より低い優先度）
                    if [[ -f "/usr/bin/${py_ver}" ]]; then
                        if update-alternatives --install /usr/bin/python3 python3 "/usr/bin/${py_ver}" 200; then
                            log_info "✅ $py_ver を python3 として設定しました（フォールバック）"
                            break
                        fi
                    fi
                fi
            fi
        done
    fi
    
    # 最終確認
    log_info "最終的なPython確認..."
    FINAL_VERSION=$(check_python_version "python3")
    FINAL_STATUS=$?
    
    if [[ $FINAL_STATUS -eq 0 ]]; then
        log_info "✅ Python $FINAL_VERSION (3.8) - 最適なバージョンが設定されました"
    elif [[ $FINAL_STATUS -eq 1 ]]; then
        log_info "✅ Python $FINAL_VERSION - 利用可能なバージョンが設定されました"
    else
        log_error "❌ Python 3.8以上のインストールに失敗しました"
        log_info "💡 手動解決方法:"
        cat << 'EOL'
1. 外部リポジトリを追加してPython 3.8をインストール:
   zypper ar https://download.opensuse.org/repositories/devel:/languages:/python/openSUSE_Leap_15.4/ python-repo
   zypper refresh
   zypper install python38 python38-pip python38-venv

2. または、ソースからPython 3.8をビルド:
   zypper install -y gcc make zlib-devel openssl-devel readline-devel sqlite3-devel libffi-devel
   wget https://www.python.org/ftp/python/3.8.18/Python-3.8.18.tgz
   tar xzf Python-3.8.18.tgz && cd Python-3.8.18
   ./configure --enable-optimizations --prefix=/usr/local
   make -j$(nproc) && make altinstall
   ln -sf /usr/local/bin/python3.8 /usr/bin/python3
EOL
        exit 1
    fi
else
    log_info "✅ Python環境は適切です。インストールをスキップします"
fi

echo ""
echo "🎉 Python環境確認が完了しました！"
echo "================================="
echo ""
echo "📋 次のステップ:"
echo "1. 完全版スクリプトの実行: sudo ./fix-python-env-v2.sh"
echo "2. またはマニュアルでの続行:"
echo "   - システムパッケージインストール"
echo "   - 仮想環境作成"
echo "   - 依存関係インストール"
echo ""
echo "🐍 現在のPython環境:"
echo "• Python: $(python3 --version 2>/dev/null || echo '確認できません')"
echo "• パス: $(which python3 2>/dev/null || echo '見つかりません')"
