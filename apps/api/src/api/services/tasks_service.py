from __future__ import annotations

from datetime import datetime
from typing import Any, Optional
from zoneinfo import ZoneInfo

from api.db.connection import ToolError, json_dumps, json_loads, now_iso8601
from api.repositories.tasks_repo import TaskRepository


class TaskService:
    def __init__(self, repo: TaskRepository) -> None:
        self._repo = repo

    @staticmethod
    def _row_to_task(row) -> dict[str, Any]:
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

    def create_task(
        self,
        *,
        title: str,
        status: str,
        priority: str,
        due_at: Optional[str],
        remind_at: Optional[str],
        tags: list[str],
        project: Optional[str],
        note: Optional[str],
        idempotency_key: Optional[str],
    ) -> dict[str, Any]:
        if idempotency_key:
            row = self._repo.get_by_idempotency(idempotency_key)
            if row is not None:
                return self._row_to_task(row)

        created_at = now_iso8601()
        updated_at = created_at
        task_id = self._repo.insert(
            title=title,
            status=status,
            priority=priority,
            due_at=due_at,
            remind_at=remind_at,
            project=project,
            tags_json=json_dumps(tags),
            note=note,
            idempotency_key=idempotency_key,
            created_at=created_at,
            updated_at=updated_at,
        )
        row = self._repo.get_by_id(task_id)
        return self._row_to_task(row)

    def update_task(self, task_id: int, fields: dict[str, Any]) -> dict[str, Any]:
        self._repo.update_fields(task_id, fields)
        row = self._repo.get_by_id(task_id)
        if row is None:
            raise ToolError("not_found", "task not found", {"task_id": task_id})
        return self._row_to_task(row)

    def complete_task(self, task_id: int) -> dict[str, Any]:
        now = now_iso8601()
        self._repo.update_fields(
            task_id,
            {"status": "done", "completed_at": now, "updated_at": now},
        )
        row = self._repo.get_by_id(task_id)
        if row is None:
            raise ToolError("not_found", "task not found", {"task_id": task_id})
        return self._row_to_task(row)

    def search_tasks(
        self,
        *,
        query: Optional[str],
        status: Optional[str],
        date_from: Optional[str],
        date_to: Optional[str],
        limit: int,
        offset: int,
    ) -> dict[str, Any]:
        rows = self._repo.search(
            query=query,
            status=status,
            date_from=date_from,
            date_to=date_to,
            limit=limit,
            offset=offset,
        )
        items = [self._row_to_task(r) for r in rows]
        return {"items": items, "total": len(items)}

    def list_tasks_today(self, timezone: str) -> dict[str, Any]:
        now = datetime.now(ZoneInfo(timezone))
        today = now.date()

        rows = self._repo.list_due_tasks()
        items = []
        for row in rows:
            try:
                due = _parse_iso8601(row["due_at"]).astimezone(ZoneInfo(timezone))
            except Exception:
                continue
            if due.date() == today and row["status"] not in {"done", "canceled"}:
                items.append(self._row_to_task(row))

        return {"items": items, "total": len(items)}

    def list_tasks_overdue(self, timezone: str) -> dict[str, Any]:
        now = datetime.now(ZoneInfo(timezone))

        rows = self._repo.list_due_tasks()
        items = []
        for row in rows:
            if row["status"] in {"done", "canceled"}:
                continue
            try:
                due = _parse_iso8601(row["due_at"]).astimezone(ZoneInfo(timezone))
            except Exception:
                continue
            if due < now:
                items.append(self._row_to_task(row))

        return {"items": items, "total": len(items)}

    def set_deleted(self, task_id: int, is_deleted: int) -> dict[str, Any]:
        now = now_iso8601()
        self._repo.update_fields(task_id, {"is_deleted": is_deleted, "updated_at": now})
        row = self._repo.get_by_id(task_id)
        if row is None:
            raise ToolError("not_found", "task not found", {"task_id": task_id})
        return self._row_to_task(row)


def _parse_iso8601(value: str) -> datetime:
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    dt = datetime.fromisoformat(value)
    if dt.tzinfo is None:
        raise ToolError("invalid_time", "ISO8601 time must include offset", {"value": value})
    return dt


__all__ = ["TaskService"]
