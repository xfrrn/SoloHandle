from __future__ import annotations

import sqlite3
from typing import Optional


class NotificationRepository:
    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    def get_by_id(self, notification_id: int) -> Optional[sqlite3.Row]:
        return self._conn.execute(
            "SELECT * FROM notifications WHERE id = ?", (notification_id,)
        ).fetchone()

    def insert(
        self,
        *,
        task_id: Optional[int],
        title: str,
        content: Optional[str],
        scheduled_at: str,
        created_at: str,
    ) -> int:
        cur = self._conn.execute(
            """
            INSERT INTO notifications (task_id, title, content, scheduled_at, sent_at, read_at, is_deleted, created_at)
            VALUES (?, ?, ?, ?, NULL, NULL, 0, ?)
            """,
            (task_id, title, content, scheduled_at, created_at),
        )
        return int(cur.lastrowid)

    def list(self, unread_only: bool, limit: int) -> list[sqlite3.Row]:
        clauses = ["is_deleted = 0"]
        if unread_only:
            clauses.append("read_at IS NULL")
        where_sql = " AND ".join(clauses)
        rows = self._conn.execute(
            f"SELECT * FROM notifications WHERE {where_sql} ORDER BY scheduled_at ASC LIMIT ?",
            (limit,),
        ).fetchall()
        return list(rows)

    def mark_read(self, notification_id: int, read_at: str) -> None:
        self._conn.execute(
            "UPDATE notifications SET read_at = ? WHERE id = ?",
            (read_at, notification_id),
        )
