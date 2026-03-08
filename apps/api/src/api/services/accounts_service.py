from __future__ import annotations

from api.db.connection import ToolError, normalize_iso8601, now_iso8601
from api.repositories.accounts_repo import AccountsRepository

ACCOUNT_KINDS = {"asset", "liability"}
ACCOUNT_SUBTYPES = {
    "bank",
    "wechat",
    "alipay",
    "cash",
    "investment",
    "other_asset",
    "huabei",
    "credit_card",
    "jd_baitiao",
    "loan",
    "other_liability",
}


class AccountsService:
    def __init__(self, repo: AccountsRepository) -> None:
        self._repo = repo

    def list_accounts(self) -> list[dict]:
        return self._repo.list_accounts(active_only=True)

    def get_account(self, account_id: int) -> dict:
        account = self._repo.get_account(account_id)
        if account is None or account.get("is_active") != 1:
            raise ToolError("not_found", "account not found", {"account_id": account_id})
        return account

    def create_account(
        self,
        *,
        name: str,
        kind: str,
        subtype: str,
        currency: str = "CNY",
        balance_base: float = 0.0,
        balance_base_at: str | None = None,
    ) -> dict:
        normalized_name = name.strip()
        if not normalized_name:
            raise ToolError("invalid_param", "name must be non-empty string")
        if kind not in ACCOUNT_KINDS:
            raise ToolError("invalid_param", f"kind must be one of {sorted(ACCOUNT_KINDS)}")
        if subtype not in ACCOUNT_SUBTYPES:
            raise ToolError("invalid_param", f"subtype must be one of {sorted(ACCOUNT_SUBTYPES)}")
        currency_value = currency.strip()
        if not currency_value:
            raise ToolError("invalid_param", "currency must be non-empty string")
        now = now_iso8601()
        account_id = self._repo.insert_account(
            name=normalized_name,
            kind=kind,
            subtype=subtype,
            currency=currency_value,
            balance_base=_normalize_balance_for_kind(float(balance_base), kind),
            balance_base_at=normalize_iso8601(balance_base_at),
            created_at=now,
            updated_at=now,
        )
        return self.get_account(account_id)

    def set_balance(
        self,
        *,
        account_id: int,
        balance_base: float,
        balance_base_at: str | None = None,
    ) -> dict:
        account = self.get_account(account_id)
        self._repo.update_account_balance(
            account_id=account_id,
            balance_base=_normalize_balance_for_kind(float(balance_base), account["kind"]),
            balance_base_at=normalize_iso8601(balance_base_at),
            updated_at=now_iso8601(),
        )
        return self.get_account(account_id)


def _normalize_balance_for_kind(balance: float, kind: str) -> float:
    if kind == "liability" and balance > 0:
        return -balance
    return balance


__all__ = ["AccountsService", "ACCOUNT_KINDS", "ACCOUNT_SUBTYPES"]
