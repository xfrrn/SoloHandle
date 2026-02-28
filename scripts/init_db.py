import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "apps", "api", "src"))

from api.db.connection import ensure_tables, get_connection


def main() -> None:
    with get_connection() as conn:
        ensure_tables(conn)
    print("OK: tables ensured")


if __name__ == "__main__":
    main()
