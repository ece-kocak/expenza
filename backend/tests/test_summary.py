"""Ana sayfa özeti: bakiye tüm işlemlerden, dağılım bu aydan hesaplanır."""
from datetime import date, timedelta

from app import models
from app.database import SessionLocal


def test_balance_counts_every_transaction_not_just_the_latest_200(client, user):
    with SessionLocal() as db:
        user_id = db.query(models.User.id).filter(models.User.email == user["email"]).scalar()
        db.add(models.Transaction(
            user_id=user_id, amount=1000, type=models.TxType.income,
            category=models.CategoryEnum.diger, note="Maaş", occurred_on=date(2025, 1, 1),
        ))
        db.add_all(
            models.Transaction(
                user_id=user_id, amount=1, type=models.TxType.expense,
                category=models.CategoryEnum.yemek, note="", occurred_on=date.today(),
            )
            for _ in range(250)
        )
        db.commit()

    s = client.get("/transactions/summary", headers=user["headers"]).json()
    assert s["total_income"] == 1000
    assert s["total_expense"] == 250
    assert s["balance"] == 750


def test_month_breakdown_only_includes_this_month(client, user, add_tx):
    h = user["headers"]
    last_month = date.today().replace(day=1) - timedelta(days=1)
    add_tx(h, amount=300, category="Yemek")
    add_tx(h, amount=50, category="Ulaşım")
    add_tx(h, amount=999, category="Eğlence", occurred_on=last_month.isoformat())
    add_tx(h, amount=2000, type="income", category="Diğer")

    s = client.get("/transactions/summary", headers=h).json()
    assert s["month"] == date.today().strftime("%Y-%m")
    assert s["month_expense"] == 350
    assert s["month_income"] == 2000
    assert s["month_by_category"] == [
        {"category": "Yemek", "total": 300},
        {"category": "Ulaşım", "total": 50},
    ]
    assert s["total_expense"] == 1349


def test_summary_of_new_user_is_zero(client, user):
    s = client.get("/transactions/summary", headers=user["headers"]).json()
    assert s["balance"] == 0 and s["month_by_category"] == []
