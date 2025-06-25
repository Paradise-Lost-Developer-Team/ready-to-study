# Ready to Study - Dockerfile (オプション: Docker環境用)

FROM opensuse/leap:15.5

# メンテナ情報
LABEL maintainer="your-email@example.com"
LABEL description="Ready to Study - 高校生学習支援アプリ"

# 環境変数
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV APP_HOME=/app

# 必要なパッケージのインストール
RUN zypper refresh && \
    zypper install -y \
        python3 \
        python3-pip \
        python3-venv \
        postgresql \
        curl \
        && zypper clean -a

# アプリケーション用ユーザー作成
RUN useradd -r -s /bin/false -d $APP_HOME appuser

# 作業ディレクトリ設定
WORKDIR $APP_HOME

# 依存関係ファイルのコピー
COPY requirements.txt deployment/requirements-production.txt ./

# Python仮想環境の作成と依存関係のインストール
RUN python3 -m venv venv && \
    . venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements-production.txt

# アプリケーションファイルのコピー
COPY . .

# ディレクトリの権限設定
RUN mkdir -p data logs && \
    chown -R appuser:appuser $APP_HOME

# ポート公開
EXPOSE 8501

# ユーザー切り替え
USER appuser

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8501 || exit 1

# アプリケーション起動
CMD ["./venv/bin/streamlit", "run", "app.py", "--server.address", "0.0.0.0", "--server.port", "8501", "--server.headless", "true"]
