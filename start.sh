#!/bin/bash

# Ready to Study アプリケーション起動スクリプト

echo "🚀 Ready to Study を起動しています..."

# 仮想環境をチェック
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "✅ 仮想環境が有効です: $VIRTUAL_ENV"
else
    echo "⚠️  仮想環境が検出されません。venvの作成をお勧めします。"
fi

# 依存関係のチェック
echo "📦 依存関係をチェックしています..."
python -c "import streamlit" 2>/dev/null || {
    echo "❌ Streamlitがインストールされていません。"
    echo "💡 次のコマンドでインストールしてください: pip install -r requirements.txt"
    exit 1
}

# データベースの初期化
echo "🗄️  データベースを初期化しています..."
python scripts/init_database.py

# アプリケーションの起動
echo "✨ アプリケーションを起動します..."
echo "🌐 ブラウザで http://localhost:8501 を開いてください"
echo ""

streamlit run app.py --server.port 8501
