#!/bin/bash

# Nginx設定スクリプト

set -e

echo "🌐 Nginxを設定しています..."

# root権限チェック
if [[ $EUID -ne 0 ]]; then
   echo "このスクリプトはroot権限で実行してください"
   exit 1
fi

# Nginxのインストール確認
if ! command -v nginx &> /dev/null; then
    echo "📦 Nginxをインストールしています..."
    zypper install -y nginx
fi

# Nginx設定ディレクトリの作成
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

# 設定ファイルのコピー
echo "📄 Nginx設定ファイルをコピーしています..."
cp /opt/ready-to-study/deployment/nginx-ready-to-study.conf /etc/nginx/sites-available/ready-to-study

# シンボリックリンクの作成
ln -sf /etc/nginx/sites-available/ready-to-study /etc/nginx/sites-enabled/

# メインのnginx.confの更新
echo "⚙️ メインのnginx.confを更新しています..."
if ! grep -q "include /etc/nginx/sites-enabled/" /etc/nginx/nginx.conf; then
    sed -i '/http {/a\    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
fi

# 設定テスト
echo "🧪 Nginx設定をテストしています..."
nginx -t

# Nginxの有効化と開始
echo "🚀 Nginxを有効化しています..."
systemctl enable nginx
systemctl restart nginx

# ファイアウォール設定（SuSEFirewall2またはfirewalld）
echo "🔥 ファイアウォール設定を更新しています..."
if command -v firewall-cmd &> /dev/null; then
    # firewalld
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
elif command -v SuSEfirewall2 &> /dev/null; then
    # SuSEFirewall2
    echo "FW_SERVICES_EXT_TCP=\"22 80 443\"" >> /etc/sysconfig/SuSEfirewall2
    SuSEfirewall2 restart
fi

echo ""
echo "✅ Nginx設定が完了しました！"
echo ""
echo "📝 次のステップ:"
echo "1. ドメイン名を設定: /etc/nginx/sites-available/ready-to-study を編集"
echo "2. SSL証明書の設定: ./setup-ssl.sh を実行"
echo "3. DNS設定: ドメインがサーバーのIPアドレスを指すように設定"
echo ""
echo "管理コマンド:"
echo "• 設定テスト: sudo nginx -t"
echo "• リロード: sudo systemctl reload nginx"
echo "• 再起動: sudo systemctl restart nginx"
echo "• ログ確認: sudo tail -f /var/log/nginx/ready-to-study.access.log"
