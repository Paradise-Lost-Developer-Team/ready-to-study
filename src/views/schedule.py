"""
スケジュール管理ビュー
"""

import streamlit as st
from datetime import datetime, timedelta
from src.controllers.database import get_database

def show_schedule():
    """スケジュール管理ページ"""
    st.markdown('<h1 class="main-header">📅 スケジュール管理</h1>', unsafe_allow_html=True)
    
    tab1, tab2 = st.tabs(["📋 予定一覧", "➕ 新規予定"])
    
    with tab1:
        show_schedule_list()
    
    with tab2:
        show_add_schedule()

def show_schedule_list():
    """予定一覧表示"""
    st.subheader("今後の予定")
    
    # フィルター
    col1, col2 = st.columns(2)
    with col1:
        filter_type = st.selectbox(
            "予定タイプ", 
            ["すべて", "定期テスト", "課題", "復習", "模試", "その他"]
        )
    
    with col2:
        filter_period = st.selectbox(
            "期間", 
            ["今週", "今月", "3ヶ月", "すべて"]
        )
    
    # 期間の計算
    now = datetime.now()
    if filter_period == "今週":
        start_date = now - timedelta(days=now.weekday())
        end_date = start_date + timedelta(days=7)
    elif filter_period == "今月":
        start_date = now.replace(day=1)
        next_month = now.replace(day=28) + timedelta(days=4)
        end_date = next_month - timedelta(days=next_month.day)
    elif filter_period == "3ヶ月":
        start_date = now
        end_date = now + timedelta(days=90)
    else:
        start_date = datetime(2000, 1, 1)
        end_date = datetime(2030, 12, 31)
    
    # データ取得
    db = get_database()
    user_id = st.session_state.get('current_user_id', 1)
    
    with db.get_connection() as conn:
        cursor = conn.cursor()
        
        query = """
            SELECT id, title, description, scheduled_date, event_type, is_completed
            FROM schedules 
            WHERE user_id = ? AND scheduled_date BETWEEN ? AND ?
        """
        params = [user_id, start_date, end_date]
        
        if filter_type != "すべて":
            event_type_map = {
                "定期テスト": "test",
                "課題": "homework", 
                "復習": "review",
                "模試": "mock_exam",
                "その他": "other"
            }
            query += " AND event_type = ?"
            params.append(event_type_map.get(filter_type, "other"))
        
        query += " ORDER BY scheduled_date"
        
        cursor.execute(query, params)
        schedules = cursor.fetchall()
    
    # 予定表示
    if schedules:
        for schedule in schedules:
            schedule_id, title, description, scheduled_date, event_type, is_completed = schedule
            
            # 予定タイプのアイコン
            type_icons = {
                "test": "📝",
                "homework": "📚", 
                "review": "🔄",
                "mock_exam": "🎯",
                "other": "📌"
            }
            icon = type_icons.get(event_type, "📌")
            
            # 完了状態
            status = "✅" if is_completed else "⏳"
            
            with st.container():
                col1, col2, col3 = st.columns([0.1, 0.7, 0.2])
                
                with col1:
                    # 完了チェックボックス
                    completed = st.checkbox("", value=is_completed, key=f"schedule_{schedule_id}")
                    if completed != is_completed:
                        # 完了状態を更新
                        with db.get_connection() as conn:
                            cursor = conn.cursor()
                            cursor.execute(
                                "UPDATE schedules SET is_completed = ? WHERE id = ?",
                                (completed, schedule_id)
                            )
                            conn.commit()
                        st.rerun()
                
                with col2:
                    # 予定詳細
                    date_str = datetime.fromisoformat(scheduled_date).strftime('%m/%d %H:%M')
                    st.write(f"{icon} **{title}** - {date_str}")
                    if description:
                        st.caption(description)
                
                with col3:
                    # 削除ボタン
                    if st.button("🗑️", key=f"delete_{schedule_id}"):
                        with db.get_connection() as conn:
                            cursor = conn.cursor()
                            cursor.execute("DELETE FROM schedules WHERE id = ?", (schedule_id,))
                            conn.commit()
                        st.success("予定を削除しました")
                        st.rerun()
                
                st.divider()
    else:
        st.info("予定がありません。新しい予定を追加してみましょう！")

def show_add_schedule():
    """新規予定追加"""
    st.subheader("新しい予定を追加")
    
    with st.form("add_schedule_form"):
        title = st.text_input("タイトル", placeholder="例: 数学の定期テスト")
        description = st.text_area("詳細", placeholder="試験範囲や準備事項など...")
        
        col1, col2 = st.columns(2)
        with col1:
            event_type = st.selectbox(
                "予定タイプ",
                ["定期テスト", "課題", "復習", "模試", "その他"]
            )
            scheduled_date = st.date_input("日付", value=datetime.now().date())
        
        with col2:
            scheduled_time = st.time_input("時刻", value=datetime.now().time())
        
        submitted = st.form_submit_button("予定を追加", type="primary")
        
        if submitted and title:
            # データベースに追加
            user_id = st.session_state.get('current_user_id', 1)
            scheduled_datetime = datetime.combine(scheduled_date, scheduled_time)
            
            event_type_map = {
                "定期テスト": "test",
                "課題": "homework", 
                "復習": "review",
                "模試": "mock_exam",
                "その他": "other"
            }
            
            db = get_database()
            with db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO schedules 
                    (user_id, title, description, scheduled_date, event_type)
                    VALUES (?, ?, ?, ?, ?)
                """, (
                    user_id,
                    title,
                    description,
                    scheduled_datetime,
                    event_type_map.get(event_type, "other")
                ))
                conn.commit()
            
            st.success("予定を追加しました！")
            st.rerun()
    
    # クイック追加ボタン
    st.subheader("クイック追加")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if st.button("📝 来週のテスト", use_container_width=True):
            add_quick_schedule("来週のテスト", "test", 7)
    
    with col2:
        if st.button("📚 明日の課題", use_container_width=True):
            add_quick_schedule("明日の課題", "homework", 1)
    
    with col3:
        if st.button("🔄 復習セッション", use_container_width=True):
            add_quick_schedule("復習セッション", "review", 0)

def add_quick_schedule(title: str, event_type: str, days_ahead: int):
    """クイック予定追加"""
    user_id = st.session_state.get('current_user_id', 1)
    scheduled_date = datetime.now() + timedelta(days=days_ahead)
    
    db = get_database()
    with db.get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO schedules 
            (user_id, title, scheduled_date, event_type)
            VALUES (?, ?, ?, ?)
        """, (user_id, title, scheduled_date, event_type))
        conn.commit()
    
    st.success(f"「{title}」を追加しました！")
    st.rerun()
