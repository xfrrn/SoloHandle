from __future__ import annotations

import json
import os
import threading
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Iterable, Optional
from zoneinfo import ZoneInfo

import psycopg
from psycopg.rows import dict_row

from api.core.constants_loader import get_constants
from api.settings import load_db_settings

DEFAULT_TZ = get_constants().defaults.timezone
DEFAULT_DB_URL = "postgresql://postgres:postgres@localhost:5432/solohandle"

_tables_ready = False
_tables_lock = threading.Lock()


@dataclass
class ToolError(Exception):
    code: str
    message: str
    details: Optional[dict] = None

    def __str__(self) -> str:
        return f"{self.code}: {self.message}"


class DBCursor:
    def __init__(self, cursor: psycopg.Cursor) -> None:
        self._cursor = cursor

    def execute(self, sql: str, params: Iterable[Any] | None = None) -> DBCursor:
        self._cursor.execute(_adapt_sql(sql), tuple(params or ()))
        return self

    def fetchone(self) -> Optional[dict[str, Any]]:
        return self._cursor.fetchone()

    def fetchall(self) -> list[dict[str, Any]]:
        rows = self._cursor.fetchall()
        return list(rows)

    @property
    def lastrowid(self) -> Optional[int]:
        return None


class DBConnection:
    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def execute(self, sql: str, params: Iterable[Any] | None = None) -> DBCursor:
        cur = self._conn.cursor()
        cur.execute(_adapt_sql(sql), tuple(params or ()))
        return DBCursor(cur)

    def cursor(self) -> DBCursor:
        return DBCursor(self._conn.cursor())

    def commit(self) -> None:
        self._conn.commit()

    def rollback(self) -> None:
        self._conn.rollback()

    def close(self) -> None:
        self._conn.close()

    def __enter__(self) -> DBConnection:
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        try:
            if exc is None:
                self._conn.commit()
            else:
                self._conn.rollback()
        finally:
            self._conn.close()


def _adapt_sql(sql: str) -> str:
    return sql.replace("?", "%s")


def get_db_url() -> str:
    from_env = os.environ.get("APP_DB_URL")
    if from_env and from_env.strip():
        return from_env.strip()
    from_config = load_db_settings()
    if from_config is not None and from_config.url.strip():
        return from_config.url.strip()
    return DEFAULT_DB_URL


def get_connection() -> DBConnection:
    conn = psycopg.connect(
        get_db_url(),
        row_factory=dict_row,
        autocommit=False,
    )
    return DBConnection(conn)


