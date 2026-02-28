from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta
from typing import Any, Iterable, Optional
from uuid import uuid4

from api.core.time_parse import parse_natural_time
from api.core.constants_loader import get_constants
from api.db.connection import (
    DEFAULT_TZ,
    ToolError,
    ensure_iso8601,
    ensure_tables,
    get_connection,
    json_dumps,
    json_loads,
    now_iso8601,
    normalize_tags,
    require_enum,
    require_non_empty_str,
)
from api.repositories.orchestrator_repo import OrchestratorRepository
from api.repositories.tasks_repo import TaskRepository
from api.services.tasks_service import TaskService
from api.router.route import route as llm_route
from api.tools.events import create_expense, create_lifelog, create_meal, create_mood, undo_event
from api.tools.tasks import create_task, postpone_task, soft_delete_task, undo_task


@dataclass
class Draft:
    draft_id: str
    tool_name: str
    payload: dict[str, Any]
    confidence: float
    card: dict[str, Any]


class OrchestratorService:
    def __init__(self, repo: OrchestratorRepository) -> None:
        self._repo = repo

    def create_drafts(self, text: str) -> dict[str, Any]:
        try:
            decision = llm_route(text)
            if decision.need_clarification:
                return {
                    "need_clarification": True,
                    "clarify_question": decision.clarify_question,
                    "reply_to_user": decision.reply_to_user,
                    "drafts": [],
                    "cards": [c.model_dump() for c in decision.cards],
                }

            drafts = _drafts_from_decision(decision)
            return {
                "need_clarification": False,
                "reply_to_user": decision.reply_to_user,
                "drafts": drafts,
                "cards": [d.card for d in drafts],
            }
        except ToolError as exc:
            if exc.code not in {
                "llm_unavailable",
                "llm_error",
                "router_invalid_json",
                "router_invalid_schema",
            }:
                raise
            drafts = _fallback_drafts(text)
            if not drafts:
                return {"need_clarification": True, "clarify_question": "你想记录什么？", "drafts": []}
            return {
                "need_clarification": False,
                "reply_to_user": None,
                "drafts": drafts,
                "cards": [d.card for d in drafts],
            }

    def save_drafts(self, request_id: str, drafts: Iterable[Draft]) -> list[dict[str, Any]]:
        created_at = now_iso8601()
        items: list[dict[str, Any]] = []
        for d in drafts:
            self._repo.insert_log(
                kind="draft",
                request_id=request_id,
                draft_id=d.draft_id,
                tool_name=d.tool_name,
                payload_json=json_dumps(d.payload),
                result_json=None,
                undo_token=None,
                created_at=created_at,
            )
            items.append(
                {
                    "draft_id": d.draft_id,
                    "tool_name": d.tool_name,
                    "payload": d.payload,
                    "confidence": d.confidence,
                    "status": "draft",
                }
            )
        return items

    def commit_drafts(self, draft_ids: Iterable[str]) -> dict[str, Any]:
        drafts = self._repo.get_drafts_by_ids(list(draft_ids))
        if not drafts:
            raise ToolError("not_found", "no drafts found", {"draft_ids": list(draft_ids)})

        undo_token = str(uuid4())
        created_at = now_iso8601()
        committed: list[dict[str, Any]] = []

        for row in drafts:
            tool_name = row["tool_name"]
            payload = json_loads(row["payload_json"])
            result = _call_tool(tool_name, payload)
            self._repo.insert_log(
                kind="commit",
                request_id=row["request_id"],
                draft_id=row["draft_id"],
                tool_name=tool_name,
                payload_json=row["payload_json"],
                result_json=json_dumps(result),
                undo_token=undo_token,
                created_at=created_at,
            )
            committed.append(
                {
                    "draft_id": row["draft_id"],
                    "tool_name": tool_name,
                    "result": result,
                }
            )

        return {"committed": committed, "undo_token": undo_token}

    def undo(self, undo_token: str) -> dict[str, Any]:
        commits = self._repo.get_commits_by_undo_token(undo_token)
        if not commits:
            raise ToolError("not_found", "undo_token not found", {"undo_token": undo_token})

        undone: list[dict[str, Any]] = []
        for row in commits:
            tool_name = row["tool_name"]
            result = json_loads(row["result_json"]) if row["result_json"] else {}
            undone.append(_undo_tool(tool_name, result))

        return {"undone": undone, "undo_token": undo_token}

    def edit_draft(self, draft_id: str, patch: dict[str, Any]) -> dict[str, Any]:
        row = self._repo.get_draft_by_id(draft_id)
        if row is None:
            raise ToolError("not_found", "draft not found", {"draft_id": draft_id})
        tool_name = row["tool_name"]
        if tool_name != "create_task":
            raise ToolError(
                "unsupported_edit",
                "only task drafts support structured edit",
                {"tool_name": tool_name},
            )
        payload = json_loads(row["payload_json"]) if row["payload_json"] else {}
        updated = _apply_task_patch(payload, patch)
        self._repo.update_draft_payload(draft_id, json_dumps(updated))
        consts = get_constants()
        draft_item = {
            "draft_id": draft_id,
            "tool_name": tool_name,
            "payload": updated,
            "confidence": consts.defaults.confidence,
            "status": "draft",
        }
        card = _task_card_from_payload(draft_id, updated)
        return {"drafts": [draft_item], "cards": [card], "request_id": row["request_id"]}

    def task_action(self, task_id: int, op: str, payload: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        if task_id <= 0:
            raise ToolError("invalid_param", "task_id must be positive integer")
        if op not in {"complete", "postpone", "delete"}:
            raise ToolError("invalid_param", "op must be one of complete/postpone/delete")

        payload = payload or {}
        prev = _get_task_snapshot(task_id)

        if op == "complete":
            result = _complete_task(task_id)
        elif op == "postpone":
            due_at, remind_at = _resolve_postpone_times(prev, payload)
            result = postpone_task(task_id=task_id, new_due_at=due_at, new_remind_at=remind_at)
        else:
            result = soft_delete_task(task_id)

        undo_token = str(uuid4())
        created_at = now_iso8601()
        self._repo.insert_log(
            kind="commit",
            request_id=None,
            draft_id=None,
            tool_name="task_action",
            payload_json=json_dumps({"task_id": task_id, "op": op, "payload": payload}),
            result_json=json_dumps({"task": result, "prev": prev, "op": op}),
            undo_token=undo_token,
            created_at=created_at,
        )
        return {"task": result, "undo_token": undo_token}


def _pick_card(cards, idx: int, draft_id: str, tool_name: str, payload: dict[str, Any]) -> dict[str, Any]:
    if idx < len(cards):
        card = cards[idx].model_dump()
    else:
        card = {
            "card_id": draft_id,
            "type": tool_name.replace("create_", ""),
            "status": "draft",
            "title": "",
            "subtitle": "",
            "data": payload,
            "actions": [],
        }
    card["card_id"] = draft_id
    card["status"] = "draft"
    return card


def _drafts_from_decision(decision) -> list[Draft]:
    drafts: list[Draft] = []
    for idx, call in enumerate(decision.tool_calls):
        draft_id = str(uuid4())
        payload = dict(call.arguments)
        payload = _normalize_time_fields(payload, call.name)
        payload.setdefault("idempotency_key", draft_id)
        card = _pick_card(decision.cards, idx, draft_id, call.name, payload)
        drafts.append(
            Draft(
                draft_id=draft_id,
                tool_name=call.name,
                payload=payload,
                confidence=decision.confidence,
                card=card,
            )
        )
    return drafts


def _fallback_drafts(text: str) -> list[Draft]:
    drafts: list[Draft] = []

    def add(tool_name: str, payload: dict[str, Any], confidence: float = 0.5) -> None:
        draft_id = str(uuid4())
        payload = _normalize_time_fields(payload, tool_name)
        payload = {**payload, "idempotency_key": draft_id}
        card = _pick_card([], 0, draft_id, tool_name, payload)
        drafts.append(
            Draft(
                draft_id=draft_id,
                tool_name=tool_name,
                payload=payload,
                confidence=confidence,
                card=card,
            )
        )

    lowered = text.lower()
    amount = _extract_amount(text)
    if amount is not None and _match_any(lowered, ["花", "消费", "付款", "支付", "买", "￥", "¥", "$"]):
        add("create_expense", {"amount": amount, "category": "unknown"}, confidence=0.6)

    if _match_any(lowered, ["提醒", "待办", "任务", "记得", "要做"]):
        add("create_task", {"title": text.strip()}, confidence=0.55)

    mood = _extract_mood(lowered)
    if mood is not None:
        add("create_mood", {"mood": mood}, confidence=0.5)

    return drafts


def _call_tool(tool_name: str, payload: dict[str, Any]) -> dict[str, Any]:
    if tool_name == "create_expense":
        return create_expense(**payload)
    if tool_name == "create_task":
        return create_task(**payload)
    if tool_name == "create_mood":
        return create_mood(**payload)
    if tool_name == "create_lifelog":
        return create_lifelog(**payload)
    if tool_name == "create_meal":
        return create_meal(**payload)
    raise ToolError("invalid_tool", "unsupported tool", {"tool_name": tool_name})


def _undo_tool(tool_name: str, result: dict[str, Any]) -> dict[str, Any]:
    if tool_name in {"create_expense", "create_lifelog", "create_meal", "create_mood"}:
        event_id = result.get("event_id")
        if isinstance(event_id, int):
            return {"event": undo_event(event_id)}
        return {"event": None}
    if tool_name == "create_task":
        task_id = result.get("task_id")
        if isinstance(task_id, int):
            return {"task": undo_task(task_id)}
        return {"task": None}
    if tool_name == "task_action":
        return _undo_task_action(result)
    return {"unknown": tool_name}


def _get_task_snapshot(task_id: int) -> dict[str, Any]:
    with get_connection() as conn:
        ensure_tables(conn)
        repo = TaskRepository(conn)
        row = repo.get_by_id(task_id)
        if row is None:
            raise ToolError("not_found", "task not found", {"task_id": task_id})
        return {
            "task_id": row["id"],
            "status": row["status"],
            "priority": row["priority"],
            "due_at": row["due_at"],
            "remind_at": row["remind_at"],
            "project": row["project"],
            "note": row["note"],
            "tags_json": row["tags_json"],
            "completed_at": row["completed_at"],
            "is_deleted": row["is_deleted"],
        }


def _complete_task(task_id: int) -> dict[str, Any]:
    with get_connection() as conn:
        ensure_tables(conn)
        service = TaskService(TaskRepository(conn))
        return service.complete_task(task_id)


def _normalize_time_fields(payload: dict[str, Any], tool_name: str) -> dict[str, Any]:
    fields: list[str] = []
    if tool_name == "create_task":
        fields = ["due_at", "remind_at"]
    elif tool_name in {"create_expense", "create_lifelog", "create_meal", "create_mood"}:
        fields = ["happened_at"]

    for field in fields:
        value = payload.get(field)
        if value is None or not isinstance(value, str):
            continue
        try:
            payload[field] = ensure_iso8601(value)
            continue
        except ToolError:
            parsed = parse_natural_time(value, DEFAULT_TZ)
            payload[field] = parsed
    return payload


def _apply_task_patch(payload: dict[str, Any], patch: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(patch, dict):
        raise ToolError("invalid_param", "patch must be object")
    consts = get_constants()
    updated = dict(payload)

    if "title" in patch:
        updated["title"] = require_non_empty_str(patch.get("title"), "title")

    if "priority" in patch:
        updated["priority"] = require_enum(patch.get("priority"), "priority", consts.task.priority)

    if "status" in patch:
        updated["status"] = require_enum(patch.get("status"), "status", consts.task.status)

    if "due_at" in patch:
        updated["due_at"] = ensure_iso8601(patch.get("due_at"))

    if "remind_at" in patch:
        updated["remind_at"] = ensure_iso8601(patch.get("remind_at"))

    if "note" in patch:
        note = patch.get("note")
        if note is not None and not isinstance(note, str):
            raise ToolError("invalid_param", "note must be string or null")
        updated["note"] = note

    if "project" in patch:
        project = patch.get("project")
        if project is not None and not isinstance(project, str):
            raise ToolError("invalid_param", "project must be string or null")
        updated["project"] = project

    if "tags" in patch:
        updated["tags"] = normalize_tags(patch.get("tags"))

    if "due_at" in patch and "remind_at" not in patch and updated.get("due_at"):
        if updated.get("remind_at") is None:
            updated["remind_at"] = _default_remind_at(updated["due_at"])

    return updated


def _default_remind_at(due_at: Optional[str]) -> Optional[str]:
    if due_at is None:
        return None
    consts = get_constants()
    minutes = consts.task.default_remind_offset_minutes
    if minutes <= 0:
        return None
    try:
        dt = _parse_iso8601(due_at)
    except ToolError:
        return None
    return (dt - timedelta(minutes=minutes)).isoformat()


def _task_card_from_payload(draft_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    title = payload.get("title") or "任务"
    due_at = payload.get("due_at")
    remind_at = payload.get("remind_at")
    priority = payload.get("priority")
    subtitle_parts: list[str] = []
    if due_at:
        subtitle_parts.append(f"截止：{due_at}")
    if remind_at:
        subtitle_parts.append(f"提醒：{remind_at}")
    if priority:
        subtitle_parts.append(f"优先级：{priority}")
    subtitle = " · ".join(subtitle_parts)
    return {
        "card_id": draft_id,
        "type": "task",
        "status": "draft",
        "title": title,
        "subtitle": subtitle,
        "data": payload,
        "actions": [],
    }


def _undo_task_action(result: dict[str, Any]) -> dict[str, Any]:
    prev = result.get("prev") or {}
    task_id = prev.get("task_id")
    if not isinstance(task_id, int):
        return {"task": None}

    op = result.get("op")
    if op == "delete":
        return {"task": undo_task(task_id)}

    with get_connection() as conn:
        ensure_tables(conn)
        repo = TaskRepository(conn)
        fields = {
            "status": prev.get("status"),
            "priority": prev.get("priority"),
            "due_at": prev.get("due_at"),
            "remind_at": prev.get("remind_at"),
            "project": prev.get("project"),
            "note": prev.get("note"),
            "tags_json": prev.get("tags_json"),
            "completed_at": prev.get("completed_at"),
            "is_deleted": prev.get("is_deleted"),
            "updated_at": now_iso8601(),
        }
        repo.update_fields(task_id, fields)
        row = repo.get_by_id(task_id)
        if row is None:
            return {"task": None}
        service = TaskService(repo)
        return {"task": service._row_to_task(row)}


def _resolve_postpone_times(
    prev: dict[str, Any], payload: dict[str, Any]
) -> tuple[Optional[str], Optional[str]]:
    due_at = payload.get("due_at")
    remind_at = payload.get("remind_at")
    if due_at is None and remind_at is None:
        raise ToolError("invalid_param", "postpone requires due_at or remind_at")

    prev_due = prev.get("due_at")
    prev_remind = prev.get("remind_at")

    due_iso = ensure_iso8601(due_at) if due_at is not None else prev_due
    remind_iso = ensure_iso8601(remind_at) if remind_at is not None else None

    if due_iso is not None and remind_at is None:
        if prev_due and prev_remind:
            try:
                delta = _parse_iso8601(due_iso) - _parse_iso8601(prev_due)
                remind_iso = (_parse_iso8601(prev_remind) + delta).isoformat()
            except ToolError:
                remind_iso = None
        if remind_iso is None:
            remind_iso = _default_remind_at(due_iso)

    if remind_iso is not None and due_iso is not None:
        try:
            if _parse_iso8601(remind_iso) > _parse_iso8601(due_iso):
                remind_iso = _default_remind_at(due_iso)
        except ToolError:
            remind_iso = _default_remind_at(due_iso)

    return due_iso, remind_iso


def _extract_amount(text: str) -> Optional[float]:
    import re

    match = re.search(r"(\\d+(?:\\.\\d+)?)", text)
    if not match:
        return None
    try:
        return float(match.group(1))
    except ValueError:
        return None


def _match_any(text: str, keywords: Iterable[str]) -> bool:
    return any(k in text for k in keywords)


def _extract_mood(text: str) -> Optional[str]:
    moods = [
        "开心",
        "难过",
        "烦",
        "焦虑",
        "生气",
        "高兴",
        "沮丧",
        "sad",
        "happy",
        "angry",
        "anxious",
    ]
    for m in moods:
        if m in text:
            return m
    return None


def get_orchestrator_service() -> OrchestratorService:
    conn = get_connection()
    ensure_tables(conn)
    return OrchestratorService(OrchestratorRepository(conn))
