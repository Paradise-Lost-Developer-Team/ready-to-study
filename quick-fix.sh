#!/bin/bash

# Ready to Study - クイック診断・修復スクリプト

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

echo "🔍 Ready to Study - クイック診断"
echo "==============================="
echo ""

APP_DIR="/opt/ready-to-study"

# 診断関数
check_and_fix() {
    local description="$1"
    local check_command="$2"
    local fix_command="$3"
    
    echo -n "[$description] "
    
    if eval "$check_command" &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}NG${NC}"
        if [[ -n "$fix_command" ]]; then
            echo "  → 修復を試行中..."
            if eval "$fix_command" &>/dev/null; then
                echo -e "  → ${GREEN}修復成功${NC}"
                return 0
            else
                echo -e "  → ${RED}修復失敗${NC}"
                return 1
            fi
        fi
        return 1
    fi
}

# 基本チェック
log_step "基本環境チェック"
check_and_fix "Python3インストール" "command -v python3" "zypper install -y python3"
check_and_fix "pipインストール" "command -v pip3" "zypper install -y python3-pip"
check_and_fix "venvモジュール" "python3 -m venv --help" "zypper install -y python3-venv"
echo ""

# ディレクトリチェック
log_step "ディレクトリ構造チェック"
check_and_fix "アプリディレクトリ" "test -d $APP_DIR" "mkdir -p $APP_DIR"
check_and_fix "メインアプリファイル" "test -f $APP_DIR/app.py" ""
check_and_fix "初期化スクリプト" "test -f $APP_DIR/scripts/init_database.py" ""
echo ""

# ユーザーチェック
log_step "ユーザー・権限チェック"
check_and_fix "ready-to-studyユーザー" "id ready-to-study" ""
check_and_fix "ディレクトリ所有者" "test \"\$(stat -c '%U' $APP_DIR 2>/dev/null)\" = 'ready-to-study'" "chown -R ready-to-study:ready-to-study $APP_DIR"
echo ""

# Python仮想環境チェック
log_step "Python仮想環境チェック"
check_and_fix "仮想環境ディレクトリ" "test -d $APP_DIR/venv" ""
check_and_fix "仮想環境Python" "test -f $APP_DIR/venv/bin/python" ""
check_and_fix "仮想環境pip" "test -f $APP_DIR/venv/bin/pip" ""
check_and_fix "Streamlit実行ファイル" "test -f $APP_DIR/venv/bin/streamlit" ""
echo ""

# 問題が見つかった場合の修復オプション
echo "🔧 修復オプション"
echo "================="
echo ""

if [[ ! -f "$APP_DIR/venv/bin/streamlit" ]]; then
    log_error "❌ Streamlitが見つかりません"
    echo ""
    echo "修復方法を選択してください:"
    echo "1) Python環境を完全に再構築する（推奨）"
    echo "2) Streamlitのみ再インストールする"
    echo "3) 手動で確認する"
    echo ""
    read -p "選択してください (1-3): " choice
    
    case $choice in
        1)
            log_info "Python環境を完全再構築します..."
            if [[ -f "./fix-python-env.sh" ]]; then
                chmod +x ./fix-python-env.sh
                ./fix-python-env.sh
            else
                log_error "fix-python-env.sh が見つかりません"
            fi
            ;;
        2)
            log_info "Streamlitを再インストールします..."
            systemctl stop ready-to-study.service || true
            sudo -u ready-to-study $APP_DIR/venv/bin/pip install --force-reinstall streamlit==1.28.0
            systemctl start ready-to-study.service
            ;;
        3)
            log_info "手動確認のためのコマンド:"
            echo "• Python確認: sudo -u ready-to-study $APP_DIR/venv/bin/python --version"
            echo "• pip一覧: sudo -u ready-to-study $APP_DIR/venv/bin/pip list"
            echo "• Streamlitテスト: sudo -u ready-to-study $APP_DIR/venv/bin/streamlit version"
            ;;
        *)
            log_warn "無効な選択です"
            ;;
    esac
fi

# systemdサービスチェック
log_step "systemdサービスチェック"
if systemctl is-active --quiet ready-to-study.service; then
    log_info "✅ サービスは実行中です"
else
    log_warn "⚠️  サービスが停止中です"
    
    echo "サービスを開始しますか？ (y/N)"
    read -p "> " start_service
    
    if [[ "$start_service" =~ ^[Yy]$ ]]; then
        systemctl start ready-to-study.service
        sleep 5
        
        if systemctl is-active --quiet ready-to-study.service; then
            log_info "✅ サービスが開始されました"
        else
            log_error "❌ サービスの開始に失敗しました"
            echo "ログを確認してください: journalctl -u ready-to-study -n 10"
        fi
    fi
fi

echo ""
log_info "🎉 診断が完了しました"
echo ""
echo "📋 役立つコマンド:"
echo "• リアルタイムログ: sudo journalctl -u ready-to-study -f"
echo "• サービス再起動: sudo systemctl restart ready-to-study"
echo "• Python環境修復: sudo ./fix-python-env.sh"
echo "• ヘルスチェック: ./health-check.sh"
