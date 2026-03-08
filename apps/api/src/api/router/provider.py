from __future__ import annotations

import base64
import json
import logging
import os
import tempfile
import urllib.request
from dataclasses import dataclass
from typing import Any, Optional
from openai import OpenAI

from api.db.connection import ToolError
from api.settings import LLMSettings, load_llm_settings

logger = logging.getLogger("api.llm")


@dataclass
class LLMConfig:
    base_url: str
    api_key: str
    model: str
    fast_model: str
    timeout_seconds: int = 30


class LLMProvider:
    def generate(
        self,
        prompt: str,
        user_input: str,
        image_base64s: list[str] | None = None,
        model: str | None = None,
    ) -> str:
        raise NotImplementedError

    def transcribe_audio(self, audio_base64: str) -> str:
        raise NotImplementedError

    @property
    def fast_model(self) -> str:
        raise NotImplementedError


class OpenAICompatibleProvider(LLMProvider):
    def __init__(self, config: LLMConfig) -> None:
        self._config = config
        self._client = OpenAI(
            api_key=config.api_key,
            base_url=config.base_url
        )

    def generate(
        self,
        prompt: str,
        user_input: str,
        image_base64s: list[str] | None = None,
        model: str | None = None,
    ) -> str:
        url = self._config.base_url.rstrip("/") + "/chat/completions"
        content = [{"type": "text", "text": user_input}]
        if image_base64s:
            for image_base64 in image_base64s:
                content.append({
                    "type": "image_url",
                    "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}
                })
            
        payload = {
            "model": model or self._config.model,
            "messages": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": content},
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
            content = parsed["choices"][0]["message"]["content"]
            self._log_model_output(
                kind="generate",
                model=model or self._config.model,
                text=_normalize_llm_text(content),
            )
            return content
        except Exception as exc:  # noqa: BLE001
            raise ToolError("llm_error", "LLM response parse failed", {"body": body}) from exc

    def transcribe_audio(self, audio_base64: str) -> str:
        audio_bytes = base64.b64decode(audio_base64)
        
        with tempfile.NamedTemporaryFile(suffix=".m4a", delete=True) as temp_audio:
            temp_audio.write(audio_bytes)
            temp_audio.flush()
            temp_audio.seek(0)
            
            try:
                transcript = self._client.audio.transcriptions.create(
                    model="whisper-large-v3",
                    file=temp_audio,
                    language="zh",
                    prompt="请准确转录中文内容，注意标点符号和语法",
                    response_format="text",
                    temperature=0.2
                )
                text = transcript.strip()
                self._log_model_output(
                    kind="transcribe_audio",
                    model="whisper-large-v3",
                    text=text,
                )
                return text
            except Exception as exc:  # noqa: BLE001
                raise ToolError("llm_error", "Audio transcription failed", {"error": str(exc)}) from exc

    @property
    def fast_model(self) -> str:
        return self._config.fast_model

    def _log_model_output(self, *, kind: str, model: str, text: str) -> None:
        if not _llm_debug_enabled():
            return
        logger.warning("LLM %s model=%s output:\n%s", kind, model, text)


def _llm_debug_enabled() -> bool:
    return os.environ.get("APP_LLM_DEBUG", "").strip().lower() in {"1", "true", "yes", "on"}


def _normalize_llm_text(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, dict):
                text = item.get("text")
                if isinstance(text, str) and text.strip():
                    parts.append(text)
            elif isinstance(item, str) and item.strip():
                parts.append(item)
        if parts:
            return "\n".join(parts)
    return str(content)


def load_provider_from_config() -> Optional[LLMProvider]:
    settings = load_llm_settings()
    if settings is None:
        return None
    config = LLMConfig(
        base_url=settings.base_url,
        api_key=settings.api_key,
        model=settings.model,
        fast_model=settings.fast_model,
        timeout_seconds=settings.timeout_seconds,
    )
    return OpenAICompatibleProvider(config)
