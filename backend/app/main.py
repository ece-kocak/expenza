"""Expenza API — uygulama giriş noktası."""
import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import recurring
from .config import settings
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
    docs_url="/docs" if settings.docs_enabled else None,
    redoc_url="/redoc" if settings.docs_enabled else None,
    openapi_url="/openapi.json" if settings.docs_enabled else None,
)

# Kimlik doğrulama çerez değil Authorization başlığıyla yapıldığı için credentials
# gerekmez. Mobil uygulama tarayıcı olmadığından CORS'tan etkilenmez.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",") if o.strip()],
    allow_origin_regex=settings.cors_origin_regex or None,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)


@app.middleware("http")
async def security_headers(request, call_next):
    response = await call_next(request)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "no-referrer")
    if request.url.scheme == "https":
        response.headers.setdefault(
            "Strict-Transport-Security", "max-age=31536000; includeSubDomains"
        )
    return response

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
