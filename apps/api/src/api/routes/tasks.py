from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from api.db.connection import ToolError, ensure_tables, get_connection, now_iso8601
from api.repositories.tasks_repo import TaskRepository
from api.services.tasks_service import TaskService

router = APIRouter()


class TaskPatchBody(BaseModel):
    title: Optional[str] = None
    note: Optional[str] = None
    priority: Optional[str] = None
    due_at: Optional[str] = None
    status: Optional[str] = None


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
    with get_connection() as conn:
        ensure_tables(conn)
        svc = TaskService(TaskRepository(conn))

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
    with get_connection() as conn:
        ensure_tables(conn)
        svc = TaskService(TaskRepository(conn))
        try:
            return svc.complete_task(task_id)
        except ToolError as exc:
            raise HTTPException(status_code=404, detail={"code": exc.code, "message": exc.message}) from exc


@router.post("/tasks/{task_id}/waiting")
def mark_task_waiting(task_id: int) -> dict:
    with get_connection() as conn:
        ensure_tables(conn)
        svc = TaskService(TaskRepository(conn))
        try:
            return svc.update_task(
                task_id,
                {
                    "status": "pending",
                    "completed_at": None,
                    "updated_at": now_iso8601(),
                },
            )
        except ToolError as exc:
            raise HTTPException(status_code=404, detail={"code": exc.code, "message": exc.message}) from exc


@router.patch("/tasks/{task_id}")
def patch_task(task_id: int, body: TaskPatchBody) -> dict:
    fields = body.model_dump(exclude_unset=True)
    if not fields:
        raise HTTPException(status_code=400, detail={"code": "invalid_param", "message": "No fields to update"})
    fields["updated_at"] = now_iso8601()
    with get_connection() as conn:
        ensure_tables(conn)
        svc = TaskService(TaskRepository(conn))
        try:
            return svc.update_task(task_id, fields)
        except ToolError as exc:
            raise HTTPException(status_code=404, detail={"code": exc.code, "message": exc.message}) from exc


@router.delete("/tasks/{task_id}")
def delete_task(task_id: int) -> dict:
    with get_connection() as conn:
        ensure_tables(conn)
        svc = TaskService(TaskRepository(conn))
        try:
            return svc.set_deleted(task_id, 1)
        except ToolError as exc:
            raise HTTPException(status_code=404, detail={"code": exc.code, "message": exc.message}) from exc
