from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv

try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:  # pragma: no cover
    import tomli as tomllib

DEFAULT_CONFIG_PATH = Path(__file__).resolve().parents[2] / "config.toml"
DEFAULT_ENV_PATH = DEFAULT_CONFIG_PATH.parent / ".env"

# Load project-local .env as a fallback source. Real environment variables
# still win because override=False.
load_dotenv(dotenv_path=DEFAULT_ENV_PATH, override=False)


def _load_toml_file(path: Path) -> dict:
    return tomllib.loads(path.read_text(encoding="utf-8-sig"))


@dataclass
class LLMSettings:
    base_url: str
    api_key: str
    model: str
    fast_model: str
    timeout_seconds: int = 30


@dataclass
class DBSettings:
    url: str


@dataclass
class ServerSettings:
    cors_allow_origins: list[str]
    bearer_token: Optional[str] = None


def _split_csv(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


def load_llm_settings(config_path: Optional[Path] = None) -> Optional[LLMSettings]:
    env_base_url = os.environ.get("APP_LLM_BASE_URL", "").strip()
    env_api_key = os.environ.get("APP_LLM_API_KEY", "").strip()
    env_model = os.environ.get("APP_LLM_MODEL", "").strip()
    env_fast_model = os.environ.get("APP_LLM_FAST_MODEL", "").strip()
    env_timeout = os.environ.get("APP_LLM_TIMEOUT_SECONDS", "").strip()
    if env_base_url and env_api_key and env_model:
        timeout_seconds = int(env_timeout) if env_timeout else 30
        return LLMSettings(
            base_url=env_base_url,
            api_key=env_api_key,
            model=env_model,
            fast_model=env_fast_model or env_model,
            timeout_seconds=timeout_seconds,
        )

    path = config_path or DEFAULT_CONFIG_PATH
    if not path.exists():
        return None
    data = _load_toml_file(path)
    llm = data.get("llm")
    if not isinstance(llm, dict):
        return None
    base_url = llm.get("base_url")
    api_key = llm.get("api_key")
    model = llm.get("model")
    if not base_url or not api_key or not model:
        return None
    fast_model = llm.get("fast_model", model)
    timeout_seconds = int(llm.get("timeout_seconds", 30))
    return LLMSettings(
        base_url=str(base_url),
        api_key=str(api_key),
        model=str(model),
        fast_model=str(fast_model),
        timeout_seconds=timeout_seconds,
    )


def load_db_settings(config_path: Optional[Path] = None) -> Optional[DBSettings]:
    env_url = os.environ.get("APP_DB_URL", "").strip()
    if env_url:
        return DBSettings(url=env_url)

    path = config_path or DEFAULT_CONFIG_PATH
    if not path.exists():
        return None
    data = _load_toml_file(path)
    db = data.get("db")
    if not isinstance(db, dict):
        return None
    url = db.get("url")
    if not isinstance(url, str) or not url.strip():
        return None
    return DBSettings(url=url.strip())


def load_server_settings(config_path: Optional[Path] = None) -> ServerSettings:
    env_origins = os.environ.get("APP_CORS_ALLOW_ORIGINS", "").strip()
    env_token = os.environ.get("APP_API_TOKEN", "").strip()
    path = config_path or DEFAULT_CONFIG_PATH
    if not path.exists():
        return ServerSettings(
            cors_allow_origins=_split_csv(env_origins),
            bearer_token=env_token or None,
        )

    data = _load_toml_file(path)
    server = data.get("server")
    auth = data.get("auth")
    origins: list[str] = []
    bearer_token: Optional[str] = None

    if isinstance(server, dict):
        raw_origins = server.get("cors_allow_origins", [])
        if isinstance(raw_origins, list):
            origins = [str(item).strip() for item in raw_origins if str(item).strip()]
        elif isinstance(raw_origins, str):
            origins = _split_csv(raw_origins)

    if isinstance(auth, dict):
        token = auth.get("bearer_token")
        if isinstance(token, str) and token.strip():
            bearer_token = token.strip()

    return ServerSettings(
        cors_allow_origins=_split_csv(env_origins) if env_origins else origins,
        bearer_token=env_token or bearer_token,
    )
