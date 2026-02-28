from __future__ import annotations

import sqlite3
from typing import Any, Optional


class OrchestratorRepository:
    def __init__(self, conn: sqlite3.Connection) -> None:
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
        created_at: str,
    ) -> int:
        cur = self._conn.execute(
            """
            INSERT INTO orchestrator_logs (
                kind, request_id, draft_id, tool_name, payload_json, result_json, undo_token, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                kind,
                request_id,
                draft_id,
                tool_name,
                payload_json,
                result_json,
                undo_token,
                created_at,
            ),
        )
        self._conn.commit()
        return int(cur.lastrowid)

    def get_drafts_by_ids(self, draft_ids: list[str]) -> list[sqlite3.Row]:
        if not draft_ids:
            return []
        placeholders = ",".join("?" for _ in draft_ids)
        rows = self._conn.execute(
            f"SELECT * FROM orchestrator_logs WHERE kind = 'draft' AND draft_id IN ({placeholders})",
            tuple(draft_ids),
        ).fetchall()
        return list(rows)

    def get_commits_by_undo_token(self, undo_token: str) -> list[sqlite3.Row]:
        rows = self._conn.execute(
            "SELECT * FROM orchestrator_logs WHERE kind = 'commit' AND undo_token = ?",
            (undo_token,),
        ).fetchall()
        return list(rows)
