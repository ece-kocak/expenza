"""Tekrarlayan işlem serileri: başlatma, durdurma ve eksik ayların üretilmesi.

Üretim okuma isteklerinde yapılmaz. Uygulama açılışta ve belirli aralıklarla
materialize_all'ı çağırır (bkz. main.py); yeni bir seri başlatıldığında da o seri
hemen güncellenir.
"""
import calendar
import logging
from datetime import date
from typing import Optional

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from . import models
from .database import SessionLocal

log = logging.getLogger(__name__)

# Seriye ait bir işlemde bunlar değişirse sonraki aylar da yeni değerle üretilir.
TEMPLATE_FIELDS = ("amount", "type", "category", "note")


def _next_month(year: int, month: int) -> tuple[int, int]:
    return (year + 1, 1) if month == 12 else (year, month + 1)


def _occurrence(series: models.RecurringSeries, year: int, month: int) -> date:
    last_day = calendar.monthrange(year, month)[1]
    return date(year, month, min(series.day_of_month, last_day))


def start_series(db: Session, tx: models.Transaction) -> models.RecurringSeries:
    """İşlemi, her ay aynı gün tekrarlanan yeni bir serinin ilk kaydı yapar."""
    series = models.RecurringSeries(
        user_id=tx.user_id,
        amount=tx.amount,
        type=tx.type,
        category=tx.category,
        note=tx.note,
        day_of_month=tx.occurred_on.day,
        start_on=tx.occurred_on,
        last_generated_on=tx.occurred_on,
    )
    db.add(series)
    db.flush()
    tx.series_id = series.id
    tx.is_recurring = True
    return series


def stop_series(db: Session, series: models.RecurringSeries) -> None:
    """Seriyi durdurur. Üretilmiş kayıtlar kalır ama artık tekrarlayan sayılmaz."""
    series.active = False
    db.query(models.Transaction).filter(
        models.Transaction.series_id == series.id
    ).update({models.Transaction.is_recurring: False}, synchronize_session="fetch")


def update_template(series: models.RecurringSeries, tx: models.Transaction) -> None:
    for field in TEMPLATE_FIELDS:
        setattr(series, field, getattr(tx, field))


def materialize(
    db: Session, series: models.RecurringSeries, today: Optional[date] = None
) -> int:
    """Son üretilen aydan bugüne kadar eksik ayları ekler; commit etmez.

    Dönüş: eklenen işlem sayısı.
    """
    if not series.active:
        return 0
    today = today or date.today()
    created = 0
    year, month = series.last_generated_on.year, series.last_generated_on.month
    while True:
        year, month = _next_month(year, month)
        day = _occurrence(series, year, month)
        if day > today:
            break
        db.add(
            models.Transaction(
                user_id=series.user_id,
                amount=series.amount,
                type=series.type,
                category=series.category,
                note=series.note,
                auto_categorized=False,
                is_recurring=True,
                series_id=series.id,
                occurred_on=day,
            )
        )
        series.last_generated_on = day
        created += 1
    return created


def materialize_all(today: Optional[date] = None) -> int:
    """Bütün aktif serileri günceller. Her seri ayrı commit edilir."""
    total = 0
    with SessionLocal() as db:
        ids = [
            series_id
            for (series_id,) in db.query(models.RecurringSeries.id).filter(
                models.RecurringSeries.active.is_(True)
            )
        ]
        for series_id in ids:
            series = db.get(models.RecurringSeries, series_id)
            try:
                total += materialize(db, series, today)
                db.commit()
            except IntegrityError:
                # Aynı ayları başka bir süreç aynı anda üretti; onun kaydı geçerli.
                db.rollback()
                log.info("Seri %s başka bir süreç tarafından güncellendi", series_id)
    return total
