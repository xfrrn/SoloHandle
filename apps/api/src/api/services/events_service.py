from __future__ import annotations

from typing import Any, Iterable, Optional

from api.db.connection import ToolError, json_dumps, json_loads, now_iso8601
from api.repositories.events_repo import EventRepository


class EventService:
    def __init__(self, repo: EventRepository) -> None:
        self._repo = repo

    @staticmethod
    def _row_to_event(row) -> dict[str, Any]:
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

    def create_event(
        self,
        *,
        event_type: str,
        data: dict[str, Any],
        happened_at: str,
        tags: list[str],
        source: str,
        confidence: float,
        idempotency_key: Optional[str],
    ) -> dict[str, Any]:
        if idempotency_key:
            row = self._repo.get_by_idempotency(idempotency_key)
            if row is not None:
                return self._row_to_event(row)

        created_at = now_iso8601()
        updated_at = created_at
        event_id = self._repo.insert(
            event_type=event_type,
            data_json=json_dumps(data),
            happened_at=happened_at,
            tags_json=json_dumps(tags),
            source=source,
            confidence=confidence,
            idempotency_key=idempotency_key,
            created_at=created_at,
            updated_at=updated_at,
        )
        row = self._repo.get_by_id(event_id)
        return self._row_to_event(row)

    def search_events(
        self,
        *,
        query: Optional[str],
        types: Optional[Iterable[str]],
        date_from: Optional[str],
        date_to: Optional[str],
        limit: int,
        offset: int,
    ) -> dict[str, Any]:
        rows = self._repo.search(
            query=query,
            types=types,
            date_from=date_from,
            date_to=date_to,
            limit=limit,
            offset=offset,
        )
        items = [self._row_to_event(r) for r in rows]
        return {"items": items, "total": len(items)}

    def set_deleted(self, event_id: int, is_deleted: int) -> dict[str, Any]:
        now = now_iso8601()
        self._repo.update_is_deleted(event_id, is_deleted, now)
        row = self._repo.get_by_id(event_id)
        if row is None:
            raise ToolError("not_found", "event not found", {"event_id": event_id})
        return self._row_to_event(row)


__all__ = ["EventService"]
