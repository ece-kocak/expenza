"""Uygulama ayarları.

Değerler ortam değişkenlerinden veya backend/.env dosyasından okunur (ortam değişkeni
önceliklidir). Örnek dosya: backend/.env.example
"""
from pathlib import Path
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # JWT imza anahtarı. Varsayılanı bilerek yok; auth modülü boşsa açılışta hata verir.
    secret_key: Optional[str] = None
    # Göreli yol yerine backend klasörüne sabitlenir; backend nereden başlatılırsa
    # başlatılsın aynı veritabanı dosyası kullanılır.
    database_url: str = f"sqlite:///{(BACKEND_DIR / 'expenza.db').as_posix()}"
    # Tanımlı değilse sohbet ve Gemini sınıflandırıcı devre dışı kalır.
    gemini_api_key: Optional[str] = None


settings = Settings()
