"""Expenza API — uygulama giriş noktası."""
import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import recurring
from .migrate import upgrade_database
from .routers import (
    analytics,
    auth_router,
    budgets,
    goals,
    ml_router,
    transactions,
    chat,
)

log = logging.getLogger(__name__)

# Şemayı açılışta en son migration'a getir (backend/migrations).
upgrade_database()

# Tekrarlayan serilerin eksik aylarını üretme aralığı (açılışta bir kez de çalışır).
RECURRING_INTERVAL_SECONDS = 60 * 60


async def _recurring_loop() -> None:
    while True:
        try:
            await asyncio.to_thread(recurring.materialize_all)
        except Exception:
            log.exception("Tekrarlayan işlemler üretilemedi")
        await asyncio.sleep(RECURRING_INTERVAL_SECONDS)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    task = asyncio.create_task(_recurring_loop())
    yield
    task.cancel()


app = FastAPI(
    title="Expenza API",
    description="Kişisel finans asistanı backend'i — kategorizasyon hero modeli dahil.",
    version="0.1.0",
    lifespan=lifespan,
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
