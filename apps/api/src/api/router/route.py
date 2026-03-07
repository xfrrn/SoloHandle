from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from pydantic import ValidationError

from api.db.connection import ToolError, now_iso8601
from api.router.provider import LLMProvider, load_provider_from_config
from api.router.schema import RouterDecision

PROMPT_PATH = (
    Path(__file__).resolve().parents[5]
    / "packages"
    / "prompts"
    / "router_prompt.txt"
)

CLASSIFY_PROMPT_PATH = (
    Path(__file__).resolve().parents[5]
    / "packages"
    / "prompts"
    / "classify_prompt.txt"
)

CHAT_PROMPT_PATH = (
    Path(__file__).resolve().parents[5]
    / "packages"
    / "prompts"
    / "chat_prompt.txt"
)


def route(
    text: str,
    image_base64s: list[str] | None = None,
    provider: LLMProvider | None = None,
    max_retries: int = 2,
) -> RouterDecision:
    prompt = PROMPT_PATH.read_text(encoding="utf-8")
    prompt += f"\n\nCURRENT TIME (Asia/Shanghai): {now_iso8601()}"
    provider = provider or load_provider_from_config()
    if provider is None:
        raise ToolError("llm_unavailable", "LLM provider not configured")

    last_error: ToolError | None = None
    user_input = text
    for attempt in range(max_retries + 1):
        output = provider.generate(prompt, user_input, image_base64s=image_base64s)
        try:
            return _parse_decision(output)
        except ToolError as exc:
            if exc.code not in {"router_invalid_json", "router_invalid_schema"}:
                raise
            last_error = exc
            if attempt < max_retries:
                user_input = _build_repair_prompt(text, output, exc)
    raise last_error or ToolError("router_invalid_json", "Router output is not valid JSON")


def _build_repair_prompt(original_text: str, output: str, error: ToolError) -> str:
    details = error.details or {}
    return (
        "Your previous output was invalid. Fix it and output ONLY valid JSON.\\n"
        f"Original user input: {original_text}\\n"
        f"Invalid output: {output}\\n"
        f"Error: {error.code} {error.message} {details}\\n"
    )


def _parse_decision(output: str) -> RouterDecision:
    try:
        data = json.loads(output)
    except json.JSONDecodeError as exc:
        raise ToolError("router_invalid_json", "Router output is not valid JSON", {"output": output}) from exc

    try:
        return RouterDecision.model_validate(data)
    except ValidationError as exc:
        raise ToolError("router_invalid_schema", "Router output schema invalid", {"errors": exc.errors()}) from exc

def classify_intent(
    text: str,
    image_base64s: list[str] | None = None,
    provider: LLMProvider | None = None,
) -> str:
    prompt = CLASSIFY_PROMPT_PATH.read_text(encoding="utf-8")
    provider = provider or load_provider_from_config()
    if provider is None:
        return "action"
    try:
        # Use a fast/cheap model for intent classification
        output = provider.generate(prompt, text, image_base64s=image_base64s, model=provider.fast_model).strip().lower()
        if "chat" in output:
            return "chat"
        return "action"
    except Exception:
        return "action"

def chat_reply(
    text: str,
    image_base64s: list[str] | None = None,
    provider: LLMProvider | None = None,
) -> str:
    prompt = CHAT_PROMPT_PATH.read_text(encoding="utf-8")
    provider = provider or load_provider_from_config()
    if provider is None:
        return "你好！有什么我可以帮你的？"
    try:
        return provider.generate(prompt, text, image_base64s=image_base64s).strip()
    except Exception as e:
        import traceback
        traceback.print_exc()
        return "抱歉，我刚刚走神了，能再说一遍吗？"
