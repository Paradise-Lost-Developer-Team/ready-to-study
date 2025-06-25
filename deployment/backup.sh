#!/bin/bash

# データベースバックアップスクリプト

set -e

# 設定
BACKUP_DIR="/var/backups/ready-to-study"
DB_NAME="ready_to_study_db"
DB_USER="ready_to_study"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/ready_to_study_backup_$DATE.sql"

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /var/log/ready-to-study/backup.log
    echo "$1"
}

# バックアップディレクトリの作成
mkdir -p "$BACKUP_DIR"

log "🗄️ データベースバックアップを開始します..."

# PostgreSQLバックアップ
export PGPASSWORD="password"
if pg_dump -h localhost -U "$DB_USER" -d "$DB_NAME" > "$BACKUP_FILE"; then
    log "✅ バックアップが完了しました: $BACKUP_FILE"
    
    # 圧縮
    gzip "$BACKUP_FILE"
    log "🗜️ バックアップファイルを圧縮しました: $BACKUP_FILE.gz"
    
    # 古いバックアップの削除
    find "$BACKUP_DIR" -name "ready_to_study_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete
    log "🧹 ${RETENTION_DAYS}日以上前のバックアップファイルを削除しました"
    
    # バックアップファイル一覧
    BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/ready_to_study_backup_*.sql.gz | wc -l)
    log "📊 現在のバックアップファイル数: $BACKUP_COUNT"
    
else
    log "❌ バックアップに失敗しました"
    exit 1
fi

# アプリケーションファイルのバックアップ（任意）
APP_BACKUP_FILE="$BACKUP_DIR/app_files_$DATE.tar.gz"
if tar -czf "$APP_BACKUP_FILE" -C /opt ready-to-study --exclude="*.log" --exclude="__pycache__" --exclude=".git"; then
    log "📦 アプリケーションファイルのバックアップが完了しました: $APP_BACKUP_FILE"
else
    log "⚠️ アプリケーションファイルのバックアップに失敗しました"
fi

log "🎉 バックアップ処理が完了しました"
