import sqlite3
from typing import Optional, Any
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from api.db.connection import get_constants, DEFAULT_TZ

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

    def get_todays_tasks_summary(self, start_date: str, end_date: str) -> list[dict[str, Any]]:
        cur = self._conn.cursor()
        # Fetch tasks due today or completed today.
        # We also look at tasks without due dates to see if they were completed today.
        cur.execute(
            """
            SELECT title, status, tags_json, completed_at, due_at
            FROM tasks
            WHERE is_deleted = 0
              AND (
                (due_at >= ? AND due_at <= ?)
                OR 
                (completed_at >= ? AND completed_at <= ?)
              )
            """,
            (start_date, end_date, start_date, end_date),
        )
        return [dict(row) for row in cur.fetchall()]
