#!/usr/bin/env python3
"""Morphe metrics report — the founder's weekly numbers.

Run:  python3 Tools/metrics_report.py

Aggregates the first-party telemetry collection (write-only from clients;
this tool reads it with the service account) into the handful of numbers
that actually matter: activation, D1/D7/D30 retention by weekly cohort,
and growth-loop event counts. No third-party analytics anywhere — this IS
the analytics.

Needs BACKEND/serviceAccount.json (gitignored, same credential as the
review tools).
"""
import json
import sys
from collections import defaultdict
from datetime import date, timedelta
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KEY_PATH = REPO / "BACKEND" / "serviceAccount.json"
if not KEY_PATH.exists():
    sys.exit(f"Service-account key not found at {KEY_PATH}")

import google.auth.transport.requests  # noqa: E402
import requests  # noqa: E402
from google.oauth2 import service_account  # noqa: E402

credentials = service_account.Credentials.from_service_account_file(
    str(KEY_PATH), scopes=["https://www.googleapis.com/auth/datastore"])
PROJECT = json.loads(KEY_PATH.read_text())["project_id"]
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"


def token() -> str:
    if not credentials.valid:
        credentials.refresh(google.auth.transport.requests.Request())
    return credentials.token


def fetch_all_events() -> list:
    """Pages through the whole telemetry collection. Fine for pilot scale
    (thousands of events); revisit with BigQuery export past ~100k."""
    events, page_token = [], None
    while True:
        params = {"pageSize": 1000}
        if page_token:
            params["pageToken"] = page_token
        response = requests.get(
            f"{FS}/telemetry", params=params,
            headers={"Authorization": f"Bearer {token()}"}, timeout=60)
        response.raise_for_status()
        data = response.json()
        for doc in data.get("documents", []):
            fields = doc.get("fields", {})
            uid = fields.get("uid", {}).get("stringValue")
            name = fields.get("name", {}).get("stringValue")
            day = fields.get("day", {}).get("stringValue")
            if uid and name and day:
                events.append((uid, name, day))
        page_token = data.get("nextPageToken")
        if not page_token:
            break
    return events


def parse_day(day: str):
    try:
        y, m, d = (int(part) for part in day.split("-"))
        return date(y, m, d)
    except (ValueError, AttributeError):
        return None


events = fetch_all_events()
if not events:
    sys.exit("No telemetry yet — ship first, then come back. (That's the point.)")

active_days = defaultdict(set)      # uid -> {date}
event_counts = defaultdict(int)     # name -> count
event_users = defaultdict(set)      # name -> {uid}
for uid, name, day in events:
    parsed = parse_day(day)
    if not parsed:
        continue
    event_counts[name] += 1
    event_users[name].add(uid)
    if name == "day_active":
        active_days[uid].add(parsed)

users = {uid for uid, _, _ in events}
cohort_day = {uid: min(days) for uid, days in active_days.items() if days}

print(f"MORPHE METRICS — {PROJECT} — {date.today().isoformat()}")
print(f"{'=' * 56}")
print(f"Accounts seen:            {len(users)}")
print(f"Activated (first log):    {len(event_users['activation_first_log'])}"
      f"  ({100 * len(event_users['activation_first_log']) / max(len(users), 1):.0f}% of accounts)")

# Retention: of users whose cohort day is at least N days old, how many
# were day_active exactly-or-later at day N? (Classic unbounded DN.)
today = date.today()
for n in (1, 7, 30):
    eligible = [uid for uid, first in cohort_day.items()
                if (today - first).days >= n]
    retained = [uid for uid in eligible
                if any((day - cohort_day[uid]).days >= n for day in active_days[uid])]
    if eligible:
        print(f"D{n} retention:{' ' * (14 - len(str(n)))}{len(retained)}/{len(eligible)}"
              f"  ({100 * len(retained) / len(eligible):.0f}%)")
    else:
        print(f"D{n} retention:{' ' * (14 - len(str(n)))}no cohort old enough yet")

print(f"\nWeekly cohorts (first-active week -> size):")
weekly = defaultdict(int)
for first in cohort_day.values():
    week_start = first - timedelta(days=first.weekday())
    weekly[week_start] += 1
for week_start in sorted(weekly):
    print(f"  {week_start.isoformat()}  {weekly[week_start]}")

print(f"\nGrowth-loop + milestone events (count / unique users):")
for name in sorted(event_counts, key=event_counts.get, reverse=True):
    print(f"  {name:<24} {event_counts[name]:>6} / {len(event_users[name])}")

print(f"\nTargets (LAUNCH_CHECKLIST §5): D30 ≥ 10-12%, activation ≥ 40%,")
print("share_card_shared + referral_consumed > 0 and growing week over week.")
