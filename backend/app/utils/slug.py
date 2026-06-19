import re
from sqlalchemy.orm import Session


def generate_slug(text: str) -> str:
    """Convert business name to URL-friendly slug."""
    slug = text.lower().strip()
    slug = re.sub(r'[^\w\s-]', '', slug)      # remove special chars
    slug = re.sub(r'[\s_]+', '-', slug)         # spaces/underscores → hyphens
    slug = re.sub(r'-+', '-', slug)             # collapse multiple hyphens
    slug = slug.strip('-')                       # strip leading/trailing hyphens
    return slug or "store"


def unique_slug(base_slug: str, db: Session, exclude_id: int = None) -> str:
    """Ensure slug is unique in the businesses table."""
    from app.models.business import Business

    slug = base_slug
    counter = 1
    while True:
        query = db.query(Business).filter(Business.store_slug == slug)
        if exclude_id:
            query = query.filter(Business.id != exclude_id)
        if not query.first():
            return slug
        slug = f"{base_slug}-{counter}"
        counter += 1
