from __future__ import annotations

import json
import urllib.request
from dataclasses import dataclass
from typing import Any, Optional

from api.db.connection import ToolError
from api.settings import LLMSettings, load_llm_settings


@dataclass
class LLMConfig:
    base_url: str
    api_key: str
    model: str
    timeout_seconds: int = 30


class LLMProvider:
    def generate(self, prompt: str, user_input: str) -> str:
        raise NotImplementedError


class OpenAICompatibleProvider(LLMProvider):
    def __init__(self, config: LLMConfig) -> None:
        self._config = config

    def generate(self, prompt: str, user_input: str) -> str:
        url = self._config.base_url.rstrip("/") + "/chat/completions"
        payload = {
            "model": self._config.model,
            "messages": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": user_input},
            ],
            "temperature": 0.2,
        }
        data = json.dumps(payload).encode("utf-8")
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self._config.api_key}",
        }
        req = urllib.request.Request(url, data=data, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=self._config.timeout_seconds) as resp:
                body = resp.read().decode("utf-8")
        except Exception as exc:  # noqa: BLE001
            raise ToolError("llm_error", "LLM request failed", {"error": str(exc)}) from exc

        try:
            parsed = json.loads(body)
            return parsed["choices"][0]["message"]["content"]
        except Exception as exc:  # noqa: BLE001
            raise ToolError("llm_error", "LLM response parse failed", {"body": body}) from exc


def load_provider_from_config() -> Optional[LLMProvider]:
    settings = load_llm_settings()
    if settings is None:
        return None
    config = LLMConfig(
        base_url=settings.base_url,
        api_key=settings.api_key,
        model=settings.model,
        timeout_seconds=settings.timeout_seconds,
    )
    return OpenAICompatibleProvider(config)
