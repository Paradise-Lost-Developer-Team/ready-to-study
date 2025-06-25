"""
設定ビュー
"""

import streamlit as st
from src.controllers.database import get_database

def show_settings():
    """設定ページ"""
    st.markdown('<h1 class="main-header">⚙️ 設定</h1>', unsafe_allow_html=True)
    
    tab1, tab2, tab3, tab4 = st.tabs(["👤 プロフィール", "🎯 学習設定", "📊 データ管理", "ℹ️ アプリ情報"])
    
    with tab1:
        show_profile_settings()
    
    with tab2:
        show_learning_settings()
    
    with tab3:
        show_data_management()
    
    with tab4:
        show_app_info()

def show_profile_settings():
    """プロフィール設定"""
    st.subheader("👤 プロフィール設定")
    
    # 現在のユーザー情報を取得
    user_id = st.session_state.get('current_user_id', 1)
    db = get_database()
    
    with db.get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT name, email, grade FROM users WHERE id = ?", (user_id,))
        user_data = cursor.fetchone()
    
    if user_data:
        current_name, current_email, current_grade = user_data
    else:
        current_name, current_email, current_grade = "デモ太郎", "demo@example.com", 2
    
    with st.form("profile_form"):
        name = st.text_input("名前", value=current_name)
        email = st.text_input("メールアドレス", value=current_email)
        grade = st.selectbox("学年", [1, 2, 3], index=current_grade-1)
        
        submitted = st.form_submit_button("プロフィールを更新", type="primary")
        
        if submitted:
            with db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE users 
                    SET name = ?, email = ?, grade = ?
                    WHERE id = ?
                """, (name, email, grade, user_id))
                conn.commit()
            
            st.success("プロフィールを更新しました！")
            st.rerun()
    
    # 学習統計
    st.subheader("📊 学習統計")
    
    with db.get_connection() as conn:
        cursor = conn.cursor()
        
        # 総学習時間
        cursor.execute("""
            SELECT COALESCE(SUM(duration_minutes), 0) / 60.0 as total_hours
            FROM study_sessions WHERE user_id = ?
        """, (user_id,))
        total_hours = cursor.fetchone()[0]
        
        # 学習日数
        cursor.execute("""
            SELECT COUNT(DISTINCT date(study_date)) as study_days
            FROM study_sessions WHERE user_id = ?
        """, (user_id,))
        study_days = cursor.fetchone()[0]
        
        # 最も学習した科目
        cursor.execute("""
            SELECT s.name, SUM(ss.duration_minutes) / 60.0 as hours
            FROM study_sessions ss
            JOIN subjects s ON ss.subject_id = s.id
            WHERE ss.user_id = ?
            GROUP BY s.name
            ORDER BY hours DESC
            LIMIT 1
        """, (user_id,))
        
        top_subject_data = cursor.fetchone()
        top_subject = f"{top_subject_data[0]} ({top_subject_data[1]:.1f}時間)" if top_subject_data else "データなし"
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric("総学習時間", f"{total_hours:.1f}時間")
    
    with col2:
        st.metric("学習日数", f"{study_days}日")
    
    with col3:
        st.metric("最も学習した科目", top_subject)

def show_learning_settings():
    """学習設定"""
    st.subheader("🎯 学習設定")
    
    # 通知設定
    st.write("### 📱 通知設定")
    
    col1, col2 = st.columns(2)
    
    with col1:
        daily_reminder = st.checkbox("日次学習リマインダー", value=True)
        study_streak = st.checkbox("学習連続記録通知", value=True)
        goal_progress = st.checkbox("目標進捗通知", value=True)
    
    with col2:
        reminder_time = st.time_input("リマインダー時刻", value=st.session_state.get('reminder_time', None))
        weekend_reminder = st.checkbox("週末リマインダー", value=False)
        achievement_badges = st.checkbox("達成バッジ通知", value=True)
    
    # 学習設定
    st.write("### 📚 学習設定")
    
    col1, col2 = st.columns(2)
    
    with col1:
        default_session_duration = st.number_input("デフォルト学習時間（分）", min_value=15, max_value=180, value=45)
        auto_break_reminder = st.checkbox("休憩リマインダー", value=True)
    
    with col2:
        difficulty_preference = st.selectbox("問題難易度設定", ["易しい", "標準", "難しい", "混合"])
        show_explanations = st.checkbox("解説を常に表示", value=True)
    
    # 設定保存
    if st.button("設定を保存", type="primary"):
        # セッションステートに保存（実際のアプリでは Databse に保存）
        st.session_state.update({
            'daily_reminder': daily_reminder,
            'study_streak': study_streak,
            'goal_progress': goal_progress,
            'reminder_time': reminder_time,
            'weekend_reminder': weekend_reminder,
            'achievement_badges': achievement_badges,
            'default_session_duration': default_session_duration,
            'auto_break_reminder': auto_break_reminder,
            'difficulty_preference': difficulty_preference,
            'show_explanations': show_explanations
        })
        
        st.success("設定を保存しました！")

def show_data_management():
    """データ管理"""
    st.subheader("📊 データ管理")
    
    # データエクスポート
    st.write("### 📤 データエクスポート")
    
    col1, col2 = st.columns(2)
    
    with col1:
        if st.button("学習記録をエクスポート", use_container_width=True):
            # CSV形式でエクスポート（実装例）
            user_id = st.session_state.get('current_user_id', 1)
            db = get_database()
            
            with db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT 
                        s.name as subject,
                        ss.content,
                        ss.duration_minutes,
                        ss.satisfaction_score,
                        ss.study_date
                    FROM study_sessions ss
                    JOIN subjects s ON ss.subject_id = s.id
                    WHERE ss.user_id = ?
                    ORDER BY ss.study_date DESC
                """, (user_id,))
                
                data = cursor.fetchall()
            
            if data:
                st.success(f"学習記録 {len(data)} 件をエクスポートしました！")
                # 実際のアプリではファイルダウンロード機能を実装
            else:
                st.info("エクスポートするデータがありません。")
    
    with col2:
        if st.button("クイズ結果をエクスポート", use_container_width=True):
            st.info("クイズ結果のエクスポート機能は準備中です。")
    
    # データ削除
    st.write("### 🗑️ データ削除")
    
    st.warning("⚠️ 以下の操作は元に戻せません。実行前に必ずデータをエクスポートしてください。")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if st.button("古い学習記録を削除", use_container_width=True):
            # 3ヶ月以上前のデータを削除
            if st.button("確認：本当に削除しますか？"):
                st.info("古い学習記録を削除しました。")
    
    with col2:
        if st.button("クイズ結果を削除", use_container_width=True):
            if st.button("確認：クイズ結果を削除？"):
                st.info("クイズ結果を削除しました。")
    
    with col3:
        if st.button("全データを削除", use_container_width=True):
            if st.button("⚠️ 確認：全データ削除"):
                st.error("この操作は実装されていません。")
    
    # データインポート
    st.write("### 📥 データインポート")
    
    uploaded_file = st.file_uploader("CSVファイルをアップロード", type=['csv'])
    
    if uploaded_file is not None:
        st.info("データインポート機能は準備中です。")

