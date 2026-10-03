"""Bir kullanıcı başka bir kullanıcının verisini göremez ve değiştiremez."""
import pytest

PROTECTED = [
    ("get", "/auth/me"),
    ("get", "/transactions"),
    ("post", "/transactions"),
    ("put", "/transactions/1"),
    ("delete", "/transactions/1"),
    ("get", "/budgets"),
    ("post", "/budgets"),
    ("delete", "/budgets/1"),
    ("get", "/goals"),
    ("post", "/goals"),
    ("post", "/goals/1/contribute"),
    ("delete", "/goals/1"),
    ("get", "/analytics/forecast"),
    ("get", "/analytics/anomalies"),
    ("get", "/analytics/insights"),
    ("post", "/ml/categorize"),
    ("post", "/chat"),
]


@pytest.mark.parametrize("method,path", PROTECTED)
def test_protected_endpoints_require_token(client, method, path):
    assert getattr(client, method)(path).status_code == 401


def test_transactions_are_isolated(client, make_user, add_tx):
    a, b = make_user(), make_user()
    tx = add_tx(a["headers"])

    assert client.get("/transactions", headers=b["headers"]).json() == []
    r = client.put(f"/transactions/{tx['id']}", json={"amount": 1}, headers=b["headers"])
    assert r.status_code == 404
    client.delete(f"/transactions/{tx['id']}", headers=b["headers"])

    mine = client.get("/transactions", headers=a["headers"]).json()
    assert len(mine) == 1 and mine[0]["amount"] == 100


def test_budgets_are_isolated(client, make_user):
    a, b = make_user(), make_user()
    budget = client.post(
        "/budgets", json={"category": "Yemek", "monthly_limit": 500}, headers=a["headers"]
    ).json()

    assert client.get("/budgets", headers=b["headers"]).json() == []
    client.delete(f"/budgets/{budget['id']}", headers=b["headers"])
    assert len(client.get("/budgets", headers=a["headers"]).json()) == 1


def test_goals_are_isolated(client, make_user):
    a, b = make_user(), make_user()
    goal = client.post(
        "/goals", json={"title": "Tatil", "target_amount": 1000}, headers=a["headers"]
    ).json()

    assert client.get("/goals", headers=b["headers"]).json() == []
    r = client.post(f"/goals/{goal['id']}/contribute", json={"amount": 100}, headers=b["headers"])
    assert r.status_code == 404
    assert client.delete(f"/goals/{goal['id']}", headers=b["headers"]).status_code == 404
    assert client.get("/goals", headers=a["headers"]).json()[0]["current_amount"] == 0


def test_analytics_only_counts_own_spending(client, make_user, add_tx):
    a, b = make_user(), make_user()
    add_tx(a["headers"], amount=900)
    r = client.get("/analytics/forecast", headers=b["headers"])
    assert r.json()["current_month_spent"] == 0
