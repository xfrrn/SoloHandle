from __future__ import annotations

from typing import Any, List, Optional

from pydantic import BaseModel, Field


class ToolCall(BaseModel):
    name: str
    arguments: dict[str, Any] = Field(default_factory=dict)


class Card(BaseModel):
    card_id: str
    type: str
    status: str
    title: str = ""
    subtitle: str = ""
    data: dict[str, Any] = Field(default_factory=dict)
    actions: List[dict[str, Any]] = Field(default_factory=list)


class RouterDecision(BaseModel):
    intent: str
    confidence: float
    need_clarification: bool
    clarify_question: Optional[str] = None
    reply_to_user: Optional[str] = None
    tool_calls: List[ToolCall] = Field(default_factory=list)
    cards: List[Card] = Field(default_factory=list)
