from __future__ import annotations

from fastapi import APIRouter
from typing import Dict, Any

from api.db.connection import get_connection, DEFAULT_TZ
from api.repositories.dashboard_repo import DashboardRepository
from api.services.dashboard_service import DashboardService

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])


def _get_dashboard_service() -> DashboardService:
    conn = get_connection()
    return DashboardService(DashboardRepository(conn))


@router.get("/summary")
def get_dashboard_summary(tz: str = DEFAULT_TZ) -> Dict[str, Any]:
    svc = _get_dashboard_service()
    return svc.get_summary(tz)
