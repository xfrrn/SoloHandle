from __future__ import annotations

from typing import Any, Iterable, Optional

from api.services.events_service import (
    create_expense as _create_expense,
    create_lifelog as _create_lifelog,
    create_meal as _create_meal,
    create_mood as _create_mood,
    search_events as _search_events,
    soft_delete_event as _soft_delete_event,
    undo_event as _undo_event,
)


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
    return _create_expense(
        amount=amount,
        currency=currency,
        category=category,
        note=note,
        happened_at=happened_at,
        tags=tags,
        source=source,
        confidence=confidence,
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
    return _create_lifelog(
        text=text,
        happened_at=happened_at,
        tags=tags,
        source=source,
        confidence=confidence,
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
    return _create_meal(
        meal_type=meal_type,
        items=items,
        happened_at=happened_at,
        tags=tags,
        source=source,
        confidence=confidence,
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
    return _create_mood(
        mood=mood,
        intensity=intensity,
        topic=topic,
        note=note,
        happened_at=happened_at,
        tags=tags,
        source=source,
        confidence=confidence,
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
    return _search_events(
        query=query,
        types=types,
        date_from=date_from,
        date_to=date_to,
        limit=limit,
        offset=offset,
    )


def soft_delete_event(event_id: int) -> dict[str, Any]:
    """Soft delete an event."""
    return _soft_delete_event(event_id)


def undo_event(event_id: int) -> dict[str, Any]:
    """Undo soft delete for an event."""
    return _undo_event(event_id)
