"""Pydantic şemaları — API istek/yanıt sözleşmeleri."""
from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from .models import CategoryEnum, TxType


# ---- Auth ----
class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    display_name: str = ""


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    email: EmailStr
    display_name: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ---- Transactions ----
class TransactionBase(BaseModel):
    amount: float = Field(gt=0)
    type: TxType = TxType.expense
    category: Optional[CategoryEnum] = None  # None => model otomatik atar
    note: str = ""
    occurred_on: date = Field(default_factory=date.today)
    is_recurring: bool = False


class TransactionCreate(TransactionBase):
    pass


class TransactionUpdate(BaseModel):
    # Tüm alanlar opsiyonel — yalnızca gönderilenler güncellenir.
    amount: Optional[float] = Field(default=None, gt=0)
    type: Optional[TxType] = None
    category: Optional[CategoryEnum] = None
    note: Optional[str] = None
    occurred_on: Optional[date] = None
    is_recurring: Optional[bool] = None


class TransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    amount: float
    type: TxType
    category: CategoryEnum
    auto_categorized: bool
    is_recurring: bool
    series_id: Optional[int] = None
    note: str
    occurred_on: date
    created_at: datetime


class CategoryTotal(BaseModel):
    category: str
    total: float


class TransactionSummary(BaseModel):
    balance: float           # tüm zamanlar: gelir - gider
    total_income: float
    total_expense: float
    month: str               # "YYYY-MM", içinde bulunulan ay
    month_income: float
    month_expense: float
    month_by_category: list[CategoryTotal]  # bu ayın giderleri, büyükten küçüğe


# ---- Budgets ----
class BudgetCreate(BaseModel):
    category: CategoryEnum
    monthly_limit: float = Field(gt=0)


class BudgetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    category: CategoryEnum
    monthly_limit: float
    spent: float = 0.0  # crud tarafından doldurulur


# ---- ML ----
class CategorizeRequest(BaseModel):
    text: str = Field(max_length=500)  # işlem notu sütunuyla aynı sınır


class CategorizeResponse(BaseModel):
    category: CategoryEnum
    confidence: float
    model: str  # hangi modelin yanıtladığı (stub / svm / berturk)


# ---- Analytics (İP-4) ----
class MonthTotal(BaseModel):
    month: str
    total: float


class CategoryProjection(BaseModel):
    category: str
    projected: float


class ForecastResponse(BaseModel):
    current_month_spent: float
    projected_month_end: float
    next_month_prediction: float
    method: str        # trend | last_month | run_rate
    velocity: str      # Yüksek | Normal | Düşük
    history: list[MonthTotal]
    by_category: list[CategoryProjection]


class AnomalyItem(BaseModel):
    transaction_id: int
    amount: float
    category: str
    note: str
    occurred_on: str
    z_score: float
    severity: str      # high | medium
    reason: str


class InsightItem(BaseModel):
    icon: str
    tone: str          # good | warn | neutral
    title: str
    text: str


# ---- Savings goals ----
class GoalCreate(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    target_amount: float = Field(gt=0)
    deadline: Optional[date] = None


class GoalContribute(BaseModel):
    amount: float = Field(gt=0)


class GoalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    title: str
    target_amount: float
    current_amount: float
    deadline: Optional[date] = None
    progress: float = 0.0  # 0..1, router doldurur
