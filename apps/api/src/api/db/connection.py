from __future__ import annotations

import json
import os
from pathlib import Path
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Iterable, Optional
from zoneinfo import ZoneInfo

DEFAULT_TZ = "Asia/Shanghai"
DEFAULT_DB_PATH = str(Path(__file__).resolve().parents[5] / "data" / "app.db")


@dataclass
class ToolError(Exception):
    code: str
    message: str
    details: Optional[dict] = None

    def __str__(self) -> str:
        return f"{self.code}: {self.message}"


def get_db_path() -> str:
    return os.environ.get("APP_DB_PATH", DEFAULT_DB_PATH)


def get_connection() -> sqlite3.Connection:
    db_path = get_db_path()
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def ensure_tables(conn: sqlite3.Connection) -> None:
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            data_json TEXT NOT NULL,
            happened_at TEXT NOT NULL,
            tags_json TEXT NOT NULL,
            source TEXT NOT NULL,
            confidence REAL NOT NULL,
            idempotency_key TEXT,
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
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            status TEXT NOT NULL,
            priority TEXT NOT NULL,
            due_at TEXT,
            remind_at TEXT,
            repeat_rule TEXT,
            project TEXT,
            tags_json TEXT NOT NULL,
            note TEXT,
            idempotency_key TEXT,
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
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER,
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
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            request_id TEXT,
            draft_id TEXT,
            tool_name TEXT,
            payload_json TEXT,
            result_json TEXT,
            undo_token TEXT,
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

    conn.commit()


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
    if len(out) > 20:
        raise ToolError("too_many_tags", "Tags size must be <= 20", {"count": len(out)})
    return out


def require_non_empty_str(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ToolError("invalid_param", f"{field} must be non-empty string")
    return value.strip()


def require_positive_number(value: Any, field: str) -> float:
    try:
        num = float(value)
    except Exception as exc:  # noqa: BLE001
        raise ToolError("invalid_param", f"{field} must be a number") from exc
    if num <= 0:
        raise ToolError("invalid_param", f"{field} must be > 0")
    return num


def require_enum(value: Any, field: str, allowed: Iterable[str]) -> str:
    if not isinstance(value, str):
        raise ToolError("invalid_param", f"{field} must be string")
    if value not in allowed:
        raise ToolError("invalid_param", f"{field} must be one of {sorted(set(allowed))}")
    return value


def require_number_in_range(value: Any, field: str, min_value: float, max_value: float) -> float:
    try:
        num = float(value)
    except Exception as exc:  # noqa: BLE001
        raise ToolError("invalid_param", f"{field} must be a number") from exc
    if num < min_value or num > max_value:
        raise ToolError(
            "invalid_param",
            f"{field} must be in range [{min_value}, {max_value}]",
        )
    return num
