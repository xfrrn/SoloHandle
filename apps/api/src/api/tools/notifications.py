from __future__ import annotations

from typing import Optional

from api.services.notifications_service import (
    create_notification_for_task as _create_notification_for_task,
    list_notifications as _list_notifications,
    mark_notification_read as _mark_notification_read,
)


def create_notification_for_task(
    *,
    task_id: Optional[int],
    scheduled_at: str,
    title: Optional[str] = None,
    content: Optional[str] = None,
) -> dict:
    """Create a notification record for a task."""
    return _create_notification_for_task(
        task_id=task_id,
        scheduled_at=scheduled_at,
        title=title,
        content=content,
    )


def list_notifications(unread_only: bool = True, limit: int = 20) -> dict:
    """List notifications."""
    return _list_notifications(unread_only=unread_only, limit=limit)


def mark_notification_read(notification_id: int) -> dict:
    """Mark notification as read."""
    return _mark_notification_read(notification_id)
