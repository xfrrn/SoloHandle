from __future__ import annotations

import sqlite3
from typing import Any, Iterable, Optional


class EventRepository:
    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    def get_by_id(self, event_id: int) -> Optional[sqlite3.Row]:
        return self._conn.execute(
            "SELECT * FROM events WHERE id = ?", (event_id,)
        ).fetchone()

    def get_by_idempotency(self, key: str) -> Optional[sqlite3.Row]:
        return self._conn.execute(
            "SELECT * FROM events WHERE idempotency_key = ? LIMIT 1", (key,)
        ).fetchone()

    def insert(
        self,
        *,
        event_type: str,
        data_json: str,
        happened_at: str,
        tags_json: str,
        source: str,
        confidence: float,
        idempotency_key: Optional[str],
        created_at: str,
        updated_at: str,
    ) -> int:
        cur = self._conn.execute(
            """
            INSERT INTO events (type, data_json, happened_at, tags_json, source, confidence, idempotency_key, is_deleted, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
            """,
            (
                event_type,
                data_json,
                happened_at,
                tags_json,
                source,
                confidence,
                idempotency_key,
                created_at,
                updated_at,
            ),
        )
        return int(cur.lastrowid)

    def search(
        self,
        *,
        query: Optional[str],
        types: Optional[Iterable[str]],
        date_from: Optional[str],
        date_to: Optional[str],
        limit: int,
        offset: int,
    ) -> list[sqlite3.Row]:
        clauses = ["is_deleted = 0"]
        params: list[Any] = []

        if types:
            placeholders = ",".join("?" for _ in types)
            clauses.append(f"type IN ({placeholders})")
            params.extend(list(types))

        if query:
            clauses.append("data_json LIKE ?")
            params.append(f"%{query}%")

        if date_from:
            clauses.append("happened_at >= ?")
            params.append(date_from)
        if date_to:
            clauses.append("happened_at <= ?")
            params.append(date_to)

        where_sql = " AND ".join(clauses)
        rows = self._conn.execute(
            f"SELECT * FROM events WHERE {where_sql} ORDER BY happened_at DESC LIMIT ? OFFSET ?",
            (*params, limit, offset),
        ).fetchall()
        return list(rows)

    def update_is_deleted(self, event_id: int, is_deleted: int, updated_at: str) -> None:
        self._conn.execute(
            "UPDATE events SET is_deleted = ?, updated_at = ? WHERE id = ?",
            (is_deleted, updated_at, event_id),
        )
