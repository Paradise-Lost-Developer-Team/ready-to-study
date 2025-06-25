#!/bin/bash

# Ready to Study - openSUSE Leap サーバーセットアップスクリプト

set -e

echo "🐧 Ready to Study - openSUSE Leap サーバーセットアップ"
echo "=================================================="

# 色付きログ関数
log_info() { echo -e "\033[32m[INFO]\033[0m $1"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

# ルート権限チェック
if [[ $EUID -eq 0 ]]; then
   log_error "このスクリプトはrootユーザーで実行しないでください"
   exit 1
fi

# システム情報の確認
log_info "システム情報を確認しています..."
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"

# 必要なパッケージのインストール
log_info "システムパッケージを更新しています..."
sudo zypper refresh
sudo zypper update -y

log_info "必要なパッケージをインストールしています..."
sudo zypper install -y \
    python3 \
    python3-pip \
    python3-venv \
    postgresql-server \
    postgresql \
    nginx \
    git \
    curl \
    wget \
    unzip \
    systemd

# Python仮想環境の作成
log_info "Python仮想環境を作成しています..."
python3 -m venv ~/ready-to-study-env
source ~/ready-to-study-env/bin/activate

# Pythonパッケージのインストール
log_info "Pythonパッケージをインストールしています..."
pip install --upgrade pip
pip install -r requirements.txt
pip install psycopg2-binary gunicorn

# PostgreSQLの設定
log_info "PostgreSQLを設定しています..."
sudo systemctl enable postgresql
sudo systemctl start postgresql

# データベースユーザーとデータベースの作成
sudo -u postgres psql << EOF
CREATE USER ready_to_study WITH PASSWORD 'password';
CREATE DATABASE ready_to_study_db OWNER ready_to_study;
GRANT ALL PRIVILEGES ON DATABASE ready_to_study_db TO ready_to_study;
\q
EOF

# アプリケーション用ユーザーの作成
log_info "アプリケーション用ユーザーを作成しています..."
sudo useradd -r -s /bin/false ready-to-study || true

# アプリケーションディレクトリの設定
APP_DIR="/opt/ready-to-study"
log_info "アプリケーションディレクトリを設定しています: $APP_DIR"

sudo mkdir -p $APP_DIR
sudo chown ready-to-study:ready-to-study $APP_DIR

# アプリケーションファイルのコピー
log_info "アプリケーションファイルをコピーしています..."
sudo cp -r . $APP_DIR/
sudo chown -R ready-to-study:ready-to-study $APP_DIR

# ログディレクトリの作成
sudo mkdir -p /var/log/ready-to-study
sudo chown ready-to-study:ready-to-study /var/log/ready-to-study

# バックアップディレクトリの作成
sudo mkdir -p /var/backups/ready-to-study
sudo chown ready-to-study:ready-to-study /var/backups/ready-to-study

# 環境設定ファイルのコピー
sudo cp deployment/.env.production $APP_DIR/.env
sudo chown ready-to-study:ready-to-study $APP_DIR/.env

log_info "✅ セットアップが完了しました！"
echo ""
echo "次のステップ:"
echo "1. systemdサービスの設定: sudo ./deployment/setup-systemd.sh"
echo "2. Nginxの設定: sudo ./deployment/setup-nginx.sh"
echo "3. SSL証明書の設定: sudo ./deployment/setup-ssl.sh"
echo "4. データベースの初期化: sudo -u ready-to-study python3 scripts/init_database.py"
