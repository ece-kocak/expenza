"""Bütçe limitleri ve harcanan tutar özeti."""
from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import get_current_user
from ..database import get_db

router = APIRouter(prefix="/budgets", tags=["budgets"])


def _spent_by_category(db: Session, user_id: int) -> dict:
    """İçinde bulunulan ay için kategori bazında toplam gideri döndürür."""
    today = date.today()
    rows = (
        db.query(
            models.Transaction.category,
            func.coalesce(func.sum(models.Transaction.amount), 0.0),
        )
        .filter(
            models.Transaction.user_id == user_id,
            models.Transaction.type == models.TxType.expense,
            extract("year", models.Transaction.occurred_on) == today.year,
            extract("month", models.Transaction.occurred_on) == today.month,
        )
        .group_by(models.Transaction.category)
        .all()
    )
    return {cat: total for cat, total in rows}


@router.post("", response_model=schemas.BudgetOut, status_code=201)
def upsert_budget(
    payload: schemas.BudgetCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    # Kategori başına tek bütçe: varsa güncelle, yoksa oluştur.
    budget = (
        db.query(models.Budget)
        .filter(
            models.Budget.user_id == user.id,
            models.Budget.category == payload.category,
        )
        .first()
    )
    if budget:
        budget.monthly_limit = payload.monthly_limit
    else:
        budget = models.Budget(
            user_id=user.id,
            category=payload.category,
            monthly_limit=payload.monthly_limit,
        )
        db.add(budget)
    db.commit()
    db.refresh(budget)

    spent = _spent_by_category(db, user.id).get(budget.category, 0.0)
    out = schemas.BudgetOut.model_validate(budget)
    out.spent = spent
    return out


@router.get("", response_model=list[schemas.BudgetOut])
def list_budgets(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    budgets = db.query(models.Budget).filter(models.Budget.user_id == user.id).all()
    spent_map = _spent_by_category(db, user.id)
    result = []
    for b in budgets:
        out = schemas.BudgetOut.model_validate(b)
        out.spent = spent_map.get(b.category, 0.0)
        result.append(out)
    return result


@router.delete("/{budget_id}", status_code=204)
def delete_budget(
    budget_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    budget = (
        db.query(models.Budget)
        .filter(models.Budget.id == budget_id, models.Budget.user_id == user.id)
        .first()
    )
    if budget:
        db.delete(budget)
        db.commit()
    return None
