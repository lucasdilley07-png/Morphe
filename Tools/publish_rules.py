#!/usr/bin/env python3
"""Morphe Firestore rules publisher.

Run:  python3 Tools/publish_rules.py

Publishes BACKEND/firestore.rules to the live project via the Firebase
Rules API, then reads the LIVE ruleset back and byte-compares it against
the local file — so "published" is verified, never assumed. This replaces
the console copy-paste routine (whose stale-clipboard failure mode burned
us once already).

Steps:
  1. Create a ruleset from the local file (the API compiles it — a syntax
     error fails HERE, before anything goes live).
  2. Point the cloud.firestore release at the new ruleset.
  3. Fetch the release + ruleset back and diff against the local file.

Needs the Firebase service-account key at BACKEND/serviceAccount.json
(gitignored, same credential the review tools use).
"""
import json
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KEY_PATH = REPO / "BACKEND" / "serviceAccount.json"
RULES_PATH = REPO / "BACKEND" / "firestore.rules"

if not KEY_PATH.exists():
    sys.exit(f"Service-account key not found at {KEY_PATH}")
if not RULES_PATH.exists():
    sys.exit(f"Rules file not found at {RULES_PATH}")

import google.auth.transport.requests  # noqa: E402
import requests  # noqa: E402
from google.oauth2 import service_account  # noqa: E402

credentials = service_account.Credentials.from_service_account_file(
    str(KEY_PATH), scopes=["https://www.googleapis.com/auth/cloud-platform"]
)
PROJECT = json.loads(KEY_PATH.read_text())["project_id"]
API = "https://firebaserules.googleapis.com/v1"
RELEASE = f"projects/{PROJECT}/releases/cloud.firestore"


def token() -> str:
    if not credentials.valid:
        credentials.refresh(google.auth.transport.requests.Request())
    return credentials.token


def call(method: str, path: str, payload=None):
    response = requests.request(
        method,
        f"{API}/{path}",
        json=payload,
        headers={"Authorization": f"Bearer {token()}"},
        timeout=30,
    )
    if not response.ok:
        sys.exit(f"{method} {path} -> {response.status_code}\n{response.text}")
    return response.json() if response.text else {}


source = RULES_PATH.read_text()

# You publish the WORKING TREE — say so when it differs from git, so an
# experimental edit never goes live by muscle memory.
diff = subprocess.run(
    ["git", "-C", str(REPO), "diff", "--stat", "--", "BACKEND/firestore.rules"],
    capture_output=True, text=True)
if diff.stdout.strip():
    print("NOTE: BACKEND/firestore.rules has UNCOMMITTED changes — publishing them:")
    print(f"  {diff.stdout.strip()}")
    if sys.stdin.isatty():
        if input("Continue? [y/N] ").strip().lower() != "y":
            sys.exit("Aborted — commit (or intend) the change, then rerun.")

# 1. Create the ruleset — the API compiles the source; a broken file dies
#    here with line-numbered issues and nothing changes in production.
print(f"Compiling + uploading {RULES_PATH.name} ({len(source.splitlines())} lines) to {PROJECT}…")
ruleset = call("POST", f"projects/{PROJECT}/rulesets", {
    "source": {"files": [{"name": "firestore.rules", "content": source}]}
})
ruleset_name = ruleset["name"]
print(f"  ruleset created: {ruleset_name}")

# 2. Point the Firestore release at it — THIS is the publish. From here on,
#    any failure is a VERIFICATION problem, not a publish failure — a retry
#    against already-changed production must never look necessary.
try:
    call("PATCH", RELEASE, {
        "release": {"name": RELEASE, "rulesetName": ruleset_name}
    })
except requests.RequestException as error:
    sys.exit(f"Release PATCH did not return cleanly ({error}).\n"
             "The publish MAY have applied — check the console before retrying.")
print(f"  release updated: {RELEASE}")

# 3. Trust nothing: read the LIVE release back and byte-compare.
try:
    live_release = call("GET", RELEASE)
    live_ruleset = call("GET", live_release["rulesetName"])
    live_source = live_ruleset["source"]["files"][0]["content"]
except requests.RequestException as error:
    sys.exit(f"Release updated, but verification could not complete ({error}).\n"
             "Rerun this script (it is idempotent) or check the console.")

if live_source == source:
    print(f"\nPUBLISHED + VERIFIED — the live ruleset is byte-identical to "
          f"{RULES_PATH.relative_to(REPO)} ({live_release['rulesetName'].split('/')[-1]}).")
    # Byte-verified ≠ enforced yet: rules propagation lags up to ~1 minute.
    # The behavioral test right after a publish must not race the old rules.
    print("Waiting 60s for rules propagation before behavioral tests are safe…")
    time.sleep(60)
    print("Done — run Tools/verify_rules_live.py now.")
else:
    sys.exit("\nMISMATCH: the live ruleset does not match the local file. Investigate.")
