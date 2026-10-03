"""İşlem (gelir/gider) uçları. Kategori verilmezse hero model otomatik atar."""
from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from .. import models, recurring, schemas
from ..auth import get_current_user
from ..database import get_db
from ..ml import categorizer

router = APIRouter(prefix="/transactions", tags=["transactions"])


@router.post("", response_model=schemas.TransactionOut, status_code=201)
def create_transaction(
    payload: schemas.TransactionCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    category = payload.category
    auto = False
    if category is None and payload.type == models.TxType.expense:
        predicted, _conf, _model = categorizer.categorize(payload.note)
        category = predicted
        auto = True
    elif category is None:
        category = models.CategoryEnum.diger

    tx = models.Transaction(
        user_id=user.id,
        amount=payload.amount,
        type=payload.type,
        category=category,
        auto_categorized=auto,
        note=payload.note,
        occurred_on=payload.occurred_on,
    )
    db.add(tx)
    if payload.is_recurring:
        # Geçmiş bir tarihle başlatılan seride aradaki aylar da hemen eklenir.
        series = recurring.start_series(db, tx)
        recurring.materialize(db, series)
    db.commit()
    db.refresh(tx)
    return tx


@router.get("", response_model=list[schemas.TransactionOut])
def list_transactions(
    limit: int = Query(200, ge=1, le=500),
    category: Optional[models.CategoryEnum] = None,
    type: Optional[models.TxType] = None,
    month: Optional[str] = None,  # "YYYY-MM"
    q: Optional[str] = None,      # not metninde arama
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    query = db.query(models.Transaction).filter(
        models.Transaction.user_id == user.id
    )
    if category is not None:
        query = query.filter(models.Transaction.category == category)
    if type is not None:
        query = query.filter(models.Transaction.type == type)
    if month:
        try:
            year_s, mon_s = month.split("-")
            query = query.filter(
                extract("year", models.Transaction.occurred_on) == int(year_s),
                extract("month", models.Transaction.occurred_on) == int(mon_s),
            )
        except (ValueError, AttributeError):
            raise HTTPException(status_code=400, detail="month formatı YYYY-MM olmalı")
    if q:
        query = query.filter(models.Transaction.note.ilike(f"%{q}%"))

    return (
        query.order_by(
            models.Transaction.occurred_on.desc(), models.Transaction.id.desc()
        )
        .limit(limit)
        .all()
    )


@router.get("/summary", response_model=schemas.TransactionSummary)
def transaction_summary(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Bakiye ve toplamlar (tüm işlemler) ile bu ayın kategori dağılımı."""
    tx = models.Transaction
    total = func.coalesce(func.sum(tx.amount), 0.0)
    today = date.today()
    this_month = (
        extract("year", tx.occurred_on) == today.year,
        extract("month", tx.occurred_on) == today.month,
    )

    def totals_by_type(*filters) -> dict:
        rows = (
            db.query(tx.type, total)
            .filter(tx.user_id == user.id, *filters)
            .group_by(tx.type)
            .all()
        )
        return {kind: amount for kind, amount in rows}

    all_time = totals_by_type()
    month = totals_by_type(*this_month)
    by_category = (
        db.query(tx.category, total)
        .filter(tx.user_id == user.id, tx.type == models.TxType.expense, *this_month)
        .group_by(tx.category)
        .order_by(total.desc())
        .all()
    )

    income = all_time.get(models.TxType.income, 0.0)
    expense = all_time.get(models.TxType.expense, 0.0)
    return schemas.TransactionSummary(
        balance=round(income - expense, 2),
        total_income=round(income, 2),
        total_expense=round(expense, 2),
        month=f"{today:%Y-%m}",
        month_income=round(month.get(models.TxType.income, 0.0), 2),
        month_expense=round(month.get(models.TxType.expense, 0.0), 2),
        month_by_category=[
            schemas.CategoryTotal(category=cat.value, total=round(amount, 2))
            for cat, amount in by_category
        ],
    )


@router.put("/{tx_id}", response_model=schemas.TransactionOut)
def update_transaction(
    tx_id: int,
    payload: schemas.TransactionUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Gönderilen alanları günceller (null gönderilen alan değişmez).

    is_recurring: false seriyi durdurur, true işlemi yeni bir serinin başlangıcı yapar.
    Aktif bir seriye ait işlemde tutar, tür, kategori veya not değişirse sonraki aylar
    da yeni değerle üretilir.
    """
    tx = (
        db.query(models.Transaction)
        .filter(models.Transaction.id == tx_id, models.Transaction.user_id == user.id)
        .first()
    )
    if not tx:
        raise HTTPException(status_code=404, detail="İşlem bulunamadı")

    data = {k: v for k, v in payload.model_dump(exclude_unset=True).items() if v is not None}
    wants_recurring = data.pop("is_recurring", None)
    for field, value in data.items():
        setattr(tx, field, value)

    series = tx.series
    active = series is not None and series.active
    if wants_recurring is False and active:
        recurring.stop_series(db, series)
    elif wants_recurring is True and not active:
        recurring.materialize(db, recurring.start_series(db, tx))
    elif active and any(field in data for field in recurring.TEMPLATE_FIELDS):
        recurring.update_template(series, tx)

    db.commit()
    db.refresh(tx)
    return tx


@router.delete("/{tx_id}", status_code=204)
def delete_transaction(
    tx_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """İşlemi siler. Seriye aitse seri devam eder ama silinen ay yeniden üretilmez."""
    tx = (
        db.query(models.Transaction)
        .filter(models.Transaction.id == tx_id, models.Transaction.user_id == user.id)
        .first()
    )
    if tx:
        db.delete(tx)
        db.commit()
    return None
