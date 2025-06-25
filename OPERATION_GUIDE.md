# Ready to Study 運用ガイド

## 📋 概要
このガイドは、openSUSE Leapサーバーで「Ready to Study」アプリを運用する管理者向けの手順書です。

## 🚀 初回セットアップ

### 1. 基本セットアップ
```bash
# リポジトリをクローン
git clone https://github.com/yourusername/ready-to-study.git
cd ready-to-study

# スクリプトに実行権限を付与
chmod +x *.sh

# openSUSE環境のセットアップ
sudo ./deployment/setup-opensuse.sh

# Python環境の構築（推奨：Python 3.8）
sudo ./fix-python-env-v2.sh

# systemdサービスの設定・起動
sudo ./install-autostart-service.sh
```

### 2. 動作確認
```bash
# サービス状態確認
sudo systemctl status ready-to-study

# アプリアクセス確認
curl http://localhost:8501

# ブラウザでアクセス
# http://[サーバーIP]:8501
```

## 🔧 日常運用

### サービス管理
```bash
# サービス状態確認
sudo systemctl status ready-to-study

# サービス開始
sudo systemctl start ready-to-study

# サービス停止
sudo systemctl stop ready-to-study

# サービス再起動
sudo systemctl restart ready-to-study

# 自動起動の有効化/無効化
sudo systemctl enable ready-to-study
sudo systemctl disable ready-to-study
```

### ログ確認
```bash
# リアルタイムログ監視
sudo journalctl -u ready-to-study -f

# 過去1時間のログ
sudo journalctl -u ready-to-study --since "1 hour ago"

# エラーログのみ
sudo journalctl -u ready-to-study -p err
```

## 🚨 トラブルシューティング

### 1. 基本診断
```bash
# 総合健康チェック
sudo ./health-check.sh

# サービス詳細デバッグ
sudo ./service-debug.sh

# システム診断
sudo ./server-diagnosis.sh
```

### 2. よくある問題と解決策

#### サービスが起動しない
```bash
# Python環境を修復
sudo ./fix-python-env-v2.sh

# サービスを再インストール
sudo ./install-autostart-service.sh

# 権限を修正
sudo ./set-permissions.sh
```

#### ポート8501にアクセスできない
```bash
# ファイアウォール確認・設定
sudo firewall-cmd --list-ports
sudo firewall-cmd --add-port=8501/tcp --permanent
sudo firewall-cmd --reload

# プロセス確認
sudo netstat -tlnp | grep :8501
```

#### Python 3.13互換性エラー
```bash
# Python 3.8への修復
sudo ./fix-python313-issue.sh
```

### 3. クイック修復
```bash
# 対話式修復メニュー
sudo ./quick-fix.sh

# 選択肢:
# 1. Pythonバージョン問題修復
# 2. 依存関係再インストール
# 3. サービス設定修復
# 4. 権限問題修復
# 5. ファイアウォール設定
# 6. Python 3.13互換性問題修復
```

## 📊 監視とメンテナンス

### システム監視
```bash
# リソース使用量確認
sudo systemctl status ready-to-study
sudo top -p $(pgrep -f streamlit)

# ディスク使用量
du -sh /opt/ready-to-study
df -h /opt/ready-to-study

# メモリ使用量
sudo systemctl show ready-to-study --property=MemoryCurrent
```

### 定期メンテナンス
```bash
# 週次
sudo ./health-check.sh

# 月次
sudo ./server-diagnosis.sh
sudo zypper update

# バックアップ（必要に応じて）
sudo tar -czf /var/backups/ready-to-study-$(date +%Y%m%d).tar.gz /opt/ready-to-study
```

## 🔐 セキュリティ

### SSL/HTTPS設定（本番環境推奨）
```bash
# Nginx + SSL設定
sudo ./deployment/setup-nginx.sh
sudo ./deployment/setup-ssl.sh
```

### ファイアウォール設定
```bash
# 基本設定
sudo firewall-cmd --add-port=8501/tcp --permanent

# HTTPS（SSL使用時）
sudo firewall-cmd --add-port=443/tcp --permanent
sudo firewall-cmd --reload
```

## 📈 パフォーマンス調整

### リソース制限の変更
```bash
# サービスファイル編集
sudo systemctl edit ready-to-study

# 追加する設定例:
[Service]
MemoryMax=4G
CPUQuota=300%
```

### Streamlit設定の最適化
```bash
# ~/.streamlit/config.toml の作成
sudo mkdir -p /home/ready-to-study/.streamlit
sudo cat > /home/ready-to-study/.streamlit/config.toml << 'EOF'
[server]
maxUploadSize = 200
enableCORS = false
enableXsrfProtection = false

[theme]
primaryColor = "#1f77b4"
backgroundColor = "#ffffff"
secondaryBackgroundColor = "#f0f2f6"
textColor = "#262730"
EOF
sudo chown -R ready-to-study:ready-to-study /home/ready-to-study/.streamlit
```

## 🆘 緊急時対応

### サービス完全停止
```bash
sudo systemctl stop ready-to-study
sudo systemctl disable ready-to-study
sudo pkill -f streamlit
```

### 緊急復旧
```bash
# 1. サービス停止
sudo systemctl stop ready-to-study

# 2. 仮想環境完全再構築
sudo rm -rf /opt/ready-to-study/venv
sudo ./fix-python-env-v2.sh

# 3. サービス再起動
sudo systemctl start ready-to-study
```

### ロールバック
```bash
# 設定ファイルのバックアップから復元
sudo cp /var/backups/ready-to-study-YYYYMMDD.tar.gz /tmp/
cd /tmp
sudo tar -xzf ready-to-study-YYYYMMDD.tar.gz
sudo cp -r opt/ready-to-study/* /opt/ready-to-study/
sudo systemctl restart ready-to-study
```

## 📞 サポート

### ログ収集（サポート依頼時）
```bash
# 診断情報の収集
sudo ./server-diagnosis.sh > diagnosis-$(date +%Y%m%d).log 2>&1
sudo journalctl -u ready-to-study --since "24 hours ago" > service-logs-$(date +%Y%m%d).log
```

### 連絡先
- GitHub Issues: https://github.com/yourusername/ready-to-study/issues
- 技術サポート: support@ready-to-study.example.com
- 緊急時連絡先: emergency@ready-to-study.example.com

## 📝 変更履歴

| 日付 | バージョン | 変更内容 |
|------|------------|----------|
| 2024-01-XX | 1.0.0 | 初回リリース |
| 2024-01-XX | 1.0.1 | Python 3.8最適化、診断機能強化 |

---

**注意**: このガイドは openSUSE Leap 15.x 環境を想定しています。他のディストリビューションでは一部コマンドが異なる場合があります。
