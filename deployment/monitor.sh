#!/bin/bash

# アプリケーション監視スクリプト

set -e

# 設定
SERVICE_NAME="ready-to-study"
LOG_FILE="/var/log/ready-to-study/monitor.log"
EMAIL_ALERT="admin@your-domain.com"  # 必要に応じて変更
HEALTH_CHECK_URL="http://localhost:8501"

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# メール送信（postfixが設定されている場合）
send_alert() {
    local subject="$1"
    local message="$2"
    
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$EMAIL_ALERT"
        log "📧 アラートメールを送信しました: $subject"
    fi
}

# サービス状態チェック
check_service() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "✅ サービス $SERVICE_NAME は正常に動作しています"
        return 0
    else
        log "❌ サービス $SERVICE_NAME が停止しています"
        return 1
    fi
}

# HTTP ヘルスチェック
check_http() {
    if curl -f -s -o /dev/null "$HEALTH_CHECK_URL"; then
        log "✅ HTTPヘルスチェック正常: $HEALTH_CHECK_URL"
        return 0
    else
        log "❌ HTTPヘルスチェック失敗: $HEALTH_CHECK_URL"
        return 1
    fi
}

# データベース接続チェック
check_database() {
    if sudo -u ready-to-study psql -h localhost -U ready_to_study -d ready_to_study_db -c "SELECT 1;" > /dev/null 2>&1; then
        log "✅ データベース接続正常"
        return 0
    else
        log "❌ データベース接続失敗"
        return 1
    fi
}

# ディスク使用量チェック
check_disk_usage() {
    local usage=$(df /opt/ready-to-study | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $usage -lt 80 ]]; then
        log "✅ ディスク使用量正常: ${usage}%"
        return 0
    elif [[ $usage -lt 90 ]]; then
        log "⚠️ ディスク使用量警告: ${usage}%"
        send_alert "Ready to Study - ディスク使用量警告" "ディスク使用量が${usage}%に達しました。"
        return 1
    else
        log "❌ ディスク使用量危険: ${usage}%"
        send_alert "Ready to Study - ディスク使用量危険" "ディスク使用量が${usage}%に達しました。緊急対応が必要です。"
        return 1
    fi
}

# メモリ使用量チェック
check_memory_usage() {
    local usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [[ $usage -lt 80 ]]; then
        log "✅ メモリ使用量正常: ${usage}%"
        return 0
    else
        log "⚠️ メモリ使用量高: ${usage}%"
        send_alert "Ready to Study - メモリ使用量警告" "メモリ使用量が${usage}%に達しました。"
        return 1
    fi
}

# CPU負荷チェック
check_cpu_load() {
    local load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_count=$(nproc)
    local load_percent=$(echo "$load * 100 / $cpu_count" | bc -l | awk '{printf "%.0f", $1}')
    
    if [[ $load_percent -lt 80 ]]; then
        log "✅ CPU負荷正常: ${load_percent}%"
        return 0
    else
        log "⚠️ CPU負荷高: ${load_percent}%"
        send_alert "Ready to Study - CPU負荷警告" "CPU負荷が${load_percent}%に達しました。"
        return 1
    fi
}

# メイン監視ループ
main() {
    log "🔍 システム監視を開始します..."
    
    local errors=0
    
    # 各チェック実行
    check_service || ((errors++))
    check_http || ((errors++))
    check_database || ((errors++))
    check_disk_usage || ((errors++))
    check_memory_usage || ((errors++))
    check_cpu_load || ((errors++))
    
    # 結果レポート
    if [[ $errors -eq 0 ]]; then
        log "🎉 すべてのチェックが正常に完了しました"
    else
        log "⚠️ $errors 件の問題が検出されました"
        
        # 自動復旧試行（サービスが停止している場合）
        if ! check_service; then
            log "🔄 サービスの自動復旧を試行します..."
            systemctl restart "$SERVICE_NAME"
            sleep 10
            
            if check_service; then
                log "✅ サービスの自動復旧が成功しました"
                send_alert "Ready to Study - サービス復旧" "サービスが自動的に復旧されました。"
            else
                log "❌ サービスの自動復旧が失敗しました"
                send_alert "Ready to Study - サービス復旧失敗" "サービスの自動復旧に失敗しました。手動での対応が必要です。"
            fi
        fi
    fi
    
    log "監視サイクルが完了しました\n"
}

# 引数による動作分岐
case "${1:-check}" in
    check)
        main
        ;;
    install-cron)
        echo "⏰ cronジョブを設定しています..."
        (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/ready-to-study/deployment/monitor.sh check") | crontab -
        echo "✅ 5分間隔での監視が設定されました"
        ;;
    *)
        echo "使用方法: $0 [check|install-cron]"
        exit 1
        ;;
esac
