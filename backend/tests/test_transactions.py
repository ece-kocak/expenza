"""İşlem uçları: ekleme, otomatik kategori, filtreleme, güncelleme, silme."""
from datetime import date

import pytest


def test_explicit_category_is_kept(add_tx, user):
    tx = add_tx(user["headers"], category="Faturalar", note="migros")
    assert tx["category"] == "Faturalar"
    assert tx["auto_categorized"] is False


def test_expense_without_category_is_categorized_by_model(client, user):
    r = client.post(
        "/transactions",
        json={"amount": 50, "type": "expense", "note": "migros market"},
        headers=user["headers"],
    )
    assert r.status_code == 201
    assert r.json()["category"] == "Yemek"
    assert r.json()["auto_categorized"] is True


def test_income_without_category_is_other(client, user):
    r = client.post(
        "/transactions", json={"amount": 1000, "type": "income"}, headers=user["headers"]
    )
    assert r.json()["category"] == "Diğer"
    assert r.json()["auto_categorized"] is False


def test_non_positive_amount_rejected(client, user):
    r = client.post("/transactions", json={"amount": 0, "type": "expense"}, headers=user["headers"])
    assert r.status_code == 422


def test_list_filters(client, user, add_tx):
    h = user["headers"]
    add_tx(h, category="Yemek", note="kahve", occurred_on="2026-01-15")
    add_tx(h, category="Ulaşım", note="taksi", occurred_on="2026-02-03")
    add_tx(h, type="income", category="Diğer", note="maaş", occurred_on="2026-02-01")

    def notes(**params):
        return [t["note"] for t in client.get("/transactions", params=params, headers=h).json()]

    assert notes(category="Ulaşım") == ["taksi"]
    assert notes(type="income") == ["maaş"]
    assert sorted(notes(month="2026-02")) == ["maaş", "taksi"]
    assert notes(q="kah") == ["kahve"]
    # En yeni tarih önce gelir.
    assert notes() == ["taksi", "maaş", "kahve"]


def test_invalid_month_format(client, user):
    r = client.get("/transactions", params={"month": "2026/02"}, headers=user["headers"])
    assert r.status_code == 400


def test_partial_update_changes_only_sent_fields(client, user, add_tx):
    tx = add_tx(user["headers"], amount=80, note="eski")
    r = client.put(f"/transactions/{tx['id']}", json={"note": "yeni"}, headers=user["headers"])
    assert r.status_code == 200
    assert r.json()["note"] == "yeni" and r.json()["amount"] == 80


def test_delete(client, user, add_tx):
    tx = add_tx(user["headers"])
    assert client.delete(f"/transactions/{tx['id']}", headers=user["headers"]).status_code == 204
    assert client.get("/transactions", headers=user["headers"]).json() == []


def test_default_date_is_today(add_tx, user):
    assert add_tx(user["headers"])["occurred_on"] == date.today().isoformat()


@pytest.mark.parametrize(
    "body",
    [
        {"amount": 10, "note": "x" * 501},
        {"amount": 1_000_000_001},
    ],
)
def test_oversized_input_is_rejected(client, user, body):
    r = client.post("/transactions", json={"type": "expense", **body}, headers=user["headers"])
    assert r.status_code == 422


@pytest.mark.parametrize("limit", [0, 501])
def test_list_limit_is_bounded(client, user, limit):
    r = client.get("/transactions", params={"limit": limit}, headers=user["headers"])
    assert r.status_code == 422
