"""
進捗管理ビュー
"""

import streamlit as st
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime, timedelta
from src.controllers.database import get_database

def show_progress():
    """進捗管理ページ"""
    st.markdown('<h1 class="main-header">📊 進捗管理</h1>', unsafe_allow_html=True)
    
    tab1, tab2, tab3 = st.tabs(["📈 学習分析", "🎯 目標設定", "📋 レポート"])
    
    with tab1:
        show_learning_analysis()
    
    with tab2:
        show_goal_setting()
    
    with tab3:
        show_reports()

def show_learning_analysis():
    """学習分析"""
    st.subheader("学習パターン分析")
    
    user_id = st.session_state.get('current_user_id', 1)
    db = get_database()
    
    # 期間選択
    col1, col2 = st.columns(2)
    with col1:
        period = st.selectbox("分析期間", ["過去1週間", "過去1ヶ月", "過去3ヶ月", "全期間"])
    
    # 期間の計算
    now = datetime.now()
    if period == "過去1週間":
        start_date = now - timedelta(days=7)
    elif period == "過去1ヶ月":
        start_date = now - timedelta(days=30)
    elif period == "過去3ヶ月":
        start_date = now - timedelta(days=90)
    else:
        start_date = datetime(2000, 1, 1)
    
    # 学習時間分析
    with db.get_connection() as conn:
        # 日別学習時間
        daily_query = """
            SELECT date(study_date) as date, SUM(duration_minutes) as total_minutes
            FROM study_sessions 
            WHERE user_id = ? AND study_date >= ?
            GROUP BY date(study_date)
            ORDER BY date
        """
        daily_df = pd.read_sql_query(daily_query, conn, params=(user_id, start_date))
        
        # 教科別学習時間
        subject_query = """
            SELECT s.name, s.category, SUM(ss.duration_minutes) as total_minutes
            FROM study_sessions ss
            JOIN subjects s ON ss.subject_id = s.id
            WHERE ss.user_id = ? AND ss.study_date >= ?
            GROUP BY s.id, s.name, s.category
            ORDER BY total_minutes DESC
        """
        subject_df = pd.read_sql_query(subject_query, conn, params=(user_id, start_date))
        
        # 時間帯別分析
        hourly_query = """
            SELECT strftime('%H', study_date) as hour, SUM(duration_minutes) as total_minutes
            FROM study_sessions 
            WHERE user_id = ? AND study_date >= ?
            GROUP BY strftime('%H', study_date)
            ORDER BY hour
        """
        hourly_df = pd.read_sql_query(hourly_query, conn, params=(user_id, start_date))
    
    # 学習時間推移グラフ
    if not daily_df.empty:
        st.subheader("📊 学習時間推移")
        daily_df['date'] = pd.to_datetime(daily_df['date'])
        daily_df['hours'] = daily_df['total_minutes'] / 60
        
        fig, ax = plt.subplots(figsize=(12, 4))
        ax.plot(daily_df['date'], daily_df['hours'], marker='o')
        ax.set_title('日別学習時間')
        ax.set_xlabel('日付')
        ax.set_ylabel('時間')
        ax.grid(True, alpha=0.3)
        plt.xticks(rotation=45)
        plt.tight_layout()
        st.pyplot(fig)
        
        # 統計情報
        col1, col2, col3, col4 = st.columns(4)
        with col1:
            st.metric("平均学習時間/日", f"{daily_df['hours'].mean():.1f}時間")
        with col2:
            st.metric("最大学習時間", f"{daily_df['hours'].max():.1f}時間")
        with col3:
            st.metric("総学習時間", f"{daily_df['hours'].sum():.1f}時間")
        with col4:
            st.metric("学習日数", f"{len(daily_df)}日")
    
    # 教科別分析
    if not subject_df.empty:
        st.subheader("📚 教科別学習時間")
        
        col1, col2 = st.columns(2)
        
        with col1:
            # 教科別棒グラフ
            fig, ax = plt.subplots(figsize=(8, 6))
            subject_df['hours'] = subject_df['total_minutes'] / 60
            bars = ax.barh(subject_df['name'], subject_df['hours'])
            ax.set_title('教科別学習時間')
            ax.set_xlabel('時間')
            
            # カテゴリ別色分け
            colors = {'数学': 'blue', '国語': 'red', '英語': 'green', '理科': 'orange', '社会': 'purple', '情報': 'brown', 'その他': 'gray'}
            for i, bar in enumerate(bars):
                category = subject_df.iloc[i]['category']
                bar.set_color(colors.get(category, 'gray'))
            
            plt.tight_layout()
            st.pyplot(fig)
        
        with col2:
            # カテゴリ別円グラフ
            category_df = subject_df.groupby('category')['total_minutes'].sum().reset_index()
            
            if len(category_df) > 1:
                fig, ax = plt.subplots(figsize=(6, 6))
                ax.pie(category_df['total_minutes'], labels=category_df['category'], autopct='%1.1f%%')
                ax.set_title('教科カテゴリ別割合')
                plt.tight_layout()
                st.pyplot(fig)
    
    # 時間帯分析
    if not hourly_df.empty:
        st.subheader("🕐 時間帯別学習パターン")
        
        hourly_df['hour'] = hourly_df['hour'].astype(int)
        hourly_df['hours'] = hourly_df['total_minutes'] / 60
        
        fig, ax = plt.subplots(figsize=(12, 4))
        ax.bar(hourly_df['hour'], hourly_df['hours'])
        ax.set_title('時間帯別学習時間')
        ax.set_xlabel('時間')
        ax.set_ylabel('学習時間(時間)')
        ax.set_xticks(range(24))
        plt.tight_layout()
        st.pyplot(fig)
        
        # 最も活発な時間帯
        peak_hour = hourly_df.loc[hourly_df['hours'].idxmax(), 'hour']
        st.info(f"💡 最も学習が活発な時間帯: {peak_hour}時台")

