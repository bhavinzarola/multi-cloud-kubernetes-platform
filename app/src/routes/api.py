"""Sample business API routes for the eks-demo-app microservice."""

import logging

from fastapi import APIRouter
from pydantic import BaseModel

from src.config import get_settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1", tags=["api"])


class Item(BaseModel):
    """A single sample item returned by the API."""

    id: int
    name: str
    in_stock: bool


_SAMPLE_ITEMS: list[Item] = [
    Item(id=1, name="widget", in_stock=True),
    Item(id=2, name="gadget", in_stock=False),
    Item(id=3, name="gizmo", in_stock=True),
]


@router.get("/items", response_model=list[Item])
def list_items() -> list[Item]:
    """Return a sample list of items, demonstrating a typical read endpoint."""
    settings = get_settings()
    logger.info("listing items", extra={"environment": settings.environment})
    return _SAMPLE_ITEMS


@router.get("/items/{item_id}", response_model=Item | None)
def get_item(item_id: int) -> Item | None:
    """Return a single item by ID, or None if not found."""
    for item in _SAMPLE_ITEMS:
        if item.id == item_id:
            return item
    return None
