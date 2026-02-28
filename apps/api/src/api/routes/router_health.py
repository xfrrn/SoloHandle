from __future__ import annotations

from fastapi import APIRouter

from api.router.provider import load_provider_from_config
from api.settings import load_llm_settings

router = APIRouter()


@router.get("/router/health")
def router_health() -> dict:
    provider = load_provider_from_config()
    settings = load_llm_settings()
    model = settings.model if settings else None
    base_url = settings.base_url if settings else None
    return {
        "llm_configured": provider is not None,
        "model": model,
        "base_url": base_url,
    }
