"""Tekrarlayan işlem serileri (eski çift kayıt hatalarının tekrarlanmaması dahil)."""
from datetime import date, timedelta

import pytest
from sqlalchemy.exc import IntegrityError

from app import models, recurring
from app.database import SessionLocal


def _user_id(email):
    with SessionLocal() as db:
        return db.query(models.User.id).filter(models.User.email == email).scalar()


def _start(user, start, amount=1000.0, note="Maaş"):
    """Verilen tarihte başlayan bir gelir serisi oluşturur (henüz ay üretmeden)."""
    with SessionLocal() as db:
        tx = models.Transaction(
            user_id=_user_id(user["email"]), amount=amount, type=models.TxType.income,
            category=models.CategoryEnum.diger, note=note, occurred_on=start,
        )
        db.add(tx)
        series = recurring.start_series(db, tx)
        db.commit()
        return series.id


def _dates(series_id):
    with SessionLocal() as db:
        rows = db.query(models.Transaction.occurred_on).filter(
            models.Transaction.series_id == series_id
        )
        return sorted(d.isoformat() for (d,) in rows)


def test_month_end_day_does_not_drift(user):
    series_id = _start(user, date(2026, 1, 31))
    recurring.materialize_all(today=date(2026, 5, 15))
    # Şubat'ta 28'e düşer ama Mart'ta yine 31'e döner (eski kod 28'den devam ediyordu).
    assert _dates(series_id) == ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30"]


def test_running_again_does_not_duplicate(user):
    series_id = _start(user, date(2026, 1, 15))
    recurring.materialize_all(today=date(2026, 4, 20))
    recurring.materialize_all(today=date(2026, 4, 20))
    assert len(_dates(series_id)) == 4


def test_deleted_occurrence_is_not_regenerated(client, user):
    series_id = _start(user, date(2026, 1, 15))
    recurring.materialize_all(today=date(2026, 3, 20))
    feb = next(
        t for t in client.get("/transactions", headers=user["headers"]).json()
        if t["occurred_on"] == "2026-02-15"
    )
    client.delete(f"/transactions/{feb['id']}", headers=user["headers"])

    recurring.materialize_all(today=date(2026, 3, 20))
    assert _dates(series_id) == ["2026-01-15", "2026-03-15"]


def test_unchecking_stops_the_series(client, user):
    series_id = _start(user, date(2026, 1, 10))
    recurring.materialize_all(today=date(2026, 2, 20))
    any_tx = client.get("/transactions", headers=user["headers"]).json()[0]

    r = client.put(f"/transactions/{any_tx['id']}", json={"is_recurring": False}, headers=user["headers"])
    assert r.status_code == 200

    recurring.materialize_all(today=date(2026, 6, 1))
    assert _dates(series_id) == ["2026-01-10", "2026-02-10"]
    txs = client.get("/transactions", headers=user["headers"]).json()
    assert all(t["is_recurring"] is False for t in txs)


def test_edited_amount_applies_to_following_months(client, user):
    series_id = _start(user, date(2026, 1, 5), amount=1000)
    recurring.materialize_all(today=date(2026, 2, 10))
    latest = client.get("/transactions", headers=user["headers"]).json()[0]
    client.put(f"/transactions/{latest['id']}", json={"amount": 1200}, headers=user["headers"])

    recurring.materialize_all(today=date(2026, 3, 10))
    amounts = {t["occurred_on"]: t["amount"] for t in client.get("/transactions", headers=user["headers"]).json()}
    assert amounts == {"2026-01-05": 1000, "2026-02-05": 1200, "2026-03-05": 1200}
    assert len(_dates(series_id)) == 3


def test_listing_transactions_does_not_write(client, user):
    _start(user, date(2026, 1, 15))  # aylar üretilmemiş durumda bekliyor
    before = len(client.get("/transactions", headers=user["headers"]).json())
    after = len(client.get("/transactions", headers=user["headers"]).json())
    assert before == after == 1


def test_same_series_cannot_have_two_rows_on_one_day(user):
    series_id = _start(user, date(2026, 1, 15))
    with SessionLocal() as db:
        db.add(models.Transaction(
            user_id=_user_id(user["email"]), amount=1, type=models.TxType.income,
            category=models.CategoryEnum.diger, note="", series_id=series_id,
            occurred_on=date(2026, 1, 15),
        ))
        with pytest.raises(IntegrityError):
            db.commit()


def test_creating_with_past_date_backfills_until_today(client, user):
    first_of_month = date.today().replace(day=1)
    two_months_ago = (first_of_month - timedelta(days=40)).replace(day=1)
    r = client.post(
        "/transactions",
        json={"amount": 500, "type": "income", "note": "Burs", "is_recurring": True,
              "occurred_on": two_months_ago.isoformat()},
        headers=user["headers"],
    )
    assert r.status_code == 201
    assert r.json()["is_recurring"] is True
    txs = client.get("/transactions", headers=user["headers"]).json()
    assert len(txs) == 3 and len({t["series_id"] for t in txs}) == 1


def test_checking_an_existing_transaction_starts_a_series(client, user, add_tx):
    tx = add_tx(user["headers"], type="income", category="Diğer", note="Kira geliri")
    r = client.put(f"/transactions/{tx['id']}", json={"is_recurring": True}, headers=user["headers"])
    assert r.json()["is_recurring"] is True
    assert r.json()["series_id"] is not None
