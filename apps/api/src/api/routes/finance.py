from __future__ import annotations

from fastapi import APIRouter, Query
from pydantic import BaseModel

from api.db.connection import ToolError, ensure_tables, get_connection
from api.repositories.finance_repo import FinanceRepository
from api.services.finance_service import FinanceService

router = APIRouter(prefix="/api/finance", tags=["finance"])


class BalanceUpdatePayload(BaseModel):
    amount: float
    effective_at: str | None = None
    currency: str = "CNY"
    tz: str | None = None


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


__all__ = ["router"]
