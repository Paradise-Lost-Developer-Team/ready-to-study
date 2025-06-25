#!/bin/bash

# Ready to Study サービス管理スクリプト

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SERVICE_NAME="ready-to-study"

show_status() {
    echo "📊 Ready to Study サービス状態"
    echo "================================"
    systemctl status $SERVICE_NAME --no-pager
    echo ""
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo "🟢 サービス状態: 実行中"
        echo "🌐 アクセス: http://$(hostname -I | awk '{print $1}'):8501"
    else
        echo "🔴 サービス状態: 停止中"
    fi
    
    if systemctl is-enabled --quiet $SERVICE_NAME; then
        echo "⚡ 自動起動: 有効"
    else
        echo "❌ 自動起動: 無効"
    fi
}

show_logs() {
    echo "📋 Ready to Study ログ (最新50行)"
    echo "================================"
    journalctl -u $SERVICE_NAME -n 50 --no-pager
    echo ""
    echo "💡 リアルタイムログを見るには: sudo journalctl -u $SERVICE_NAME -f"
}

show_help() {
    echo "🛠️  Ready to Study サービス管理"
    echo "================================"
    echo ""
    echo "使用方法: $0 [コマンド]"
    echo ""
    echo "コマンド:"
    echo "  start     - サービスを開始"
    echo "  stop      - サービスを停止"
    echo "  restart   - サービスを再起動"
    echo "  status    - サービス状態を表示"
    echo "  enable    - 自動起動を有効化"
    echo "  disable   - 自動起動を無効化"
    echo "  logs      - ログを表示"
    echo "  tail      - リアルタイムログ"
    echo "  install   - サービスをインストール"
    echo "  uninstall - サービスをアンインストール"
    echo "  update    - アプリケーションを更新"
    echo "  backup    - データをバックアップ"
    echo "  help      - このヘルプを表示"
    echo ""
    echo "例:"
    echo "  $0 start        # サービス開始"
    echo "  $0 status       # 状態確認"
    echo "  $0 logs         # ログ確認"
}

check_permissions() {
    if [[ $1 == "install" ]] || [[ $1 == "uninstall" ]] || [[ $1 == "start" ]] || [[ $1 == "stop" ]] || [[ $1 == "restart" ]] || [[ $1 == "enable" ]] || [[ $1 == "disable" ]]; then
        if [[ $EUID -ne 0 ]]; then
            log_error "このコマンドはroot権限が必要です"
            echo "実行方法: sudo $0 $1"
            exit 1
        fi
    fi
}

case "$1" in
    start)
        check_permissions $1
        log_info "Ready to Study サービスを開始しています..."
        systemctl start $SERVICE_NAME
        sleep 2
        if systemctl is-active --quiet $SERVICE_NAME; then
            log_info "✅ サービスが開始されました"
            echo "🌐 アクセス: http://$(hostname -I | awk '{print $1}'):8501"
        else
            log_error "❌ サービスの開始に失敗しました"
            exit 1
        fi
        ;;
    
    stop)
        check_permissions $1
        log_info "Ready to Study サービスを停止しています..."
        systemctl stop $SERVICE_NAME
        log_info "✅ サービスが停止されました"
        ;;
    
    restart)
        check_permissions $1
        log_info "Ready to Study サービスを再起動しています..."
        systemctl restart $SERVICE_NAME
        sleep 2
        if systemctl is-active --quiet $SERVICE_NAME; then
            log_info "✅ サービスが再起動されました"
            echo "🌐 アクセス: http://$(hostname -I | awk '{print $1}'):8501"
        else
            log_error "❌ サービスの再起動に失敗しました"
            exit 1
        fi
        ;;
    
    status)
        show_status
        ;;
    
    enable)
        check_permissions $1
        systemctl enable $SERVICE_NAME
        log_info "✅ 自動起動が有効になりました"
        ;;
    
    disable)
        check_permissions $1
        systemctl disable $SERVICE_NAME
        log_info "✅ 自動起動が無効になりました"
        ;;
    
    logs)
        show_logs
        ;;
    
    tail)
        log_info "Ready to Study リアルタイムログ (Ctrl+C で終了)"
        journalctl -u $SERVICE_NAME -f
        ;;
    
    install)
        check_permissions $1
        if [[ -f "./install-autostart-service.sh" ]]; then
            log_info "自動起動サービスをインストールしています..."
            ./install-autostart-service.sh
        else
            log_error "install-autostart-service.sh が見つかりません"
            exit 1
        fi
        ;;
    
    uninstall)
        check_permissions $1
        log_warn "Ready to Study サービスをアンインストールします"
        read -p "続行しますか？ (y/N): " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            systemctl stop $SERVICE_NAME 2>/dev/null || true
            systemctl disable $SERVICE_NAME 2>/dev/null || true
            rm -f /etc/systemd/system/$SERVICE_NAME.service
            systemctl daemon-reload
            log_info "✅ サービスがアンインストールされました"
            echo "💡 アプリケーションファイルは /opt/ready-to-study に残っています"
        else
            log_info "アンインストールをキャンセルしました"
        fi
        ;;
    
    update)
        log_info "アプリケーションを更新しています..."
        if [[ -d "/opt/ready-to-study" ]]; then
            sudo systemctl stop $SERVICE_NAME 2>/dev/null || true
            
            # バックアップ
            sudo cp -r /opt/ready-to-study /opt/ready-to-study.backup.$(date +%Y%m%d_%H%M%S)
            
            # 更新（gitが利用可能な場合）
            if command -v git &> /dev/null && [[ -d "/opt/ready-to-study/.git" ]]; then
                cd /opt/ready-to-study
                sudo -u ready-to-study git pull
                sudo -u ready-to-study /opt/ready-to-study/venv/bin/pip install -r requirements.txt
            else
                log_warn "Gitリポジトリではありません。手動で更新してください"
            fi
            
            sudo systemctl start $SERVICE_NAME
            log_info "✅ 更新が完了しました"
        else
            log_error "アプリケーションがインストールされていません"
        fi
        ;;
    
    backup)
        log_info "データをバックアップしています..."
        BACKUP_DIR="/var/backups/ready-to-study/$(date +%Y%m%d_%H%M%S)"
        sudo mkdir -p $BACKUP_DIR
        
        if [[ -f "/opt/ready-to-study/data/study_app.db" ]]; then
            sudo cp /opt/ready-to-study/data/study_app.db $BACKUP_DIR/
            log_info "✅ データベースをバックアップしました: $BACKUP_DIR"
        fi
        
        sudo cp /opt/ready-to-study/.env $BACKUP_DIR/ 2>/dev/null || true
        log_info "✅ バックアップが完了しました: $BACKUP_DIR"
        ;;
    
    help|--help|-h)
        show_help
        ;;
    
    "")
        show_status
        echo ""
        echo "💡 詳細なコマンドについては: $0 help"
        ;;
    
    *)
        log_error "不明なコマンド: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