def show_goal_setting():
    """目標設定"""
    st.subheader("学習目標設定")
    
    # 現在の目標表示
    if 'learning_goals' not in st.session_state:
        st.session_state.learning_goals = {
            'weekly_hours': 20,
            'daily_hours': 3,
            'subjects_per_week': 5
        }
    
    goals = st.session_state.learning_goals
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("📋 現在の目標")
        st.write(f"🎯 週間学習時間: {goals['weekly_hours']}時間")
        st.write(f"📅 1日の学習時間: {goals['daily_hours']}時間")
        st.write(f"📚 週間学習科目数: {goals['subjects_per_week']}科目")
    
    with col2:
        st.subheader("✏️ 目標編集")
        
        with st.form("goal_setting_form"):
            new_weekly = st.number_input("週間学習時間（時間）", min_value=1, max_value=100, value=goals['weekly_hours'])
            new_daily = st.number_input("1日の学習時間（時間）", min_value=0.5, max_value=12.0, value=goals['daily_hours'], step=0.5)
            new_subjects = st.number_input("週間学習科目数", min_value=1, max_value=15, value=goals['subjects_per_week'])
            
            if st.form_submit_button("目標を更新"):
                st.session_state.learning_goals = {
                    'weekly_hours': new_weekly,
                    'daily_hours': new_daily,
                    'subjects_per_week': new_subjects
                }
                st.success("目標を更新しました！")
                st.rerun()
    
    # 目標達成状況
    st.subheader("🎖️ 目標達成状況")
    
    user_id = st.session_state.get('current_user_id', 1)
    db = get_database()
    
    # 今週の実績
    now = datetime.now()
    week_start = now - timedelta(days=now.weekday())
    
    with db.get_connection() as conn:
        cursor = conn.cursor()
        
        # 今週の学習時間
        cursor.execute("""
            SELECT COALESCE(SUM(duration_minutes), 0) / 60.0 as hours
            FROM study_sessions 
            WHERE user_id = ? AND study_date >= ?
        """, (user_id, week_start))
        weekly_actual = cursor.fetchone()[0]
        
        # 今日の学習時間
        cursor.execute("""
            SELECT COALESCE(SUM(duration_minutes), 0) / 60.0 as hours
            FROM study_sessions 
            WHERE user_id = ? AND date(study_date) = date('now')
        """, (user_id,))
        daily_actual = cursor.fetchone()[0]
        
        # 今週学習した科目数
        cursor.execute("""
            SELECT COUNT(DISTINCT subject_id)
            FROM study_sessions 
            WHERE user_id = ? AND study_date >= ?
        """, (user_id, week_start))
        subjects_actual = cursor.fetchone()[0]
    
    # 進捗表示
    col1, col2, col3 = st.columns(3)
    
    with col1:
        weekly_progress = min(weekly_actual / goals['weekly_hours'] * 100, 100)
        st.metric(
            "週間学習時間",
            f"{weekly_actual:.1f}h / {goals['weekly_hours']}h",
            f"{weekly_progress:.0f}%"
        )
        st.progress(weekly_progress / 100)
    
    with col2:
        daily_progress = min(daily_actual / goals['daily_hours'] * 100, 100)
        st.metric(
            "今日の学習時間", 
            f"{daily_actual:.1f}h / {goals['daily_hours']}h",
            f"{daily_progress:.0f}%"
        )
        st.progress(daily_progress / 100)
    
    with col3:
        subject_progress = min(subjects_actual / goals['subjects_per_week'] * 100, 100)
        st.metric(
            "週間学習科目数",
            f"{subjects_actual} / {goals['subjects_per_week']}科目",
            f"{subject_progress:.0f}%"
        )
        st.progress(subject_progress / 100)

