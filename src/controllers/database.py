"""
データベース制御
"""

import sqlite3
import os
from datetime import datetime
from typing import List, Dict, Optional

class DatabaseController:
    """データベースコントローラー"""
    
    def __init__(self, db_path: str = "data/study_app.db"):
        self.db_path = db_path
        self.ensure_data_directory()
        self.init_tables()
    
    def ensure_data_directory(self):
        """データディレクトリの存在確認・作成"""
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
    
    def get_connection(self):
        """データベース接続を取得"""
        return sqlite3.connect(self.db_path)
    
    def init_tables(self):
        """テーブルの初期化"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            # ユーザーテーブル
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    email TEXT UNIQUE NOT NULL,
                    grade INTEGER NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # 教科テーブル
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS subjects (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    category TEXT NOT NULL,
                    description TEXT,
                    grade_level INTEGER NOT NULL
                )
            """)
            
            # 学習セッションテーブル
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS study_sessions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    subject_id INTEGER NOT NULL,
                    duration_minutes INTEGER NOT NULL,
                    content TEXT,
                    satisfaction_score INTEGER,
                    study_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users (id),
                    FOREIGN KEY (subject_id) REFERENCES subjects (id)
                )
            """)
            
            # クイズテーブル
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS quizzes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    subject_id INTEGER NOT NULL,
                    title TEXT NOT NULL,
                    question TEXT NOT NULL,
                    options TEXT,
                    correct_answer TEXT NOT NULL,
                    explanation TEXT,
                    difficulty INTEGER DEFAULT 1,
                    FOREIGN KEY (subject_id) REFERENCES subjects (id)
                )
            """)
            
            # クイズ結果テーブル
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS quiz_results (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    quiz_id INTEGER NOT NULL,
                    user_answer TEXT,
                    is_correct BOOLEAN NOT NULL,
                    time_taken_seconds INTEGER,
                    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users (id),
                    FOREIGN KEY (quiz_id) REFERENCES quizzes (id)
                )
            """)
            
            # スケジュールテーブル
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS schedules (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    title TEXT NOT NULL,
                    description TEXT,
                    scheduled_date TIMESTAMP NOT NULL,
                    event_type TEXT NOT NULL,
                    is_completed BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users (id)
                )
            """)
            
            conn.commit()
            self.insert_initial_data()
    
    def insert_initial_data(self):
        """初期データの投入"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            # 教科データが存在しない場合のみ投入
            cursor.execute("SELECT COUNT(*) FROM subjects")
            if cursor.fetchone()[0] == 0:
                subjects = [
                    # 国語
                    ("現代文", "国語", "現代文の読解・表現", 1),
                    ("古文", "国語", "古典文学の読解", 2),
                    ("漢文", "国語", "漢文の読解", 2),
                    
                    # 数学
                    ("数学I", "数学", "数と式、図形と計量、二次関数、データの分析", 1),
                    ("数学A", "数学", "図形の性質、場合の数と確率", 1),
                    ("数学II", "数学", "式と証明、複素数と方程式、図形と方程式、三角関数、指数・対数関数、微分・積分", 2),
                    ("数学B", "数学", "数列、統計的な推測、ベクトル", 2),
                    ("数学III", "数学", "極限、微分法、積分法", 3),
                    ("数学C", "数学", "ベクトル、平面上の曲線と複素数平面", 3),
                    
                    # 英語
                    ("英語コミュニケーションI", "英語", "聞く・読む・話す・書く技能の総合的育成", 1),
                    ("英語コミュニケーションII", "英語", "英語コミュニケーション能力の向上", 2),
                    ("英語コミュニケーションIII", "英語", "高度な英語コミュニケーション", 3),
                    ("論理・表現I", "英語", "論理的な思考力と表現力", 1),
                    ("論理・表現II", "英語", "高度な論理的表現", 2),
                    ("論理・表現III", "英語", "実践的な論理的表現", 3),
                    
                    # 理科
                    ("物理基礎", "理科", "物理現象の基本原理", 1),
                    ("化学基礎", "理科", "化学現象の基本原理", 1),
                    ("生物基礎", "理科", "生物現象の基本原理", 1),
                    ("地学基礎", "理科", "地球科学の基本", 1),
                    ("物理", "理科", "物理現象の詳細な理解", 2),
                    ("化学", "理科", "化学現象の詳細な理解", 2),
                    ("生物", "理科", "生物現象の詳細な理解", 2),
                    ("地学", "理科", "地球科学の詳細な理解", 2),
                    
                    # 社会
                    ("地理総合", "社会", "地理的な見方・考え方", 1),
                    ("歴史総合", "社会", "歴史的な見方・考え方", 1),
                    ("公共", "社会", "公共的な事柄への参画", 1),
                    ("地理探究", "社会", "地理的探究", 2),
                    ("日本史探究", "社会", "日本史の探究", 2),
                    ("世界史探究", "社会", "世界史の探究", 2),
                    ("政治・経済", "社会", "政治経済の理解", 2),
                    ("倫理", "社会", "人間としての在り方生き方", 2),
                    
                    # 情報
                    ("情報I", "情報", "情報活用能力の育成", 1),
                ]
                
                cursor.executemany(
                    "INSERT INTO subjects (name, category, description, grade_level) VALUES (?, ?, ?, ?)",
                    subjects
                )
                conn.commit()

# グローバルインスタンス
db_controller = DatabaseController()

def init_database():
    """データベース初期化（アプリ起動時に呼び出し）"""
    global db_controller
    db_controller = DatabaseController()

def get_database():
    """データベースコントローラーを取得"""
    return db_controller
