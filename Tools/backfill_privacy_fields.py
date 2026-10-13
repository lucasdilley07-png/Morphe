#!/usr/bin/env python3
"""One-time backfill (2026-10-12): every post carries `authorPrivate` and
every usernames doc carries `private`, explicitly false when missing.

Why: the private-account rules filter reads on these fields
(`authorPrivate == false`, `private == false`); a doc without the field is
excluded from those queries, so old public posts and handles would vanish
from the feed and Quick Add. Additive and idempotent: only docs missing the
field are touched; existing true/false values are left alone.

Run:  python3 Tools/backfill_privacy_fields.py          (dry run)
      python3 Tools/backfill_privacy_fields.py --apply
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KEY_PATH = REPO / "BACKEND" / "serviceAccount.json"
import google.auth.transport.requests  # noqa: E402
import requests  # noqa: E402
from google.oauth2 import service_account  # noqa: E402

cred = service_account.Credentials.from_service_account_file(
    str(KEY_PATH), scopes=["https://www.googleapis.com/auth/datastore"])
PROJECT = json.loads(KEY_PATH.read_text())["project_id"]
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
APPLY = "--apply" in sys.argv


def auth() -> dict:
    if not cred.valid:
        cred.refresh(google.auth.transport.requests.Request())
    return {"Authorization": f"Bearer {cred.token}"}


def docs(collection: str):
    token = None
    while True:
        params = {"pageSize": 300, "mask.fieldPaths": ["authorPrivate", "private"]}
        if token:
            params["pageToken"] = token
        r = requests.get(f"{FS}/{collection}", params=params, headers=auth(), timeout=60)
        r.raise_for_status()
        body = r.json()
        yield from body.get("documents", [])
        token = body.get("nextPageToken")
        if not token:
            return


def backfill(collection: str, field: str):
    missing = [d["name"] for d in docs(collection) if field not in d.get("fields", {})]
    print(f"{collection}: {len(missing)} docs missing `{field}`")
    if not APPLY or not missing:
        return
    for start in range(0, len(missing), 400):
        writes = [{"update": {"name": n, "fields": {field: {"booleanValue": False}}},
                   "updateMask": {"fieldPaths": [field]},
                   "currentDocument": {"exists": True}} for n in missing[start:start + 400]]
        r = requests.post(f"{FS.rsplit('/documents', 1)[0]}/documents:commit",
                          json={"writes": writes}, headers=auth(), timeout=60)
        r.raise_for_status()
    print(f"  set {field}=false on {len(missing)}")


backfill("posts", "authorPrivate")
backfill("usernames", "private")
print("applied" if APPLY else "dry run — rerun with --apply")
