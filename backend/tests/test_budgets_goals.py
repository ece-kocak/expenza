"""Bütçe ve tasarruf hedefi uçları."""
from datetime import date, timedelta


def test_budget_upsert_updates_existing_category(client, user):
    h = user["headers"]
    first = client.post("/budgets", json={"category": "Yemek", "monthly_limit": 500}, headers=h).json()
    second = client.post("/budgets", json={"category": "Yemek", "monthly_limit": 800}, headers=h).json()
    assert first["id"] == second["id"]
    budgets = client.get("/budgets", headers=h).json()
    assert len(budgets) == 1 and budgets[0]["monthly_limit"] == 800


def test_budget_spent_counts_only_this_months_expenses(client, user, add_tx):
    h = user["headers"]
    today = date.today()
    last_month = today.replace(day=1) - timedelta(days=1)
    add_tx(h, amount=120, category="Yemek")
    add_tx(h, amount=999, category="Yemek", occurred_on=last_month.isoformat())
    add_tx(h, amount=5000, type="income", category="Yemek")

    client.post("/budgets", json={"category": "Yemek", "monthly_limit": 500}, headers=h)
    assert client.get("/budgets", headers=h).json()[0]["spent"] == 120


def test_total_budget_spent_is_sum_of_all_categories(client, user, add_tx):
    h = user["headers"]
    add_tx(h, amount=100, category="Yemek")
    add_tx(h, amount=40, category="Ulaşım")
    r = client.post("/budgets", json={"category": "Toplam", "monthly_limit": 1000}, headers=h)
    assert r.json()["spent"] == 140


def test_budget_limit_must_be_positive(client, user):
    r = client.post("/budgets", json={"category": "Yemek", "monthly_limit": 0}, headers=user["headers"])
    assert r.status_code == 422


def test_goal_progress_and_cap(client, user):
    h = user["headers"]
    goal = client.post("/goals", json={"title": "Tatil", "target_amount": 1000}, headers=h).json()
    assert goal["progress"] == 0

    r = client.post(f"/goals/{goal['id']}/contribute", json={"amount": 250}, headers=h)
    assert r.json()["current_amount"] == 250 and r.json()["progress"] == 0.25

    r = client.post(f"/goals/{goal['id']}/contribute", json={"amount": 2000}, headers=h)
    assert r.json()["progress"] == 1.0


def test_goal_delete(client, user):
    h = user["headers"]
    goal = client.post("/goals", json={"title": "Bilgisayar", "target_amount": 30000}, headers=h).json()
    assert client.delete(f"/goals/{goal['id']}", headers=h).status_code == 204
    assert client.get("/goals", headers=h).json() == []
