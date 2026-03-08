from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta
import threading
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
from api.repositories.accounts_repo import AccountsRepository
from api.repositories.orchestrator_repo import OrchestratorRepository
from api.repositories.tasks_repo import TaskRepository
from api.services.tasks_service import TaskService
from api.router.route import route as llm_route, classify_intent, chat_reply
from api.router.provider import load_provider_from_config
from api.tools.events import (
    create_expense,
    create_income,
    create_lifelog,
    create_meal,
    create_mood,
    create_transfer,
    undo_event,
    soft_delete_event,
)
from api.tools.tasks import create_task, postpone_task, soft_delete_task, undo_task


@dataclass
class Draft:
    draft_id: str
    tool_name: str
    payload: dict[str, Any]
    confidence: float
    card: dict[str, Any]


_commit_lock = threading.Lock()
_DISABLED_CHAT_TOOLS = {"create_mood"}


class OrchestratorService:
    def __init__(self, repo: OrchestratorRepository) -> None:
        self._repo = repo

    def close(self) -> None:
        self._repo._conn.close()

    def create_drafts(
        self,
        text: str,
        image_base64s: list[str] | None = None,
        type_hint: str | None = None,
        draft_defaults: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        routed_text = _inject_type_hint(text, type_hint)
        provider = load_provider_from_config()

        # Deterministic route for explicit lifelog tag: avoid LLM misclassification.
        if type_hint in {"lifelog", "income", "transfer", "repayment"}:
            drafts = _fallback_drafts(
                text,
                type_hint=type_hint,
                image_base64s=image_base64s,
                draft_defaults=draft_defaults,
            )
            if drafts:
                return {
                    "need_clarification": False,
                    "reply_to_user": None,
                    "drafts": drafts,
                    "cards": [d.card for d in drafts],
                }
            return {
                "need_clarification": True,
                "clarify_question": _clarify_for_type_hint(type_hint),
                "drafts": [],
                "cards": [],
            }
        
        # Fast intent classification using gpt-4o-mini.
        # If the user explicitly gives type_hint, skip chat short-circuit.
        if type_hint is None:
            intent = classify_intent(routed_text, image_base64s, provider)
            if intent == "chat":
                reply = chat_reply(routed_text, image_base64s, provider)
                return {
                    "need_clarification": False,
                    "reply_to_user": reply,
                    "drafts": [],
                    "cards": []
                }

        try:
            decision = llm_route(text=routed_text, image_base64s=image_base64s, provider=provider)
            if decision.need_clarification:
                return {
                    "need_clarification": True,
                    "clarify_question": decision.clarify_question,
                    "reply_to_user": decision.reply_to_user,
                    "drafts": [],
                    "cards": [c.model_dump() for c in decision.cards],
                }

            drafts = _drafts_from_decision(decision)
            drafts = _apply_draft_defaults(drafts, draft_defaults)
            if not drafts and any(c.name in _DISABLED_CHAT_TOOLS for c in decision.tool_calls):
                return {
                    "need_clarification": False,
                    "reply_to_user": "心情记录请使用 Dashboard 的快捷入口。",
                    "drafts": [],
                    "cards": [],
                }
            if type_hint is not None and not drafts:
                forced = _fallback_drafts(
                    text,
                    type_hint=type_hint,
                    image_base64s=image_base64s,
                    draft_defaults=draft_defaults,
                )
                if forced:
                    return {
                        "need_clarification": False,
                        "reply_to_user": decision.reply_to_user,
                        "drafts": forced,
                        "cards": [d.card for d in forced],
                    }
                return {
                    "need_clarification": True,
                    "clarify_question": _clarify_for_type_hint(type_hint),
                    "reply_to_user": None,
                    "drafts": [],
                    "cards": [],
                }
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
            drafts = _fallback_drafts(
                text,
                type_hint=type_hint,
                image_base64s=image_base64s,
                draft_defaults=draft_defaults,
            )
            if not drafts:
                return {
                    "need_clarification": True,
                    "clarify_question": _clarify_for_type_hint(type_hint),
                    "drafts": [],
                }
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
                commit_id=None,
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
        unique_ids = list(dict.fromkeys(draft_ids))
        drafts = self._repo.get_drafts_by_ids(unique_ids)
        if not drafts:
            raise ToolError("not_found", "no drafts found", {"draft_ids": unique_ids})

        self._repo._conn.commit()

        committed: list[dict[str, Any]] = []
        new_undo_token: Optional[str] = None
        existing_undo_token: Optional[str] = None
        created_at = now_iso8601()

        with _commit_lock:
            for row in drafts:
                draft_id = row["draft_id"]
                tool_name = row["tool_name"]

                existed = self._repo.get_commit_by_draft_id(draft_id)
                if existed is not None:
                    if existing_undo_token is None and existed["undo_token"]:
                        existing_undo_token = existed["undo_token"]
                    existed_result = (
                        json_loads(existed["result_json"]) if existed["result_json"] else {}
                    )
                    committed.append(
                        {
                            "draft_id": draft_id,
                            "tool_name": tool_name,
                            "commit_id": existed["commit_id"],
                            "result": existed_result,
                        }
                    )
                    continue

                if new_undo_token is None:
                    new_undo_token = str(uuid4())

                payload = json_loads(row["payload_json"])
                commit_id = str(uuid4())
                result = _call_tool(tool_name, {**payload, "commit_id": commit_id})
                self._repo.insert_log(
                    kind="commit",
                    request_id=row["request_id"],
                    draft_id=draft_id,
                    tool_name=tool_name,
                    payload_json=row["payload_json"],
                    result_json=json_dumps(result),
                    undo_token=new_undo_token,
                    commit_id=commit_id,
                    created_at=created_at,
                )
                committed.append(
                    {
                        "draft_id": draft_id,
                        "tool_name": tool_name,
                        "commit_id": commit_id,
                        "result": result,
                    }
                )

        undo_token = new_undo_token or existing_undo_token
        return {"committed": committed, "undo_token": undo_token}

    def undo(self, undo_token: str) -> dict[str, Any]:
        commits = self._repo.get_commits_by_undo_token(undo_token)
        if not commits:
            raise ToolError("not_found", "undo_token not found", {"undo_token": undo_token})

        self._repo._conn.commit()

        undone: list[dict[str, Any]] = []
        for row in commits:
            tool_name = row["tool_name"]
            result = json_loads(row["result_json"]) if row["result_json"] else {}
            undone.append(_undo_tool(tool_name, result))

        return {"undone": undone, "undo_token": undo_token}

    def undo_commit(self, commit_id: str) -> dict[str, Any]:
        row = self._repo.get_commit_by_id(commit_id)
        if row is None:
            raise ToolError("not_found", "commit_id not found", {"commit_id": commit_id})
        self._repo._conn.commit()
        tool_name = row["tool_name"]
        result = json_loads(row["result_json"]) if row["result_json"] else {}
        undone = _undo_tool(tool_name, result)
        return {"undone": [undone], "commit_id": commit_id}

    def edit_draft(self, draft_id: str, patch: dict[str, Any]) -> dict[str, Any]:
        row = self._repo.get_draft_by_id(draft_id)
        if row is None:
            raise ToolError("not_found", "draft not found", {"draft_id": draft_id})
        tool_name = row["tool_name"]
        payload = json_loads(row["payload_json"]) if row["payload_json"] else {}
        
        if tool_name == "create_task":
            updated = _apply_task_patch(payload, patch)
            card = _task_card_from_payload(draft_id, updated)
        else:
            updated = dict(payload)
            for k, v in patch.items():
                if v is None and k in updated:
                    del updated[k]
                elif v is not None:
                    updated[k] = v
            card = _pick_card([], 0, draft_id, tool_name, updated)

        self._repo.update_draft_payload(draft_id, json_dumps(updated))
        consts = get_constants()
        draft_item = {
            "draft_id": draft_id,
            "tool_name": tool_name,
            "payload": updated,
            "confidence": consts.defaults.confidence,
            "status": "draft",
        }
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
            commit_id=str(uuid4()),
            created_at=created_at,
        )
        return {"task": result, "undo_token": undo_token}