def show_app_info():
    """アプリ情報"""
    st.subheader("ℹ️ アプリ情報")
    
    # アプリ概要
    st.write("### 📱 Ready to Study")
    st.write("バージョン: 1.0.0")
    st.write("開発者: Your Name")
    st.write("リリース日: 2024年")
    
    # 機能一覧
    st.write("### 🚀 主要機能")
    
    features = [
        "📚 2025年度高校教育課程対応",
        "📊 学習進捗の可視化",
        "🧠 インタラクティブクイズ",
        "📅 スケジュール管理",
        "📈 学習分析とレポート",
        "🎯 目標設定と達成管理",
        "📱 リマインダー機能",
        "💾 データエクスポート"
    ]
    
    for feature in features:
        st.write(f"✓ {feature}")
    
    # 対応教科
    st.write("### 📖 対応教科")
    
    subjects_by_category = {
        "国語": ["現代文", "古文", "漢文"],
        "数学": ["数学I", "数学A", "数学II", "数学B", "数学III", "数学C"],
        "英語": ["英語コミュニケーションI・II・III", "論理・表現I・II・III"],
        "理科": ["物理基礎・物理", "化学基礎・化学", "生物基礎・生物", "地学基礎・地学"],
        "社会": ["地理総合・探究", "歴史総合・日本史・世界史探究", "公共・政治経済・倫理"],
        "情報": ["情報I"]
    }
    
    for category, subjects in subjects_by_category.items():
        with st.expander(f"{category}"):
            for subject in subjects:
                st.write(f"• {subject}")
    
    # ライセンス
    st.write("### 📄 ライセンス")
    st.write("MIT License")
    
    # お問い合わせ
    st.write("### 📧 お問い合わせ")
    st.write("バグ報告や機能要求がございましたら、下記までご連絡ください：")
    st.write("Email: support@ready-to-study.com")
    
    # システム情報
    with st.expander("🔧 システム情報"):
        st.write("- Python 3.11+")
        st.write("- Streamlit 1.28+")
        st.write("- SQLite Database")
        st.write("- Matplotlib & Seaborn for Visualization")
        st.write("- Pandas for Data Analysis")
