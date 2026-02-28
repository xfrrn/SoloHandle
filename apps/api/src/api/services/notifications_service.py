from __future__ import annotations

import sqlite3
from typing import Any, Optional

from api.db.connection import (
    ToolError,
    ensure_iso8601,
    ensure_tables,
    get_connection,
    now_iso8601,
    require_non_empty_str,
)


def _row_to_notification(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "notification_id": row["id"],
        "task_id": row["task_id"],
        "title": row["title"],
        "content": row["content"],
        "scheduled_at": row["scheduled_at"],
        "sent_at": row["sent_at"],
        "read_at": row["read_at"],
        "created_at": row["created_at"],
        "is_deleted": row["is_deleted"],
    }


def create_notification_for_task(
    *,
    task_id: Optional[int],
    scheduled_at: str,
    title: Optional[str] = None,
    content: Optional[str] = None,
) -> dict[str, Any]:
    if task_id is not None and (not isinstance(task_id, int) or task_id <= 0):
        raise ToolError("invalid_param", "task_id must be positive integer or null")
    if not isinstance(scheduled_at, str):
        raise ToolError("invalid_param", "scheduled_at must be string")
    if content is not None and not isinstance(content, str):
        raise ToolError("invalid_param", "content must be string or null")
    scheduled_at_iso = ensure_iso8601(scheduled_at)
    if scheduled_at_iso is None:
        raise ToolError("invalid_param", "scheduled_at is required")

    if title is None:
        title_value = "Task Reminder" if task_id is not None else "Notification"
    else:
        title_value = require_non_empty_str(title, "title")

    created_at = now_iso8601()

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO notifications (task_id, title, content, scheduled_at, sent_at, read_at, is_deleted, created_at)
            VALUES (?, ?, ?, ?, NULL, NULL, 0, ?)
            """,
            (task_id, title_value, content, scheduled_at_iso, created_at),
        )
        notification_id = cur.lastrowid
        row = cur.execute(
            "SELECT * FROM notifications WHERE id = ?", (notification_id,)
        ).fetchone()
        return _row_to_notification(row)


def list_notifications(unread_only: bool = True, limit: int = 20) -> dict[str, Any]:
    if limit <= 0 or limit > 200:
        raise ToolError("invalid_param", "limit must be in 1..200")

    clauses = ["is_deleted = 0"]
    if unread_only:
        clauses.append("read_at IS NULL")
    where_sql = " AND ".join(clauses)

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        rows = cur.execute(
            f"SELECT * FROM notifications WHERE {where_sql} ORDER BY scheduled_at ASC LIMIT ?",
            (limit,),
        ).fetchall()

    items = [_row_to_notification(r) for r in rows]
    return {"items": items, "total": len(items)}


def mark_notification_read(notification_id: int) -> dict[str, Any]:
    if not isinstance(notification_id, int) or notification_id <= 0:
        raise ToolError("invalid_param", "notification_id must be positive integer")
    now = now_iso8601()

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        cur.execute(
            "UPDATE notifications SET read_at = ? WHERE id = ?",
            (now, notification_id),
        )
        row = cur.execute(
            "SELECT * FROM notifications WHERE id = ?", (notification_id,)
        ).fetchone()
        if row is None:
            raise ToolError(
                "not_found", "notification not found", {"notification_id": notification_id}
            )
        return _row_to_notification(row)
