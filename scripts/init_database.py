"""
データベース初期化スクリプト
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.controllers.database import DatabaseController

def main():
    """データベースを初期化"""
    print("データベースを初期化しています...")
    
    # データベースコントローラーを作成（自動的にテーブルが作成される）
    db = DatabaseController()
    
    print("✅ データベースの初期化が完了しました！")
    print(f"📁 データベースファイル: {db.db_path}")
    
    # 作成されたテーブルを確認
    with db.get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()
        
        print("\n📋 作成されたテーブル:")
        for table in tables:
            print(f"  - {table[0]}")
        
        # 教科データの確認
        cursor.execute("SELECT COUNT(*) FROM subjects")
        subject_count = cursor.fetchone()[0]
        print(f"\n📚 登録された教科数: {subject_count}")

if __name__ == "__main__":
    main()
