from __future__ import annotations

import time
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Optional
from zoneinfo import ZoneInfo

from api.db.connection import DEFAULT_TZ, ToolError, ensure_tables, get_connection, now_iso8601
from api.repositories.notifications_repo import NotificationRepository
from api.repositories.tasks_repo import TaskRepository
from api.services.notifications_service import NotificationService


@dataclass
class SchedulerResult:
    checked: int
    triggered: int
    skipped: int
    notification_ids: list[int]
    task_ids: list[int]


class ReminderScheduler:
    def __init__(self, *, timezone: str = DEFAULT_TZ, poll_limit: int = 200) -> None:
        self._timezone = timezone
        self._poll_limit = poll_limit

    def run_once(self, now: Optional[datetime] = None) -> SchedulerResult:
        now_dt = now or datetime.now(ZoneInfo(self._timezone))
        now_iso = now_dt.isoformat()

        with get_connection() as conn:
            ensure_tables(conn)
            task_repo = TaskRepository(conn)
            notification_service = NotificationService(NotificationRepository(conn))
            rows = task_repo.list_pending_reminders(self._poll_limit)

            notification_ids: list[int] = []
            task_ids: list[int] = []
            skipped = 0

            for row in rows:
                remind_at = row["remind_at"]
                if not remind_at:
                    skipped += 1
                    continue
                try:
                    remind_dt = _parse_iso8601(remind_at)
                except ToolError:
                    skipped += 1
                    continue
                if remind_dt > now_dt:
                    continue

                content = row["note"] or row["title"]
                notification = notification_service.create_notification(
                    task_id=row["id"],
                    title="Task Reminder",
                    content=content,
                    scheduled_at=remind_at,
                    sent_at=now_iso,
                )
                task_repo.update_fields(
                    row["id"],
                    {
                        "reminded_at": now_iso,
                        "notification_id": notification["notification_id"],
                        "updated_at": now_iso,
                    },
                )
                notification_ids.append(notification["notification_id"])
                task_ids.append(row["id"])

        return SchedulerResult(
            checked=len(rows),
            triggered=len(notification_ids),
            skipped=skipped,
            notification_ids=notification_ids,
            task_ids=task_ids,
        )

    def run_forever(self, poll_interval_seconds: float = 30.0) -> None:
        while True:
            self.run_once()
            time.sleep(poll_interval_seconds)


def _parse_iso8601(value: str) -> datetime:
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    dt = datetime.fromisoformat(value)
    if dt.tzinfo is None:
        raise ToolError("invalid_time", "ISO8601 time must include offset", {"value": value})
    return dt
