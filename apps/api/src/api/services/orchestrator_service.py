from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable, Optional
from uuid import uuid4

from api.core.time_parse import parse_natural_time
from api.db.connection import (
    DEFAULT_TZ,
    ToolError,
    ensure_iso8601,
    ensure_tables,
    get_connection,
    json_dumps,
    json_loads,
    now_iso8601,
)
from api.repositories.orchestrator_repo import OrchestratorRepository
from api.router.route import route as llm_route
from api.tools.events import create_expense, create_lifelog, create_meal, create_mood, undo_event
from api.tools.tasks import create_task, undo_task


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
    return {"unknown": tool_name}


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
