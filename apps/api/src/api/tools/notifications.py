from __future__ import annotations

from typing import Optional

from api.db.connection import ToolError, ensure_iso8601, ensure_tables, get_connection, require_non_empty_str
from api.repositories.notifications_repo import NotificationRepository
from api.services.notifications_service import NotificationService


def create_notification_for_task(
    *,
    task_id: Optional[int],
    scheduled_at: str,
    title: Optional[str] = None,
    content: Optional[str] = None,
) -> dict:
    """Create a notification record for a task."""
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

    with get_connection() as conn:
        ensure_tables(conn)
        service = NotificationService(NotificationRepository(conn))
        return service.create_notification(
            task_id=task_id,
            title=title_value,
            content=content,
            scheduled_at=scheduled_at_iso,
        )


def list_notifications(unread_only: bool = True, limit: int = 20) -> dict:
    """List notifications."""
    if limit <= 0 or limit > 200:
        raise ToolError("invalid_param", "limit must be in 1..200")

    with get_connection() as conn:
        ensure_tables(conn)
        service = NotificationService(NotificationRepository(conn))
        return service.list_notifications(unread_only=unread_only, limit=limit)


def mark_notification_read(notification_id: int) -> dict:
    """Mark notification as read."""
    if not isinstance(notification_id, int) or notification_id <= 0:
        raise ToolError("invalid_param", "notification_id must be positive integer")

    with get_connection() as conn:
        ensure_tables(conn)
        service = NotificationService(NotificationRepository(conn))
        return service.mark_read(notification_id)
