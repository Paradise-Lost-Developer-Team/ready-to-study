#!/bin/bash

# SSL証明書設定スクリプト（Let's Encrypt使用）

set -e

echo "🔒 SSL証明書を設定しています..."

# root権限チェック
if [[ $EUID -ne 0 ]]; then
   echo "このスクリプトはroot権限で実行してください"
   exit 1
fi

# ドメイン名の入力
read -p "ドメイン名を入力してください（例: example.com）: " DOMAIN
read -p "メールアドレスを入力してください: " EMAIL

if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
    echo "❌ ドメイン名とメールアドレスは必須です"
    exit 1
fi

# certbotのインストール
echo "📦 certbotをインストールしています..."
zypper install -y python3-certbot python3-certbot-nginx

# Let's Encrypt証明書の取得
echo "🔐 Let's Encrypt証明書を取得しています..."
certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive

# 自動更新の設定
echo "⏰ 証明書の自動更新を設定しています..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

# Nginxの再起動
systemctl restart nginx

# SSL設定のテスト
echo "🧪 SSL設定をテストしています..."
sleep 5
curl -I -s "https://$DOMAIN" | head -1

echo ""
echo "✅ SSL証明書の設定が完了しました！"
echo ""
echo "🌐 アプリケーションURL: https://$DOMAIN"
echo ""
echo "証明書管理コマンド:"
echo "• 証明書情報確認: sudo certbot certificates"
echo "• 手動更新: sudo certbot renew"
echo "• 更新テスト: sudo certbot renew --dry-run"
