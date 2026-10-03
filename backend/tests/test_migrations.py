"""Migration'lar: modellerle uyum ve eski (create_all) veritabanlarının güncellenmesi.

Uygulamanın veritabanı bağlantısı açılışta kurulduğu için bu testler ayrı süreçlerde çalışır.
"""
import os
import sqlite3
import subprocess
import sys

from conftest import BACKEND_DIR

LEGACY_SCHEMA = """
CREATE TABLE users (
    id INTEGER NOT NULL PRIMARY KEY, email VARCHAR(255) NOT NULL,
    hashed_password VARCHAR(255) NOT NULL, display_name VARCHAR(120) NOT NULL,
    created_at DATETIME DEFAULT (CURRENT_TIMESTAMP) NOT NULL);
CREATE TABLE transactions (
    id INTEGER NOT NULL PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users (id),
    amount FLOAT NOT NULL, type VARCHAR(7) NOT NULL, category VARCHAR(9) NOT NULL,
    auto_categorized BOOLEAN NOT NULL, note VARCHAR(500) NOT NULL, occurred_on DATE NOT NULL,
    created_at DATETIME DEFAULT (CURRENT_TIMESTAMP) NOT NULL);
CREATE TABLE budgets (
    id INTEGER NOT NULL PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users (id),
    category VARCHAR(9) NOT NULL, monthly_limit FLOAT NOT NULL);
CREATE TABLE goals (
    id INTEGER NOT NULL PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users (id),
    title VARCHAR(120) NOT NULL, target_amount FLOAT NOT NULL, current_amount FLOAT NOT NULL,
    deadline DATE, created_at DATETIME DEFAULT (CURRENT_TIMESTAMP) NOT NULL);
INSERT INTO users (id, email, hashed_password, display_name) VALUES (1, 'eski@example.com', 'x', 'Eski');
INSERT INTO transactions (user_id, amount, type, category, auto_categorized, note, occurred_on)
VALUES (1, 42.5, 'expense', 'yemek', 0, 'kahve', '2026-01-10');
"""


def _run(code_or_args, db_path):
    env = {**os.environ, "DATABASE_URL": f"sqlite:///{db_path.as_posix()}"}
    args = code_or_args if isinstance(code_or_args, list) else ["-c", code_or_args]
    return subprocess.run(
        [sys.executable, *args], cwd=BACKEND_DIR, env=env, capture_output=True, text=True
    )


def test_migrations_match_models(tmp_path):
    db = tmp_path / "fresh.db"
    upgrade = _run("from app.migrate import upgrade_database; upgrade_database()", db)
    assert upgrade.returncode == 0, upgrade.stderr
    check = _run(["-m", "alembic", "check"], db)
    assert check.returncode == 0, check.stdout + check.stderr


def test_legacy_database_is_upgraded_without_data_loss(tmp_path):
    db = tmp_path / "legacy.db"
    con = sqlite3.connect(db)
    con.executescript(LEGACY_SCHEMA)
    con.close()

    r = _run("from app.migrate import upgrade_database; upgrade_database()", db)
    assert r.returncode == 0, r.stderr

    con = sqlite3.connect(db)
    columns = [row[1] for row in con.execute("PRAGMA table_info(transactions)")]
    rows = con.execute("SELECT note, is_recurring FROM transactions").fetchall()
    version = con.execute("SELECT version_num FROM alembic_version").fetchone()[0]
    con.close()

    assert "is_recurring" in columns
    assert rows == [("kahve", 0)]
    head = _run(["-m", "alembic", "heads"], db).stdout.split()[0]
    assert version == head


def test_old_recurring_rows_are_linked_to_series(tmp_path):
    db = tmp_path / "recurring.db"
    r = _run(["-m", "alembic", "upgrade", "0002"], db)
    assert r.returncode == 0, r.stderr

    con = sqlite3.connect(db)
    con.execute(
        "INSERT INTO users (id, email, hashed_password, display_name) VALUES (1, 'a@example.com', 'x', 'A')"
    )
    rows = [
        # (tutar, not, tarih, is_recurring) - eski kodun ürettiği türden kayıtlar
        (1000, "Maaş", "2026-01-31", 1),
        (1000, "Maaş", "2026-02-28", 1),
        (1000, "Maaş", "2026-03-28", 1),  # 28'den kayan kopya
        (1000, "Maaş", "2026-03-31", 1),
        (1000, "Maaş", "2026-03-31", 1),  # aynı güne düşen birebir kopya
        (300, "Kira", "2026-02-01", 1),
        (50, "kahve", "2026-02-02", 0),
    ]
    con.executemany(
        "INSERT INTO transactions (user_id, amount, type, category, auto_categorized, is_recurring, note, occurred_on) "
        "VALUES (1, ?, 'income', 'diger', 0, ?, ?, ?)",
        [(amount, flag, note, day) for amount, note, day, flag in rows],
    )
    con.commit()
    con.close()

    r = _run("from app.migrate import upgrade_database; upgrade_database()", db)
    assert r.returncode == 0, r.stderr

    con = sqlite3.connect(db)
    series = con.execute(
        "SELECT note, day_of_month, last_generated_on, active FROM recurring_series ORDER BY note"
    ).fetchall()
    linked = con.execute(
        "SELECT occurred_on FROM transactions WHERE note = 'Maaş' AND series_id IS NOT NULL ORDER BY occurred_on"
    ).fetchall()
    unlinked = con.execute(
        "SELECT occurred_on, is_recurring FROM transactions WHERE note = 'Maaş' AND series_id IS NULL"
    ).fetchall()
    total = con.execute("SELECT count(*) FROM transactions").fetchone()[0]
    con.close()

    assert series == [("Kira", 1, "2026-02-01", 1), ("Maaş", 31, "2026-03-31", 1)]
    assert [d for (d,) in linked] == ["2026-01-31", "2026-02-28", "2026-03-28", "2026-03-31"]
    assert unlinked == [("2026-03-31", 0)]
    assert total == len(rows)  # hiçbir kayıt silinmedi
