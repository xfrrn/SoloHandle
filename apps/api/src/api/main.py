from __future__ import annotations

from fastapi import FastAPI

from api.routes.chat import router as chat_router
from api.routes.router_health import router as router_health_router

app = FastAPI(title="AI Companion API")
app.include_router(chat_router)
app.include_router(router_health_router)
