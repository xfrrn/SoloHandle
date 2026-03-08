from __future__ import annotations

from typing import Any


class AccountsRepository:
    def __init__(self, conn) -> None:
        self._conn = conn

    def list_accounts(self, active_only: bool = True) -> list[dict[str, Any]]:
        cur = self._conn.cursor()
        if active_only:
            cur.execute(
                """
                SELECT id, name, kind, subtype, currency, balance_base, balance_base_at,
                       is_active, created_at, updated_at
                FROM accounts
                WHERE is_active = 1
                ORDER BY kind ASC, id ASC
                """
            )
        else:
            cur.execute(
                """
                SELECT id, name, kind, subtype, currency, balance_base, balance_base_at,
                       is_active, created_at, updated_at
                FROM accounts
                ORDER BY kind ASC, id ASC
                """
            )
        return [dict(row) for row in cur.fetchall()]

    def get_account(self, account_id: int) -> dict[str, Any] | None:
        cur = self._conn.cursor()
        cur.execute(
            """
            SELECT id, name, kind, subtype, currency, balance_base, balance_base_at,
                   is_active, created_at, updated_at
            FROM accounts
            WHERE id = ?
            """,
            (account_id,),
        )
        row = cur.fetchone()
        return dict(row) if row else None

    def insert_account(
        self,
        *,
        name: str,
        kind: str,
        subtype: str,
        currency: str,
        balance_base: float,
        balance_base_at: str,
        created_at: str,
        updated_at: str,
    ) -> int:
        cur = self._conn.cursor()
        cur.execute(
            """
            INSERT INTO accounts (
                name, kind, subtype, currency, balance_base, balance_base_at,
                is_active, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
            RETURNING id
            """,
            (
                name,
                kind,
                subtype,
                currency,
                balance_base,
                balance_base_at,
                created_at,
                updated_at,
            ),
        )
        row = cur.fetchone()
        return int(row["id"])

    def update_account_balance(
        self,
        *,
        account_id: int,
        balance_base: float,
        balance_base_at: str,
        updated_at: str,
    ) -> None:
        self._conn.execute(
            """
            UPDATE accounts
            SET balance_base = ?, balance_base_at = ?, updated_at = ?
            WHERE id = ?
            """,
            (balance_base, balance_base_at, updated_at, account_id),
        )


__all__ = ["AccountsRepository"]
