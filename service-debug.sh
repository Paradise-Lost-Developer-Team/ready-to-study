#!/bin/bash
# Ready to Study サービスデバッグスクリプト
# サービスが起動しない場合の詳細診断

set -euo pipefail

# カラーコード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ログ関数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 定数
APP_DIR="/opt/ready-to-study"
VENV_DIR="$APP_DIR/venv"
SERVICE_NAME="ready-to-study"
USER_NAME="ready-to-study"

echo "======================================"
echo "Ready to Study サービスデバッグ診断"
echo "======================================"
echo

# 1. サービス状態の詳細確認
log_step "1. サービス状態の詳細確認"
echo "--- systemctl status ---"
systemctl status "$SERVICE_NAME" --no-pager -l || true
echo

echo "--- journalctl ログ（最新20行） ---"
journalctl -u "$SERVICE_NAME" -n 20 --no-pager || true
echo

# 2. ファイル・ディレクトリの存在確認
log_step "2. ファイル・ディレクトリの存在確認"
check_file_or_dir() {
    local path="$1"
    local description="$2"
    if [[ -e "$path" ]]; then
        echo -e "✅ $description: ${GREEN}存在${NC} ($path)"
        ls -la "$path" 2>/dev/null | head -3 || true
    else
        echo -e "❌ $description: ${RED}存在しない${NC} ($path)"
    fi
    echo
}

check_file_or_dir "$APP_DIR" "アプリディレクトリ"
check_file_or_dir "$APP_DIR/app.py" "メインアプリファイル"
check_file_or_dir "$VENV_DIR" "仮想環境ディレクトリ"
check_file_or_dir "$VENV_DIR/bin/python" "Python実行ファイル"
check_file_or_dir "$VENV_DIR/bin/streamlit" "Streamlit実行ファイル"
check_file_or_dir "/etc/systemd/system/$SERVICE_NAME.service" "systemdサービスファイル"

# 3. 権限確認
log_step "3. 権限確認"
echo "--- アプリディレクトリの権限 ---"
ls -la "$APP_DIR" 2>/dev/null | head -10 || echo "権限確認エラー"
echo

echo "--- ユーザー・グループ確認 ---"
if id "$USER_NAME" &>/dev/null; then
    echo -e "✅ ユーザー $USER_NAME: ${GREEN}存在${NC}"
    id "$USER_NAME"
else
    echo -e "❌ ユーザー $USER_NAME: ${RED}存在しない${NC}"
fi
echo

# 4. Python/仮想環境の詳細確認
log_step "4. Python/仮想環境の詳細確認"
if [[ -f "$VENV_DIR/bin/python" ]]; then
    echo "--- 仮想環境Python情報 ---"
    "$VENV_DIR/bin/python" --version || echo "Pythonバージョン取得エラー"
    "$VENV_DIR/bin/python" -c "import sys; print('Python実行パス:', sys.executable)" 2>/dev/null || echo "Python実行パス取得エラー"
    echo
    
    echo "--- インストール済みパッケージ（主要なもの） ---"
    "$VENV_DIR/bin/pip" list | grep -E "(streamlit|pandas|numpy|matplotlib)" || echo "パッケージ情報取得エラー"
    echo
    
    echo "--- Streamlit動作テスト ---"
    if "$VENV_DIR/bin/streamlit" --version &>/dev/null; then
        echo -e "✅ Streamlit: ${GREEN}正常動作${NC}"
        "$VENV_DIR/bin/streamlit" --version
    else
        echo -e "❌ Streamlit: ${RED}動作エラー${NC}"
    fi
else
    echo -e "❌ 仮想環境Python: ${RED}存在しない${NC}"
fi
echo

# 5. ポート使用状況確認
log_step "5. ポート使用状況確認"
echo "--- ポート8501の使用状況 ---"
netstat -tlnp | grep :8501 || echo "ポート8501は使用されていません"
echo

echo "--- プロセス確認 ---"
ps aux | grep -E "(streamlit|ready-to-study)" | grep -v grep || echo "関連プロセスは動作していません"
echo

# 6. アプリケーション手動起動テスト
log_step "6. アプリケーション手動起動テスト"
if [[ -f "$APP_DIR/app.py" ]] && [[ -f "$VENV_DIR/bin/streamlit" ]]; then
    echo "--- 手動起動テスト（5秒間） ---"
    cd "$APP_DIR"
    timeout 5s sudo -u "$USER_NAME" "$VENV_DIR/bin/streamlit" run app.py --server.address 0.0.0.0 --server.port 8501 --server.headless true 2>&1 || {
        echo -e "${RED}手動起動でエラーが発生しました${NC}"
        echo "上記のエラーメッセージを確認してください"
    }
else
    echo -e "${RED}手動起動テスト不可（ファイルが存在しません）${NC}"
fi
echo

# 7. 修復提案
log_step "7. 修復提案"
echo "問題が見つかった場合の修復手順:"
echo "1. 仮想環境の再作成: ./fix-python-env-v2.sh"
echo "2. サービスの再インストール: ./install-autostart-service.sh"
echo "3. 権限の修正: ./set-permissions.sh"
echo "4. 総合修復: ./quick-fix.sh"
echo "5. システム全体の診断: ./health-check.sh"
echo

echo "======================================"
echo "デバッグ診断完了"
echo "======================================"
