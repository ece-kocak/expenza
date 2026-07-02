"""SQLAlchemy ORM modelleri — Expenza veri modeli.

Kategoriler tasarım mockup'larıyla uyumludur:
Yemek, Ulaşım, Faturalar, Eğlence, Sağlık, Eğitim, Alışveriş, Diğer.
"""
import enum
from datetime import date, datetime
from typing import Optional

from sqlalchemy import (
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class CategoryEnum(str, enum.Enum):
    """Sabit harcama kategorileri. Hero NLP modeli bu etiketleri üretecek."""

    yemek = "Yemek"
    ulasim = "Ulaşım"
    faturalar = "Faturalar"
    eglence = "Eğlence"
    saglik = "Sağlık"
    egitim = "Eğitim"
    alisveris = "Alışveriş"
    diger = "Diğer"
    toplam = "Toplam"


class TxType(str, enum.Enum):
    income = "income"
    expense = "expense"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(120), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    transactions: Mapped[list["Transaction"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    budgets: Mapped[list["Budget"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    amount: Mapped[float] = mapped_column(Float)
    type: Mapped[TxType] = mapped_column(Enum(TxType), default=TxType.expense)
    category: Mapped[CategoryEnum] = mapped_column(
        Enum(CategoryEnum), default=CategoryEnum.diger
    )
    # Modelin kategoriyi otomatik atayıp atamadığını ve güven skorunu izlemek için.
    auto_categorized: Mapped[bool] = mapped_column(default=False)
    note: Mapped[str] = mapped_column(String(500), default="")
    occurred_on: Mapped[date] = mapped_column(Date, default=date.today)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship(back_populates="transactions")


class Budget(Base):
    __tablename__ = "budgets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    category: Mapped[CategoryEnum] = mapped_column(Enum(CategoryEnum))
    monthly_limit: Mapped[float] = mapped_column(Float)

    user: Mapped["User"] = relationship(back_populates="budgets")


class Goal(Base):
    """Tasarruf hedefi (örn. 'Tatil için 10.000₺'). Raporun çekirdek özelliği."""

    __tablename__ = "goals"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    title: Mapped[str] = mapped_column(String(120))
    target_amount: Mapped[float] = mapped_column(Float)
    current_amount: Mapped[float] = mapped_column(Float, default=0.0)
    deadline: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
