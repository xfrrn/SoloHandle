from __future__ import annotations

import secrets

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.requests import Request
from fastapi.responses import JSONResponse

from api.routes.chat import router as chat_router
from api.routes.dashboard import router as dashboard_router
from api.routes.events import router as events_router
from api.routes.finance import router as finance_router
from api.routes.router_health import router as router_health_router
from api.routes.tasks import router as tasks_router
from api.settings import load_server_settings

server_settings = load_server_settings()

app = FastAPI(title="AI Companion API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=server_settings.cors_allow_origins,
    allow_credentials=bool(server_settings.cors_allow_origins),
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def bearer_auth(request: Request, call_next):
    if request.method == "OPTIONS":
        return await call_next(request)

    token = server_settings.bearer_token
    if not token:
        return await call_next(request)

    if request.url.path == "/router/health":
        return await call_next(request)

    auth_header = request.headers.get("Authorization", "")
    prefix = "Bearer "
    if not auth_header.startswith(prefix):
        return JSONResponse(
            status_code=401,
            content={"detail": {"code": "unauthorized", "message": "Missing bearer token"}},
        )

    provided = auth_header[len(prefix):].strip()
    if not provided or not secrets.compare_digest(provided, token):
        return JSONResponse(
            status_code=401,
            content={"detail": {"code": "unauthorized", "message": "Invalid bearer token"}},
        )

    return await call_next(request)


app.include_router(chat_router)
app.include_router(events_router)
app.include_router(tasks_router)
app.include_router(router_health_router)
app.include_router(dashboard_router)
app.include_router(finance_router)
