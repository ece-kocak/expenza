"""Veritabanı bağlantısı ve oturum yönetimi.

MVP aşamasında SQLite kullanılır (kurulum gerektirmez). Üretim/ileri aşamada
DATABASE_URL ortam değişkeni ile PostgreSQL'e geçilebilir.
"""
import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./expenza.db")

# SQLite tek dosyalı; çok-thread'li FastAPI için check_same_thread kapatılır.
connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """FastAPI bağımlılığı: istek başına bir DB oturumu açar ve kapatır."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
