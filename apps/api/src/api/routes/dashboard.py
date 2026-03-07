from __future__ import annotations

from fastapi import APIRouter
from typing import Dict, Any

from api.db.connection import get_connection, ensure_tables, DEFAULT_TZ
from api.repositories.dashboard_repo import DashboardRepository
from api.services.dashboard_service import DashboardService

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])


@router.get("/summary")
def get_dashboard_summary(tz: str = DEFAULT_TZ) -> Dict[str, Any]:
    with get_connection() as conn:
        ensure_tables(conn)
        svc = DashboardService(DashboardRepository(conn))
        return svc.get_summary(tz)
