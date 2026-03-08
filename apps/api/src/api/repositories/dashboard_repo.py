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

    def get_tasks_summary_by_due_window(self, start_date: str, end_date: str) -> list[dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute(
            """
            SELECT status, due_at, completed_at
            FROM tasks
            WHERE is_deleted = 0
              AND due_at >= ?
              AND due_at <= ?
            """,
            (start_date, end_date),
        )
        return [dict(row) for row in cur.fetchall()]

    def get_todays_records_count(self, start_date: str, end_date: str) -> int:
        cur = self._conn.cursor()
        row = cur.execute(
            """
            SELECT COUNT(1) AS count
            FROM events
            WHERE is_deleted = 0
              AND happened_at >= ?
              AND happened_at <= ?
            """,
            (start_date, end_date),
        ).fetchone()
        return int(row["count"]) if row else 0
