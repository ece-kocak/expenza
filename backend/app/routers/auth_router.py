"""Kayıt ve giriş uçları."""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from .. import auth, models, schemas
from ..database import get_db

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=schemas.UserOut, status_code=201)
def register(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.email == payload.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Bu e-posta zaten kayıtlı")
    user = models.User(
        email=payload.email,
        hashed_password=auth.hash_password(payload.password),
        display_name=payload.display_name,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=schemas.Token)
def login(
    form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)
):
    # OAuth2 form 'username' alanını e-posta olarak kullanıyoruz.
    user = db.query(models.User).filter(models.User.email == form.username).first()
    if not user or not auth.verify_password(form.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-posta veya parola hatalı",
        )
    return schemas.Token(access_token=auth.create_access_token(user.email))


@router.get("/me", response_model=schemas.UserOut)
def me(current: models.User = Depends(auth.get_current_user)):
    return current


@router.post("/me/ai-consent", response_model=schemas.UserOut)
def give_ai_consent(
    current: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)
):
    """Sohbet asistanı için verilerin Google Gemini'ye gönderilmesine onay verir."""
    current.ai_consent_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.commit()
    db.refresh(current)
    return current


@router.delete("/me/ai-consent", response_model=schemas.UserOut)
def withdraw_ai_consent(
    current: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)
):
    """Onayı geri çeker; sohbet asistanı tekrar onay verilene kadar kullanılamaz."""
    current.ai_consent_at = None
    db.commit()
    db.refresh(current)
    return current
