"""Google Gemini API istemcisi.

Sohbet asistanı ve (ayarla açılırsa) kategori sınıflandırıcı bu modülü kullanır.
API anahtarı URL'de değil x-goog-api-key başlığında gönderilir; hata ayrıntıları
istemciye değil sunucu loguna yazılır.
"""
import logging
from typing import Optional

import httpx

from .config import settings

log = logging.getLogger(__name__)

API_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"


class GeminiError(Exception):
    """Gemini'den kullanılabilir bir cevap alınamadı."""


def enabled() -> bool:
    return bool(settings.gemini_api_key)


def generate(
    user_text: str,
    *,
    model: str,
    system: Optional[str] = None,
    timeout: float = 30.0,
) -> str:
    """Tek turluk istek gönderir ve modelin metin cevabını döndürür.

    Kullanıcı metni ile sistem talimatı ayrı alanlarda gider; kullanıcı metni talimatın
    içine yapıştırılmaz.
    """
    if not enabled():
        raise GeminiError("GEMINI_API_KEY tanımlı değil")

    body: dict = {"contents": [{"role": "user", "parts": [{"text": user_text}]}]}
    if system:
        body["systemInstruction"] = {"parts": [{"text": system}]}

    try:
        response = httpx.post(
            API_URL.format(model=model),
            json=body,
            headers={"x-goog-api-key": settings.gemini_api_key},
            timeout=timeout,
        )
    except httpx.HTTPError as exc:
        log.warning("Gemini isteği başarısız: %s", type(exc).__name__)
        raise GeminiError("bağlantı hatası") from exc

    if response.status_code != 200:
        log.warning("Gemini %s döndürdü: %s", response.status_code, response.text[:500])
        raise GeminiError(f"HTTP {response.status_code}")

    try:
        return response.json()["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        log.warning("Gemini cevabı beklenen biçimde değil")
        raise GeminiError("beklenmeyen cevap") from exc
