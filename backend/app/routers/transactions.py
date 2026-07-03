"""İşlem (gelir/gider) uçları. Kategori verilmezse hero model otomatik atar."""
from typing import Optional
from datetime import date
import calendar

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import extract
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import get_current_user
from ..database import get_db
from ..ml import categorizer

router = APIRouter(prefix="/transactions", tags=["transactions"])


def _generate_recurring_transactions(db: Session, user_id: int):
    """Her ay tekrarlanan işlemleri otomatik üretir (lazy generation)."""
    recurring_txs = db.query(models.Transaction).filter(
        models.Transaction.user_id == user_id,
        models.Transaction.is_recurring == True
    ).all()
    
    today = date.today()
    for tx in recurring_txs:
        start_date = tx.occurred_on
        if start_date >= today:
            continue
            
        curr_year = start_date.year
        curr_month = start_date.month
        
        while True:
            curr_month += 1
            if curr_month > 12:
                curr_month = 1
                curr_year += 1
                
            if curr_year > today.year or (curr_year == today.year and curr_month > today.month):
                break
                
            max_day = calendar.monthrange(curr_year, curr_month)[1]
            target_day = min(start_date.day, max_day)
            target_date = date(curr_year, curr_month, target_day)
            
            if target_date > today:
                break
                
            exists = db.query(models.Transaction).filter(
                models.Transaction.user_id == user_id,
                models.Transaction.is_recurring == True,
                models.Transaction.type == tx.type,
                models.Transaction.category == tx.category,
                models.Transaction.amount == tx.amount,
                models.Transaction.note == tx.note,
                models.Transaction.occurred_on == target_date
            ).first()
            
            if not exists:
                new_tx = models.Transaction(
                    user_id=user_id,
                    amount=tx.amount,
                    type=tx.type,
                    category=tx.category,
                    auto_categorized=tx.auto_categorized,
                    is_recurring=True,
                    note=tx.note,
                    occurred_on=target_date
                )
                db.add(new_tx)
                db.commit()


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
        is_recurring=payload.is_recurring,
        note=payload.note,
        occurred_on=payload.occurred_on,
    )
    db.add(tx)
    db.commit()
    db.refresh(tx)
    return tx


@router.get("", response_model=list[schemas.TransactionOut])
def list_transactions(
    limit: int = 200,
    category: Optional[models.CategoryEnum] = None,
    type: Optional[models.TxType] = None,
    month: Optional[str] = None,  # "YYYY-MM"
    q: Optional[str] = None,      # not metninde arama
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _generate_recurring_transactions(db, user.id)
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


@router.put("/{tx_id}", response_model=schemas.TransactionOut)
def update_transaction(
    tx_id: int,
    payload: schemas.TransactionUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    tx = (
        db.query(models.Transaction)
        .filter(models.Transaction.id == tx_id, models.Transaction.user_id == user.id)
        .first()
    )
    if not tx:
        raise HTTPException(status_code=404, detail="İşlem bulunamadı")

    data = payload.model_dump(exclude_unset=True)
    for field, value in data.items():
        setattr(tx, field, value)
    db.commit()
    db.refresh(tx)
    return tx


@router.delete("/{tx_id}", status_code=204)
def delete_transaction(
    tx_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    tx = (
        db.query(models.Transaction)
        .filter(models.Transaction.id == tx_id, models.Transaction.user_id == user.id)
        .first()
    )
    if tx:
        db.delete(tx)
        db.commit()
    return None
