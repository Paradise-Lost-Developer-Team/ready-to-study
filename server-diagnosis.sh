#!/bin/bash

# server-diagnosis.sh - サーバー環境診断スクリプト
# openSUSE Leap での Ready to Study 環境の総合診断

set -euo pipefail

# 色付きログ関数
log_info() { echo -e "\e[32m[INFO]\e[0m $1"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
log_step() { echo -e "\e[36m[STEP]\e[0m $1"; }
log_ok() { echo -e "\e[32m[✅ OK]\e[0m $1"; }
log_fail() { echo -e "\e[31m[❌ FAIL]\e[0m $1"; }

# 設定値
APP_DIR="/opt/ready-to-study"
SERVICE_NAME="ready-to-study"

echo "🔍 Ready to Study - サーバー環境診断"
echo "==================================="
date
echo ""

# 1. システム基本情報
log_step "1/10: システム基本情報"
echo "ホスト名: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "カーネル: $(uname -r)"
echo "アーキテクチャ: $(uname -m)"
echo "メモリ: $(free -h | grep Mem | awk '{print $2}')"
echo "ディスク: $(df -h / | tail -1 | awk '{print $4}')"
echo ""

# 2. Pythonバージョンと利用可能性
log_step "2/10: Python環境の診断"

check_python_version() {
    local python_cmd="$1"
    if command -v "$python_cmd" &>/dev/null; then
        local version=$($python_cmd --version 2>&1 | awk '{print $2}')
        local major=$(echo "$version" | cut -d. -f1)
        local minor=$(echo "$version" | cut -d. -f2)
        
        echo "  $python_cmd: $version"
        
        if [[ $major -eq 3 && $minor -ge 8 ]]; then
            log_ok "$python_cmd は要件を満たしています（3.8以上）"
        else
            log_fail "$python_cmd は古すぎます（3.8未満）"
        fi
    else
        log_fail "$python_cmd が見つかりません"
    fi
}

echo "利用可能なPythonバージョン:"
for py in python python3 python3.8 python3.9 python3.10 python3.11; do
    check_python_version "$py" 2>/dev/null || true
done
echo ""

# 3. 必要パッケージの確認
log_step "3/10: システムパッケージの確認"

check_package() {
    local package="$1"
    if rpm -q "$package" &>/dev/null; then
        log_ok "$package がインストールされています"
    else
        log_fail "$package がインストールされていません"
    fi
}

for pkg in python3 python3-pip python3-venv gcc gcc-c++ make sqlite3-devel; do
    check_package "$pkg"
done
echo ""

# 4. プロジェクトディレクトリの確認
log_step "4/10: プロジェクトディレクトリの確認"

if [[ -d "$APP_DIR" ]]; then
    log_ok "プロジェクトディレクトリが存在します: $APP_DIR"
    echo "  ディレクトリサイズ: $(du -sh $APP_DIR 2>/dev/null | awk '{print $1}')"
    echo "  所有者: $(ls -ld $APP_DIR | awk '{print $3":"$4}')"
    
    # 重要ファイルの確認
    for file in app.py requirements.txt; do
        if [[ -f "$APP_DIR/$file" ]]; then
            log_ok "$file が存在します"
        else
            log_fail "$file が見つかりません"
        fi
    done
else
    log_fail "プロジェクトディレクトリが見つかりません: $APP_DIR"
fi
echo ""

# 5. 仮想環境の確認
log_step "5/10: Python仮想環境の確認"

VENV_PATH="$APP_DIR/venv"
if [[ -d "$VENV_PATH" ]]; then
    log_ok "仮想環境ディレクトリが存在します"
    
    if [[ -f "$VENV_PATH/bin/python" ]]; then
        log_ok "Python実行ファイルが存在します"
        echo "  仮想環境Pythonバージョン: $($VENV_PATH/bin/python --version 2>&1)"
    else
        log_fail "Python実行ファイルが見つかりません"
    fi
    
    if [[ -f "$VENV_PATH/bin/streamlit" ]]; then
        log_ok "Streamlit実行ファイルが存在します"
        echo "  Streamlitバージョン: $($VENV_PATH/bin/streamlit version 2>/dev/null | head -1 || echo 'バージョン取得失敗')"
    else
        log_fail "Streamlit実行ファイルが見つかりません"
    fi
    
    if [[ -f "$VENV_PATH/bin/pip" ]]; then
        log_ok "pip実行ファイルが存在します"
        echo "  インストールされたパッケージ数: $($VENV_PATH/bin/pip list 2>/dev/null | wc -l || echo '0')"
    else
        log_fail "pip実行ファイルが見つかりません"
    fi
else
    log_fail "仮想環境が見つかりません: $VENV_PATH"
fi
echo ""

# 6. ユーザーとグループの確認
log_step "6/10: ユーザーとグループの確認"

if id "ready-to-study" &>/dev/null; then
    log_ok "ready-to-study ユーザーが存在します"
    echo "  UID: $(id -u ready-to-study)"
    echo "  GID: $(id -g ready-to-study)"
    echo "  ホームディレクトリ: $(getent passwd ready-to-study | cut -d: -f6)"
else
    log_fail "ready-to-study ユーザーが見つかりません"
fi
echo ""

# 7. systemdサービスの確認
log_step "7/10: systemdサービスの確認"

SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
if [[ -f "$SERVICE_FILE" ]]; then
    log_ok "サービスファイルが存在します: $SERVICE_FILE"
    echo "  ファイルサイズ: $(ls -lh $SERVICE_FILE | awk '{print $5}')"
    echo "  最終更新: $(ls -l $SERVICE_FILE | awk '{print $6" "$7" "$8}')"
    
    # サービス状態
    echo "  サービス状態: $(systemctl is-active $SERVICE_NAME 2>/dev/null || echo 'inactive')"
    echo "  自動起動設定: $(systemctl is-enabled $SERVICE_NAME 2>/dev/null || echo 'disabled')"
    
    # サービス設定の確認
    if systemctl status $SERVICE_NAME &>/dev/null; then
        echo "  プロセスID: $(systemctl show $SERVICE_NAME --property=MainPID --value 2>/dev/null)"
        echo "  メモリ使用量: $(systemctl show $SERVICE_NAME --property=MemoryCurrent --value 2>/dev/null | numfmt --to=iec 2>/dev/null || echo 'N/A')"
    fi
else
    log_fail "サービスファイルが見つかりません: $SERVICE_FILE"
fi
echo ""

# 8. ネットワークとポートの確認
log_step "8/10: ネットワークとポートの確認"

echo "IPアドレス: $(hostname -I | awk '{print $1}')"

# ポート8501の確認
if command -v netstat &>/dev/null; then
    if netstat -tlnp 2>/dev/null | grep -q ":8501"; then
        log_ok "ポート8501がリッスン中です"
        netstat -tlnp 2>/dev/null | grep ":8501" | head -1
    else
        log_fail "ポート8501がリッスンされていません"
    fi
elif command -v ss &>/dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":8501"; then
        log_ok "ポート8501がリッスン中です"
        ss -tlnp 2>/dev/null | grep ":8501" | head -1
    else
        log_fail "ポート8501がリッスンされていません"
    fi
else
    log_warn "netstatもssも利用できません"
fi

# ファイアウォール確認
if command -v firewall-cmd &>/dev/null; then
    if firewall-cmd --query-port=8501/tcp 2>/dev/null; then
        log_ok "ファイアウォールでポート8501が開放されています"
    else
        log_fail "ファイアウォールでポート8501が閉じられています"
    fi
elif command -v ufw &>/dev/null; then
    if ufw status | grep -q "8501"; then
        log_ok "UFWでポート8501が設定されています"
    else
        log_fail "UFWでポート8501が設定されていません"
    fi
else
    log_warn "ファイアウォール管理ツールが見つかりません"
fi
echo ""

# 9. データベースとデータディレクトリ
log_step "9/10: データベースとデータディレクトリ"

DATA_DIR="$APP_DIR/data"
if [[ -d "$DATA_DIR" ]]; then
    log_ok "データディレクトリが存在します: $DATA_DIR"
    echo "  所有者: $(ls -ld $DATA_DIR | awk '{print $3":"$4}')"
    echo "  権限: $(ls -ld $DATA_DIR | awk '{print $1}')"
    
    DB_FILE="$DATA_DIR/study_app.db"
    if [[ -f "$DB_FILE" ]]; then
        log_ok "データベースファイルが存在します"
        echo "  ファイルサイズ: $(ls -lh $DB_FILE | awk '{print $5}')"
        echo "  最終更新: $(ls -l $DB_FILE | awk '{print $6" "$7" "$8}')"
    else
        log_fail "データベースファイルが見つかりません: $DB_FILE"
    fi
else
    log_fail "データディレクトリが見つかりません: $DATA_DIR"
fi
echo ""

# 10. 最近のログ（エラー）
log_step "10/10: 最近のサービスログ（直近10行）"

if systemctl list-units | grep -q "$SERVICE_NAME"; then
    echo "最近のサービスログ:"
    journalctl -u "$SERVICE_NAME" -n 10 --no-pager 2>/dev/null || echo "ログが見つかりません"
else
    log_warn "サービスが systemd に登録されていません"
fi
echo ""

# 診断結果のサマリー
echo "🎯 診断結果サマリー"
echo "=================="

# クリティカル問題の確認
CRITICAL_ISSUES=0

if ! command -v python3 &>/dev/null; then
    echo "❌ Python3がインストールされていません"
    ((CRITICAL_ISSUES++))
fi

if [[ ! -d "$APP_DIR" ]]; then
    echo "❌ プロジェクトディレクトリが見つかりません"
    ((CRITICAL_ISSUES++))
fi

if [[ ! -f "$VENV_PATH/bin/streamlit" ]]; then
    echo "❌ Streamlitがインストールされていません"
    ((CRITICAL_ISSUES++))
fi

if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "❌ systemdサービスファイルが見つかりません"
    ((CRITICAL_ISSUES++))
fi

if [[ $CRITICAL_ISSUES -eq 0 ]]; then
    log_ok "重大な問題は見つかりませんでした！"
    echo ""
    echo "🚀 推奨する次のステップ:"
    echo "1. サービス開始: sudo systemctl start $SERVICE_NAME"
    echo "2. ブラウザでアクセス: http://$(hostname -I | awk '{print $1}'):8501"
else
    log_error "$CRITICAL_ISSUES 個の重大な問題が見つかりました"
    echo ""
    echo "🔧 推奨する修復手順:"
    echo "1. Python環境修復: sudo bash fix-python-env-v2.sh"
    echo "2. 基本セットアップ: sudo bash install-autostart-service.sh"
    echo "3. クイック修復: sudo bash quick-fix.sh"
fi

echo ""
echo "📋 その他の診断・修復ツール:"
echo "• 全体ヘルスチェック: sudo bash health-check.sh"
echo "• サービス管理: sudo bash service-manager.sh"
echo "• 権限修復: sudo bash set-permissions.sh"
echo ""
echo "診断完了: $(date)"
