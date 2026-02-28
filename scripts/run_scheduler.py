import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "apps", "api", "src"))

from api.scheduler.reminder_scheduler import ReminderScheduler


def main() -> None:
    poll_seconds = float(os.environ.get("SCHEDULER_POLL_SECONDS", "30"))
    scheduler = ReminderScheduler()
    print(f"Scheduler started. Poll interval: {poll_seconds:.1f}s")
    while True:
        result = scheduler.run_once()
        if result.triggered:
            print(
                f"Triggered {result.triggered} reminders "
                f"(tasks={result.task_ids}, notifications={result.notification_ids})"
            )
        time.sleep(poll_seconds)


if __name__ == "__main__":
    main()
