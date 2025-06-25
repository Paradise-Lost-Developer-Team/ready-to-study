"""
データベースコントローラーのテスト
"""

import unittest
import tempfile
import os
import sys

# プロジェクトルートをパスに追加
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.controllers.database import DatabaseController

class TestDatabaseController(unittest.TestCase):
    """データベースコントローラーのテストクラス"""
    
    def setUp(self):
        """テスト前の準備"""
        # 一時ファイルでテスト用データベースを作成
        self.test_db_file = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        self.test_db_path = self.test_db_file.name
        self.test_db_file.close()
        
        self.db = DatabaseController(self.test_db_path)
    
    def tearDown(self):
        """テスト後のクリーンアップ"""
        if os.path.exists(self.test_db_path):
            os.unlink(self.test_db_path)
    
    def test_table_creation(self):
        """テーブル作成のテスト"""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            
            # テーブルが作成されているかチェック
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = [row[0] for row in cursor.fetchall()]
            
            expected_tables = ['users', 'subjects', 'study_sessions', 'quizzes', 'quiz_results', 'schedules']
            for table in expected_tables:
                self.assertIn(table, tables, f"テーブル '{table}' が作成されていません")
    
    def test_initial_data_insertion(self):
        """初期データ投入のテスト"""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            
            # 教科データが投入されているかチェック
            cursor.execute("SELECT COUNT(*) FROM subjects")
            subject_count = cursor.fetchone()[0]
            
            self.assertGreater(subject_count, 0, "教科データが投入されていません")
            self.assertGreaterEqual(subject_count, 20, "教科データが不足しています")
    
    def test_subject_categories(self):
        """教科カテゴリのテスト"""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("SELECT DISTINCT category FROM subjects")
            categories = [row[0] for row in cursor.fetchall()]
            
            expected_categories = ['国語', '数学', '英語', '理科', '社会', '情報']
            for category in expected_categories:
                self.assertIn(category, categories, f"カテゴリ '{category}' が見つかりません")

if __name__ == '__main__':
    unittest.main()
