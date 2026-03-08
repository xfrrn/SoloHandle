from __future__ import annotations

from typing import Any


class FinanceRepository:
    def __init__(self, conn) -> None:
        self._conn = conn

    def get_finance_setting(self) -> dict[str, Any] | None:
        cur = self._conn.cursor()
        cur.execute(
            """
            SELECT id, balance_base, balance_base_at, currency, updated_at
            FROM finance_settings
            WHERE id = 1
            """
        )
        row = cur.fetchone()
        return dict(row) if row else None

    def upsert_finance_setting(
        self,
        *,
        balance_base: float,
        balance_base_at: str,
        currency: str,
        updated_at: str,
    ) -> None:
        cur = self._conn.cursor()
        cur.execute(
            """
            INSERT INTO finance_settings (id, balance_base, balance_base_at, currency, updated_at)
            VALUES (1, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
                balance_base = excluded.balance_base,
                balance_base_at = excluded.balance_base_at,
                currency = excluded.currency,
                updated_at = excluded.updated_at
            """,
            (balance_base, balance_base_at, currency, updated_at),
        )

    def list_income_expense_events(self, start_at: str | None = None) -> list[dict[str, Any]]:
        cur = self._conn.cursor()
        if start_at:
            cur.execute(
                """
                SELECT id, type, data_json, happened_at, created_at
                FROM events
                WHERE is_deleted = 0
                  AND type IN ('income', 'expense', 'transfer')
                  AND happened_at >= ?
                ORDER BY happened_at DESC, id DESC
                """,
                (start_at,),
            )
        else:
            cur.execute(
                """
                SELECT id, type, data_json, happened_at, created_at
                FROM events
                WHERE is_deleted = 0
                  AND type IN ('income', 'expense', 'transfer')
                ORDER BY happened_at DESC, id DESC
                """
            )
        return [dict(row) for row in cur.fetchall()]

    def list_month_income_expense_events(self, start_at: str, end_at: str) -> list[dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute(
            """
            SELECT id, type, data_json, happened_at, created_at
            FROM events
            WHERE is_deleted = 0
              AND type IN ('income', 'expense')
              AND happened_at >= ?
              AND happened_at < ?
            ORDER BY happened_at DESC, id DESC
            """,
            (start_at, end_at),
        )
        return [dict(row) for row in cur.fetchall()]

    def list_recent_income_expense_events(self, limit: int = 20) -> list[dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute(
            """
            SELECT id, type, data_json, happened_at, created_at
            FROM events
            WHERE is_deleted = 0
              AND type IN ('income', 'expense', 'transfer')
            ORDER BY happened_at DESC, id DESC
            LIMIT ?
            """,
            (limit,),
        )
        return [dict(row) for row in cur.fetchall()]

    def list_accounts(self) -> list[dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute(
            """
            SELECT id, name, kind, subtype, currency, balance_base, balance_base_at,
                   is_active, created_at, updated_at
            FROM accounts
            WHERE is_active = 1
            ORDER BY kind ASC, id ASC
            """
        )
        return [dict(row) for row in cur.fetchall()]


__all__ = ["FinanceRepository"]
