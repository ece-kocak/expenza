"""Alembic ortamı: bağlantı ve şema uygulamanın kendi ayarlarından alınır."""
from logging.config import fileConfig

from alembic import context

from app import models  # noqa: F401  (tabloları Base.metadata'ya kaydeder)
from app.config import settings
from app.database import Base, engine

config = context.config

# Uygulama açılışında (app/migrate.py) çağrıldığında uvicorn'un log ayarları bozulmasın.
if config.config_file_name is not None and not config.attributes.get("skip_logging"):
    fileConfig(config.config_file_name, disable_existing_loggers=False)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Veritabanına bağlanmadan SQL çıktısı üretir (alembic upgrade --sql)."""
    context.configure(
        url=settings.database_url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        render_as_batch=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    with engine.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            # SQLite'ın ALTER TABLE desteği sınırlı; batch modu gerektiğinde tabloyu
            # yeniden oluşturarak değiştirir.
            render_as_batch=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
