"""
教科学習ビュー
"""

import streamlit as st
import json
from datetime import datetime
from src.controllers.database import get_database

def show_subjects():
    """教科学習ページを表示"""
    st.markdown('<h1 class="main-header">📚 教科学習</h1>', unsafe_allow_html=True)
    
    # サイドバーで教科選択
    with st.sidebar:
        st.subheader("教科選択")
        
        db = get_database()
        with db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT DISTINCT category FROM subjects ORDER BY category")
            categories = [row[0] for row in cursor.fetchall()]
        
        selected_category = st.selectbox("教科カテゴリ", categories)
        
        # 選択されたカテゴリの科目を取得
        with db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT id, name, description FROM subjects WHERE category = ? ORDER BY grade_level, name",
                (selected_category,)
            )
            subjects = cursor.fetchall()
        
        if subjects:
            subject_options = {f"{subject[1]}": subject[0] for subject in subjects}
            selected_subject_name = st.selectbox("科目選択", list(subject_options.keys()))
            selected_subject_id = subject_options[selected_subject_name]
        else:
            st.error("科目が見つかりません")
            return
    
    # メインコンテンツ
    tab1, tab2, tab3 = st.tabs(["📖 学習記録", "🧠 クイズ", "📊 進捗確認"])
    
    with tab1:
        show_study_recording(selected_subject_id, selected_subject_name)
    
    with tab2:
        show_quiz_section(selected_subject_id, selected_subject_name)
    
    with tab3:
        show_subject_progress_detail(selected_subject_id, selected_subject_name)

