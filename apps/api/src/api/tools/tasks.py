from __future__ import annotations

from typing import Any, Iterable, Optional

from api.services.tasks_service import (
    complete_task as _complete_task,
    create_task as _create_task,
    list_tasks_overdue as _list_tasks_overdue,
    list_tasks_today as _list_tasks_today,
    postpone_task as _postpone_task,
    search_tasks as _search_tasks,
    soft_delete_task as _soft_delete_task,
    undo_task as _undo_task,
    update_task as _update_task,
)


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
    """Create a task."""
    return _create_task(
        title=title,
        due_at=due_at,
        remind_at=remind_at,
        priority=priority,
        tags=tags,
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
    return _update_task(
        task_id=task_id,
        title=title,
        status=status,
        priority=priority,
        due_at=due_at,
        remind_at=remind_at,
        tags=tags,
        project=project,
        note=note,
    )


def complete_task(task_id: int) -> dict[str, Any]:
    """Complete a task."""
    return _complete_task(task_id)


def postpone_task(
    *,
    task_id: int,
    new_due_at: Optional[str] = None,
    new_remind_at: Optional[str] = None,
) -> dict[str, Any]:
    """Postpone a task due/remind time."""
    return _postpone_task(
        task_id=task_id, new_due_at=new_due_at, new_remind_at=new_remind_at
    )


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
    return _search_tasks(
        query=query,
        status=status,
        date_from=date_from,
        date_to=date_to,
        limit=limit,
        offset=offset,
    )


def list_tasks_today(timezone: str = "Asia/Tokyo") -> dict[str, Any]:
    """List tasks due today in the given timezone."""
    return _list_tasks_today(timezone)


def list_tasks_overdue(timezone: str = "Asia/Tokyo") -> dict[str, Any]:
    """List overdue tasks in the given timezone."""
    return _list_tasks_overdue(timezone)


def soft_delete_task(task_id: int) -> dict[str, Any]:
    """Soft delete a task."""
    return _soft_delete_task(task_id)


def undo_task(task_id: int) -> dict[str, Any]:
    """Undo soft delete for a task."""
    return _undo_task(task_id)
