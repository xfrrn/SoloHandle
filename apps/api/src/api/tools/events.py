from __future__ import annotations

from typing import Any, Iterable, Optional

from api.core.constants_loader import get_constants
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
from api.repositories.accounts_repo import AccountsRepository
from api.services.accounts_service import AccountsService
from api.services.events_service import EventService

def create_expense(
    *,
    amount: Any,
    currency: Optional[str] = None,
    category: Optional[str] = None,
    note: Optional[str] = None,
    happened_at: Optional[str] = None,
    tags: Optional[Iterable[str]] = None,
    source: Optional[str] = None,
    account_id: Optional[int] = None,
    confidence: Optional[float] = None,
    idempotency_key: Optional[str] = None,
    commit_id: Optional[str] = None,
) -> dict[str, Any]:
    """Create an expense event."""
    consts = get_constants()
    amt = require_positive_number(amount, "amount")
    cat = require_enum(
        category or consts.expense.default_category,
        "category",
        consts.expense.categories,
    )
    if note is not None and not isinstance(note, str):
        raise ToolError("invalid_param", "note must be string or null")
    currency_value = currency or consts.defaults.currency
    if not isinstance(currency_value, str) or not currency_value.strip():
        raise ToolError("invalid_param", "currency must be non-empty string")

    data = {
        "amount": amt,
        "currency": currency_value.strip(),
        "category": cat,
        "note": note,
    }
    happened_at_iso = normalize_iso8601(happened_at)
    tags_list = normalize_tags(tags)
    src = require_enum(source or consts.defaults.source, "source", consts.sources)
    conf_value = confidence if confidence is not None else consts.defaults.confidence
    conf = require_number_in_range(conf_value, "confidence", 0.0, 1.0)

    with get_connection() as conn:
        ensure_tables(conn)
        if account_id is not None:
            if not isinstance(account_id, int) or account_id <= 0:
                raise ToolError("invalid_param", "account_id must be positive integer")
            AccountsService(AccountsRepository(conn)).get_account(account_id)
            data["account_id"] = account_id
        service = EventService(EventRepository(conn))
        return service.create_event(
            event_type="expense",
            data=data,
            happened_at=happened_at_iso,
            tags=tags_list,
            source=src,
            confidence=conf,
            idempotency_key=idempotency_key,
            commit_id=commit_id,
        )


def create_income(
    *,
    amount: Any,
    currency: Optional[str] = None,
    category: Optional[str] = None,
    note: Optional[str] = None,
    happened_at: Optional[str] = None,
    tags: Optional[Iterable[str]] = None,
    source: Optional[str] = None,
    account_id: Optional[int] = None,
    confidence: Optional[float] = None,
    idempotency_key: Optional[str] = None,
    commit_id: Optional[str] = None,
) -> dict[str, Any]:
    """Create an income event."""
    consts = get_constants()
    amt = require_positive_number(amount, "amount")
    cat = require_enum(
        category or consts.income.default_category,
        "category",
        consts.income.categories,
    )
    if note is not None and not isinstance(note, str):
        raise ToolError("invalid_param", "note must be string or null")
    currency_value = currency or consts.defaults.currency
    if not isinstance(currency_value, str) or not currency_value.strip():
        raise ToolError("invalid_param", "currency must be non-empty string")

    data = {
        "amount": amt,
        "currency": currency_value.strip(),
        "category": cat,
        "note": note,
    }
    happened_at_iso = normalize_iso8601(happened_at)
    tags_list = normalize_tags(tags)
    src = require_enum(source or consts.defaults.source, "source", consts.sources)
    conf_value = confidence if confidence is not None else consts.defaults.confidence
    conf = require_number_in_range(conf_value, "confidence", 0.0, 1.0)

    with get_connection() as conn:
        ensure_tables(conn)
        if account_id is not None:
            if not isinstance(account_id, int) or account_id <= 0:
                raise ToolError("invalid_param", "account_id must be positive integer")
            AccountsService(AccountsRepository(conn)).get_account(account_id)
            data["account_id"] = account_id
        service = EventService(EventRepository(conn))
        return service.create_event(
            event_type="income",
            data=data,
            happened_at=happened_at_iso,
            tags=tags_list,
            source=src,
            confidence=conf,
            idempotency_key=idempotency_key,
            commit_id=commit_id,
        )


