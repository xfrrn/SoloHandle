import sqlite3
from typing import Any

class DashboardRepository:
    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    def get_expenses_summary(self, start_date: str, end_date: str) -> list[dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute(
            """
            SELECT happened_at, data_json 
            FROM events 
            WHERE type = 'expense' 
              AND is_deleted = 0 
              AND happened_at >= ?
              AND happened_at <= ?
            """,
            (start_date, end_date),
        )
        return [dict(row) for row in cur.fetchall()]

    def get_moods_summary(self, start_date: str, end_date: str) -> list[dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute(
            """
            SELECT happened_at, data_json 
            FROM events 
            WHERE type = 'mood' 
              AND is_deleted = 0 
              AND happened_at >= ?
              AND happened_at <= ?
            """,
            (start_date, end_date),
        )
        return [dict(row) for row in cur.fetchall()]

    def get_tasks_summary_by_due_window(self) -> list[dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute(
            """
            SELECT status, due_at, completed_at
            FROM tasks
            WHERE is_deleted = 0
              AND due_at IS NOT NULL
            """,
        )
        return [dict(row) for row in cur.fetchall()]

    def get_all_records_happened_at(self) -> list[str]:
        cur = self._conn.cursor()
        rows = cur.execute(
            """
            SELECT happened_at
            FROM events
            WHERE is_deleted = 0
            """,
        ).fetchone()
        out: list[str] = []
        for row in rows.fetchall():
            value = row["happened_at"]
            if isinstance(value, str):
                out.append(value)
        return out
