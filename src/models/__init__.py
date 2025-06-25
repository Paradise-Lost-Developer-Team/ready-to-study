"""
データベースモデル定義
"""

from sqlalchemy import create_engine, Column, Integer, String, DateTime, Float, Text, Boolean, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime

Base = declarative_base()

class User(Base):
    """ユーザーモデル"""
    __tablename__ = 'users'
    
    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    email = Column(String(200), unique=True, nullable=False)
    grade = Column(Integer, nullable=False)  # 学年 (1-3)
    created_at = Column(DateTime, default=datetime.now)
    
    # リレーション
    study_sessions = relationship("StudySession", back_populates="user")
    quiz_results = relationship("QuizResult", back_populates="user")
    schedules = relationship("Schedule", back_populates="user")

class Subject(Base):
    """教科モデル"""
    __tablename__ = 'subjects'
    
    id = Column(Integer, primary_key=True)
    name = Column(String(50), nullable=False)
    category = Column(String(50), nullable=False)  # 国語、数学、英語、理科、社会、情報、その他
    description = Column(Text)
    grade_level = Column(Integer, nullable=False)  # 対象学年
    
    # リレーション
    study_sessions = relationship("StudySession", back_populates="subject")
    quizzes = relationship("Quiz", back_populates="subject")

class StudySession(Base):
    """学習セッションモデル"""
    __tablename__ = 'study_sessions'
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    subject_id = Column(Integer, ForeignKey('subjects.id'), nullable=False)
    duration_minutes = Column(Integer, nullable=False)
    content = Column(Text)
    satisfaction_score = Column(Integer)  # 1-5の満足度
    study_date = Column(DateTime, default=datetime.now)
    
    # リレーション
    user = relationship("User", back_populates="study_sessions")
    subject = relationship("Subject", back_populates="study_sessions")

class Quiz(Base):
    """クイズモデル"""
    __tablename__ = 'quizzes'
    
    id = Column(Integer, primary_key=True)
    subject_id = Column(Integer, ForeignKey('subjects.id'), nullable=False)
    title = Column(String(200), nullable=False)
    question = Column(Text, nullable=False)
    options = Column(Text)  # JSON形式で選択肢を保存
    correct_answer = Column(String(500), nullable=False)
    explanation = Column(Text)
    difficulty = Column(Integer, default=1)  # 1-5の難易度
    
    # リレーション
    subject = relationship("Subject", back_populates="quizzes")
    results = relationship("QuizResult", back_populates="quiz")

class QuizResult(Base):
    """クイズ結果モデル"""
    __tablename__ = 'quiz_results'
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    quiz_id = Column(Integer, ForeignKey('quizzes.id'), nullable=False)
    user_answer = Column(Text)
    is_correct = Column(Boolean, nullable=False)
    time_taken_seconds = Column(Integer)
    attempted_at = Column(DateTime, default=datetime.now)
    
    # リレーション
    user = relationship("User", back_populates="quiz_results")
    quiz = relationship("Quiz", back_populates="results")

class Schedule(Base):
    """スケジュールモデル"""
    __tablename__ = 'schedules'
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    scheduled_date = Column(DateTime, nullable=False)
    event_type = Column(String(50), nullable=False)  # test, homework, review, etc.
    is_completed = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.now)
    
    # リレーション
    user = relationship("User", back_populates="schedules")

# データベース設定
DATABASE_URL = "sqlite:///data/study_app.db"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    """データベースセッションを取得"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