def _pick_card(cards, idx: int, draft_id: str, tool_name: str, payload: dict[str, Any]) -> dict[str, Any]:
    display_data = _display_card_data(tool_name, payload)
    if idx < len(cards):
        card = cards[idx].model_dump()
    else:
        title = ""
        subtitle = ""
        if tool_name == "create_income":
            title = "收入"
            amount = payload.get("amount")
            currency = payload.get("currency") or "CNY"
            if amount is not None:
                subtitle = f"{amount} {currency}"
        card = {
            "card_id": draft_id,
            "type": tool_name.replace("create_", ""),
            "status": "draft",
            "title": title,
            "subtitle": subtitle,
            "data": display_data,
            "actions": [],
        }
    card["data"] = display_data
    card["card_id"] = draft_id
    card["status"] = "draft"
    return card


def _display_card_data(tool_name: str, payload: dict[str, Any]) -> dict[str, Any]:
    data = dict(payload)
    if tool_name not in {"create_expense", "create_income", "create_transfer"}:
        return data

    try:
        with get_connection() as conn:
            ensure_tables(conn)
            repo = AccountsRepository(conn)
            if tool_name == "create_transfer":
                from_account_id = payload.get("from_account_id")
                to_account_id = payload.get("to_account_id")
                if isinstance(from_account_id, int) and from_account_id > 0:
                    account = repo.get_account(from_account_id)
                    if account and account.get("name"):
                        data["from_account_name"] = account["name"]
                if isinstance(to_account_id, int) and to_account_id > 0:
                    account = repo.get_account(to_account_id)
                    if account and account.get("name"):
                        data["to_account_name"] = account["name"]
                return data
            account_id = payload.get("account_id")
            if not isinstance(account_id, int) or account_id <= 0:
                return data
            account = repo.get_account(account_id)
    except Exception:
        return data

    if account and account.get("name"):
        data["account_name"] = account["name"]
    return data


