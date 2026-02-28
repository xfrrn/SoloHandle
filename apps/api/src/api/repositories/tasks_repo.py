from __future__ import annotations

import sqlite3
from typing import Any, Iterable, Optional


class TaskRepository:
    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    def get_by_id(self, task_id: int) -> Optional[sqlite3.Row]:
        return self._conn.execute(
            "SELECT * FROM tasks WHERE id = ?", (task_id,)
        ).fetchone()

    def get_by_idempotency(self, key: str) -> Optional[sqlite3.Row]:
        return self._conn.execute(
            "SELECT * FROM tasks WHERE idempotency_key = ? LIMIT 1", (key,)
        ).fetchone()

    def insert(
        self,
        *,
        title: str,
        status: str,
        priority: str,
        due_at: Optional[str],
        remind_at: Optional[str],
        project: Optional[str],
        tags_json: str,
        note: Optional[str],
        idempotency_key: Optional[str],
        created_at: str,
        updated_at: str,
    ) -> int:
        cur = self._conn.execute(
            """
            INSERT INTO tasks (title, status, priority, due_at, remind_at, reminded_at, notification_id, repeat_rule, project, tags_json, note, idempotency_key, is_deleted, created_at, updated_at, completed_at)
            VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?, ?, ?, 0, ?, ?, NULL)
            """,
            (
                title,
                status,
                priority,
                due_at,
                remind_at,
                project,
                tags_json,
                note,
                idempotency_key,
                created_at,
                updated_at,
            ),
        )
        return int(cur.lastrowid)

    def update_fields(self, task_id: int, fields: dict[str, Any]) -> None:
        assignments = ", ".join(f"{k} = ?" for k in fields)
        params = list(fields.values()) + [task_id]
        self._conn.execute(f"UPDATE tasks SET {assignments} WHERE id = ?", params)

    def search(
        self,
        *,
        query: Optional[str],
        status: Optional[str],
        date_from: Optional[str],
        date_to: Optional[str],
        limit: int,
        offset: int,
    ) -> list[sqlite3.Row]:
        clauses = ["is_deleted = 0"]
        params: list[Any] = []

        if status:
            clauses.append("status = ?")
            params.append(status)

        if query:
            clauses.append("(title LIKE ? OR note LIKE ?)")
            params.extend([f"%{query}%", f"%{query}%"])

        if date_from:
            clauses.append("due_at >= ?")
            params.append(date_from)
        if date_to:
            clauses.append("due_at <= ?")
            params.append(date_to)

        where_sql = " AND ".join(clauses)
        rows = self._conn.execute(
            f"SELECT * FROM tasks WHERE {where_sql} ORDER BY due_at IS NULL, due_at ASC, created_at DESC LIMIT ? OFFSET ?",
            (*params, limit, offset),
        ).fetchall()
        return list(rows)

    def list_due_tasks(self) -> list[sqlite3.Row]:
        rows = self._conn.execute(
            "SELECT * FROM tasks WHERE is_deleted = 0 AND due_at IS NOT NULL"
        ).fetchall()
        return list(rows)

    def list_pending_reminders(self, limit: int) -> list[sqlite3.Row]:
        rows = self._conn.execute(
            """
            SELECT * FROM tasks
            WHERE is_deleted = 0
              AND remind_at IS NOT NULL
              AND reminded_at IS NULL
              AND status NOT IN ('done', 'canceled')
            ORDER BY remind_at ASC
            LIMIT ?
            """,
            (limit,),
        ).fetchall()
        return list(rows)
