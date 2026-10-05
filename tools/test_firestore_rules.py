"""Checks firestore.rules against the local Firestore emulator (nothing touches the real project).

Usage (needs Java and the Firebase CLI):
    firebase emulators:exec --only firestore --project kifa-games "python3 tools/test_firestore_rules.py"
"""

import base64
import json
import sys
import urllib.error
import urllib.request

PROJECT = "kifa-games"
BASE = f"http://127.0.0.1:8085/v1/projects/{PROJECT}/databases/(default)/documents"
VALID = {"version": 2, "best_score": 42, "coins": 310, "owned": ["little_girl", "little_boy", "cat"]}


def token(uid: str) -> str:
    """The emulator accepts unsigned tokens, so any uid can be simulated."""

    def part(data: dict) -> str:
        return base64.urlsafe_b64encode(json.dumps(data).encode()).decode().rstrip("=")

    return f'{part({"alg": "none", "typ": "JWT"})}.{part({"sub": uid, "user_id": uid, "aud": PROJECT})}.'


def encode(value):
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int):
        return {"integerValue": str(value)}
    if isinstance(value, float):
        return {"doubleValue": value}
    if isinstance(value, list):
        return {"arrayValue": {"values": [encode(item) for item in value]}}
    return {"stringValue": str(value)}


def call(method: str, path: str, uid: str | None, data: dict | None = None) -> int:
    body = None if data is None else json.dumps({"fields": {k: encode(v) for k, v in data.items()}}).encode()
    request = urllib.request.Request(f"{BASE}/{path}", data=body, method=method)
    request.add_header("Content-Type", "application/json")
    if uid is not None:
        request.add_header("Authorization", f"Bearer {token(uid)}")
    try:
        with urllib.request.urlopen(request) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code


def changed(**fields) -> dict:
    return {**VALID, **fields}


OWN = "saves/alice/games/runner"
CASES = [
    # (description, expected status, method, path, uid, data)
    ("owner reads a missing save", 404, "GET", OWN, "alice", None),
    ("owner creates a valid save", 200, "PATCH", OWN, "alice", VALID),
    ("owner reads the save", 200, "GET", OWN, "alice", None),
    ("owner updates the save", 200, "PATCH", OWN, "alice", changed(coins=0, owned=[])),
    ("another account cannot read it", 403, "GET", OWN, "bob", None),
    ("another account cannot write it", 403, "PATCH", OWN, "bob", VALID),
    ("another account cannot delete it", 403, "DELETE", OWN, "bob", None),
    ("a guest cannot read it", 403, "GET", OWN, None, None),
    ("a guest cannot write it", 403, "PATCH", OWN, None, VALID),
    ("extra field is refused", 403, "PATCH", OWN, "alice", changed(admin=True)),
    ("missing field is refused", 403, "PATCH", OWN, "alice", {"version": 2, "coins": 1, "owned": []}),
    ("other version is refused", 403, "PATCH", OWN, "alice", changed(version=3)),
    ("negative coins are refused", 403, "PATCH", OWN, "alice", changed(coins=-1)),
    ("too many coins are refused", 403, "PATCH", OWN, "alice", changed(coins=1_000_000_001)),
    ("text coins are refused", 403, "PATCH", OWN, "alice", changed(coins="999")),
    ("fractional coins are refused", 403, "PATCH", OWN, "alice", changed(coins=1.5)),
    ("negative best score is refused", 403, "PATCH", OWN, "alice", changed(best_score=-1)),
    ("owned that is not a list is refused", 403, "PATCH", OWN, "alice", changed(owned="cat")),
    ("oversized owned list is refused", 403, "PATCH", OWN, "alice", changed(owned=["cat"] * 21)),
    ("a game without rules is refused", 403, "PATCH", "saves/alice/games/other", "alice", VALID),
    ("a document outside saves is refused", 403, "PATCH", "admin/alice", "alice", VALID),
    ("the account document itself is refused", 403, "PATCH", "saves/alice", "alice", VALID),
    ("refused writes left the save unchanged", 200, "GET", OWN, "alice", None),
    ("owner deletes the save", 200, "DELETE", OWN, "alice", None),
    ("the save is gone", 404, "GET", OWN, "alice", None),
]


def main() -> int:
    failures = 0
    for description, expected, method, path, uid, data in CASES:
        status = call(method, path, uid, data)
        ok = status == expected
        failures += not ok
        print(f'{"ok  " if ok else "FAIL"} {description}: {status}' + ("" if ok else f" (expected {expected})"))
    print(f"{len(CASES) - failures}/{len(CASES)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
