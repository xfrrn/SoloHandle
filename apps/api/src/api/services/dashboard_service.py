from __future__ import annotations

import sqlite3
import json
from typing import Any, Dict, List
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from api.db.connection import now_iso8601, DEFAULT_TZ
from api.repositories.dashboard_repo import DashboardRepository


class DashboardService:
    def __init__(self, repo: DashboardRepository) -> None:
        self._repo = repo

    def get_summary(self, tz: str = DEFAULT_TZ) -> Dict[str, Any]:
        """
        Aggregates dashboard data:
        1. Expenses: past 30 days
        2. Mood: past 7 days
        3. Tasks: today's completion and streaks (mocked streak computation for now)
        """
        now = datetime.now(ZoneInfo(tz))
        
        # 30 days window for expenses
        thirty_days_ago = now - timedelta(days=30)
        start_date_30d = thirty_days_ago.replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
        end_date_now = now.isoformat()

        # 7 days window for mood
        seven_days_ago = now - timedelta(days=6) # 7 days including today
        start_date_7d = seven_days_ago.replace(hour=0, minute=0, second=0, microsecond=0).isoformat()

        # Today's window for tasks
        start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
        end_of_today = now.replace(hour=23, minute=59, second=59, microsecond=999999).isoformat()

        # Fetch Raw Data
        raw_expenses = self._repo.get_expenses_summary(start_date_30d, end_date_now)
        raw_moods = self._repo.get_moods_summary(start_date_7d, end_date_now)
        raw_tasks = self._repo.get_todays_tasks_summary(start_of_today, end_of_today)

        # Aggregate Expenses (Group by day, format: yyyy-mm-dd)
        expenses_by_day: Dict[str, float] = {}
        total_monthly_expense = 0.0
        for row in raw_expenses:
            try:
                dt = datetime.fromisoformat(row["happened_at"]).astimezone(ZoneInfo(tz))
                day_str = dt.strftime("%Y-%m-%d")
                
                data = json.loads(row["data_json"])
                # Assumes 'amount' is stored in the Expense event
                amount = float(data.get("amount", 0.0))
                
                if day_str not in expenses_by_day:
                    expenses_by_day[day_str] = 0.0
                expenses_by_day[day_str] += amount
                total_monthly_expense += amount
            except Exception:
                continue
                
        # Format expenses into a sorted list
        expense_trend = [
             {"date": k, "amount": v} for k, v in sorted(expenses_by_day.items())
        ]

        # Aggregate Mood (Group by day)
        mood_by_day: Dict[str, list[float]] = {}
        for row in raw_moods:
            try:
                dt = datetime.fromisoformat(row["happened_at"]).astimezone(ZoneInfo(tz))
                day_str = dt.strftime("%Y-%m-%d")
                
                data = json.loads(row["data_json"])
                # Assumes 'valence' or 'score' is stored. Let's look for valence or default to 5.0
                val = float(data.get("valence", data.get("score", 5.0)))
                
                if day_str not in mood_by_day:
                    mood_by_day[day_str] = []
                mood_by_day[day_str].append(val)
            except Exception:
                continue

        # Average mood per day
        mood_trend = []
        for d in range(7):
            target_date = (now - timedelta(days=6 - d)).strftime("%Y-%m-%d")
            if target_date in mood_by_day and mood_by_day[target_date]:
                avg = sum(mood_by_day[target_date]) / len(mood_by_day[target_date])
            else:
                avg = 0.0 # Or maybe some neutral value or null indicator
            mood_trend.append({"date": target_date, "average_valence": round(avg, 2)})

        # Aggregate Tasks
        completed_count = 0
        total_count = len(raw_tasks)
        for t in raw_tasks:
            if t["status"] == "completed":
                completed_count += 1
                
        # Note: True streak calculation is complex and requires scanning history.
        # Currently, return an empty array until the real streak calculation is implemented.
        mock_streaks = []

        return {
            "finance": {
                "total_expense_30d": round(total_monthly_expense, 2),
                "trend": expense_trend
            },
            "mood": {
                "trend": mood_trend
            },
            "tasks": {
                "today_completed": completed_count,
                "today_total": total_count,
                "streaks": mock_streaks
            }
        }

__all__ = ["DashboardService"]
