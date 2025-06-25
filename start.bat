@echo off
chcp 65001 > nul

echo 🚀 Ready to Study を起動しています...

REM 依存関係のチェック
echo 📦 依存関係をチェックしています...
python -c "import streamlit" 2>nul
if errorlevel 1 (
    echo ❌ Streamlitがインストールされていません。
    echo 💡 次のコマンドでインストールしてください: pip install -r requirements.txt
    pause
    exit /b 1
)

REM データベースの初期化
echo 🗄️  データベースを初期化しています...
python scripts\init_database.py

REM アプリケーションの起動
echo ✨ アプリケーションを起動します...
echo 🌐 ブラウザで http://localhost:8501 を開いてください
echo.

streamlit run app.py --server.port 8501
