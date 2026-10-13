#!/usr/bin/env python3
"""Export the website waitlist (create-only from the web; read here with
the service account). Prints unique emails, newest first, skipping the
rules-test entries.

Run:  python3 Tools/export_waitlist.py > waitlist.txt
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KEY_PATH = REPO / "BACKEND" / "serviceAccount.json"
if not KEY_PATH.exists():
    sys.exit(f"Service-account key not found at {KEY_PATH}")
import google.auth.transport.requests  # noqa: E402
import requests  # noqa: E402
from google.oauth2 import service_account  # noqa: E402

cred = service_account.Credentials.from_service_account_file(
    str(KEY_PATH), scopes=["https://www.googleapis.com/auth/datastore"])
cred.refresh(google.auth.transport.requests.Request())
PROJECT = json.loads(KEY_PATH.read_text())["project_id"]
URL = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents/waitlist"

rows, token = [], None
while True:
    params = {"pageSize": 300}
    if token:
        params["pageToken"] = token
    r = requests.get(URL, params=params, headers={"Authorization": f"Bearer {cred.token}"}, timeout=60)
    r.raise_for_status()
    body = r.json()
    for d in body.get("documents", []):
        f = d.get("fields", {})
        if f.get("source", {}).get("stringValue") == "rules-test":
            continue
        rows.append((d.get("createTime", ""), f.get("email", {}).get("stringValue", "")))
    token = body.get("nextPageToken")
    if not token:
        break

seen = set()
for _, email in sorted(rows, reverse=True):
    if email and email not in seen:
        seen.add(email)
        print(email)
print(f"# {len(seen)} unique", file=sys.stderr)
