from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query

from api.db.connection import ToolError, ensure_tables, get_connection
from api.repositories.tasks_repo import TaskRepository
from api.services.tasks_service import TaskService

router = APIRouter()


def _get_task_service() -> TaskService:
    conn = get_connection()
    ensure_tables(conn)
    return TaskService(TaskRepository(conn))


@router.get("/tasks")
def list_tasks(
    query: str | None = Query(None, description="Full-text search keyword"),
    status: str | None = Query(None, description="Filter by status (e.g. pending, done)"),
    scope: str | None = Query(None, description="Shortcut filter: today | overdue"),
    date_from: str | None = Query(None, description="ISO8601 start date filter"),
    date_to: str | None = Query(None, description="ISO8601 end date filter"),
    timezone: str = Query("Asia/Shanghai"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> dict:
    svc = _get_task_service()

    if scope == "today":
        return svc.list_tasks_today(timezone=timezone)
    if scope == "overdue":
        return svc.list_tasks_overdue(timezone=timezone)

    return svc.search_tasks(
        query=query,
        status=status,
        date_from=date_from,
        date_to=date_to,
        limit=limit,
        offset=offset,
    )


@router.post("/tasks/{task_id}/complete")
def complete_task(task_id: int) -> dict:
    svc = _get_task_service()
    try:
        return svc.complete_task(task_id)
    except ToolError as exc:
        raise HTTPException(status_code=404, detail={"code": exc.code, "message": exc.message}) from exc
