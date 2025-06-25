"""
ダッシュボードビュー
"""

import streamlit as st
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime, timedelta
import sqlite3
from src.controllers.database import get_database

plt.rcParams['font.family'] = 'DejaVu Sans'
sns.set_palette("husl")

def show_dashboard():
    """ダッシュボードを表示"""
    st.markdown('<h1 class="main-header">📊 学習ダッシュボード</h1>', unsafe_allow_html=True)
    
    # デモユーザーの設定
    if 'current_user_id' not in st.session_state:
        st.session_state.current_user_id = 1
        create_demo_user()
    
    # 概要メトリクス
    show_overview_metrics()
    
    st.markdown("---")
    
    # 学習時間グラフと教科別進捗
    col1, col2 = st.columns(2)
    
    with col1:
        show_study_time_chart()
    
    with col2:
        show_subject_progress()
    
    st.markdown("---")
    
    # 最近の学習活動
    show_recent_activities()
    
    # 今日のタスク
    show_todays_tasks()

def create_demo_user():
    """デモユーザーとデータを作成"""
    db = get_database()
    with db.get_connection() as conn:
        cursor = conn.cursor()
        
        # ユーザーが存在しない場合は作成
        cursor.execute("SELECT COUNT(*) FROM users WHERE id = 1")
        if cursor.fetchone()[0] == 0:
            cursor.execute(
                "INSERT INTO users (id, name, email, grade) VALUES (1, 'デモ太郎', 'demo@example.com', 2)"
            )
            
            # デモ学習セッションデータ
            demo_sessions = [
                (1, 1, 60, "二次関数の学習", 4, datetime.now() - timedelta(days=1)),
                (1, 5, 45, "英語長文読解", 3, datetime.now() - timedelta(days=2)),
                (1, 3, 90, "古文の助動詞", 5, datetime.now() - timedelta(days=3)),
                (1, 10, 30, "化学結合", 4, datetime.now() - timedelta(days=4)),
                (1, 1, 75, "数学I復習", 4, datetime.now()),
            ]
            
            for session in demo_sessions:
                cursor.execute("""
                    INSERT INTO study_sessions 
                    (user_id, subject_id, duration_minutes, content, satisfaction_score, study_date)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, session)
            
            conn.commit()

def show_overview_metrics():
    """概要メトリクスを表示"""
    db = get_database()
    
    with db.get_connection() as conn:
        # 今週の学習時間
        cursor = conn.cursor()
        cursor.execute("""
            SELECT COALESCE(SUM(duration_minutes), 0) as total_minutes
            FROM study_sessions 
            WHERE user_id = ? AND study_date >= date('now', '-7 days')
        """, (st.session_state.current_user_id,))
        
        weekly_minutes = cursor.fetchone()[0]
        weekly_hours = weekly_minutes / 60
        
        # 今月の学習日数
        cursor.execute("""
            SELECT COUNT(DISTINCT date(study_date)) as study_days
            FROM study_sessions 
            WHERE user_id = ? AND study_date >= date('now', 'start of month')
        """, (st.session_state.current_user_id,))
        
        monthly_days = cursor.fetchone()[0]
        
        # 完了したクイズ数
        cursor.execute("""
            SELECT COUNT(*) as quiz_count
            FROM quiz_results 
            WHERE user_id = ? AND attempted_at >= date('now', '-30 days')
        """, (st.session_state.current_user_id,))
        
        quiz_count = cursor.fetchone()[0] if cursor.fetchone() else 0
    
    # メトリクス表示
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric(
            label="📚 今週の学習時間",
            value=f"{weekly_hours:.1f}時間",
            delta=f"{weekly_minutes}分"
        )
    
    with col2:
        st.metric(
            label="📅 今月の学習日数",
            value=f"{monthly_days}日",
            delta="継続中" if monthly_days > 0 else "開始しよう"
        )
    
    with col3:
        st.metric(
            label="🎯 今月のクイズ",
            value=f"{quiz_count}問",
            delta="挑戦中"
        )
    
    with col4:
        target_hours = 20  # 週20時間目標
        progress = min(weekly_hours / target_hours * 100, 100)
        st.metric(
            label="🎖️ 週目標達成率",
            value=f"{progress:.0f}%",
            delta=f"目標: {target_hours}時間"
        )

def show_study_time_chart():
    """学習時間チャートを表示"""
    st.subheader("📈 最近の学習時間推移")
    
    db = get_database()
    with db.get_connection() as conn:
        query = """
            SELECT date(study_date) as study_date, 
                   SUM(duration_minutes) as total_minutes
            FROM study_sessions 
            WHERE user_id = ? AND study_date >= date('now', '-14 days')
            GROUP BY date(study_date)
            ORDER BY study_date
        """
        
        df = pd.read_sql_query(query, conn, params=(st.session_state.current_user_id,))
    
    if not df.empty:
        df['study_date'] = pd.to_datetime(df['study_date'])
        df['hours'] = df['total_minutes'] / 60
        
        fig, ax = plt.subplots(figsize=(10, 4))
        ax.plot(df['study_date'], df['hours'], marker='o', linewidth=2, markersize=6)
        ax.set_xlabel('日付')
        ax.set_ylabel('学習時間 (時間)')
        ax.set_title('過去14日間の学習時間')
        ax.grid(True, alpha=0.3)
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        st.pyplot(fig)
    else:
        st.info("学習データがありません。学習を記録してみましょう！")

def show_subject_progress():
    """教科別進捗を表示"""
    st.subheader("📊 教科別学習時間")
    
    db = get_database()
    with db.get_connection() as conn:
        query = """
            SELECT s.name, SUM(ss.duration_minutes) as total_minutes
            FROM study_sessions ss
            JOIN subjects s ON ss.subject_id = s.id
            WHERE ss.user_id = ? AND ss.study_date >= date('now', '-30 days')
            GROUP BY s.id, s.name
            ORDER BY total_minutes DESC
            LIMIT 8
        """
        
        df = pd.read_sql_query(query, conn, params=(st.session_state.current_user_id,))
    
    if not df.empty:
        df['hours'] = df['total_minutes'] / 60
        
        fig, ax = plt.subplots(figsize=(10, 4))
        bars = ax.barh(df['name'], df['hours'])
        ax.set_xlabel('学習時間 (時間)')
        ax.set_title('教科別学習時間 (過去30日)')
        
        # カラフルなバー
        colors = plt.cm.Set3(range(len(df)))
        for bar, color in zip(bars, colors):
            bar.set_color(color)
        
        plt.tight_layout()
        st.pyplot(fig)
    else:
        st.info("教科別データがありません。")

def show_recent_activities():
    """最近の学習活動を表示"""
    st.subheader("🕐 最近の学習活動")
    
    db = get_database()
    with db.get_connection() as conn:
        query = """
            SELECT s.name as subject, ss.content, ss.duration_minutes, 
                   ss.satisfaction_score, ss.study_date
            FROM study_sessions ss
            JOIN subjects s ON ss.subject_id = s.id
            WHERE ss.user_id = ?
            ORDER BY ss.study_date DESC
            LIMIT 5
        """
        
        df = pd.read_sql_query(query, conn, params=(st.session_state.current_user_id,))
    
    if not df.empty:
        for _, row in df.iterrows():
            with st.container():
                col1, col2, col3 = st.columns([2, 1, 1])
                
                with col1:
                    st.write(f"**{row['subject']}** - {row['content']}")
                
                with col2:
                    st.write(f"⏱️ {row['duration_minutes']}分")
                
                with col3:
                    stars = "⭐" * (row['satisfaction_score'] if row['satisfaction_score'] else 0)
                    st.write(f"{stars}")
                
                study_date = pd.to_datetime(row['study_date'])
                st.caption(f"📅 {study_date.strftime('%m/%d %H:%M')}")
                st.divider()
    else:
        st.info("学習記録がありません。")

def show_todays_tasks():
    """今日のタスクを表示"""
    st.subheader("✅ 今日のタスク")
    
    # 簡単なタスク例（実際はデータベースから取得）
    tasks = [
        {"task": "数学II: 三角関数の復習", "completed": False},
        {"task": "英語: 単語暗記 50個", "completed": True},
        {"task": "物理: 力学の問題演習", "completed": False},
        {"task": "古文: 助動詞の活用確認", "completed": False},
    ]
    
    for i, task in enumerate(tasks):
        col1, col2 = st.columns([0.1, 0.9])
        
        with col1:
            completed = st.checkbox("", value=task["completed"], key=f"task_{i}")
        
        with col2:
            if completed:
                st.write(f"~~{task['task']}~~")
            else:
                st.write(task['task'])
    
    # 新しいタスク追加
    with st.expander("新しいタスクを追加"):
        new_task = st.text_input("タスク内容")
        if st.button("追加") and new_task:
            st.success(f"タスク「{new_task}」を追加しました！")
            st.rerun()