def show_study_recording(subject_id: int, subject_name: str):
    """学習記録セクション"""
    st.subheader(f"📝 {subject_name}の学習記録")
    
    with st.form("study_session_form"):
        col1, col2 = st.columns(2)
        
        with col1:
            duration = st.number_input("学習時間（分）", min_value=1, max_value=480, value=30)
            satisfaction = st.slider("満足度", min_value=1, max_value=5, value=3)
        
        with col2:
            content = st.text_area("学習内容", placeholder="今日学習した内容を記録しましょう...")
            study_date = st.date_input("学習日", value=datetime.now().date())
        
        submitted = st.form_submit_button("記録する", type="primary")
        
        if submitted and content:
            # データベースに記録
            if 'current_user_id' not in st.session_state:
                st.session_state.current_user_id = 1
            
            db = get_database()
            with db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO study_sessions 
                    (user_id, subject_id, duration_minutes, content, satisfaction_score, study_date)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, (
                    st.session_state.current_user_id,
                    subject_id,
                    duration,
                    content,
                    satisfaction,
                    datetime.combine(study_date, datetime.now().time())
                ))
                conn.commit()
            
            st.success("学習記録を保存しました！")
            st.rerun()
    
    # 最近の学習記録表示
    st.subheader("最近の学習記録")
    
    db = get_database()
    with db.get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT content, duration_minutes, satisfaction_score, study_date
            FROM study_sessions
            WHERE user_id = ? AND subject_id = ?
            ORDER BY study_date DESC
            LIMIT 10
        """, (st.session_state.get('current_user_id', 1), subject_id))
        
        records = cursor.fetchall()
    
    if records:
        for record in records:
            with st.expander(
                f"📅 {record[3][:10]} - {record[1]}分 - {'⭐' * record[2]}"
            ):
                st.write(record[0])
    else:
        st.info("まだ学習記録がありません。上のフォームから記録を始めましょう！")

def show_quiz_section(subject_id: int, subject_name: str):
    """クイズセクション"""
    st.subheader(f"🧠 {subject_name}のクイズ")
    
    # クイズ管理
    tab1, tab2 = st.tabs(["クイズ挑戦", "クイズ作成"])
    
    with tab1:
        show_quiz_challenge(subject_id, subject_name)
    
    with tab2:
        show_quiz_creation(subject_id, subject_name)

def show_quiz_challenge(subject_id: int, subject_name: str):
    """クイズ挑戦"""
    db = get_database()
    
    with db.get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, title, question, options, correct_answer, explanation, difficulty
            FROM quizzes 
            WHERE subject_id = ?
            ORDER BY RANDOM()
            LIMIT 1
        """, (subject_id,))
        
        quiz = cursor.fetchone()
    
    if quiz:
        quiz_id, title, question, options_json, correct_answer, explanation, difficulty = quiz
        
        st.write(f"**{title}**")
        st.write(f"難易度: {'⭐' * difficulty}")
        st.write(question)
        
        # 選択肢がある場合
        if options_json:
            try:
                options = json.loads(options_json)
                user_answer = st.radio("答えを選択してください:", options)
            except:
                user_answer = st.text_input("答えを入力してください:")
        else:
            user_answer = st.text_input("答えを入力してください:")
        
        if st.button("回答する", type="primary"):
            is_correct = str(user_answer).strip().lower() == str(correct_answer).strip().lower()
            
            # 結果をデータベースに保存
            with db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO quiz_results 
                    (user_id, quiz_id, user_answer, is_correct, attempted_at)
                    VALUES (?, ?, ?, ?, ?)
                """, (
                    st.session_state.get('current_user_id', 1),
                    quiz_id,
                    str(user_answer),
                    is_correct,
                    datetime.now()
                ))
                conn.commit()
            
            if is_correct:
                st.success("🎉 正解です！")
            else:
                st.error(f"❌ 不正解です。正解は: {correct_answer}")
            
            if explanation:
                st.info(f"💡 解説: {explanation}")
            
            if st.button("次の問題"):
                st.rerun()
    
    else:
        st.info("この科目のクイズがまだありません。クイズ作成タブから問題を追加してみましょう！")

def show_quiz_creation(subject_id: int, subject_name: str):
    """クイズ作成"""
    st.write("新しいクイズを作成しましょう")
    
    with st.form("quiz_creation_form"):
        title = st.text_input("クイズタイトル")
        question = st.text_area("問題文")
        
        # 選択肢タイプ
        question_type = st.radio("問題タイプ", ["選択式", "記述式"])
        
        if question_type == "選択式":
            st.write("選択肢を入力してください:")
            option1 = st.text_input("選択肢1")
            option2 = st.text_input("選択肢2")
            option3 = st.text_input("選択肢3", value="")
            option4 = st.text_input("選択肢4", value="")
            
            options = [opt for opt in [option1, option2, option3, option4] if opt.strip()]
            correct_answer = st.selectbox("正解", options if options else [""])
            
            options_json = json.dumps(options) if len(options) >= 2 else None
        else:
            options_json = None
            correct_answer = st.text_input("正解")
        
        explanation = st.text_area("解説（任意）")
        difficulty = st.slider("難易度", min_value=1, max_value=5, value=3)
        
        submitted = st.form_submit_button("クイズを作成", type="primary")
        
        if submitted and title and question and correct_answer:
            db = get_database()
            with db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO quizzes 
                    (subject_id, title, question, options, correct_answer, explanation, difficulty)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (subject_id, title, question, options_json, correct_answer, explanation, difficulty))
                conn.commit()
            
            st.success("クイズを作成しました！")
            st.rerun()

def show_subject_progress_detail(subject_id: int, subject_name: str):
    """科目別進捗詳細"""
    st.subheader(f"📊 {subject_name}の進捗")
    
    db = get_database()
    user_id = st.session_state.get('current_user_id', 1)
    
    # 学習統計
    with db.get_connection() as conn:
        cursor = conn.cursor()
        
        # 総学習時間
        cursor.execute("""
            SELECT COALESCE(SUM(duration_minutes), 0)
            FROM study_sessions 
            WHERE user_id = ? AND subject_id = ?
        """, (user_id, subject_id))
        total_minutes = cursor.fetchone()[0]
        
        # 学習日数
        cursor.execute("""
            SELECT COUNT(DISTINCT date(study_date))
            FROM study_sessions 
            WHERE user_id = ? AND subject_id = ?
        """, (user_id, subject_id))
        study_days = cursor.fetchone()[0]
        
        # クイズ正解率
        cursor.execute("""
            SELECT 
                COUNT(*) as total,
                SUM(CASE WHEN is_correct THEN 1 ELSE 0 END) as correct
            FROM quiz_results qr
            JOIN quizzes q ON qr.quiz_id = q.id
            WHERE qr.user_id = ? AND q.subject_id = ?
        """, (user_id, subject_id))
        quiz_stats = cursor.fetchone()
        
        if quiz_stats[0] > 0:
            accuracy = (quiz_stats[1] / quiz_stats[0]) * 100
        else:
            accuracy = 0
    
    # メトリクス表示
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric(
            "総学習時間",
            f"{total_minutes // 60}時間{total_minutes % 60}分",
            f"{total_minutes}分"
        )
    
    with col2:
        st.metric(
            "学習日数",
            f"{study_days}日",
            "継続中"
        )
    
    with col3:
        st.metric(
            "クイズ正解率",
            f"{accuracy:.1f}%",
            f"{quiz_stats[1]}/{quiz_stats[0]}問" if quiz_stats[0] > 0 else "未挑戦"
        )
    
    # 学習履歴
    st.subheader("学習履歴")
    
    with db.get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT date(study_date) as date, SUM(duration_minutes) as minutes
            FROM study_sessions 
            WHERE user_id = ? AND subject_id = ?
            GROUP BY date(study_date)
            ORDER BY date(study_date) DESC
            LIMIT 30
        """, (user_id, subject_id))
        
        history = cursor.fetchall()
    
    if history:
        for date, minutes in history:
            st.write(f"📅 {date}: {minutes}分")
    else:
        st.info("学習履歴がありません。")
