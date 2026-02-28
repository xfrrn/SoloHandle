import json
import sys
import urllib.request
from dataclasses import dataclass
from typing import Any


@dataclass
class Options:
    base_url: str = "http://127.0.0.1:7876"


def post_json(url: str, payload: dict[str, Any]) -> dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        body = resp.read().decode("utf-8")
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        return {"raw": body}


def get_json(url: str) -> dict[str, Any]:
    with urllib.request.urlopen(url) as resp:
        body = resp.read().decode("utf-8")
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        return {"raw": body}


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python scripts/debug_request.py health")
        print("  python scripts/debug_request.py chat \"text\"")
        print("  python scripts/debug_request.py confirm <draft_id>")
        print("  python scripts/debug_request.py undo <undo_token>")
        sys.exit(1)

    cmd = sys.argv[1]
    opts = Options()

    if cmd == "health":
        res = get_json(f"{opts.base_url}/router/health")
        print(json.dumps(res, ensure_ascii=False, indent=2))
        return

    if cmd == "chat":
        if len(sys.argv) < 3:
            print("Missing text")
            sys.exit(1)
        text = sys.argv[2]
        res = post_json(f"{opts.base_url}/chat", {"text": text})
        print(json.dumps(res, ensure_ascii=False, indent=2))
        return

    if cmd == "confirm":
        if len(sys.argv) < 3:
            print("Missing draft_id")
            sys.exit(1)
        draft_id = sys.argv[2]
        res = post_json(f"{opts.base_url}/chat", {"confirm_draft_ids": [draft_id]})
        print(json.dumps(res, ensure_ascii=False, indent=2))
        return

    if cmd == "undo":
        if len(sys.argv) < 3:
            print("Missing undo_token")
            sys.exit(1)
        undo_token = sys.argv[2]
        res = post_json(f"{opts.base_url}/chat", {"undo_token": undo_token})
        print(json.dumps(res, ensure_ascii=False, indent=2))
        return

    print("Unknown command")
    sys.exit(1)


if __name__ == "__main__":
    main()
