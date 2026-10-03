"""Kayıt, giriş ve token doğrulama."""
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone

import jwt

from app.auth import ALGORITHM, SECRET_KEY
from conftest import BACKEND_DIR


def test_register_returns_user_without_password(client):
    r = client.post(
        "/auth/register",
        json={"email": "a@example.com", "password": "parola123", "display_name": "A"},
    )
    assert r.status_code == 201
    body = r.json()
    assert body["email"] == "a@example.com"
    assert "password" not in body and "hashed_password" not in body


def test_login_returns_bearer_token(client, user):
    r = client.post("/auth/login", data={"username": user["email"], "password": "parola123"})
    assert r.status_code == 200
    assert r.json()["token_type"] == "bearer"


def test_duplicate_email_rejected(client, user):
    r = client.post("/auth/register", json={"email": user["email"], "password": "parola123"})
    assert r.status_code == 400


def test_short_password_rejected(client):
    r = client.post("/auth/register", json={"email": "b@example.com", "password": "123"})
    assert r.status_code == 422


def test_wrong_password_and_unknown_user_give_same_error(client, user):
    wrong = client.post("/auth/login", data={"username": user["email"], "password": "yanlis-parola"})
    unknown = client.post("/auth/login", data={"username": "yok@example.com", "password": "x"})
    assert wrong.status_code == unknown.status_code == 401
    assert wrong.json()["detail"] == unknown.json()["detail"]


def test_me_requires_token(client):
    assert client.get("/auth/me").status_code == 401


def test_me_returns_current_user(client, user):
    r = client.get("/auth/me", headers=user["headers"])
    assert r.status_code == 200
    assert r.json()["email"] == user["email"]


def test_token_signed_with_another_secret_is_rejected(client, user):
    forged = jwt.encode(
        {"sub": user["email"], "exp": datetime.now(timezone.utc) + timedelta(hours=1)},
        "baska-bir-anahtar-" * 3,
        algorithm="HS256",
    )
    r = client.get("/auth/me", headers={"Authorization": f"Bearer {forged}"})
    assert r.status_code == 401


def test_token_without_expiry_is_rejected(client, user):
    no_exp = jwt.encode({"sub": user["email"]}, SECRET_KEY, algorithm=ALGORITHM)
    r = client.get("/auth/me", headers={"Authorization": f"Bearer {no_exp}"})
    assert r.status_code == 401


def test_unsigned_token_is_rejected(client, user):
    unsigned = jwt.encode(
        {"sub": user["email"], "exp": datetime.now(timezone.utc) + timedelta(hours=1)},
        key=None,
        algorithm="none",
    )
    r = client.get("/auth/me", headers={"Authorization": f"Bearer {unsigned}"})
    assert r.status_code == 401


def test_expired_token_is_rejected(client, user):
    expired = jwt.encode(
        {"sub": user["email"], "exp": datetime.now(timezone.utc) - timedelta(minutes=1)},
        SECRET_KEY,
        algorithm=ALGORITHM,
    )
    r = client.get("/auth/me", headers={"Authorization": f"Bearer {expired}"})
    assert r.status_code == 401


def test_backend_refuses_to_start_without_secret(tmp_path):
    env = {
        **os.environ,
        "SECRET_KEY": "",
        "DATABASE_URL": f"sqlite:///{(tmp_path / 'x.db').as_posix()}",
    }
    r = subprocess.run(
        [sys.executable, "-c", "import app.main"],
        cwd=BACKEND_DIR, env=env, capture_output=True, text=True,
    )
    assert r.returncode != 0
    assert "SECRET_KEY" in r.stderr
