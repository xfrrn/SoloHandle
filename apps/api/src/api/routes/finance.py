from __future__ import annotations

from fastapi import APIRouter, Query
from pydantic import BaseModel

from api.db.connection import ToolError, ensure_tables, get_connection
from api.repositories.accounts_repo import AccountsRepository
from api.repositories.finance_repo import FinanceRepository
from api.services.accounts_service import AccountsService
from api.services.finance_service import FinanceService
from api.tools.events import create_transfer

router = APIRouter(prefix="/api/finance", tags=["finance"])


class BalanceUpdatePayload(BaseModel):
    amount: float
    effective_at: str | None = None
    currency: str = "CNY"
    tz: str | None = None


class AccountCreatePayload(BaseModel):
    name: str
    kind: str
    subtype: str
    currency: str = "CNY"
    balance_base: float = 0.0
    balance_base_at: str | None = None


class AccountBalancePayload(BaseModel):
    balance_base: float
    balance_base_at: str | None = None


class TransferPayload(BaseModel):
    amount: float
    from_account_id: int
    to_account_id: int
    currency: str = "CNY"
    note: str | None = None
    happened_at: str | None = None


@router.get("/summary")
def get_finance_summary(tz: str = Query("Asia/Shanghai")) -> dict:
    with get_connection() as conn:
        ensure_tables(conn)
        svc = FinanceService(FinanceRepository(conn))
        return svc.get_summary(tz)


@router.post("/balance")
def set_balance(payload: BalanceUpdatePayload) -> dict:
    if not payload.currency.strip():
        raise ToolError("invalid_param", "currency must be non-empty string")
    with get_connection() as conn:
        ensure_tables(conn)
        svc = FinanceService(FinanceRepository(conn))
        return svc.set_balance(
            amount=payload.amount,
            effective_at=payload.effective_at,
            currency=payload.currency,
            tz=payload.tz or "Asia/Shanghai",
        )


@router.get("/accounts")
def list_accounts() -> dict:
    with get_connection() as conn:
        ensure_tables(conn)
        svc = AccountsService(AccountsRepository(conn))
        return {"items": svc.list_accounts()}


@router.post("/accounts")
def create_account(payload: AccountCreatePayload) -> dict:
    with get_connection() as conn:
        ensure_tables(conn)
        svc = AccountsService(AccountsRepository(conn))
        return svc.create_account(
            name=payload.name,
            kind=payload.kind,
            subtype=payload.subtype,
            currency=payload.currency,
            balance_base=payload.balance_base,
            balance_base_at=payload.balance_base_at,
        )


@router.post("/accounts/{account_id}/balance")
def set_account_balance(account_id: int, payload: AccountBalancePayload) -> dict:
    with get_connection() as conn:
        ensure_tables(conn)
        svc = AccountsService(AccountsRepository(conn))
        return svc.set_balance(
            account_id=account_id,
            balance_base=payload.balance_base,
            balance_base_at=payload.balance_base_at,
        )


@router.post("/transfer")
def create_finance_transfer(payload: TransferPayload) -> dict:
    if not payload.currency.strip():
        raise ToolError("invalid_param", "currency must be non-empty string")
    return create_transfer(
        amount=payload.amount,
        from_account_id=payload.from_account_id,
        to_account_id=payload.to_account_id,
        currency=payload.currency,
        note=payload.note,
        happened_at=payload.happened_at,
    )


__all__ = ["router"]
