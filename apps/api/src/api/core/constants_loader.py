from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Optional


class ConstantsError(Exception):
    pass


@dataclass(frozen=True)
class DefaultsConfig:
    timezone: str
    currency: str
    confidence: float
    source: str


@dataclass(frozen=True)
class ExpenseConfig:
    categories: list[str]
    default_category: str


@dataclass(frozen=True)
class MealConfig:
    types: list[str]


@dataclass(frozen=True)
class TaskConfig:
    status: list[str]
    priority: list[str]
    default_priority: str
    default_status: str
    default_remind_offset_minutes: int


@dataclass(frozen=True)
class LimitsConfig:
    max_tags: int
    max_text_len: int


@dataclass(frozen=True)
class AppConstants:
    defaults: DefaultsConfig
    expense: ExpenseConfig
    meal: MealConfig
    task: TaskConfig
    limits: LimitsConfig
    sources: list[str]
    event_types: list[str]


_CACHED: Optional[AppConstants] = None


def _require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ConstantsError(f"{path} must be object")
    return value


def _require_str(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ConstantsError(f"{path} must be non-empty string")
    return value


def _require_number(value: Any, path: str) -> float:
    if not isinstance(value, (int, float)):
        raise ConstantsError(f"{path} must be number")
    return float(value)


def _require_int(value: Any, path: str) -> int:
    if not isinstance(value, int):
        raise ConstantsError(f"{path} must be integer")
    return value


def _require_list_of_str(value: Any, path: str) -> list[str]:
    if not isinstance(value, list):
        raise ConstantsError(f"{path} must be list")
    if len(value) == 0:
        raise ConstantsError(f"{path} must be non-empty list")
    out: list[str] = []
    for idx, item in enumerate(value):
        if not isinstance(item, str) or not item.strip():
            raise ConstantsError(f"{path}[{idx}] must be non-empty string")
        out.append(item)
    return out


def _load_json(path: Path) -> dict[str, Any]:
    try:
        text = path.read_text(encoding="utf-8-sig")
    except FileNotFoundError as exc:
        raise ConstantsError(f"constants file not found: {path}") from exc

    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ConstantsError(
            f"invalid JSON in constants file {path}: line {exc.lineno} col {exc.colno}"
        ) from exc

    return _require_dict(data, "$")


def _validate_constants(data: dict[str, Any]) -> AppConstants:
    defaults = _require_dict(data.get("defaults"), "defaults")
    expense = _require_dict(data.get("expense"), "expense")
    meal = _require_dict(data.get("meal"), "meal")
    task = _require_dict(data.get("task"), "task")
    limits = _require_dict(data.get("limits"), "limits")

    defaults_cfg = DefaultsConfig(
        timezone=_require_str(defaults.get("timezone"), "defaults.timezone"),
        currency=_require_str(defaults.get("currency"), "defaults.currency"),
        confidence=_require_number(defaults.get("confidence"), "defaults.confidence"),
        source=_require_str(defaults.get("source"), "defaults.source"),
    )
    if not (0.0 <= defaults_cfg.confidence <= 1.0):
        raise ConstantsError("defaults.confidence must be in range [0, 1]")

    expense_categories = _require_list_of_str(expense.get("categories"), "expense.categories")
    default_category = _require_str(expense.get("default_category"), "expense.default_category")
    if default_category not in expense_categories:
        raise ConstantsError("expense.default_category must be in expense.categories")

    meal_types = _require_list_of_str(meal.get("types"), "meal.types")

    task_status = _require_list_of_str(task.get("status"), "task.status")
    task_priority = _require_list_of_str(task.get("priority"), "task.priority")
    default_priority = _require_str(task.get("default_priority"), "task.default_priority")
    default_status = _require_str(task.get("default_status"), "task.default_status")
    if default_priority not in task_priority:
        raise ConstantsError("task.default_priority must be in task.priority")
    if default_status not in task_status:
        raise ConstantsError("task.default_status must be in task.status")

    default_remind_offset_minutes = _require_int(
        task.get("default_remind_offset_minutes"),
        "task.default_remind_offset_minutes",
    )
    if default_remind_offset_minutes < 0:
        raise ConstantsError("task.default_remind_offset_minutes must be >= 0")

    max_tags = _require_int(limits.get("max_tags"), "limits.max_tags")
    max_text_len = _require_int(limits.get("max_text_len"), "limits.max_text_len")
    if max_tags <= 0:
        raise ConstantsError("limits.max_tags must be > 0")
    if max_text_len <= 0:
        raise ConstantsError("limits.max_text_len must be > 0")

    sources = _require_list_of_str(data.get("sources"), "sources")
    if defaults_cfg.source not in sources:
        raise ConstantsError("defaults.source must be in sources")

    event = _require_dict(data.get("event"), "event")
    event_types = _require_list_of_str(event.get("types"), "event.types")

    return AppConstants(
        defaults=defaults_cfg,
        expense=ExpenseConfig(categories=expense_categories, default_category=default_category),
        meal=MealConfig(types=meal_types),
        task=TaskConfig(
            status=task_status,
            priority=task_priority,
            default_priority=default_priority,
            default_status=default_status,
            default_remind_offset_minutes=default_remind_offset_minutes,
        ),
        limits=LimitsConfig(max_tags=max_tags, max_text_len=max_text_len),
        sources=sources,
        event_types=event_types,
    )


def _default_constants_path() -> Path:
    return (
        Path(__file__).resolve().parents[5]
        / "packages"
        / "constants"
        / "constants.json"
    )


def load_constants(path: Optional[str] = None) -> AppConstants:
    if path is None:
        path = os.environ.get("CONSTANTS_PATH")
    constants_path = Path(path) if path else _default_constants_path()
    data = _load_json(constants_path)
    return _validate_constants(data)


def get_constants() -> AppConstants:
    global _CACHED
    if _CACHED is None:
        _CACHED = load_constants()
    return _CACHED


def _reset_constants_cache() -> None:
    global _CACHED
    _CACHED = None


def _as_json(constants: AppConstants) -> str:
    return json.dumps(asdict(constants), ensure_ascii=False, indent=2)


if __name__ == "__main__":
    consts = get_constants()
    print(_as_json(consts))
