# Ready to Study - openSUSE Leap サーバーセットアップガイド

## 🚀 クイックスタート

### 1. システム要件
- openSUSE Leap 15.4以上
- RAM: 2GB以上（推奨: 4GB）
- ディスク容量: 10GB以上
- ネットワーク接続

### 2. 自動セットアップ（推奨）

```bash
# 1. リポジトリをクローン
git clone https://github.com/yourusername/ready-to-study.git
cd ready-to-study

# 2. 実行権限を設定
chmod +x server-setup.sh

# 3. セットアップスクリプトを実行
./server-setup.sh
```

### 3. 手動セットアップ

#### ステップ1: 基本パッケージのインストール
```bash
sudo zypper refresh
sudo zypper update -y
sudo zypper install -y python3 python3-pip python3-venv postgresql nginx git
```

#### ステップ2: アプリケーションセットアップ
```bash
# 実行権限を設定
chmod +x deployment/*.sh

# openSUSE用セットアップ
./deployment/setup-opensuse.sh
```

#### ステップ3: サービス設定
```bash
# systemdサービス設定
sudo ./deployment/setup-systemd.sh

# Nginx設定
sudo ./deployment/setup-nginx.sh

# SSL証明書設定（オプション）
sudo ./deployment/setup-ssl.sh
```

#### ステップ4: データベース初期化
```bash
sudo -u ready-to-study python3 /opt/ready-to-study/scripts/init_database.py
```

### 4. Dockerセットアップ（代替方法）

```bash
# Dockerのインストール
sudo zypper install -y docker docker-compose
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# ログアウト/ログインまたは
newgrp docker

# Docker Composeで起動
cd deployment
docker-compose up -d
```

### 5. アクセス確認

```bash
# サービス状態確認
sudo systemctl status ready-to-study

# ログ確認
sudo journalctl -u ready-to-study -f

# ポート確認
sudo netstat -tlnp | grep 8501
```

### 6. ブラウザでアクセス
- HTTP: `http://[サーバーIP]:8501`
- HTTPS: `https://[ドメイン名]`（SSL設定後）

## 🔧 管理コマンド

### サービス管理
```bash
# 開始
sudo systemctl start ready-to-study

# 停止
sudo systemctl stop ready-to-study

# 再起動
sudo systemctl restart ready-to-study

# 自動起動有効化
sudo systemctl enable ready-to-study
```

### ログ確認
```bash
# リアルタイムログ
sudo journalctl -u ready-to-study -f

# 過去のログ
sudo journalctl -u ready-to-study --since "1 hour ago"
```

### バックアップ
```bash
# データベースバックアップ
./deployment/backup.sh

# 設定ファイルバックアップ
sudo cp /opt/ready-to-study/.env /var/backups/ready-to-study/
```

### 監視
```bash
# システム状態監視
./deployment/monitor.sh

# リソース使用量確認
htop
df -h
free -h
```

## 🔒 セキュリティ設定

### ファイアウォール
```bash
# firewalldの設定
sudo systemctl enable firewalld
sudo systemctl start firewalld

# HTTPSポートを開放
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### SSL証明書（Let's Encrypt）
```bash
# SSL設定スクリプトを実行
sudo ./deployment/setup-ssl.sh
```

## 📁 重要なファイルとディレクトリ

```
/opt/ready-to-study/          # アプリケーション本体
├── app.py                    # メインアプリケーション
├── data/                     # データベースファイル
├── .env                      # 環境設定
└── venv/                     # Python仮想環境

/etc/systemd/system/          # systemdサービス
└── ready-to-study.service    # サービス設定

/etc/nginx/                   # Nginx設定
└── sites-available/ready-to-study

/var/log/ready-to-study/      # ログファイル
/var/backups/ready-to-study/  # バックアップ
```

## 🆘 トラブルシューティング

### アプリケーションが起動しない
```bash
# サービス状態確認
sudo systemctl status ready-to-study

# 詳細ログ確認
sudo journalctl -u ready-to-study --no-pager

# 設定ファイル確認
sudo cat /opt/ready-to-study/.env
```

### データベース接続エラー
```bash
# PostgreSQL状態確認
sudo systemctl status postgresql

# データベース接続テスト
sudo -u postgres psql -c "\l"
```

### ポートエラー
```bash
# ポート使用状況確認
sudo netstat -tlnp | grep 8501

# プロセス強制終了
sudo pkill -f streamlit
```

### 権限エラー
```bash
# ファイル権限修正
sudo chown -R ready-to-study:ready-to-study /opt/ready-to-study
sudo chmod -R 755 /opt/ready-to-study
```

## 📊 性能最適化

### リソース制限調整
```bash
# systemdサービス設定編集
sudo systemctl edit ready-to-study
```

### データベース最適化
```bash
# PostgreSQL設定調整
sudo nano /var/lib/pgsql/data/postgresql.conf
```

### Nginx設定最適化
```bash
# worker_processes設定
sudo nano /etc/nginx/nginx.conf
```

## 🔄 アップデート手順

```bash
# アプリケーション停止
sudo systemctl stop ready-to-study

# バックアップ作成
./deployment/backup.sh

# 新しいコードを取得
git pull origin main

# 依存関係更新
sudo -u ready-to-study /opt/ready-to-study/venv/bin/pip install -r requirements.txt

# アプリケーション再起動
sudo systemctl start ready-to-study
```
