from __future__ import annotations

import json
import uuid

from fastapi import APIRouter, HTTPException, Request

from api.db.connection import ToolError
from api.services.orchestrator_service import get_orchestrator_service

router = APIRouter()


@router.post("/chat")
async def chat(request: Request) -> dict:
    try:
        body = await request.json()
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=400,
            detail={"code": "invalid_json", "message": "Request body must be JSON"},
        ) from exc

    text = body.get("text")
    confirm_draft_ids = body.get("confirm_draft_ids")
    undo_token = body.get("undo_token")
    action = body.get("action")
    draft_id = body.get("draft_id")
    patch = body.get("patch")
    task_id = body.get("task_id")
    op = body.get("op")
    payload = body.get("payload")

    service = get_orchestrator_service()

    try:
        if action == "edit":
            if not isinstance(draft_id, str) or not draft_id.strip():
                raise ToolError("invalid_param", "draft_id must be non-empty string")
            if patch is None:
                raise ToolError("invalid_param", "patch is required")
            return service.edit_draft(draft_id.strip(), patch)

        if action == "task_action":
            if not isinstance(task_id, int) or task_id <= 0:
                raise ToolError("invalid_param", "task_id must be positive integer")
            if not isinstance(op, str) or not op.strip():
                raise ToolError("invalid_param", "op must be non-empty string")
            if payload is not None and not isinstance(payload, dict):
                raise ToolError("invalid_param", "payload must be object")
            return service.task_action(task_id, op.strip(), payload)

        if undo_token:
            if not isinstance(undo_token, str):
                raise ToolError("invalid_param", "undo_token must be string")
            return service.undo(undo_token)

        if confirm_draft_ids:
            if not isinstance(confirm_draft_ids, list):
                raise ToolError("invalid_param", "confirm_draft_ids must be list")
            return service.commit_drafts(confirm_draft_ids)

        if not isinstance(text, str) or not text.strip():
            raise ToolError("invalid_param", "text must be non-empty string")

        request_id = body.get("request_id") or str(uuid.uuid4())
        draft_result = service.create_drafts(text.strip())
        if draft_result.get("need_clarification"):
            return draft_result

        drafts = draft_result["drafts"]
        cards = draft_result.get("cards", [])
        items = service.save_drafts(request_id, drafts)
        return {"drafts": items, "cards": cards, "request_id": request_id}
    except ToolError as exc:
        raise HTTPException(status_code=400, detail={"code": exc.code, "message": exc.message}) from exc