def create_transfer(
    *,
    amount: Any,
    from_account_id: int,
    to_account_id: int,
    currency: Optional[str] = None,
    note: Optional[str] = None,
    happened_at: Optional[str] = None,
    tags: Optional[Iterable[str]] = None,
    source: Optional[str] = None,
    confidence: Optional[float] = None,
    idempotency_key: Optional[str] = None,
    commit_id: Optional[str] = None,
) -> dict[str, Any]:
    """Create a transfer event."""
    consts = get_constants()
    amt = require_positive_number(amount, "amount")
    if not isinstance(from_account_id, int) or from_account_id <= 0:
        raise ToolError("invalid_param", "from_account_id must be positive integer")
    if not isinstance(to_account_id, int) or to_account_id <= 0:
        raise ToolError("invalid_param", "to_account_id must be positive integer")
    if from_account_id == to_account_id:
        raise ToolError("invalid_param", "from_account_id and to_account_id must be different")
    if note is not None and not isinstance(note, str):
        raise ToolError("invalid_param", "note must be string or null")
    currency_value = currency or consts.defaults.currency
    if not isinstance(currency_value, str) or not currency_value.strip():
        raise ToolError("invalid_param", "currency must be non-empty string")

    happened_at_iso = normalize_iso8601(happened_at)
    tags_list = normalize_tags(tags)
    src = require_enum(source or consts.defaults.source, "source", consts.sources)
    conf_value = confidence if confidence is not None else consts.defaults.confidence
    conf = require_number_in_range(conf_value, "confidence", 0.0, 1.0)

    with get_connection() as conn:
        ensure_tables(conn)
        accounts = AccountsService(AccountsRepository(conn))
        from_account = accounts.get_account(from_account_id)
        to_account = accounts.get_account(to_account_id)
        data = {
            "amount": amt,
            "currency": currency_value.strip(),
            "from_account_id": from_account_id,
            "to_account_id": to_account_id,
            "from_account_name": from_account["name"],
            "to_account_name": to_account["name"],
            "note": note,
        }
        service = EventService(EventRepository(conn))
        return service.create_event(
            event_type="transfer",
            data=data,
            happened_at=happened_at_iso,
            tags=tags_list,
            source=src,
            confidence=conf,
            idempotency_key=idempotency_key,
            commit_id=commit_id,
        )


def create_lifelog(
    *,
    text: Any = None,
    images: Optional[Iterable[str]] = None,
    happened_at: Optional[str] = None,
    tags: Optional[Iterable[str]] = None,
    source: Optional[str] = None,
    confidence: Optional[float] = None,
    idempotency_key: Optional[str] = None,
    commit_id: Optional[str] = None,
) -> dict[str, Any]:
    """Create a lifelog event."""
    consts = get_constants()
    text_value = None
    if text is not None:
        text_value = require_non_empty_str(text, "text")

    images_list: list[str] = []
    if images is not None:
        if isinstance(images, str) or not isinstance(images, Iterable):
            raise ToolError("invalid_param", "images must be list of base64 strings")
        for item in images:
            if not isinstance(item, str) or not item.strip():
                raise ToolError("invalid_param", "images must be list of base64 strings")
            images_list.append(item.strip())

    if text_value is None and not images_list:
        raise ToolError("invalid_param", "text or images must be provided")

    data: dict[str, Any] = {}
    if text_value is not None:
        data["text"] = text_value
    if images_list:
        data["images"] = images_list
    happened_at_iso = normalize_iso8601(happened_at)
    tags_list = normalize_tags(tags)
    src = require_enum(source or consts.defaults.source, "source", consts.sources)
    conf_value = confidence if confidence is not None else consts.defaults.confidence
    conf = require_number_in_range(conf_value, "confidence", 0.0, 1.0)

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
            commit_id=commit_id,
        )


def create_meal(
    *,
    meal_type: str,
    items: Iterable[str],
    happened_at: Optional[str] = None,
    tags: Optional[Iterable[str]] = None,
    source: Optional[str] = None,
    confidence: Optional[float] = None,
    idempotency_key: Optional[str] = None,
    commit_id: Optional[str] = None,
) -> dict[str, Any]:
    """Create a meal event."""
    consts = get_constants()
    meal = require_enum(meal_type, "meal_type", consts.meal.types)
    if isinstance(items, str) or not isinstance(items, Iterable):
        raise ToolError("invalid_param", "items must be list of strings")
    items_list = [require_non_empty_str(i, "item") for i in items]
    if len(items_list) == 0:
        raise ToolError("invalid_param", "items must be non-empty list")
    data = {"meal_type": meal, "items": items_list}
    happened_at_iso = normalize_iso8601(happened_at)
    tags_list = normalize_tags(tags)
    src = require_enum(source or consts.defaults.source, "source", consts.sources)
    conf_value = confidence if confidence is not None else consts.defaults.confidence
    conf = require_number_in_range(conf_value, "confidence", 0.0, 1.0)

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
            commit_id=commit_id,
        )


def create_mood(
    *,
    mood: Any,
    intensity: float = 0.5,
    topic: Optional[str] = None,
    note: Optional[str] = None,
    happened_at: Optional[str] = None,
    tags: Optional[Iterable[str]] = None,
    source: Optional[str] = None,
    confidence: Optional[float] = None,
    idempotency_key: Optional[str] = None,
    commit_id: Optional[str] = None,
) -> dict[str, Any]:
    """Create a mood event."""
    consts = get_constants()
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
    src = require_enum(source or consts.defaults.source, "source", consts.sources)
    conf_value = confidence if confidence is not None else consts.defaults.confidence
    conf = require_number_in_range(conf_value, "confidence", 0.0, 1.0)

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
            commit_id=commit_id,
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
        consts = get_constants()
        types_list = [require_enum(t, "type", consts.event_types) for t in types]

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