def _drafts_from_decision(decision) -> list[Draft]:
    drafts: list[Draft] = []
    for idx, call in enumerate(decision.tool_calls):
        if call.name in _DISABLED_CHAT_TOOLS:
            continue
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


def _fallback_drafts(
    text: str,
    type_hint: str | None = None,
    image_base64s: list[str] | None = None,
    draft_defaults: dict[str, Any] | None = None,
) -> list[Draft]:
    drafts: list[Draft] = []

    def add(tool_name: str, payload: dict[str, Any], confidence: float = 0.5) -> None:
        draft_id = str(uuid4())
        payload = _normalize_time_fields(payload, tool_name)
        payload = _merge_draft_defaults(tool_name, payload, draft_defaults)
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

    stripped = text.strip()
    if type_hint == "lifelog":
        payload: dict[str, Any] = {}
        if stripped:
            payload["text"] = stripped
        if image_base64s:
            payload["images"] = image_base64s
        if payload:
            add("create_lifelog", payload, confidence=0.7)
        return drafts
    if type_hint == "task" and stripped:
        add("create_task", {"title": stripped}, confidence=0.7)
        return drafts
    if type_hint == "income":
        amount_hint = _extract_amount(text)
        if amount_hint is not None:
            add("create_income", {"amount": amount_hint, "category": "other"}, confidence=0.7)
        return drafts
    if type_hint in {"transfer", "repayment"}:
        amount_hint = _extract_amount(text)
        if amount_hint is not None:
            payload: dict[str, Any] = {"amount": amount_hint}
            if type_hint == "repayment":
                payload["note"] = "还款"
            add("create_transfer", payload, confidence=0.7)
        return drafts
    if type_hint == "meal" and stripped:
        add("create_meal", {"meal_type": "snack", "items": [stripped]}, confidence=0.7)
        return drafts
    if type_hint == "expense":
        amount_hint = _extract_amount(text)
        if amount_hint is not None:
            add("create_expense", {"amount": amount_hint, "category": "food"}, confidence=0.7)
        return drafts

    lowered = text.lower()
    amount = _extract_amount(text)
    if amount is not None and _match_any(lowered, ["花", "消费", "付款", "支付", "买", "￥", "¥", "$"]):
        add("create_expense", {"amount": amount, "category": "food"}, confidence=0.6)
    if amount is not None and _match_any(
        lowered,
        ["收入", "赚了", "收到", "到账", "工资", "报销", "奖金", "打款", "进账"],
    ):
        add("create_income", {"amount": amount, "category": "other"}, confidence=0.6)

    if _match_any(lowered, ["提醒", "待办", "任务", "记得", "要做"]):
        add("create_task", {"title": text.strip()}, confidence=0.55)

    return drafts


