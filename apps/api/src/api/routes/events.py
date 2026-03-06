from __future__ import annotations

from fastapi import APIRouter, Query

from api.db.connection import ensure_tables, get_connection
from api.repositories.events_repo import EventRepository
from api.services.events_service import EventService

router = APIRouter()


def _get_event_service() -> EventService:
    conn = get_connection()
    ensure_tables(conn)
    return EventService(EventRepository(conn))


@router.get("/events")
def list_events(
    query: str | None = Query(None, description="Full-text search keyword"),
    types: str | None = Query(None, description="Comma-separated event types, e.g. expense,mood,meal"),
    date_from: str | None = Query(None, description="ISO8601 start date filter"),
    date_to: str | None = Query(None, description="ISO8601 end date filter"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> dict:
    type_list = [t.strip() for t in types.split(",") if t.strip()] if types else None
    svc = _get_event_service()
    return svc.search_events(
        query=query,
        types=type_list,
        date_from=date_from,
        date_to=date_to,
        limit=limit,
        offset=offset,
    )
