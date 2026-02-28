from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import tomllib

DEFAULT_CONFIG_PATH = Path(__file__).resolve().parents[2] / "config.toml"


@dataclass
class LLMSettings:
    base_url: str
    api_key: str
    model: str
    timeout_seconds: int = 30


def load_llm_settings(config_path: Optional[Path] = None) -> Optional[LLMSettings]:
    path = config_path or DEFAULT_CONFIG_PATH
    if not path.exists():
        return None
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    llm = data.get("llm")
    if not isinstance(llm, dict):
        return None
    base_url = llm.get("base_url")
    api_key = llm.get("api_key")
    model = llm.get("model")
    if not base_url or not api_key or not model:
        return None
    timeout_seconds = int(llm.get("timeout_seconds", 30))
    return LLMSettings(
        base_url=str(base_url),
        api_key=str(api_key),
        model=str(model),
        timeout_seconds=timeout_seconds,
    )
