from __future__ import annotations

import sqlite3
from typing import Any, Iterable, Optional

from api.db.connection import (
    ToolError,
    ensure_iso8601,
    ensure_tables,
    get_connection,
    json_dumps,
    json_loads,
    normalize_iso8601,
    normalize_tags,
    now_iso8601,
    require_enum,
    require_non_empty_str,
    require_number_in_range,
    require_positive_number,
)

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


def _row_to_event(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "event_id": row["id"],
        "type": row["type"],
        "happened_at": row["happened_at"],
        "tags": json_loads(row["tags_json"]),
        "data": json_loads(row["data_json"]),
        "source": row["source"],
        "confidence": row["confidence"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
        "is_deleted": row["is_deleted"],
    }


def _get_event_by_idempotency(cur: sqlite3.Cursor, key: str) -> Optional[sqlite3.Row]:
    return cur.execute(
        "SELECT * FROM events WHERE idempotency_key = ? LIMIT 1", (key,)
    ).fetchone()


def _create_event(
    *,
    event_type: str,
    data: dict[str, Any],
    happened_at: Optional[str],
    tags: Optional[Iterable[str]],
    source: str,
    confidence: float,
    idempotency_key: Optional[str],
) -> dict[str, Any]:
    require_enum(event_type, "type", EVENT_TYPES)
    require_enum(source, "source", SOURCES)
    conf = require_number_in_range(confidence, "confidence", 0.0, 1.0)
    tags_list = normalize_tags(tags)
    happened_at_iso = normalize_iso8601(happened_at)
    created_at = now_iso8601()
    updated_at = created_at

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        if idempotency_key:
            row = _get_event_by_idempotency(cur, idempotency_key)
            if row is not None:
                return _row_to_event(row)

        cur.execute(
            """
            INSERT INTO events (type, data_json, happened_at, tags_json, source, confidence, idempotency_key, is_deleted, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
            """,
            (
                event_type,
                json_dumps(data),
                happened_at_iso,
                json_dumps(tags_list),
                source,
                conf,
                idempotency_key,
                created_at,
                updated_at,
            ),
        )
        event_id = cur.lastrowid
        row = cur.execute("SELECT * FROM events WHERE id = ?", (event_id,)).fetchone()
        return _row_to_event(row)


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
    return _create_event(
        event_type="expense",
        data=data,
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
    text_value = require_non_empty_str(text, "text")
    data = {"text": text_value}
    return _create_event(
        event_type="lifelog",
        data=data,
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
    meal = require_enum(meal_type, "meal_type", MEAL_TYPES)
    if isinstance(items, str) or not isinstance(items, Iterable):
        raise ToolError("invalid_param", "items must be list of strings")
    items_list = [require_non_empty_str(i, "item") for i in items]
    if len(items_list) == 0:
        raise ToolError("invalid_param", "items must be non-empty list")
    data = {"meal_type": meal, "items": items_list}
    return _create_event(
        event_type="meal",
        data=data,
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
    return _create_event(
        event_type="mood",
        data=data,
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
    if limit <= 0 or limit > 200:
        raise ToolError("invalid_param", "limit must be in 1..200")
    if offset < 0:
        raise ToolError("invalid_param", "offset must be >= 0")

    types_list = None
    if types is not None:
        types_list = [require_enum(t, "type", EVENT_TYPES) for t in types]

    date_from_iso = ensure_iso8601(date_from)
    date_to_iso = ensure_iso8601(date_to)

    clauses = ["is_deleted = 0"]
    params: list[Any] = []

    if types_list:
        placeholders = ",".join("?" for _ in types_list)
        clauses.append(f"type IN ({placeholders})")
        params.extend(types_list)

    if query:
        clauses.append("data_json LIKE ?")
        params.append(f"%{query}%")

    if date_from_iso:
        clauses.append("happened_at >= ?")
        params.append(date_from_iso)
    if date_to_iso:
        clauses.append("happened_at <= ?")
        params.append(date_to_iso)

    where_sql = " AND ".join(clauses)

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        rows = cur.execute(
            f"SELECT * FROM events WHERE {where_sql} ORDER BY happened_at DESC LIMIT ? OFFSET ?",
            (*params, limit, offset),
        ).fetchall()

    items = [_row_to_event(r) for r in rows]
    return {"items": items, "total": len(items)}


def soft_delete_event(event_id: int) -> dict[str, Any]:
    if not isinstance(event_id, int) or event_id <= 0:
        raise ToolError("invalid_param", "event_id must be positive integer")
    now = now_iso8601()

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        cur.execute(
            "UPDATE events SET is_deleted = 1, updated_at = ? WHERE id = ?",
            (now, event_id),
        )
        row = cur.execute("SELECT * FROM events WHERE id = ?", (event_id,)).fetchone()
        if row is None:
            raise ToolError("not_found", "event not found", {"event_id": event_id})
        return _row_to_event(row)


def undo_event(event_id: int) -> dict[str, Any]:
    if not isinstance(event_id, int) or event_id <= 0:
        raise ToolError("invalid_param", "event_id must be positive integer")
    now = now_iso8601()

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        cur.execute(
            "UPDATE events SET is_deleted = 0, updated_at = ? WHERE id = ?",
            (now, event_id),
        )
        row = cur.execute("SELECT * FROM events WHERE id = ?", (event_id,)).fetchone()
        if row is None:
            raise ToolError("not_found", "event not found", {"event_id": event_id})
        return _row_to_event(row)