def show_reports():
    """レポート"""
    st.subheader("学習レポート")
    
    # レポート期間選択
    report_period = st.selectbox("レポート期間", ["週次", "月次", "学期"])
    
    user_id = st.session_state.get('current_user_id', 1)
    db = get_database()
    
    if report_period == "週次":
        show_weekly_report(db, user_id)
    elif report_period == "月次":
        show_monthly_report(db, user_id)
    else:
        show_semester_report(db, user_id)

def show_weekly_report(db, user_id):
    """週次レポート"""
    st.write("### 📅 今週の学習レポート")
    
    now = datetime.now()
    week_start = now - timedelta(days=now.weekday())
    
    with db.get_connection() as conn:
        # 今週の総学習時間
        cursor = conn.cursor()
        cursor.execute("""
            SELECT 
                COALESCE(SUM(duration_minutes), 0) / 60.0 as total_hours,
                COUNT(*) as session_count,
                AVG(satisfaction_score) as avg_satisfaction
            FROM study_sessions 
            WHERE user_id = ? AND study_date >= ?
        """, (user_id, week_start))
        
        result = cursor.fetchone()
        total_hours, session_count, avg_satisfaction = result
        
        # 教科別時間
        cursor.execute("""
            SELECT s.name, SUM(ss.duration_minutes) / 60.0 as hours
            FROM study_sessions ss
            JOIN subjects s ON ss.subject_id = s.id
            WHERE ss.user_id = ? AND ss.study_date >= ?
            GROUP BY s.name
            ORDER BY hours DESC
        """, (user_id, week_start))
        
        subjects = cursor.fetchall()
    
    # サマリー
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("総学習時間", f"{total_hours:.1f}時間")
    with col2:
        st.metric("学習セッション数", f"{session_count}回")
    with col3:
        satisfaction = avg_satisfaction if avg_satisfaction else 0
        st.metric("平均満足度", f"{satisfaction:.1f}/5")
    
    # 教科別詳細
    if subjects:
        st.write("**教科別学習時間:**")
        for subject, hours in subjects:
            st.write(f"- {subject}: {hours:.1f}時間")
    
    # アドバイス
    st.write("### 💡 学習アドバイス")
    if total_hours >= 15:
        st.success("素晴らしい学習量です！この調子で継続しましょう。")
    elif total_hours >= 10:
        st.info("良い学習ペースです。もう少し時間を増やせるとより良いですね。")
    else:
        st.warning("学習時間が少し不足しています。毎日少しずつでも学習を継続しましょう。")

def show_monthly_report(db, user_id):
    """月次レポート"""
    st.write("### 📊 今月の学習レポート")
    st.info("月次レポート機能は準備中です。")

def show_semester_report(db, user_id):
    """学期レポート"""
    st.write("### 📈 学期学習レポート")
    st.info("学期レポート機能は準備中です。")
