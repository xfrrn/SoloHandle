from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any, Iterable, Optional

from api.core.constants_loader import get_constants
from api.db.connection import (
    ToolError,
    ensure_iso8601,
    ensure_tables,
    get_connection,
    json_dumps,
    normalize_tags,
    now_iso8601,
    require_enum,
    require_non_empty_str,
)
from api.repositories.tasks_repo import TaskRepository
from api.services.tasks_service import TaskService


def _parse_iso8601(value: str) -> datetime:
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    dt = datetime.fromisoformat(value)
    if dt.tzinfo is None:
        raise ToolError("invalid_time", "ISO8601 time must include offset", {"value": value})
    return dt

def create_task(
    *,
    title: Any,
    due_at: Optional[str] = None,
    remind_at: Optional[str] = None,
    priority: Optional[str] = None,
    tags: Optional[Iterable[str]] = None,
    project: Optional[str] = None,
    note: Optional[str] = None,
    idempotency_key: Optional[str] = None,
) -> dict[str, Any]:
    """Create a task."""
    consts = get_constants()
    title_value = require_non_empty_str(title, "title")
    pr = require_enum(
        priority or consts.task.default_priority,
        "priority",
        consts.task.priority,
    )
    if project is not None and not isinstance(project, str):
        raise ToolError("invalid_param", "project must be string or null")
    if note is not None and not isinstance(note, str):
        raise ToolError("invalid_param", "note must be string or null")

    due_at_iso = ensure_iso8601(due_at)
    remind_at_iso = ensure_iso8601(remind_at)
    if due_at_iso is not None and remind_at_iso is None:
        minutes = consts.task.default_remind_offset_minutes
        if minutes > 0:
            try:
                dt = _parse_iso8601(due_at_iso)
                remind_at_iso = (dt - timedelta(minutes=minutes)).isoformat()
            except ToolError:
                pass
    tags_list = normalize_tags(tags)

    with get_connection() as conn:
        ensure_tables(conn)
        service = TaskService(TaskRepository(conn))
        return service.create_task(
            title=title_value,
            status=consts.task.default_status,
            priority=pr,
            due_at=due_at_iso,
            remind_at=remind_at_iso,
            tags=tags_list,
            project=project,
            note=note,
            idempotency_key=idempotency_key,
        )


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
    """Update a task."""
    consts = get_constants()
    if not isinstance(task_id, int) or task_id <= 0:
        raise ToolError("invalid_param", "task_id must be positive integer")

    fields: dict[str, Any] = {}
    if title is not None:
        fields["title"] = require_non_empty_str(title, "title")
    if status is not None:
        fields["status"] = require_enum(status, "status", consts.task.status)
    if priority is not None:
        fields["priority"] = require_enum(priority, "priority", consts.task.priority)
    if due_at is not None:
        fields["due_at"] = ensure_iso8601(due_at)
    if remind_at is not None:
        fields["remind_at"] = ensure_iso8601(remind_at)
        fields["reminded_at"] = None
        fields["notification_id"] = None
    if tags is not None:
        fields["tags_json"] = json_dumps(normalize_tags(tags))
    if project is not None:
        if not isinstance(project, str):
            raise ToolError("invalid_param", "project must be string or null")
        fields["project"] = project
    if note is not None:
        if not isinstance(note, str):
            raise ToolError("invalid_param", "note must be string or null")
        fields["note"] = note

    if not fields:
        raise ToolError("invalid_param", "no fields to update")

    fields["updated_at"] = now_iso8601()

    with get_connection() as conn:
        ensure_tables(conn)
        service = TaskService(TaskRepository(conn))
        return service.update_task(task_id, fields)


def complete_task(task_id: int) -> dict[str, Any]:
    """Complete a task."""
    if not isinstance(task_id, int) or task_id <= 0:
        raise ToolError("invalid_param", "task_id must be positive integer")

    with get_connection() as conn:
        ensure_tables(conn)
        service = TaskService(TaskRepository(conn))
        return service.complete_task(task_id)


def postpone_task(
    *,
    task_id: int,
    new_due_at: Optional[str] = None,
    new_remind_at: Optional[str] = None,
) -> dict[str, Any]:
    """Postpone a task due/remind time."""
    if not isinstance(task_id, int) or task_id <= 0:
        raise ToolError("invalid_param", "task_id must be positive integer")
    if new_due_at is None and new_remind_at is None:
        raise ToolError("invalid_param", "new_due_at or new_remind_at required")

    fields: dict[str, Any] = {}
    if new_due_at is not None:
        fields["due_at"] = ensure_iso8601(new_due_at)
    if new_remind_at is not None:
        fields["remind_at"] = ensure_iso8601(new_remind_at)
        fields["reminded_at"] = None
        fields["notification_id"] = None
    fields["updated_at"] = now_iso8601()

    with get_connection() as conn:
        ensure_tables(conn)
        service = TaskService(TaskRepository(conn))
        return service.update_task(task_id, fields)


def search_tasks(
    *,
    query: Optional[str] = None,
    status: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
) -> dict[str, Any]:
    """Search tasks using simple filters."""
    if limit <= 0 or limit > 200:
        raise ToolError("invalid_param", "limit must be in 1..200")
    if offset < 0:
        raise ToolError("invalid_param", "offset must be >= 0")

    status_value = None
    if status is not None:
        consts = get_constants()
        status_value = require_enum(status, "status", consts.task.status)

    date_from_iso = ensure_iso8601(date_from)
    date_to_iso = ensure_iso8601(date_to)

    with get_connection() as conn:
        ensure_tables(conn)
        service = TaskService(TaskRepository(conn))
        return service.search_tasks(
            query=query,
            status=status_value,
            date_from=date_from_iso,
            date_to=date_to_iso,
            limit=limit,
            offset=offset,
        )


def list_tasks_today(timezone: Optional[str] = None) -> dict[str, Any]:
    """List tasks due today in the given timezone."""
    consts = get_constants()
    tz = timezone or consts.defaults.timezone
    with get_connection() as conn:
        ensure_tables(conn)
        service = TaskService(TaskRepository(conn))
        return service.list_tasks_today(tz)


def list_tasks_overdue(timezone: Optional[str] = None) -> dict[str, Any]:
    """List overdue tasks in the given timezone."""
    consts = get_constants()
    tz = timezone or consts.defaults.timezone
    with get_connection() as conn:
        ensure_tables(conn)
        service = TaskService(TaskRepository(conn))
        return service.list_tasks_overdue(tz)


def soft_delete_task(task_id: int) -> dict[str, Any]:
    """Soft delete a task."""
    if not isinstance(task_id, int) or task_id <= 0:
        raise ToolError("invalid_param", "task_id must be positive integer")

    with get_connection() as conn:
        ensure_tables(conn)
        service = TaskService(TaskRepository(conn))
        return service.set_deleted(task_id, 1)


def undo_task(task_id: int) -> dict[str, Any]:
    """Undo soft delete for a task."""
    if not isinstance(task_id, int) or task_id <= 0:
        raise ToolError("invalid_param", "task_id must be positive integer")

    with get_connection() as conn:
        ensure_tables(conn)
        service = TaskService(TaskRepository(conn))
        return service.set_deleted(task_id, 0)