def _call_tool(tool_name: str, payload: dict[str, Any]) -> dict[str, Any]:
    if tool_name == "create_expense":
        return create_expense(**payload)
    if tool_name == "create_income":
        return create_income(**payload)
    if tool_name == "create_transfer":
        return create_transfer(**payload)
    if tool_name == "create_task":
        return create_task(**payload)
    if tool_name == "create_mood":
        return create_mood(**payload)
    if tool_name == "create_lifelog":
        return create_lifelog(**payload)
    if tool_name == "create_meal":
        return create_meal(**payload)
    raise ToolError("invalid_tool", "unsupported tool", {"tool_name": tool_name})


def _apply_draft_defaults(
    drafts: list[Draft],
    draft_defaults: dict[str, Any] | None,
) -> list[Draft]:
    if not draft_defaults:
        return drafts

    updated: list[Draft] = []
    for draft in drafts:
        payload = _merge_draft_defaults(draft.tool_name, draft.payload, draft_defaults)
        if payload == draft.payload:
            updated.append(draft)
            continue
        updated.append(
            Draft(
                draft_id=draft.draft_id,
                tool_name=draft.tool_name,
                payload=payload,
                confidence=draft.confidence,
                card=_pick_card([], 0, draft.draft_id, draft.tool_name, payload),
            )
        )
    return updated


def _merge_draft_defaults(
    tool_name: str,
    payload: dict[str, Any],
    draft_defaults: dict[str, Any] | None,
) -> dict[str, Any]:
    if not draft_defaults:
        return payload

    updated = dict(payload)
    if tool_name in {"create_expense", "create_income"}:
        account_id = draft_defaults.get("account_id")
        if isinstance(account_id, int) and account_id > 0:
            updated["account_id"] = account_id
        category = draft_defaults.get("category")
        if isinstance(category, str) and category.strip():
            updated["category"] = category.strip()
    if tool_name == "create_transfer":
        from_account_id = draft_defaults.get("from_account_id")
        to_account_id = draft_defaults.get("to_account_id")
        if isinstance(from_account_id, int) and from_account_id > 0:
            updated["from_account_id"] = from_account_id
        if isinstance(to_account_id, int) and to_account_id > 0:
            updated["to_account_id"] = to_account_id
        note = draft_defaults.get("note")
        if isinstance(note, str) and note.strip():
            updated["note"] = note.strip()
    return updated


def _undo_tool(tool_name: str, result: dict[str, Any]) -> dict[str, Any]:
    if tool_name in {"create_expense", "create_income", "create_lifelog", "create_meal", "create_mood", "create_transfer"}:
        event_id = result.get("event_id")
        if isinstance(event_id, int):
            return {"event": soft_delete_event(event_id)}
        return {"event": None}
    if tool_name == "create_task":
        task_id = result.get("task_id")
        if isinstance(task_id, int):
            return {"task": soft_delete_task(task_id)}
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
    elif tool_name in {"create_expense", "create_income", "create_lifelog", "create_meal", "create_mood", "create_transfer"}:
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

    match = re.search(r"(\d+(?:\.\d+)?)", text)
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


def _inject_type_hint(text: str, type_hint: str | None) -> str:
    if not type_hint:
        return text
    return f"[TYPE_HINT:{type_hint}] {text}".strip()


def _clarify_for_type_hint(type_hint: str | None) -> str:
    if type_hint == "expense":
        return "请补充这笔支出的金额。"
    if type_hint == "income":
        return "请补充这笔收入的金额。"
    if type_hint == "transfer":
        return "请补充转账金额，并选择转出和转入账户。"
    if type_hint == "repayment":
        return "请补充还款金额，并选择还款账户和负债账户。"
    if type_hint == "meal":
        return "请补充你吃了什么。"
    if type_hint == "task":
        return "请补充任务内容。"
    if type_hint == "lifelog":
        return "请补充这条日志的内容，或上传一张图片。"
    return "你想记录什么？"


def get_orchestrator_service() -> OrchestratorService:
    conn = get_connection()
    ensure_tables(conn)
    return OrchestratorService(OrchestratorRepository(conn))
