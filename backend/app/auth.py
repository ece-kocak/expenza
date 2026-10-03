"""Kimlik doğrulama: parola hashleme + JWT üretimi/çözümü.

SECRET_KEY zorunludur ve ortam değişkeninden ya da backend/.env dosyasından gelir.
"""
import secrets
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jwt import InvalidTokenError
from sqlalchemy.orm import Session

from . import models
from .config import settings
from .database import get_db

MIN_SECRET_LENGTH = 32

if not settings.secret_key or len(settings.secret_key) < MIN_SECRET_LENGTH:
    raise RuntimeError(
        f"SECRET_KEY tanımlı değil ya da {MIN_SECRET_LENGTH} karakterden kısa. "
        "backend/.env dosyasına (örnek: backend/.env.example) rastgele bir değer ekleyin: "
        'python -c "import secrets; print(secrets.token_urlsafe(48))"'
    )

SECRET_KEY = settings.secret_key
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 1 hafta

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")


def hash_password(password: str) -> str:
    # bcrypt 72 bayt sınırına sahip; daha uzun parolaları güvenle kısaltıyoruz.
    pw = password.encode("utf-8")[:72]
    return bcrypt.hashpw(pw, bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    pw = plain.encode("utf-8")[:72]
    try:
        return bcrypt.checkpw(pw, hashed.encode("utf-8"))
    except ValueError:
        return False


# Kullanıcı bulunamadığında da bir bcrypt kontrolü yapılır; böylece cevap süresi
# e-postanın kayıtlı olup olmadığını ele vermez.
DUMMY_PASSWORD_HASH = hash_password(secrets.token_urlsafe(16))


def create_access_token(subject: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": subject,
        "iat": now,
        "exp": now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(
    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)
) -> models.User:
    cred_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Geçersiz kimlik bilgisi",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(
            token, SECRET_KEY, algorithms=[ALGORITHM], options={"require": ["exp", "sub"]}
        )
    except InvalidTokenError:
        raise cred_error
    email = payload["sub"]

    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise cred_error
    return user
