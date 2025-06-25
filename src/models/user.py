"""
ユーザーモデル
"""

from dataclasses import dataclass
from datetime import datetime
from typing import Optional

@dataclass
class User:
    """ユーザークラス"""
    id: Optional[int] = None
    name: str = ""
    email: str = ""
    grade: int = 1  # 学年 (1-3)
    created_at: datetime = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now()
    
    def get_grade_text(self) -> str:
        """学年をテキストで取得"""
        grade_map = {1: "高校1年生", 2: "高校2年生", 3: "高校3年生"}
        return grade_map.get(self.grade, "不明")
    
    def is_valid(self) -> bool:
        """ユーザー情報の妥当性をチェック"""
        return (
            bool(self.name.strip()) and
            bool(self.email.strip()) and
            "@" in self.email and
            1 <= self.grade <= 3
        )
