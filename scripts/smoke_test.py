import os
import sys
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "apps", "api", "src"))

from api.tools.events import create_expense, search_events
from api.tools.notifications import create_notification_for_task, list_notifications, mark_notification_read
from api.tools.tasks import complete_task, create_task, list_tasks_overdue, list_tasks_today


def main() -> None:
    os.environ["APP_DB_PATH"] = os.path.join("data", "smoke_test.db")

    # create_expense idempotency
    idem_key = "expense-123"
    e1 = create_expense(amount=12.5, category="food", idempotency_key=idem_key)
    e2 = create_expense(amount=12.5, category="food", idempotency_key=idem_key)
    assert e1["event_id"] == e2["event_id"], "idempotency failed"

    # search_events
    res = search_events(query="food")
    assert len(res["items"]) >= 1, "search_events failed"

    # create_task + complete_task
    due = (datetime.now(ZoneInfo("Asia/Shanghai")) + timedelta(hours=1)).isoformat()
    t1 = create_task(title="Smoke Task", due_at=due)
    t1_done = complete_task(t1["task_id"])
    assert t1_done["status"] == "done", "complete_task failed"

    # list_tasks_today / overdue
    today = list_tasks_today(timezone="Asia/Shanghai")
    overdue = list_tasks_overdue(timezone="Asia/Shanghai")
    assert isinstance(today["items"], list)
    assert isinstance(overdue["items"], list)

    # create_notification + mark_read
    scheduled = (datetime.now(ZoneInfo("Asia/Shanghai")) + timedelta(minutes=5)).isoformat()
    n1 = create_notification_for_task(
        task_id=t1["task_id"],
        scheduled_at=scheduled,
        title="Reminder",
        content="Test reminder",
    )
    mark_notification_read(n1["notification_id"])
    unread = list_notifications(unread_only=True)
    assert all(n["notification_id"] != n1["notification_id"] for n in unread["items"])

    print("OK: smoke test passed")


if __name__ == "__main__":
    main()
