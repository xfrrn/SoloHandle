from __future__ import annotations

import sqlite3
from datetime import datetime
from typing import Any, Iterable, Optional
from zoneinfo import ZoneInfo

from api.db.connection import (
    ToolError,
    ensure_iso8601,
    ensure_tables,
    get_connection,
    json_dumps,
    json_loads,
    normalize_tags,
    now_iso8601,
    require_enum,
    require_non_empty_str,
)

TASK_STATUS = {"todo", "doing", "done", "canceled"}
TASK_PRIORITY = {"low", "medium", "high"}


def _row_to_task(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "task_id": row["id"],
        "title": row["title"],
        "status": row["status"],
        "priority": row["priority"],
        "due_at": row["due_at"],
        "remind_at": row["remind_at"],
        "repeat_rule": row["repeat_rule"],
        "project": row["project"],
        "tags": json_loads(row["tags_json"]),
        "note": row["note"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
        "completed_at": row["completed_at"],
        "is_deleted": row["is_deleted"],
    }


def _get_task_by_idempotency(cur: sqlite3.Cursor, key: str) -> Optional[sqlite3.Row]:
    return cur.execute(
        "SELECT * FROM tasks WHERE idempotency_key = ? LIMIT 1", (key,)
    ).fetchone()


def create_task(
    *,
    title: Any,
    due_at: Optional[str] = None,
    remind_at: Optional[str] = None,
    priority: str = "medium",
    tags: Optional[Iterable[str]] = None,
    project: Optional[str] = None,
    note: Optional[str] = None,
    idempotency_key: Optional[str] = None,
) -> dict[str, Any]:
    title_value = require_non_empty_str(title, "title")
    pr = require_enum(priority, "priority", TASK_PRIORITY)
    if project is not None and not isinstance(project, str):
        raise ToolError("invalid_param", "project must be string or null")
    if note is not None and not isinstance(note, str):
        raise ToolError("invalid_param", "note must be string or null")

    due_at_iso = ensure_iso8601(due_at)
    remind_at_iso = ensure_iso8601(remind_at)

    tags_list = normalize_tags(tags)
    created_at = now_iso8601()
    updated_at = created_at

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        if idempotency_key:
            row = _get_task_by_idempotency(cur, idempotency_key)
            if row is not None:
                return _row_to_task(row)

        cur.execute(
            """
            INSERT INTO tasks (title, status, priority, due_at, remind_at, repeat_rule, project, tags_json, note, idempotency_key, is_deleted, created_at, updated_at, completed_at)
            VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, 0, ?, ?, NULL)
            """,
            (
                title_value,
                "todo",
                pr,
                due_at_iso,
                remind_at_iso,
                project,
                json_dumps(tags_list),
                note,
                idempotency_key,
                created_at,
                updated_at,
            ),
        )
        task_id = cur.lastrowid
        row = cur.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
        return _row_to_task(row)


def update_task(
    *,
    task_id: int,
    title: Optional[str] = None,
    status: Optional[str] = None,
    priority: Optional[str] = None,
    due_at: Optional[str] = None,
    remind_at: Optional[str] = None,
    tags: Optional[Iterable[str]] = None,
    project: Optional[str] = None,
    note: Optional[str] = None,
) -> dict[str, Any]:
    if not isinstance(task_id, int) or task_id <= 0:
        raise ToolError("invalid_param", "task_id must be positive integer")

    fields = []
    params: list[Any] = []

    if title is not None:
        fields.append("title = ?")
        params.append(require_non_empty_str(title, "title"))
    if status is not None:
        fields.append("status = ?")
        params.append(require_enum(status, "status", TASK_STATUS))
    if priority is not None:
        fields.append("priority = ?")
        params.append(require_enum(priority, "priority", TASK_PRIORITY))
    if due_at is not None:
        fields.append("due_at = ?")
        params.append(ensure_iso8601(due_at))
    if remind_at is not None:
        fields.append("remind_at = ?")
        params.append(ensure_iso8601(remind_at))
    if tags is not None:
        fields.append("tags_json = ?")
        params.append(json_dumps(normalize_tags(tags)))
    if project is not None:
        if not isinstance(project, str):
            raise ToolError("invalid_param", "project must be string or null")
        fields.append("project = ?")
        params.append(project)
    if note is not None:
        if not isinstance(note, str):
            raise ToolError("invalid_param", "note must be string or null")
        fields.append("note = ?")
        params.append(note)

    if not fields:
        raise ToolError("invalid_param", "no fields to update")

    fields.append("updated_at = ?")
    params.append(now_iso8601())

    params.append(task_id)

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        cur.execute(f"UPDATE tasks SET {', '.join(fields)} WHERE id = ?", params)
        row = cur.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
        if row is None:
            raise ToolError("not_found", "task not found", {"task_id": task_id})
        return _row_to_task(row)


def complete_task(task_id: int) -> dict[str, Any]:
    if not isinstance(task_id, int) or task_id <= 0:
        raise ToolError("invalid_param", "task_id must be positive integer")
    now = now_iso8601()

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        cur.execute(
            "UPDATE tasks SET status = 'done', completed_at = ?, updated_at = ? WHERE id = ?",
            (now, now, task_id),
        )
        row = cur.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
        if row is None:
            raise ToolError("not_found", "task not found", {"task_id": task_id})
        return _row_to_task(row)


def postpone_task(
    *,
    task_id: int,
    new_due_at: Optional[str] = None,
    new_remind_at: Optional[str] = None,
) -> dict[str, Any]:
    if not isinstance(task_id, int) or task_id <= 0:
        raise ToolError("invalid_param", "task_id must be positive integer")
    if new_due_at is None and new_remind_at is None:
        raise ToolError("invalid_param", "new_due_at or new_remind_at required")

    fields = []
    params: list[Any] = []

    if new_due_at is not None:
        fields.append("due_at = ?")
        params.append(ensure_iso8601(new_due_at))
    if new_remind_at is not None:
        fields.append("remind_at = ?")
        params.append(ensure_iso8601(new_remind_at))

    fields.append("updated_at = ?")
    params.append(now_iso8601())

    params.append(task_id)

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        cur.execute(f"UPDATE tasks SET {', '.join(fields)} WHERE id = ?", params)
        row = cur.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
        if row is None:
            raise ToolError("not_found", "task not found", {"task_id": task_id})
        return _row_to_task(row)


def search_tasks(
    *,
    query: Optional[str] = None,
    status: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
) -> dict[str, Any]:
    if limit <= 0 or limit > 200:
        raise ToolError("invalid_param", "limit must be in 1..200")
    if offset < 0:
        raise ToolError("invalid_param", "offset must be >= 0")

    status_value = None
    if status is not None:
        status_value = require_enum(status, "status", TASK_STATUS)

    date_from_iso = ensure_iso8601(date_from)
    date_to_iso = ensure_iso8601(date_to)

    clauses = ["is_deleted = 0"]
    params: list[Any] = []

    if status_value:
        clauses.append("status = ?")
        params.append(status_value)

    if query:
        clauses.append("(title LIKE ? OR note LIKE ?)")
        params.extend([f"%{query}%", f"%{query}%"])

    if date_from_iso:
        clauses.append("due_at >= ?")
        params.append(date_from_iso)
    if date_to_iso:
        clauses.append("due_at <= ?")
        params.append(date_to_iso)

    where_sql = " AND ".join(clauses)

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        rows = cur.execute(
            f"SELECT * FROM tasks WHERE {where_sql} ORDER BY due_at IS NULL, due_at ASC, created_at DESC LIMIT ? OFFSET ?",
            (*params, limit, offset),
        ).fetchall()

    items = [_row_to_task(r) for r in rows]
    return {"items": items, "total": len(items)}


def _parse_iso8601(value: str) -> datetime:
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    dt = datetime.fromisoformat(value)
    if dt.tzinfo is None:
        raise ToolError("invalid_time", "ISO8601 time must include offset", {"value": value})
    return dt


def list_tasks_today(timezone: str = "Asia/Tokyo") -> dict[str, Any]:
    now = datetime.now(ZoneInfo(timezone))
    today = now.date()

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        rows = cur.execute(
            "SELECT * FROM tasks WHERE is_deleted = 0 AND due_at IS NOT NULL"
        ).fetchall()

    items = []
    for row in rows:
        try:
            due = _parse_iso8601(row["due_at"]).astimezone(ZoneInfo(timezone))
        except Exception:
            continue
        if due.date() == today and row["status"] not in {"done", "canceled"}:
            items.append(_row_to_task(row))

    return {"items": items, "total": len(items)}


def list_tasks_overdue(timezone: str = "Asia/Tokyo") -> dict[str, Any]:
    now = datetime.now(ZoneInfo(timezone))

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        rows = cur.execute(
            "SELECT * FROM tasks WHERE is_deleted = 0 AND due_at IS NOT NULL"
        ).fetchall()

    items = []
    for row in rows:
        if row["status"] in {"done", "canceled"}:
            continue
        try:
            due = _parse_iso8601(row["due_at"]).astimezone(ZoneInfo(timezone))
        except Exception:
            continue
        if due < now:
            items.append(_row_to_task(row))

    return {"items": items, "total": len(items)}


def soft_delete_task(task_id: int) -> dict[str, Any]:
    if not isinstance(task_id, int) or task_id <= 0:
        raise ToolError("invalid_param", "task_id must be positive integer")
    now = now_iso8601()

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        cur.execute(
            "UPDATE tasks SET is_deleted = 1, updated_at = ? WHERE id = ?",
            (now, task_id),
        )
        row = cur.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
        if row is None:
            raise ToolError("not_found", "task not found", {"task_id": task_id})
        return _row_to_task(row)


def undo_task(task_id: int) -> dict[str, Any]:
    if not isinstance(task_id, int) or task_id <= 0:
        raise ToolError("invalid_param", "task_id must be positive integer")
    now = now_iso8601()

    with get_connection() as conn:
        ensure_tables(conn)
        cur = conn.cursor()
        cur.execute(
            "UPDATE tasks SET is_deleted = 0, updated_at = ? WHERE id = ?",
            (now, task_id),
        )
        row = cur.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
        if row is None:
            raise ToolError("not_found", "task not found", {"task_id": task_id})
        return _row_to_task(row)
