from __future__ import annotations

import time
from typing import Any, Optional


class OrchestratorRepository:
    def __init__(self, conn) -> None:
        self._conn = conn

    def insert_log(
        self,
        *,
        kind: str,
        request_id: Optional[str],
        draft_id: Optional[str],
        tool_name: Optional[str],
        payload_json: Optional[str],
        result_json: Optional[str],
        undo_token: Optional[str],
        commit_id: Optional[str],
        created_at: str,
    ) -> int:
        cur = self._execute_write(
            """
            INSERT INTO orchestrator_logs (
                kind, request_id, draft_id, tool_name, payload_json, result_json, undo_token, commit_id, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            RETURNING id
            """,
            (
                kind,
                request_id,
                draft_id,
                tool_name,
                payload_json,
                result_json,
                undo_token,
                commit_id,
                created_at,
            ),
        )
        row = cur.fetchone()
        return int(row["id"])

    def get_drafts_by_ids(self, draft_ids: list[str]) -> list[dict[str, Any]]:
        if not draft_ids:
            return []
        placeholders = ",".join("?" for _ in draft_ids)
        rows = self._conn.execute(
            f"SELECT * FROM orchestrator_logs WHERE kind = 'draft' AND draft_id IN ({placeholders})",
            tuple(draft_ids),
        ).fetchall()
        return list(rows)

    def get_draft_by_id(self, draft_id: str) -> Optional[dict[str, Any]]:
        row = self._conn.execute(
            "SELECT * FROM orchestrator_logs WHERE kind = 'draft' AND draft_id = ?",
            (draft_id,),
        ).fetchone()
        return row

    def update_draft_payload(self, draft_id: str, payload_json: str) -> None:
        self._execute_write(
            "UPDATE orchestrator_logs SET payload_json = ? WHERE kind = 'draft' AND draft_id = ?",
            (payload_json, draft_id),
        )

    def get_commits_by_undo_token(self, undo_token: str) -> list[dict[str, Any]]:
        rows = self._conn.execute(
            "SELECT * FROM orchestrator_logs WHERE kind = 'commit' AND undo_token = ?",
            (undo_token,),
        ).fetchall()
        return list(rows)

    def get_commit_by_id(self, commit_id: str) -> Optional[dict[str, Any]]:
        row = self._conn.execute(
            "SELECT * FROM orchestrator_logs WHERE kind = 'commit' AND commit_id = ?",
            (commit_id,),
        ).fetchone()
        return row

    def get_commit_by_draft_id(self, draft_id: str) -> Optional[dict[str, Any]]:
        row = self._conn.execute(
            "SELECT * FROM orchestrator_logs WHERE kind = 'commit' AND draft_id = ? ORDER BY id DESC LIMIT 1",
            (draft_id,),
        ).fetchone()
        return row

    def _execute_write(
        self, sql: str, params: tuple[Any, ...], retries: int = 4, base_sleep: float = 0.05
    ):
        last_error: Optional[Exception] = None
        for attempt in range(retries + 1):
            try:
                cur = self._conn.execute(sql, params)
                self._conn.commit()
                return cur
            except Exception as exc:
                last_error = exc
                msg = str(exc).lower()
                if (
                    "database is locked" not in msg
                    and "could not obtain lock" not in msg
                    and "deadlock detected" not in msg
                ) or attempt >= retries:
                    raise
                time.sleep(base_sleep * (attempt + 1))
        assert last_error is not None
        raise last_error
