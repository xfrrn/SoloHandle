from __future__ import annotations

import json
from datetime import datetime
from typing import Any
from zoneinfo import ZoneInfo

from api.db.connection import DEFAULT_TZ, normalize_iso8601, now_iso8601
from api.repositories.finance_repo import FinanceRepository


class FinanceService:
    def __init__(self, repo: FinanceRepository) -> None:
        self._repo = repo

    def get_summary(self, tz: str = DEFAULT_TZ) -> dict[str, Any]:
        now = datetime.now(ZoneInfo(tz))
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        next_month = _add_month(month_start)

        setting = self._repo.get_finance_setting()
        currency = (setting or {}).get("currency") or "CNY"
        balance_base = (setting or {}).get("balance_base")
        balance_base_at = (setting or {}).get("balance_base_at")

        month_events = self._repo.list_month_income_expense_events(
            month_start.isoformat(),
            next_month.isoformat(),
        )
        recent_events = self._repo.list_recent_income_expense_events(20)
        accounts = self._repo.list_accounts()

        month_income = 0.0
        month_expense = 0.0
        income_categories: dict[str, float] = {}
        expense_categories: dict[str, float] = {}
        for row in month_events:
            payload = _read_event_payload(row)
            amount = payload.get("amount")
            if not isinstance(amount, float):
                continue
            category = payload.get("category") or "other"
            if row.get("type") == "income":
                month_income += amount
                income_categories[category] = income_categories.get(category, 0.0) + amount
            elif row.get("type") == "expense":
                month_expense += amount
                expense_categories[category] = expense_categories.get(category, 0.0) + amount

        current_balance = None
        if isinstance(balance_base, (int, float)) and isinstance(balance_base_at, str) and balance_base_at:
            current_balance = float(balance_base)
            balance_events = self._repo.list_income_expense_events(balance_base_at)
            for row in balance_events:
                amount = _read_amount(row)
                if amount is None:
                    continue
                if row.get("type") == "income":
                    current_balance += amount
                elif row.get("type") == "expense":
                    current_balance -= amount
            current_balance = round(current_balance, 2)

        account_summaries = _build_account_summaries(accounts, self._repo.list_income_expense_events())
        total_assets = round(
            sum(item["current_balance"] for item in account_summaries if item["kind"] == "asset"),
            2,
        )
        total_liabilities = round(
            sum(-item["current_balance"] for item in account_summaries if item["kind"] == "liability"),
            2,
        )

        return {
            "balance": {
                "current": current_balance,
                "currency": currency,
                "base_amount": balance_base,
                "base_at": balance_base_at,
                "is_set": current_balance is not None,
            },
            "month": {
                "income": round(month_income, 2),
                "expense": round(month_expense, 2),
                "net": round(month_income - month_expense, 2),
                "month_start": month_start.date().isoformat(),
                "income_categories": _serialize_breakdown(income_categories),
                "expense_categories": _serialize_breakdown(expense_categories),
            },
            "accounts": {
                "items": account_summaries,
                "total_assets": total_assets,
                "total_liabilities": total_liabilities,
                "net_assets": round(total_assets - total_liabilities, 2),
            },
            "recent": [_serialize_event(row) for row in recent_events],
        }

    def set_balance(
        self,
        *,
        amount: float,
        effective_at: str | None = None,
        currency: str = "CNY",
        tz: str = DEFAULT_TZ,
    ) -> dict[str, Any]:
        amount_value = float(amount)
        effective_iso = normalize_iso8601(effective_at, tz)
        self._repo.upsert_finance_setting(
            balance_base=amount_value,
            balance_base_at=effective_iso,
            currency=currency.strip() or "CNY",
            updated_at=now_iso8601(tz),
        )
        return self.get_summary(tz)


def _read_amount(row: dict[str, Any]) -> float | None:
    payload = _read_event_payload(row)
    amount = payload.get("amount")
    if not isinstance(amount, float):
        return None
    return amount


def _read_event_payload(row: dict[str, Any]) -> dict[str, Any]:
    try:
        data = json.loads(row["data_json"])
    except Exception:
        return {}
    amount = data.get("amount")
    return {
        "amount": float(amount) if isinstance(amount, (int, float)) else None,
        "category": data.get("category"),
        "currency": data.get("currency") or "CNY",
        "note": data.get("note"),
        "account_id": data.get("account_id"),
        "from_account_id": data.get("from_account_id"),
        "to_account_id": data.get("to_account_id"),
        "from_account_name": data.get("from_account_name"),
        "to_account_name": data.get("to_account_name"),
    }


def _serialize_event(row: dict[str, Any]) -> dict[str, Any]:
    payload = _read_event_payload(row)
    return {
        "event_id": row.get("id"),
        "type": row.get("type"),
        "happened_at": row.get("happened_at"),
        "created_at": row.get("created_at"),
        "amount": payload["amount"] if isinstance(payload.get("amount"), float) else 0.0,
        "currency": payload.get("currency") or "CNY",
        "category": payload.get("category"),
        "note": payload.get("note"),
        "account_id": payload.get("account_id"),
        "from_account_id": payload.get("from_account_id"),
        "to_account_id": payload.get("to_account_id"),
        "from_account_name": payload.get("from_account_name"),
        "to_account_name": payload.get("to_account_name"),
    }


def _serialize_breakdown(values: dict[str, float]) -> list[dict[str, Any]]:
    return [
        {"category": category, "amount": round(amount, 2)}
        for category, amount in sorted(values.items(), key=lambda item: item[1], reverse=True)
    ]


def _build_account_summaries(
    accounts: list[dict[str, Any]],
    events: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for account in accounts:
        account_id = account.get("id")
        base_balance = float(account.get("balance_base") or 0.0)
        base_at = account.get("balance_base_at")
        kind = account.get("kind") or "asset"
        current = base_balance
        for row in events:
            payload = _read_event_payload(row)
            if isinstance(base_at, str) and base_at and isinstance(row.get("happened_at"), str):
                if row["happened_at"] < base_at:
                    continue
            amount = payload.get("amount")
            if not isinstance(amount, float):
                continue
            if row.get("type") == "income":
                if payload.get("account_id") != account_id:
                    continue
                current += amount
            elif row.get("type") == "expense":
                if payload.get("account_id") != account_id:
                    continue
                current -= amount
            elif row.get("type") == "transfer":
                if payload.get("from_account_id") == account_id:
                    current -= amount
                if payload.get("to_account_id") == account_id:
                    current += amount
        result.append(
            {
                "account_id": account_id,
                "name": account.get("name"),
                "kind": kind,
                "subtype": account.get("subtype"),
                "currency": account.get("currency") or "CNY",
                "base_balance": base_balance,
                "base_at": base_at,
                "current_balance": round(current, 2),
            }
        )
    return result


def _add_month(value: datetime) -> datetime:
    if value.month == 12:
        return value.replace(year=value.year + 1, month=1)
    return value.replace(month=value.month + 1)


__all__ = ["FinanceService"]
