"""transactions.is_recurring sütunu

Tekrarlayan işlem özelliği sütunu create_all döneminde eklendi; o dönemde oluşturulan
bazı veritabanlarında sütun zaten var, daha eskilerinde yok. Bu yüzden sadece eksikse eklenir.

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-03

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0002"
down_revision: Union[str, Sequence[str], None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    columns = {c["name"] for c in sa.inspect(op.get_bind()).get_columns("transactions")}
    if "is_recurring" in columns:
        return
    with op.batch_alter_table("transactions", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column("is_recurring", sa.Boolean(), nullable=False, server_default=sa.false())
        )


def downgrade() -> None:
    with op.batch_alter_table("transactions", schema=None) as batch_op:
        batch_op.drop_column("is_recurring")
