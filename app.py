"""
Ready to Study - 高校生学習支援アプリ
メインアプリケーションファイル
"""

import streamlit as st
from datetime import datetime
import sys
import os

# プロジェクトルートをパスに追加
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from src.views.dashboard import show_dashboard
from src.views.subjects import show_subjects
from src.views.schedule import show_schedule
from src.views.progress import show_progress
from src.views.settings import show_settings
from src.controllers.database import init_database
from src.models.user import User

# ページ設定
st.set_page_config(
    page_title="Ready to Study",
    page_icon="📚",
    layout="wide",
    initial_sidebar_state="expanded"
)

# カスタムCSS
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        color: #1f77b4;
        text-align: center;
        margin-bottom: 2rem;
        font-weight: bold;
    }
    .sidebar-content {
        padding: 1rem 0;
    }
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        margin: 0.5rem 0;
    }
</style>
""", unsafe_allow_html=True)

def main():
    """メインアプリケーション"""
    
    # データベース初期化
    init_database()
    
    # サイドバー
    with st.sidebar:
        st.markdown('<div class="sidebar-content">', unsafe_allow_html=True)
        st.title("📚 Ready to Study")
        st.markdown("---")
        
        # ナビゲーション
        page = st.selectbox(
            "ページを選択",
            ["ダッシュボード", "教科学習", "スケジュール", "進捗管理", "設定"],
            index=0
        )
        
        st.markdown("---")
        
        # 今日の情報
        today = datetime.now()
        st.write(f"📅 {today.strftime('%Y年%m月%d日')}")
        st.write(f"🕐 {today.strftime('%H:%M')}")
        
        st.markdown('</div>', unsafe_allow_html=True)
    
    # メインコンテンツ
    if page == "ダッシュボード":
        show_dashboard()
    elif page == "教科学習":
        show_subjects()
    elif page == "スケジュール":
        show_schedule()
    elif page == "進捗管理":
        show_progress()
    elif page == "設定":
        show_settings()

if __name__ == "__main__":
    main()
