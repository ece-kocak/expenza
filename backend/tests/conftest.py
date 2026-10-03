"""Ortak test ayarları.

Ortam değişkenleri uygulama import edilmeden önce ayarlanır: testler geçici bir SQLite
dosyası kullanır, Gemini kapalıdır ve backend/.env'deki değerler ezilir.
"""
import os
import tempfile
import uuid
from pathlib import Path

import pytest

_TMP_DIR = Path(tempfile.mkdtemp(prefix="expenza-test-"))
os.environ["DATABASE_URL"] = f"sqlite:///{(_TMP_DIR / 'test.db').as_posix()}"
os.environ["SECRET_KEY"] = "test-" + "x" * 40
os.environ["GEMINI_API_KEY"] = ""

from fastapi.testclient import TestClient  # noqa: E402

from app import models, ratelimit  # noqa: E402
from app.database import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402

BACKEND_DIR = Path(__file__).resolve().parent.parent


@pytest.fixture(scope="session")
def client():
    return TestClient(app)


@pytest.fixture(autouse=True)
def _clean_db():
    ratelimit.reset_all()
    yield
    with SessionLocal() as db:
        for model in (
            models.Transaction,
            models.RecurringSeries,
            models.Budget,
            models.Goal,
            models.User,
        ):
            db.query(model).delete()
        db.commit()


@pytest.fixture
def make_user(client):
    """Kayıt olup giriş yapan ve token başlığını döndüren yardımcı."""

    def _make(password: str = "parola123", name: str = "Test"):
        email = f"u-{uuid.uuid4().hex[:10]}@example.com"
        r = client.post(
            "/auth/register",
            json={"email": email, "password": password, "display_name": name},
        )
        assert r.status_code == 201, r.text
        r = client.post("/auth/login", data={"username": email, "password": password})
        token = r.json()["access_token"]
        return {"email": email, "headers": {"Authorization": f"Bearer {token}"}}

    return _make


@pytest.fixture
def user(make_user):
    return make_user()


@pytest.fixture
def add_tx(client):
    """İşlem ekleyip JSON cevabını döndüren yardımcı."""

    def _add(headers, **fields):
        body = {"amount": 100, "type": "expense", "category": "Yemek", "note": "kahve"}
        body.update(fields)
        r = client.post("/transactions", json=body, headers=headers)
        assert r.status_code == 201, r.text
        return r.json()

    return _add