def ensure_tables(conn: DBConnection) -> None:
    global _tables_ready
    if _tables_ready:
        return
    with _tables_lock:
        if _tables_ready:
            return

        cur = conn.cursor()
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS events (
                id BIGSERIAL PRIMARY KEY,
                type TEXT NOT NULL,
                data_json TEXT NOT NULL,
                happened_at TEXT NOT NULL,
                tags_json TEXT NOT NULL,
                source TEXT NOT NULL,
                confidence DOUBLE PRECISION NOT NULL,
                idempotency_key TEXT,
                commit_id TEXT,
                is_deleted INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_events_type_happened_at ON events(type, happened_at)"
        )
        cur.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_events_idempotency_key ON events(idempotency_key)"
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS tasks (
                id BIGSERIAL PRIMARY KEY,
                title TEXT NOT NULL,
                status TEXT NOT NULL,
                priority TEXT NOT NULL,
                due_at TEXT,
                remind_at TEXT,
                reminded_at TEXT,
                notification_id BIGINT,
                repeat_rule TEXT,
                project TEXT,
                tags_json TEXT NOT NULL,
                note TEXT,
                idempotency_key TEXT,
                commit_id TEXT,
                is_deleted INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                completed_at TEXT
            )
            """
        )
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_tasks_status_due_at ON tasks(status, due_at)"
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_tasks_remind_at ON tasks(remind_at)")
        cur.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_idempotency_key ON tasks(idempotency_key)"
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS notifications (
                id BIGSERIAL PRIMARY KEY,
                task_id BIGINT,
                title TEXT NOT NULL,
                content TEXT,
                scheduled_at TEXT NOT NULL,
                sent_at TEXT,
                read_at TEXT,
                is_deleted INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL
            )
            """
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_notifications_task_id ON notifications(task_id)")
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_notifications_scheduled_at ON notifications(scheduled_at)"
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_notifications_read_at ON notifications(read_at)")

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS orchestrator_logs (
                id BIGSERIAL PRIMARY KEY,
                kind TEXT NOT NULL,
                request_id TEXT,
                draft_id TEXT,
                tool_name TEXT,
                payload_json TEXT,
                result_json TEXT,
                undo_token TEXT,
                commit_id TEXT,
                created_at TEXT NOT NULL
            )
            """
        )
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_orchestrator_draft_id ON orchestrator_logs(draft_id)"
        )
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_orchestrator_undo_token ON orchestrator_logs(undo_token)"
        )

        cur.execute("ALTER TABLE tasks ADD COLUMN IF NOT EXISTS reminded_at TEXT")
        cur.execute("ALTER TABLE tasks ADD COLUMN IF NOT EXISTS notification_id BIGINT")
        cur.execute("ALTER TABLE tasks ADD COLUMN IF NOT EXISTS commit_id TEXT")
        cur.execute("ALTER TABLE events ADD COLUMN IF NOT EXISTS commit_id TEXT")
        cur.execute("ALTER TABLE orchestrator_logs ADD COLUMN IF NOT EXISTS commit_id TEXT")

        conn.commit()
        _tables_ready = True


def now_iso8601(tz: str = DEFAULT_TZ) -> str:
    dt = datetime.now(ZoneInfo(tz))
    return dt.isoformat()


def _parse_iso8601(value: str) -> datetime:
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    dt = datetime.fromisoformat(value)
    if dt.tzinfo is None:
        raise ToolError("invalid_time", "ISO8601 time must include offset", {"value": value})
    return dt


def normalize_iso8601(value: Optional[str], tz: str = DEFAULT_TZ) -> str:
    if value is None:
        return now_iso8601(tz)
    dt = _parse_iso8601(value)
    return dt.isoformat()


def ensure_iso8601(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    dt = _parse_iso8601(value)
    return dt.isoformat()


def json_dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def json_loads(value: str) -> Any:
    return json.loads(value)


def normalize_tags(tags: Optional[Iterable[str]]) -> list[str]:
    consts = get_constants()
    if tags is None:
        return []
    if isinstance(tags, str):
        raise ToolError("invalid_tag", "Tags must be list of strings")
    out: list[str] = []
    for t in tags:
        if not isinstance(t, str):
            raise ToolError("invalid_tag", "Tag must be string")
        s = t.strip()
        if not s:
            continue
        out.append(s)
    if len(out) > consts.limits.max_tags:
        raise ToolError(
            "too_many_tags",
            f"Tags size must be <= {consts.limits.max_tags}",
            {"count": len(out)},
        )
    return out


def require_non_empty_str(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ToolError("invalid_param", f"{field} must be non-empty string")
    return value.strip()


def require_enum(value: Any, field: str, allowed: Iterable[str]) -> str:
    s = require_non_empty_str(value, field)
    allowed_list = list(allowed)
    if s not in allowed_list:
        raise ToolError("invalid_param", f"{field} must be one of {allowed_list}")
    return s


def require_number_in_range(
    value: Any,
    field: str,
    min_value: float,
    max_value: float,
) -> float:
    if not isinstance(value, (int, float)):
        raise ToolError("invalid_param", f"{field} must be number")
    val = float(value)
    if val < min_value or val > max_value:
        raise ToolError(
            "invalid_param",
            f"{field} must be in [{min_value}, {max_value}]",
        )
    return val


def require_positive_number(value: Any, field: str) -> float:
    if not isinstance(value, (int, float)):
        raise ToolError("invalid_param", f"{field} must be number")
    val = float(value)
    if val <= 0:
        raise ToolError("invalid_param", f"{field} must be > 0")
    return val
