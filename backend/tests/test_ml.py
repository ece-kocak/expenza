"""Kategori önerisi ucu ve yerel model."""
from app.ml import categorizer
from app.models import CategoryEnum


def test_categorize_returns_known_category(client, user):
    r = client.post("/ml/categorize", json={"text": "uber ile eve döndüm"}, headers=user["headers"])
    assert r.status_code == 200
    body = r.json()
    assert body["category"] == "Ulaşım"
    assert 0 <= body["confidence"] <= 1
    # Gemini testlerde kapalı; cevap yerel modelden gelmeli.
    assert body["model"] in {"baseline-svm-v1", "rule-stub-v1"}


def test_categorize_rejects_long_text(client, user):
    r = client.post("/ml/categorize", json={"text": "x" * 501}, headers=user["headers"])
    assert r.status_code == 422


def test_trained_model_is_loaded():
    # Model scikit-learn sürümüyle uyumsuz olursa kod sessizce kural tabanlı yedeğe düşer.
    assert categorizer._active.name == "baseline-svm-v1"


def test_rule_stub_fallback():
    stub = categorizer.RuleBasedCategorizer()
    assert stub.predict("eczaneden ilaç")[0] == CategoryEnum.saglik
    assert stub.predict("")[0] == CategoryEnum.diger
