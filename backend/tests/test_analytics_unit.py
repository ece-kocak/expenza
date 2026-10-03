"""Tahmin, anomali ve içgörü hesaplarının birim testleri (veritabanı gerektirmez)."""
from datetime import date
from types import SimpleNamespace

from app.ml.analytics import detect_anomalies, forecast_spending
from app.ml.insights import generate_insights
from app.models import CategoryEnum, TxType

_ids = iter(range(1, 10_000))


def tx(amount, day, category=CategoryEnum.yemek, type_=TxType.expense):
    return SimpleNamespace(
        id=next(_ids), amount=amount, occurred_on=day, category=category, type=type_, note=""
    )


def test_run_rate_when_there_is_no_history():
    result = forecast_spending([tx(100, date(2026, 3, 5))], today=date(2026, 3, 10))
    assert result["method"] == "run_rate"
    # 10 günde 100 harcandıysa 31 günlük ayın sonunda 310 beklenir.
    assert result["projected_month_end"] == 310
    assert result["next_month_prediction"] == 310


def test_last_month_when_there_is_one_complete_month():
    txs = [tx(400, date(2026, 2, 10)), tx(50, date(2026, 3, 2))]
    result = forecast_spending(txs, today=date(2026, 3, 10))
    assert result["method"] == "last_month"
    assert result["next_month_prediction"] == 400


def test_linear_trend_over_complete_months():
    txs = [tx(100, date(2026, 1, 5)), tx(200, date(2026, 2, 5)), tx(300, date(2026, 3, 5))]
    result = forecast_spending(txs, today=date(2026, 4, 10))
    assert result["method"] == "trend"
    assert result["next_month_prediction"] == 400
    assert [h["month"] for h in result["history"]] == ["2026-01", "2026-02", "2026-03"]


def test_income_is_ignored_in_forecast():
    txs = [tx(5000, date(2026, 3, 1), type_=TxType.income)]
    assert forecast_spending(txs, today=date(2026, 3, 10))["current_month_spent"] == 0


def test_outlier_is_flagged():
    txs = [tx(50, date(2026, 3, d)) for d in range(1, 10)] + [tx(500, date(2026, 3, 20))]
    anomalies = detect_anomalies(txs)
    assert len(anomalies) == 1
    assert anomalies[0]["amount"] == 500


def test_too_few_samples_are_not_evaluated():
    txs = [tx(50, date(2026, 3, 1)), tx(50, date(2026, 3, 2)), tx(5000, date(2026, 3, 3))]
    assert detect_anomalies(txs) == []


def test_insights_without_data():
    insights = generate_insights([], today=date(2026, 3, 10))
    assert insights[0]["title"] == "Henüz yeterli veri yok"


def test_insights_report_spending_increase():
    txs = [tx(100, date(2026, 2, 5)), tx(200, date(2026, 3, 5))]
    titles = [i["title"] for i in generate_insights(txs, today=date(2026, 3, 10))]
    assert "Harcaman arttı" in titles
