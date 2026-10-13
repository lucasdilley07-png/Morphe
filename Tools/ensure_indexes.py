#!/usr/bin/env python3
"""Ensure the Firestore composite indexes Morphe's queries need exist.

Run:  python3 Tools/ensure_indexes.py            (create missing, then wait)
      python3 Tools/ensure_indexes.py --list     (show what exists)

Source of truth: BACKEND/firestore.indexes.json. Creating an index is
additive and safe; this tool never deletes one. Builds take a few minutes
on a small database; queries that need a building index fail until it is
READY, so the script waits.

Needs BACKEND/serviceAccount.json (gitignored), same credential as
Tools/publish_rules.py.
"""
import json
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KEY_PATH = REPO / "BACKEND" / "serviceAccount.json"
SPEC_PATH = REPO / "BACKEND" / "firestore.indexes.json"
if not KEY_PATH.exists():
    sys.exit(f"Service-account key not found at {KEY_PATH}")

import google.auth.transport.requests  # noqa: E402
import requests  # noqa: E402
from google.oauth2 import service_account  # noqa: E402

credentials = service_account.Credentials.from_service_account_file(
    str(KEY_PATH), scopes=["https://www.googleapis.com/auth/cloud-platform"])
PROJECT = json.loads(KEY_PATH.read_text())["project_id"]
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/collectionGroups"


def token() -> str:
    if not credentials.valid:
        credentials.refresh(google.auth.transport.requests.Request())
    return credentials.token


def call(method: str, url: str, payload=None) -> dict:
    response = requests.request(method, url, json=payload,
                                headers={"Authorization": f"Bearer {token()}"}, timeout=30)
    if not response.ok:
        sys.exit(f"{method} {url} -> {response.status_code}\n{response.text}")
    return response.json() if response.text else {}


def shape(fields: list) -> tuple:
    """Comparable key; the server appends __name__ to some indexes."""
    return tuple((f["fieldPath"], f.get("order") or f.get("arrayConfig"))
                 for f in fields if not (f["fieldPath"] == "__name__" and f is fields[-1] and len(fields) > 1
                                         and fields[-2]["fieldPath"] != "__name__"))


def existing(collection: str) -> list:
    data = call("GET", f"{BASE}/{collection}/indexes")
    return data.get("indexes", [])


spec = json.loads(SPEC_PATH.read_text())["indexes"]

if "--list" in sys.argv:
    for collection in sorted({i["collectionGroup"] for i in spec}):
        for index in existing(collection):
            fields = ", ".join(f"{f['fieldPath']} {f.get('order', '')}" for f in index["fields"])
            print(f"{collection:10} {index.get('state', '?'):9} {fields}")
    sys.exit(0)

pending = []
for wanted in spec:
    collection = wanted["collectionGroup"]
    have = {shape(i["fields"]) for i in existing(collection)}
    if shape(wanted["fields"]) in have:
        print(f"exists   {collection}: {[f['fieldPath'] for f in wanted['fields']]}")
        continue
    call("POST", f"{BASE}/{collection}/indexes",
         {"queryScope": wanted.get("queryScope", "COLLECTION"), "fields": wanted["fields"]})
    print(f"CREATED  {collection}: {[f['fieldPath'] for f in wanted['fields']]}")
    pending.append(collection)

# Wait until every index on the touched collections is READY.
deadline = time.time() + 900
while pending and time.time() < deadline:
    states = [i.get("state") for c in set(pending) for i in existing(c)]
    if all(s == "READY" for s in states):
        break
    print(f"  building… {states.count('CREATING')} still creating")
    time.sleep(20)
print("ALL INDEXES READY" if not pending or time.time() < deadline else "Timed out waiting — rerun to check.")
