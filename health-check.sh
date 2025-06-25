#!/bin/bash

# Ready to Study ヘルスチェックスクリプト

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_check() { echo -e "${BLUE}[CHECK]${NC} $1"; }

HEALTH_SCORE=0
TOTAL_CHECKS=0

check_item() {
    local description="$1"
    local command="$2"
    local expected_result="$3"
    
    log_check "$description"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if eval "$command" &>/dev/null; then
        if [[ -z "$expected_result" ]] || eval "$expected_result" &>/dev/null; then
            log_info "✅ OK"
            HEALTH_SCORE=$((HEALTH_SCORE + 1))
            return 0
        else
            log_warn "⚠️  条件不一致"
            return 1
        fi
    else
        log_error "❌ 失敗"
        return 1
    fi
}

echo "🔍 Ready to Study ヘルスチェック"
echo "================================"
echo "実行時刻: $(date)"
echo ""

# システム基本チェック
echo "📋 システム基本チェック"
echo "------------------------"
check_item "Python 3.x がインストールされている" "command -v python3"
check_item "pip がインストールされている" "command -v pip"
check_item "systemctl が利用可能" "command -v systemctl"
echo ""

# アプリケーションファイルチェック
echo "📁 アプリケーションファイルチェック"
echo "--------------------------------"
check_item "アプリケーションディレクトリが存在" "test -d /opt/ready-to-study"
check_item "メインアプリケーションファイルが存在" "test -f /opt/ready-to-study/app.py"
check_item "要件定義ファイルが存在" "test -f /opt/ready-to-study/requirements.txt"
check_item "データベース初期化スクリプトが存在" "test -f /opt/ready-to-study/scripts/init_database.py"
check_item "Python仮想環境が存在" "test -d /opt/ready-to-study/venv"
check_item "データディレクトリが存在" "test -d /opt/ready-to-study/data"
echo ""

# ユーザーと権限チェック
echo "👤 ユーザーと権限チェック"
echo "----------------------"
check_item "ready-to-study ユーザーが存在" "id ready-to-study"
check_item "アプリケーションディレクトリの所有者が正しい" "test \"\$(stat -c '%U' /opt/ready-to-study)\" = 'ready-to-study'"
check_item "データディレクトリの所有者が正しい" "test \"\$(stat -c '%U' /opt/ready-to-study/data)\" = 'ready-to-study'"
echo ""

# systemdサービスチェック
echo "⚙️ systemdサービスチェック"
echo "-------------------------"
check_item "systemdサービスファイルが存在" "test -f /etc/systemd/system/ready-to-study.service"
check_item "サービスが自動起動に設定されている" "systemctl is-enabled ready-to-study"
check_item "サービスが実行中" "systemctl is-active ready-to-study"
echo ""

# ネットワークとポートチェック
echo "🌐 ネットワークとポートチェック"
echo "----------------------------"
check_item "ポート8501がリッスン中" "netstat -tlnp | grep :8501"
check_item "ローカルホストでHTTPアクセス可能" "curl -s http://localhost:8501 | grep -q 'Ready to Study' || timeout 5 curl -s http://localhost:8501"
echo ""

# データベースチェック
echo "🗄️ データベースチェック"
echo "----------------------"
check_item "データベースファイルが存在" "test -f /opt/ready-to-study/data/study_app.db"
if [[ -f /opt/ready-to-study/data/study_app.db ]]; then
    check_item "データベースに教科テーブルが存在" "sudo -u ready-to-study sqlite3 /opt/ready-to-study/data/study_app.db 'SELECT name FROM sqlite_master WHERE type=\"table\" AND name=\"subjects\";' | grep -q subjects"
    check_item "教科データが登録されている" "sudo -u ready-to-study sqlite3 /opt/ready-to-study/data/study_app.db 'SELECT COUNT(*) FROM subjects;' | grep -v '^0$'"
fi
echo ""

# Pythonパッケージチェック
echo "🐍 Pythonパッケージチェック"
echo "-------------------------"
if [[ -d /opt/ready-to-study/venv ]]; then
    check_item "streamlit がインストールされている" "sudo -u ready-to-study /opt/ready-to-study/venv/bin/pip list | grep streamlit"
    check_item "pandas がインストールされている" "sudo -u ready-to-study /opt/ready-to-study/venv/bin/pip list | grep pandas"
    check_item "matplotlib がインストールされている" "sudo -u ready-to-study /opt/ready-to-study/venv/bin/pip list | grep matplotlib"
fi
echo ""

# ログとモニタリング
echo "📊 ログとモニタリング"
echo "------------------"
check_item "ログディレクトリが存在" "test -d /var/log/ready-to-study"
check_item "バックアップディレクトリが存在" "test -d /var/backups/ready-to-study"
check_item "systemdログが出力されている" "journalctl -u ready-to-study --since '1 hour ago' | grep -q ."
echo ""

# 結果サマリー
echo "📈 ヘルスチェック結果"
echo "===================="
HEALTH_PERCENTAGE=$((HEALTH_SCORE * 100 / TOTAL_CHECKS))

echo "総チェック項目: $TOTAL_CHECKS"
echo "成功項目: $HEALTH_SCORE"
echo "失敗項目: $((TOTAL_CHECKS - HEALTH_SCORE))"
echo "健康度: $HEALTH_PERCENTAGE%"
echo ""

if [[ $HEALTH_PERCENTAGE -ge 90 ]]; then
    log_info "🎉 システムは正常に動作しています！"
    exit 0
elif [[ $HEALTH_PERCENTAGE -ge 70 ]]; then
    log_warn "⚠️  一部に問題がありますが、基本的な動作は可能です"
    exit 0
else
    log_error "❌ 重要な問題が検出されました。システムの確認が必要です"
    echo ""
    echo "🔧 トラブルシューティング:"
    echo "• サービス状態確認: sudo systemctl status ready-to-study"
    echo "• ログ確認: sudo journalctl -u ready-to-study -f"
    echo "• サービス再起動: sudo systemctl restart ready-to-study"
    echo "• サービス管理: ./service-manager.sh help"
    exit 1
fi
