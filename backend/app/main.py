"""Expenza API — uygulama giriş noktası."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import Base, engine
from .routers import (
    analytics,
    auth_router,
    budgets,
    goals,
    ml_router,
    transactions,
    chat,
)

# MVP: tabloları açılışta oluştur. (İleride Alembic migration'a geçilebilir.)
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Expenza API",
    description="Kişisel finans asistanı backend'i — kategorizasyon hero modeli dahil.",
    version="0.1.0",
)

# Flutter (mobil/web) istemcisinin erişebilmesi için CORS açık. Üretimde kısıtlanmalı.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router.router)
app.include_router(transactions.router)
app.include_router(budgets.router)
app.include_router(ml_router.router)
app.include_router(analytics.router)
app.include_router(goals.router)
app.include_router(chat.router)


@app.get("/", tags=["health"])
def health():
    return {"status": "ok", "app": "Expenza API", "version": "0.1.0"}
