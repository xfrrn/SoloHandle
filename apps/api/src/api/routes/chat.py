from __future__ import annotations

import json
import uuid

from fastapi import APIRouter, HTTPException, Request

from api.db.connection import ToolError, ensure_tables, get_connection, normalize_iso8601
from api.repositories.events_repo import EventRepository
from api.services.events_service import EventService
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
        if action == "mood_quick":
            if payload is None or not isinstance(payload, dict):
                raise ToolError("invalid_param", "payload must be object")
            emoji = payload.get("emoji")
            score = payload.get("score")
            score_percent = payload.get("score_percent")
            note = payload.get("note")
            topic = payload.get("topic")
            happened_at = payload.get("happened_at")
            mood = payload.get("mood")

            if not isinstance(emoji, str) or not emoji.strip():
                raise ToolError("invalid_param", "emoji must be non-empty string")
            if score_percent is not None:
                if not isinstance(score_percent, (int, float)):
                    raise ToolError("invalid_param", "score_percent must be number in 0..100")
                score_percent = int(round(float(score_percent)))
                if score_percent < 0 or score_percent > 100:
                    raise ToolError("invalid_param", "score_percent must be number in 0..100")
            if score is None:
                if score_percent is None:
                    raise ToolError(
                        "invalid_param",
                        "score or score_percent must be provided",
                    )
                if score_percent < 20:
                    score = 1
                elif score_percent < 40:
                    score = 2
                elif score_percent < 60:
                    score = 3
                elif score_percent < 80:
                    score = 4
                else:
                    score = 5
            if not isinstance(score, int) or score < 1 or score > 5:
                raise ToolError("invalid_param", "score must be integer in 1..5")
            if score_percent is None:
                score_percent = int(round(((score - 1) / 4.0) * 100))
            if note is not None and not isinstance(note, str):
                raise ToolError("invalid_param", "note must be string or null")
            if topic is not None and not isinstance(topic, str):
                raise ToolError("invalid_param", "topic must be string or null")
            if mood is not None and not isinstance(mood, str):
                raise ToolError("invalid_param", "mood must be string or null")

            intensity = score_percent / 100.0
            happened_at_iso = normalize_iso8601(happened_at)
            data = {
                "emoji": emoji.strip(),
                "score": score,
                "score_percent": score_percent,
                "mood": (mood or "").strip() or emoji.strip(),
                "intensity": intensity,
                "note": note,
                "topic": topic,
            }
            with get_connection() as conn:
                ensure_tables(conn)
                event_service = EventService(EventRepository(conn))
                event = event_service.create_event(
                    event_type="mood",
                    data=data,
                    happened_at=happened_at_iso,
                    tags=[],
                    source="user",
                    confidence=1.0,
                    idempotency_key=None,
                )
            return {"ok": True, "event": event}

        if action == "mood_patch":
            if payload is None or not isinstance(payload, dict):
                raise ToolError("invalid_param", "payload must be object")
            event_id = payload.get("event_id")
            note = payload.get("note")
            topic = payload.get("topic")
            if not isinstance(event_id, int) or event_id <= 0:
                raise ToolError("invalid_param", "event_id must be positive integer")
            if note is not None and not isinstance(note, str):
                raise ToolError("invalid_param", "note must be string or null")
            if topic is not None and not isinstance(topic, str):
                raise ToolError("invalid_param", "topic must be string or null")
            patch_data = {
                k: v for k, v in {
                    "note": note,
                    "topic": topic,
                }.items()
                if v is not None
            }
            with get_connection() as conn:
                ensure_tables(conn)
                repo = EventRepository(conn)
                event_service = EventService(repo)
                row = repo.get_by_id(event_id)
                if row is None:
                    raise ToolError("not_found", "event not found", {"event_id": event_id})
                if row["type"] != "mood":
                    raise ToolError("invalid_param", "event is not mood")
                event = event_service.patch_event_data(event_id, patch_data)
            return {"ok": True, "event": event}

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
    finally:
        service.close()
