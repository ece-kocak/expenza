"""İstek sınırları, parola kuralı, CORS, güvenlik başlıkları ve API belgeleri."""
import os
import subprocess
import sys

import pytest

from app import llm
from app.config import settings
from conftest import BACKEND_DIR


def test_repeated_wrong_passwords_lock_the_account_temporarily(client, user):
    for _ in range(5):
        r = client.post("/auth/login", data={"username": user["email"], "password": "yanlis-123"})
        assert r.status_code == 401
    # Altıncı denemede doğru parola da kabul edilmez.
    r = client.post("/auth/login", data={"username": user["email"], "password": "parola123"})
    assert r.status_code == 429


def test_login_attempts_are_limited_per_ip(client):
    codes = [
        client.post("/auth/login", data={"username": f"x{i}@example.com", "password": "x"}).status_code
        for i in range(21)
    ]
    assert codes[:20] == [401] * 20 and codes[20] == 429


def test_registrations_are_limited_per_ip(client):
    codes = [
        client.post(
            "/auth/register", json={"email": f"k{i}@example.com", "password": "parola123"}
        ).status_code
        for i in range(11)
    ]
    assert codes[:10] == [201] * 10 and codes[10] == 429


def test_chat_is_limited_per_user(client, user, monkeypatch):
    monkeypatch.setattr(settings, "gemini_api_key", "k")
    monkeypatch.setattr(llm, "generate", lambda *a, **k: "tamam")
    client.post("/auth/me/ai-consent", headers=user["headers"])
    codes = [
        client.post("/chat", json={"message": "x"}, headers=user["headers"]).status_code
        for _ in range(21)
    ]
    assert codes[:20] == [200] * 20 and codes[20] == 429


@pytest.mark.parametrize(
    "password,message",
    [
        ("kisa1", "en az 8 karakter"),
        ("sadeceharf", "harf ve bir rakam"),
        ("12345678", "harf ve bir rakam"),
    ],
)
def test_weak_passwords_are_rejected_with_turkish_message(client, password, message):
    r = client.post("/auth/register", json={"email": "p@example.com", "password": password})
    assert r.status_code == 422
    assert message in r.json()["detail"][0]["msg"]


def test_cors_allows_localhost_dev_ports_only(client):
    def preflight(origin):
        return client.options(
            "/transactions",
            headers={"Origin": origin, "Access-Control-Request-Method": "GET"},
        ).headers.get("access-control-allow-origin")

    assert preflight("http://localhost:53812") == "http://localhost:53812"
    assert preflight("https://kotu-site.example") is None


def test_security_headers_are_set(client):
    headers = client.get("/").headers
    assert headers["x-content-type-options"] == "nosniff"
    assert headers["x-frame-options"] == "DENY"
    assert headers["referrer-policy"] == "no-referrer"


def test_docs_can_be_disabled(tmp_path):
    env = {
        **os.environ,
        "DOCS_ENABLED": "false",
        "DATABASE_URL": f"sqlite:///{(tmp_path / 'docs.db').as_posix()}",
    }
    code = (
        "from fastapi.testclient import TestClient; from app.main import app; "
        "c = TestClient(app); "
        "print(c.get('/docs').status_code, c.get('/openapi.json').status_code)"
    )
    r = subprocess.run(
        [sys.executable, "-c", code], cwd=BACKEND_DIR, env=env, capture_output=True, text=True
    )
    # Önceki satırlarda modelin yüklendiğine dair açılış mesajı olabilir.
    assert r.stdout.strip().splitlines()[-1] == "404 404", r.stdout + r.stderr
