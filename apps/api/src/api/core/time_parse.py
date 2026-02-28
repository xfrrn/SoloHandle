from __future__ import annotations

import re
from datetime import datetime, timedelta
from typing import Optional
from zoneinfo import ZoneInfo

from api.db.connection import DEFAULT_TZ

WEEKDAY_MAP = {
    "一": 0,
    "二": 1,
    "三": 2,
    "四": 3,
    "五": 4,
    "六": 5,
    "日": 6,
    "天": 6,
}


def parse_natural_time(value: str, tz: str = DEFAULT_TZ) -> Optional[str]:
    text = value.strip()
    if not text:
        return None

    base = datetime.now(ZoneInfo(tz))
    day_delta: Optional[int] = None

    if "今天" in text:
        day_delta = 0
    elif "明天" in text:
        day_delta = 1
    elif "后天" in text:
        day_delta = 2
    elif "大后天" in text:
        day_delta = 3
    elif "昨天" in text:
        day_delta = -1
    elif "前天" in text:
        day_delta = -2

    # Relative days like 3天后 / 2天前
    m_rel = re.search(r"(\d{1,2})\s*天(后|前)", text)
    if m_rel:
        days = int(m_rel.group(1))
        day_delta = days if m_rel.group(2) == "后" else -days

    # Weeks like 下周三 / 本周五 / 周一 / 下星期二
    m_week = re.search(r"(下周|下星期|本周|这周|本星期|周|星期)([一二三四五六日天])", text)
    if m_week:
        target = WEEKDAY_MAP[m_week.group(2)]
        today = base.weekday()
        delta = (target - today) % 7
        if m_week.group(1) in {"下周", "下星期"}:
            delta = delta + 7 if delta == 0 else delta + 7
        elif m_week.group(1) in {"本周", "这周", "本星期"}:
            delta = delta
        else:
            delta = 7 if delta == 0 else delta
        day_delta = delta

    # Explicit date like 3/15 or 03-15
    m_md = re.search(r"(\d{1,2})[/-](\d{1,2})", text)
    if m_md:
        month = int(m_md.group(1))
        day = int(m_md.group(2))
        year = base.year
        try:
            candidate = datetime(year, month, day, tzinfo=ZoneInfo(tz))
            if candidate.date() < base.date():
                candidate = datetime(year + 1, month, day, tzinfo=ZoneInfo(tz))
            return _apply_time(candidate, text, tz)
        except ValueError:
            return None

    # Time of day
    time_match = re.search(
        r"(凌晨|早上|上午|中午|下午|晚上)?\s*(\d{1,2})(?:点|:)(?:(\d{1,2})分?)?", text
    )
    half = "半" in text

    if day_delta is None or time_match is None:
        return None

    period = time_match.group(1) or ""
    hour = int(time_match.group(2))
    minute = int(time_match.group(3)) if time_match.group(3) else (30 if half else 0)

    if period in {"下午", "晚上"} and hour < 12:
        hour += 12
    if period == "中午" and hour < 11:
        hour += 12
    if period == "凌晨" and hour == 12:
        hour = 0

    target_date = (base + timedelta(days=day_delta)).date()
    dt = datetime(
        year=target_date.year,
        month=target_date.month,
        day=target_date.day,
        hour=hour,
        minute=minute,
        second=0,
        tzinfo=ZoneInfo(tz),
    )
    return dt.isoformat()


def _apply_time(date_dt: datetime, text: str, tz: str) -> Optional[str]:
    time_match = re.search(
        r"(凌晨|早上|上午|中午|下午|晚上)?\s*(\d{1,2})(?:点|:)(?:(\d{1,2})分?)?", text
    )
    half = "半" in text
    if time_match is None:
        return None
    period = time_match.group(1) or ""
    hour = int(time_match.group(2))
    minute = int(time_match.group(3)) if time_match.group(3) else (30 if half else 0)

    if period in {"下午", "晚上"} and hour < 12:
        hour += 12
    if period == "中午" and hour < 11:
        hour += 12
    if period == "凌晨" and hour == 12:
        hour = 0

    return datetime(
        date_dt.year,
        date_dt.month,
        date_dt.day,
        hour,
        minute,
        0,
        tzinfo=ZoneInfo(tz),
    ).isoformat()
