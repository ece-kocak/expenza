"""Veritabanı şemasını uygulama açılışında en son migration'a getirir."""
from alembic import command
from alembic.config import Config
from sqlalchemy import inspect

from .config import BACKEND_DIR
from .database import engine

# Alembic'ten önce create_all ile oluşturulmuş veritabanlarının karşılık geldiği revizyon.
BASELINE_REVISION = "0001"


def upgrade_database() -> None:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.attributes["skip_logging"] = True

    tables = set(inspect(engine).get_table_names())
    if "users" in tables and "alembic_version" not in tables:
        # Eski kurulum: tablolar var ama sürüm kaydı yok. Başlangıç şemasında sayılır,
        # sonraki migration'lar eksik kalanları tamamlar.
        command.stamp(cfg, BASELINE_REVISION)
    command.upgrade(cfg, "head")
