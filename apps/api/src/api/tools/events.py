from __future__ import annotations

from typing import Any, Iterable, Optional

from api.db.connection import (
    ToolError,
    ensure_iso8601,
    ensure_tables,
    get_connection,
    normalize_iso8601,
    normalize_tags,
    require_enum,
    require_non_empty_str,
    require_number_in_range,
    require_positive_number,
)
from api.repositories.events_repo import EventRepository
from api.services.events_service import EventService

EVENT_TYPES = {"expense", "lifelog", "meal", "mood"}
EXPENSE_CATEGORIES = {
    "food",
    "transport",
    "shopping",
    "entertainment",
    "housing",
    "medical",
    "education",
    "other",
    "unknown",
}
MEAL_TYPES = {"breakfast", "lunch", "dinner", "snack", "unknown"}
SOURCES = {"chat_text", "chat_image", "chat_voice", "import"}


def create_expense(
    *,
    amount: Any,
    currency: str = "CNY",
    category: str = "unknown",
    note: Optional[str] = None,
    happened_at: Optional[str] = None,
    tags: Optional[Iterable[str]] = None,
    source: str = "chat_text",
    confidence: float = 0.8,
    idempotency_key: Optional[str] = None,
) -> dict[str, Any]:
    """Create an expense event."""
    amt = require_positive_number(amount, "amount")
    cat = require_enum(category, "category", EXPENSE_CATEGORIES)
    if note is not None and not isinstance(note, str):
        raise ToolError("invalid_param", "note must be string or null")
    if not isinstance(currency, str) or not currency.strip():
        raise ToolError("invalid_param", "currency must be non-empty string")

    data = {
        "amount": amt,
        "currency": currency.strip(),
        "category": cat,
        "note": note,
    }
    happened_at_iso = normalize_iso8601(happened_at)
    tags_list = normalize_tags(tags)
    src = require_enum(source, "source", SOURCES)
    conf = require_number_in_range(confidence, "confidence", 0.0, 1.0)

    with get_connection() as conn:
        ensure_tables(conn)
        service = EventService(EventRepository(conn))
        return service.create_event(
            event_type="expense",
            data=data,
            happened_at=happened_at_iso,
            tags=tags_list,
            source=src,
            confidence=conf,
            idempotency_key=idempotency_key,
        )


def create_lifelog(
    *,
    text: Any,
    happened_at: Optional[str] = None,
    tags: Optional[Iterable[str]] = None,
    source: str = "chat_text",
    confidence: float = 0.8,
    idempotency_key: Optional[str] = None,
) -> dict[str, Any]:
    """Create a lifelog event."""
    text_value = require_non_empty_str(text, "text")
    data = {"text": text_value}
    happened_at_iso = normalize_iso8601(happened_at)
    tags_list = normalize_tags(tags)
    src = require_enum(source, "source", SOURCES)
    conf = require_number_in_range(confidence, "confidence", 0.0, 1.0)

    with get_connection() as conn:
        ensure_tables(conn)
        service = EventService(EventRepository(conn))
        return service.create_event(
            event_type="lifelog",
            data=data,
            happened_at=happened_at_iso,
            tags=tags_list,
            source=src,
            confidence=conf,
            idempotency_key=idempotency_key,
        )


def create_meal(
    *,
    meal_type: str,
    items: Iterable[str],
    happened_at: Optional[str] = None,
    tags: Optional[Iterable[str]] = None,
    source: str = "chat_text",
    confidence: float = 0.8,
    idempotency_key: Optional[str] = None,
) -> dict[str, Any]:
    """Create a meal event."""
    meal = require_enum(meal_type, "meal_type", MEAL_TYPES)
    if isinstance(items, str) or not isinstance(items, Iterable):
        raise ToolError("invalid_param", "items must be list of strings")
    items_list = [require_non_empty_str(i, "item") for i in items]
    if len(items_list) == 0:
        raise ToolError("invalid_param", "items must be non-empty list")
    data = {"meal_type": meal, "items": items_list}
    happened_at_iso = normalize_iso8601(happened_at)
    tags_list = normalize_tags(tags)
    src = require_enum(source, "source", SOURCES)
    conf = require_number_in_range(confidence, "confidence", 0.0, 1.0)

    with get_connection() as conn:
        ensure_tables(conn)
        service = EventService(EventRepository(conn))
        return service.create_event(
            event_type="meal",
            data=data,
            happened_at=happened_at_iso,
            tags=tags_list,
            source=src,
            confidence=conf,
            idempotency_key=idempotency_key,
        )


def create_mood(
    *,
    mood: Any,
    intensity: float = 0.5,
    topic: Optional[str] = None,
    note: Optional[str] = None,
    happened_at: Optional[str] = None,
    tags: Optional[Iterable[str]] = None,
    source: str = "chat_text",
    confidence: float = 0.8,
    idempotency_key: Optional[str] = None,
) -> dict[str, Any]:
    """Create a mood event."""
    mood_value = require_non_empty_str(mood, "mood")
    inten = require_number_in_range(intensity, "intensity", 0.0, 1.0)
    if topic is not None and not isinstance(topic, str):
        raise ToolError("invalid_param", "topic must be string or null")
    if note is not None and not isinstance(note, str):
        raise ToolError("invalid_param", "note must be string or null")
    data = {
        "mood": mood_value,
        "intensity": inten,
        "topic": topic,
        "note": note,
    }
    happened_at_iso = normalize_iso8601(happened_at)
    tags_list = normalize_tags(tags)
    src = require_enum(source, "source", SOURCES)
    conf = require_number_in_range(confidence, "confidence", 0.0, 1.0)

    with get_connection() as conn:
        ensure_tables(conn)
        service = EventService(EventRepository(conn))
        return service.create_event(
            event_type="mood",
            data=data,
            happened_at=happened_at_iso,
            tags=tags_list,
            source=src,
            confidence=conf,
            idempotency_key=idempotency_key,
        )


def search_events(
    *,
    query: Optional[str] = None,
    types: Optional[Iterable[str]] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
) -> dict[str, Any]:
    """Search events using simple filters."""
    if limit <= 0 or limit > 200:
        raise ToolError("invalid_param", "limit must be in 1..200")
    if offset < 0:
        raise ToolError("invalid_param", "offset must be >= 0")

    types_list = None
    if types is not None:
        types_list = [require_enum(t, "type", EVENT_TYPES) for t in types]

    date_from_iso = ensure_iso8601(date_from)
    date_to_iso = ensure_iso8601(date_to)

    with get_connection() as conn:
        ensure_tables(conn)
        service = EventService(EventRepository(conn))
        return service.search_events(
            query=query,
            types=types_list,
            date_from=date_from_iso,
            date_to=date_to_iso,
            limit=limit,
            offset=offset,
        )


def soft_delete_event(event_id: int) -> dict[str, Any]:
    """Soft delete an event."""
    if not isinstance(event_id, int) or event_id <= 0:
        raise ToolError("invalid_param", "event_id must be positive integer")

    with get_connection() as conn:
        ensure_tables(conn)
        service = EventService(EventRepository(conn))
        return service.set_deleted(event_id, 1)


def undo_event(event_id: int) -> dict[str, Any]:
    """Undo soft delete for an event."""
    if not isinstance(event_id, int) or event_id <= 0:
        raise ToolError("invalid_param", "event_id must be positive integer")

    with get_connection() as conn:
        ensure_tables(conn)
        service = EventService(EventRepository(conn))
        return service.set_deleted(event_id, 0)
