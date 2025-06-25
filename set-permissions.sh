#!/bin/bash

# ファイル権限設定スクリプト

echo "🔧 ファイル権限を設定しています..."

# スクリプトファイルに実行権限を設定
chmod +x server-setup.sh
chmod +x start.sh
chmod +x deployment/*.sh

# Pythonファイルは読み取り可能に設定
chmod 644 *.py
chmod 644 src/**/*.py

# 設定ファイルのセキュリティ設定
chmod 600 .env
chmod 600 deployment/.env.production

# データディレクトリの作成と権限設定
mkdir -p data
mkdir -p logs
chmod 755 data
chmod 755 logs

echo "✅ ファイル権限の設定が完了しました！"

echo ""
echo "📋 実行可能なスクリプト:"
echo "• ./server-setup.sh        - サーバー全体セットアップ"
echo "• ./start.sh              - ローカル開発環境での起動"
echo "• ./deployment/deploy.sh   - 本番環境完全デプロイ"
echo ""
echo "🚀 次のステップ:"
echo "ローカル開発: ./start.sh"
echo "サーバー設置: ./server-setup.sh"
