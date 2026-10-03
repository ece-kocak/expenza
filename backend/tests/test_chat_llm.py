"""Sohbet asistanı, açık rıza ve Gemini istemcisi (gerçek istek atılmaz)."""
import httpx
import pytest

from app import llm
from app.config import settings
from app.ml import categorizer
from app.models import CategoryEnum


@pytest.fixture
def gemini_on(monkeypatch):
    """Gemini anahtarı tanımlıymış gibi davranır ve gönderilen istekleri kaydeder."""
    monkeypatch.setattr(settings, "gemini_api_key", "test-key")
    calls = []

    def fake_generate(user_text, *, model, system=None, timeout=30.0):
        calls.append({"user_text": user_text, "model": model, "system": system})
        return "Bu ay harcaman dengeli görünüyor."

    monkeypatch.setattr(llm, "generate", fake_generate)
    return calls


def _consent(client, user):
    r = client.post("/auth/me/ai-consent", headers=user["headers"])
    assert r.status_code == 200 and r.json()["ai_consent_at"] is not None


def test_chat_is_off_without_api_key(client, user, monkeypatch):
    monkeypatch.setattr(settings, "gemini_api_key", None)
    r = client.post("/chat", json={"message": "merhaba"}, headers=user["headers"])
    assert r.status_code == 200
    assert "kapalı" in r.json()["reply"]


def test_chat_requires_consent(client, user, gemini_on):
    r = client.post("/chat", json={"message": "bütçem nasıl?"}, headers=user["headers"])
    assert r.status_code == 403
    assert gemini_on == []  # onay yokken hiçbir veri gönderilmez


def test_chat_sends_own_data_separately_from_the_question(client, make_user, add_tx, gemini_on):
    me, other = make_user(name="Ayşe Yılmaz"), make_user()
    add_tx(me["headers"], note="migros market")
    add_tx(other["headers"], note="baskasinin-notu")
    _consent(client, me)

    r = client.post("/chat", json={"message": "Bu ay ne kadar harcadım?"}, headers=me["headers"])
    assert r.status_code == 200
    assert r.json()["reply"] == "Bu ay harcaman dengeli görünüyor."

    call = gemini_on[0]
    assert call["user_text"] == "Bu ay ne kadar harcadım?"
    assert "migros market" in call["system"]
    assert "baskasinin-notu" not in call["system"]
    assert "Ayşe" not in call["system"]  # ad gönderilmiyor


def test_withdrawn_consent_blocks_chat_again(client, user, gemini_on):
    _consent(client, user)
    r = client.delete("/auth/me/ai-consent", headers=user["headers"])
    assert r.json()["ai_consent_at"] is None
    assert client.post("/chat", json={"message": "x"}, headers=user["headers"]).status_code == 403


def test_gemini_failure_returns_generic_error(client, user, monkeypatch):
    monkeypatch.setattr(settings, "gemini_api_key", "test-key")

    def failing(*args, **kwargs):
        raise llm.GeminiError("HTTP 400: API key not valid ...")

    monkeypatch.setattr(llm, "generate", failing)
    _consent(client, user)
    r = client.post("/chat", json={"message": "x"}, headers=user["headers"])
    assert r.status_code == 502
    assert "API key" not in r.json()["detail"]


def test_chat_message_length_is_limited(client, user, gemini_on):
    _consent(client, user)
    r = client.post("/chat", json={"message": "x" * 1001}, headers=user["headers"])
    assert r.status_code == 422


def test_api_key_goes_in_header_not_url(monkeypatch):
    monkeypatch.setattr(settings, "gemini_api_key", "gizli-anahtar")
    seen = {}

    def fake_post(url, json, headers, timeout):
        seen.update(url=url, headers=headers, body=json)
        return httpx.Response(
            200, json={"candidates": [{"content": {"parts": [{"text": "tamam"}]}}]}
        )

    monkeypatch.setattr(llm.httpx, "post", fake_post)
    assert llm.generate("soru", model="m", system="kurallar") == "tamam"
    assert "gizli-anahtar" not in seen["url"]
    assert seen["headers"]["x-goog-api-key"] == "gizli-anahtar"
    assert seen["body"]["systemInstruction"]["parts"][0]["text"] == "kurallar"
    assert seen["body"]["contents"][0]["parts"][0]["text"] == "soru"


def test_gemini_http_error_raises_gemini_error(monkeypatch):
    monkeypatch.setattr(settings, "gemini_api_key", "k")
    monkeypatch.setattr(llm.httpx, "post", lambda *a, **k: httpx.Response(500, text="iç hata"))
    with pytest.raises(llm.GeminiError):
        llm.generate("soru", model="m")


def test_local_model_is_used_even_when_a_key_exists(monkeypatch):
    monkeypatch.setattr(settings, "gemini_api_key", "k")
    monkeypatch.setattr(settings, "categorizer", "local")

    def must_not_call(*args, **kwargs):
        raise AssertionError("Gemini çağrılmamalı")

    monkeypatch.setattr(llm, "generate", must_not_call)
    category, _conf, model = categorizer.categorize("migros market")
    assert category == CategoryEnum.yemek and model == "baseline-svm-v1"


def test_gemini_categorizer_can_be_enabled_for_comparison(monkeypatch):
    monkeypatch.setattr(settings, "gemini_api_key", "k")
    monkeypatch.setattr(settings, "categorizer", "gemini")
    monkeypatch.setattr(
        llm, "generate", lambda *a, **k: '```json\n{"category": "Sağlık", "confidence": 0.8}\n```'
    )
    category, conf, model = categorizer.categorize("eczane")
    assert (category, conf, model) == (CategoryEnum.saglik, 0.8, "gemini-classifier-v1")


def test_gemini_categorizer_falls_back_to_local_model(monkeypatch):
    monkeypatch.setattr(settings, "gemini_api_key", "k")
    monkeypatch.setattr(settings, "categorizer", "gemini")
    monkeypatch.setattr(llm, "generate", lambda *a, **k: "anlamsız cevap")
    assert categorizer.categorize("uber")[2] == "baseline-svm-v1"
