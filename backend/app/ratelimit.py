"""Bellek içi istek sınırlayıcı (kayan pencere).

Tek süreçli kurulum için yeterlidir. Birden fazla sunucu süreci çalıştırılırsa her süreç
kendi sayacını tutar; o durumda Redis gibi paylaşılan bir depo gerekir.
"""
import threading
import time
from collections import defaultdict, deque

from fastapi import Depends, HTTPException, Request, status

from . import models
from .auth import get_current_user


class RateLimiter:
    def __init__(self, limit: int, window_seconds: float):
        self.limit = limit
        self.window = window_seconds
        self._hits: dict[str, deque] = defaultdict(deque)
        self._lock = threading.Lock()

    def _purge(self, key: str, now: float) -> deque:
        hits = self._hits[key]
        while hits and now - hits[0] > self.window:
            hits.popleft()
        return hits

    def is_limited(self, key: str) -> bool:
        with self._lock:
            return len(self._purge(key, time.monotonic())) >= self.limit

    def add(self, key: str) -> None:
        with self._lock:
            self._purge(key, time.monotonic()).append(time.monotonic())

    def hit(self, key: str) -> bool:
        """İsteği sayar; sınır zaten dolmuşsa saymadan False döner."""
        with self._lock:
            now = time.monotonic()
            hits = self._purge(key, now)
            if len(hits) >= self.limit:
                return False
            hits.append(now)
            return True

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()


login_by_ip = RateLimiter(limit=20, window_seconds=60)
# Aynı e-posta için 15 dakikada 5 hatalı parola: sonrası doğru parolayla da beklemeli.
login_failures_by_email = RateLimiter(limit=5, window_seconds=15 * 60)
register_by_ip = RateLimiter(limit=10, window_seconds=60 * 60)
chat_by_user = RateLimiter(limit=20, window_seconds=60)
categorize_by_user = RateLimiter(limit=60, window_seconds=60)

_ALL = (login_by_ip, login_failures_by_email, register_by_ip, chat_by_user, categorize_by_user)


def reset_all() -> None:
    for limiter in _ALL:
        limiter.reset()


def too_many() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail="Çok fazla istek. Biraz bekleyip tekrar dene.",
    )


def client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def enforce(limiter: RateLimiter, key: str) -> None:
    if not limiter.hit(key):
        raise too_many()


def limit_chat(user: models.User = Depends(get_current_user)) -> None:
    enforce(chat_by_user, str(user.id))


def limit_categorize(user: models.User = Depends(get_current_user)) -> None:
    enforce(categorize_by_user, str(user.id))
