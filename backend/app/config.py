"""Uygulama ayarları.

Değerler ortam değişkenlerinden veya backend/.env dosyasından okunur (ortam değişkeni
önceliklidir). Örnek dosya: backend/.env.example
"""
from pathlib import Path
from typing import Literal, Optional

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
    gemini_chat_model: str = "gemini-2.5-flash"
    gemini_categorizer_model: str = "gemini-2.5-flash"
    # Kategori önerisi varsayılan olarak projede eğitilen yerel modelden gelir.
    # "gemini" yapılırsa önce Gemini denenir (kıyas için); not metni Google'a gider.
    categorizer: Literal["local", "gemini"] = "local"

    # Web istemcisinin yayınlandığı adresler, virgülle ayrılmış (ör. https://expenza.app).
    cors_origins: str = ""
    # Geliştirmede Flutter web her seferinde farklı bir localhost portu kullanır.
    cors_origin_regex: str = r"http://(localhost|127\.0\.0\.1)(:\d+)?"
    # Yayında kapatılabilir: /docs, /redoc ve /openapi.json.
    docs_enabled: bool = True


settings = Settings()
