from __future__ import annotations

import json
import uuid

from fastapi import APIRouter, HTTPException, Request

from api.db.connection import ToolError
from api.services.orchestrator_service import get_orchestrator_service

from api.db.connection import ToolError
from api.services.orchestrator_service import get_orchestrator_service
from api.router.provider import load_provider_from_config

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
    images = body.get("images")
    confirm_draft_ids = body.get("confirm_draft_ids")
    undo_token = body.get("undo_token")
    commit_id = body.get("commit_id")
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

        if commit_id:
            if not isinstance(commit_id, str):
                raise ToolError("invalid_param", "commit_id must be string")
            return service.undo_commit(commit_id)

        if undo_token:
            if not isinstance(undo_token, str):
                raise ToolError("invalid_param", "undo_token must be string")
            return service.undo(undo_token)

        if confirm_draft_ids is not None:
            if not isinstance(confirm_draft_ids, list):
                raise ToolError("invalid_param", "confirm_draft_ids must be list")
            cleaned = [str(d).strip() for d in confirm_draft_ids if str(d).strip()]
            if not cleaned:
                raise ToolError("invalid_param", "confirm_draft_ids must be non-empty list")
            return service.commit_drafts(cleaned)

        image = body.get("image")
        audio = body.get("audio")

        images_list: list[str] = []
        if isinstance(images, list):
            for item in images:
                if not isinstance(item, str) or not item.strip():
                    raise ToolError("invalid_param", "images must be list of base64 strings")
                images_list.append(item)
        elif images is not None:
            raise ToolError("invalid_param", "images must be list of base64 strings")

        if image and isinstance(image, str):
            images_list.append(image)
        
        if audio:
            provider = load_provider_from_config()
            if not provider:
                raise ToolError("llm_unavailable", "LLM provider not configured for audio transcription")
            transcription = provider.transcribe_audio(audio)
            
            # Use the transcribed text. Prepend or replace as needed. 
            # We'll just set it as the primary text for intent routing.
            if not text:
                text = transcription
            else:
                text = f"{text}\n\n[语音附加内容]: {transcription}"

        if not (text and text.strip()) and not images_list and not audio:
            raise ToolError("invalid_param", "text, images, or audio must be provided")

        request_id = body.get("request_id") or str(uuid.uuid4())
        draft_result = service.create_drafts(
            text.strip() if text else "",
            image_base64s=images_list if images_list else None,
        )
        if draft_result.get("need_clarification"):
            return draft_result

        drafts = draft_result["drafts"]
        cards = draft_result.get("cards", [])
        items = service.save_drafts(request_id, drafts)
        return {
            "drafts": items,
            "cards": cards,
            "request_id": request_id,
            "reply_to_user": draft_result.get("reply_to_user"),
        }
    except ToolError as exc:
        raise HTTPException(status_code=400, detail={"code": exc.code, "message": exc.message}) from exc
