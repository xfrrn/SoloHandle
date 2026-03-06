from __future__ import annotations

import base64
import json
import tempfile
import urllib.request
from dataclasses import dataclass
from typing import Any, Optional
from openai import OpenAI

from api.db.connection import ToolError
from api.settings import LLMSettings, load_llm_settings


@dataclass
class LLMConfig:
    base_url: str
    api_key: str
    model: str
    timeout_seconds: int = 30


class LLMProvider:
    def generate(self, prompt: str, user_input: str, image_base64: str | None = None) -> str:
        raise NotImplementedError

    def transcribe_audio(self, audio_base64: str) -> str:
        raise NotImplementedError


class OpenAICompatibleProvider(LLMProvider):
    def __init__(self, config: LLMConfig) -> None:
        self._config = config
        self._client = OpenAI(
            api_key=config.api_key,
            base_url=config.base_url
        )

    def generate(self, prompt: str, user_input: str, image_base64: str | None = None) -> str:
        url = self._config.base_url.rstrip("/") + "/chat/completions"
        content = [{"type": "text", "text": user_input}]
        if image_base64:
            content.append({
                "type": "image_url",
                "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}
            })
            
        payload = {
            "model": self._config.model,
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
            return parsed["choices"][0]["message"]["content"]
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
                return transcript.strip()
            except Exception as exc:  # noqa: BLE001
                raise ToolError("llm_error", "Audio transcription failed", {"error": str(exc)}) from exc


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
