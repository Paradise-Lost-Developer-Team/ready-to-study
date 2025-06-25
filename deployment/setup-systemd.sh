#!/bin/bash

# systemdサービス設定スクリプト

set -e

echo "🔧 systemdサービスを設定しています..."

# root権限チェック
if [[ $EUID -ne 0 ]]; then
   echo "このスクリプトはroot権限で実行してください"
   exit 1
fi

# Python仮想環境の作成（アプリケーション用）
echo "📦 アプリケーション用仮想環境を作成しています..."
sudo -u ready-to-study python3 -m venv /opt/ready-to-study/venv
sudo -u ready-to-study /opt/ready-to-study/venv/bin/pip install --upgrade pip
sudo -u ready-to-study /opt/ready-to-study/venv/bin/pip install -r /opt/ready-to-study/requirements.txt
sudo -u ready-to-study /opt/ready-to-study/venv/bin/pip install psycopg2-binary

# systemdサービスファイルのコピー
echo "📄 systemdサービスファイルを設定しています..."
cp /opt/ready-to-study/deployment/ready-to-study.service /etc/systemd/system/

# systemdリロード
systemctl daemon-reload

# サービスの有効化と開始
echo "🚀 サービスを有効化しています..."
systemctl enable ready-to-study
systemctl start ready-to-study

# ステータス確認
echo "📊 サービスの状態:"
systemctl status ready-to-study --no-pager

echo ""
echo "✅ systemdサービスの設定が完了しました！"
echo ""
echo "サービス管理コマンド:"
echo "• 開始: sudo systemctl start ready-to-study"
echo "• 停止: sudo systemctl stop ready-to-study"
echo "• 再起動: sudo systemctl restart ready-to-study"
echo "• 状態確認: sudo systemctl status ready-to-study"
echo "• ログ確認: sudo journalctl -u ready-to-study -f"
