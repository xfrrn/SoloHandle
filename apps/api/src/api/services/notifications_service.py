from __future__ import annotations

from typing import Any, Optional

from api.db.connection import ToolError, now_iso8601
from api.repositories.notifications_repo import NotificationRepository


class NotificationService:
    def __init__(self, repo: NotificationRepository) -> None:
        self._repo = repo

    @staticmethod
    def _row_to_notification(row) -> dict[str, Any]:
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

    def create_notification(
        self,
        *,
        task_id: Optional[int],
        title: str,
        content: Optional[str],
        scheduled_at: str,
    ) -> dict[str, Any]:
        created_at = now_iso8601()
        notification_id = self._repo.insert(
            task_id=task_id,
            title=title,
            content=content,
            scheduled_at=scheduled_at,
            created_at=created_at,
        )
        row = self._repo.get_by_id(notification_id)
        return self._row_to_notification(row)

    def list_notifications(self, unread_only: bool, limit: int) -> dict[str, Any]:
        rows = self._repo.list(unread_only, limit)
        items = [self._row_to_notification(r) for r in rows]
        return {"items": items, "total": len(items)}

    def mark_read(self, notification_id: int) -> dict[str, Any]:
        now = now_iso8601()
        self._repo.mark_read(notification_id, now)
        row = self._repo.get_by_id(notification_id)
        if row is None:
            raise ToolError(
                "not_found", "notification not found", {"notification_id": notification_id}
            )
        return self._row_to_notification(row)


__all__ = ["NotificationService"]
