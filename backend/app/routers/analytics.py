"""Analitik uçları (İP-4) — harcama tahmini ve anomali tespiti."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import get_current_user
from ..database import get_db
from ..ml import analytics, insights

router = APIRouter(prefix="/analytics", tags=["analytics"])


def _user_transactions(db: Session, user_id: int) -> list[models.Transaction]:
    return (
        db.query(models.Transaction)
        .filter(models.Transaction.user_id == user_id)
        .all()
    )


@router.get("/forecast", response_model=schemas.ForecastResponse)
def forecast(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    txs = _user_transactions(db, user.id)
    return analytics.forecast_spending(txs)


@router.get("/anomalies", response_model=list[schemas.AnomalyItem])
def anomalies(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    txs = _user_transactions(db, user.id)
    return analytics.detect_anomalies(txs)


@router.get("/insights", response_model=list[schemas.InsightItem])
def get_insights(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    txs = _user_transactions(db, user.id)
    return insights.generate_insights(txs)
