"""add store_slug to businesses

Revision ID: d4e5f6a7b8c9
Revises:
Create Date: 2026-05-29

"""
from alembic import op
import sqlalchemy as sa
import re


def generate_slug(text: str) -> str:
    slug = text.lower().strip()
    slug = re.sub(r'[^\w\s-]', '', slug)
    slug = re.sub(r'[\s_]+', '-', slug)
    slug = re.sub(r'-+', '-', slug)
    return slug.strip('-') or "store"


revision = 'd4e5f6a7b8c9'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    # Add store_slug column (nullable first)
    op.add_column('businesses', sa.Column('store_slug', sa.String(100), nullable=True))

    # Populate slugs for existing businesses
    conn = op.get_bind()
    businesses = conn.execute(sa.text("SELECT id, business_name FROM businesses WHERE deleted_at IS NULL")).fetchall()

    used_slugs = set()
    for biz in businesses:
        base = generate_slug(biz.business_name)
        slug = base
        counter = 1
        while slug in used_slugs:
            slug = f"{base}-{counter}"
            counter += 1
        used_slugs.add(slug)
        conn.execute(
            sa.text("UPDATE businesses SET store_slug = :slug WHERE id = :id"),
            {"slug": slug, "id": biz.id}
        )

    # Add unique index
    op.create_index('ix_businesses_store_slug', 'businesses', ['store_slug'], unique=True)


def downgrade():
    op.drop_index('ix_businesses_store_slug', table_name='businesses')
    op.drop_column('businesses', 'store_slug')
