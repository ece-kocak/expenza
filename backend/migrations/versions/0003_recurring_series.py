"""Tekrarlayan işlem serileri

recurring_series tablosu ve transactions.series_id eklenir. Eski düzende tekrarlayan
işlemler is_recurring bayrağıyla tutuluyor ve kopyalar da kaynak gibi işlendiği için
çift kayıt oluşabiliyordu. Mevcut is_recurring kayıtları aynı şablona (kullanıcı, tür,
kategori, tutar, not) göre gruplanıp birer seriye bağlanır. Aynı seride aynı güne düşen
birebir kopyalar silinmez; seriden ayrılır ve tekrarlayan sayılmaz.

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-03

"""
from collections import defaultdict
from datetime import date
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0003"
down_revision: Union[str, Sequence[str], None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TX_TYPE = sa.Enum("income", "expense", name="txtype")
CATEGORY = sa.Enum(
    "yemek", "ulasim", "faturalar", "eglence", "saglik", "egitim", "alisveris",
    "diger", "toplam",
    name="categoryenum",
)


def upgrade() -> None:
    op.create_table(
        "recurring_series",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("type", TX_TYPE, nullable=False),
        sa.Column("category", CATEGORY, nullable=False),
        sa.Column("note", sa.String(length=500), nullable=False),
        sa.Column("day_of_month", sa.Integer(), nullable=False),
        sa.Column("start_on", sa.Date(), nullable=False),
        sa.Column("last_generated_on", sa.Date(), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.text("(CURRENT_TIMESTAMP)"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("recurring_series", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_recurring_series_user_id"), ["user_id"], unique=False)

    with op.batch_alter_table("transactions", schema=None) as batch_op:
        batch_op.add_column(sa.Column("series_id", sa.Integer(), nullable=True))
        batch_op.create_index(batch_op.f("ix_transactions_series_id"), ["series_id"], unique=False)

    _link_existing_recurring()

    with op.batch_alter_table("transactions", schema=None) as batch_op:
        batch_op.create_unique_constraint("uq_transactions_series_day", ["series_id", "occurred_on"])
        batch_op.create_foreign_key(
            "fk_transactions_series_id", "recurring_series", ["series_id"], ["id"]
        )


def _link_existing_recurring() -> None:
    bind = op.get_bind()
    series_table = sa.Table(
        "recurring_series",
        sa.MetaData(),
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("user_id", sa.Integer),
        sa.Column("amount", sa.Float),
        sa.Column("type", sa.String),
        sa.Column("category", sa.String),
        sa.Column("note", sa.String),
        sa.Column("day_of_month", sa.Integer),
        sa.Column("start_on", sa.Date),
        sa.Column("last_generated_on", sa.Date),
        sa.Column("active", sa.Boolean),
    )
    rows = bind.execute(
        sa.text(
            "SELECT id, user_id, amount, type, category, note, occurred_on "
            "FROM transactions WHERE is_recurring = :yes ORDER BY occurred_on, id"
        ),
        {"yes": True},
    ).mappings().all()

    groups = defaultdict(list)
    for row in rows:
        groups[(row["user_id"], row["type"], row["category"], row["amount"], row["note"])].append(row)

    for (user_id, type_, category, amount, note), items in groups.items():
        days = [date.fromisoformat(str(item["occurred_on"])) for item in items]
        series_id = bind.execute(
            series_table.insert().values(
                user_id=user_id, amount=amount, type=type_, category=category, note=note,
                day_of_month=days[0].day, start_on=days[0], last_generated_on=max(days),
                active=True,
            )
        ).inserted_primary_key[0]

        seen = set()
        for item, day in zip(items, days):
            if day in seen:
                bind.execute(
                    sa.text("UPDATE transactions SET is_recurring = :no WHERE id = :id"),
                    {"no": False, "id": item["id"]},
                )
                continue
            seen.add(day)
            bind.execute(
                sa.text("UPDATE transactions SET series_id = :sid WHERE id = :id"),
                {"sid": series_id, "id": item["id"]},
            )


def downgrade() -> None:
    with op.batch_alter_table("transactions", schema=None) as batch_op:
        batch_op.drop_constraint("fk_transactions_series_id", type_="foreignkey")
        batch_op.drop_constraint("uq_transactions_series_day", type_="unique")
        batch_op.drop_index(batch_op.f("ix_transactions_series_id"))
        batch_op.drop_column("series_id")

    with op.batch_alter_table("recurring_series", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_recurring_series_user_id"))
    op.drop_table("recurring_series")
