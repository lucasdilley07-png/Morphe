#!/usr/bin/env python3
"""Morphe LIVE rules verification.

Run:  python3 Tools/verify_rules_live.py

Exercises the PUBLISHED Firestore rules with real throwaway Auth users
over REST — every check hits production security enforcement, not a local
emulator. ALLOW cases prove features work; DENY cases prove strangers
can't touch what isn't theirs. Cleans up everything it creates (docs +
throwaway accounts).

Reads the Web API key from GoogleService-Info.plist (repo root,
gitignored). No service account needed — the whole point is testing what
NORMAL user tokens can do.
"""
import json
import secrets
import subprocess
import sys
import time
import uuid
from pathlib import Path

import requests

REPO = Path(__file__).resolve().parent.parent
PLIST = REPO / "GoogleService-Info.plist"
if not PLIST.exists():
    sys.exit("GoogleService-Info.plist not found at repo root.")

API_KEY = subprocess.run(
    ["plutil", "-extract", "API_KEY", "raw", str(PLIST)],
    capture_output=True, text=True, check=True).stdout.strip()
PROJECT = subprocess.run(
    ["plutil", "-extract", "PROJECT_ID", "raw", str(PLIST)],
    capture_output=True, text=True, check=True).stdout.strip()

AUTH = "https://identitytoolkit.googleapis.com/v1"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"

RUN_ID = uuid.uuid4().hex[:8]
# Real production Auth accounts, so a real secret — never derivable from
# the log output.
PASSWORD = secrets.token_urlsafe(18)
results = []


def check(name: str, expect_allow: bool, status: int):
    allowed = 200 <= status < 300
    ok = allowed == expect_allow
    results.append((name, expect_allow, allowed, ok))
    mark = "PASS" if ok else "FAIL"
    want = "ALLOW" if expect_allow else "DENY"
    got = "allowed" if allowed else f"denied ({status})"
    print(f"  [{mark}] {name}  (want {want}, got {got})")


def sign_up(tag: str) -> dict:
    email = f"rulestest-{RUN_ID}-{tag}@morphe.app"
    response = requests.post(
        f"{AUTH}/accounts:signUp?key={API_KEY}",
        json={"email": email, "password": PASSWORD, "returnSecureToken": True},
        timeout=30)
    response.raise_for_status()
    data = response.json()
    return {"uid": data["localId"], "token": data["idToken"], "email": email}


def fs_call(user: dict, method: str, path: str, payload=None, params="") -> int:
    response = requests.request(
        method, f"{FS}/{path}{params}", json=payload,
        headers={"Authorization": f"Bearer {user['token']}"}, timeout=30)
    return response.status_code


def s(value): return {"stringValue": value}
def b(value): return {"booleanValue": value}
def i(value): return {"integerValue": str(value)}


print(f"Live rules verification on {PROJECT} (run {RUN_ID})")
print("Creating throwaway users A (athlete), B (stranger), C (coach)…")
A, B, C = sign_up("a"), sign_up("b"), sign_up("c")

created_users = [A, B, C]
try:
    post_id = f"rulestest-{RUN_ID}"
    username = f"rulestest{RUN_ID}"

    print("\n— Identity + backup —")
    check("A creates own users/{A} doc", True,
          fs_call(A, "PATCH", f"users/{A['uid']}",
                  {"fields": {"role": s("athlete"), "displayName": s("Rules A")}}))
    check("B reads A's user doc", False, fs_call(B, "GET", f"users/{A['uid']}"))
    check("A writes own state/profile backup", True,
          fs_call(A, "PATCH", f"users/{A['uid']}/state/profile",
                  {"fields": {"schemaVersion": i(1), "json": s("{}")}}))
    check("B reads A's state backup", False,
          fs_call(B, "GET", f"users/{A['uid']}/state/profile"))

    print("\n— Usernames —")
    check("A claims a username", True,
          fs_call(A, "PATCH", f"usernames/{username}", {"fields": {"uid": s(A["uid"])}}))
    check("B overwrites A's username claim", False,
          fs_call(B, "PATCH", f"usernames/{username}", {"fields": {"uid": s(B["uid"])}}))

    print("\n— Posts (honest shapes) —")
    check("A publishes a valid post", True,
          fs_call(A, "PATCH", f"posts/{post_id}",
                  {"fields": {"authorUid": s(A["uid"]), "authorName": s("Rules A"),
                              "verified": b(False), "text": s("live rules test"),
                              "setCount": i(12)}}))
    check("A self-mints verified:true on a post", False,
          fs_call(A, "PATCH", f"posts/{post_id}-v",
                  {"fields": {"authorUid": s(A["uid"]), "authorName": s("Rules A"),
                              "verified": b(True), "text": s("forged badge")}}))
    check("A sneaks an undeclared key into a post", False,
          fs_call(A, "PATCH", f"posts/{post_id}-x",
                  {"fields": {"authorUid": s(A["uid"]), "authorName": s("Rules A"),
                              "verified": b(False), "text": s("extra"), "hax": s("y")}}))
    check("B forges a post AS A", False,
          fs_call(B, "PATCH", f"posts/{post_id}-f",
                  {"fields": {"authorUid": s(A["uid"]), "authorName": s("Fake A"),
                              "verified": b(False), "text": s("impostor")}}))
    check("A posts with accent + headline identity", True,
          fs_call(A, "PATCH", f"posts/{post_id}-a",
                  {"fields": {"authorUid": s(A["uid"]), "authorName": s("Rules A"),
                              "verified": b(False), "text": s("accent test"),
                              "authorAccent": s("Electric Blue"),
                              "authorHeadline": s("Strength · 12-day streak")}}))
    check("A posts an oversized headline", False,
          fs_call(A, "PATCH", f"posts/{post_id}-h",
                  {"fields": {"authorUid": s(A["uid"]), "authorName": s("Rules A"),
                              "verified": b(False), "text": s("headline abuse"),
                              "authorHeadline": s("x" * 120)}}))
    check("A posts an oversized accent value", False,
          fs_call(A, "PATCH", f"posts/{post_id}-a2",
                  {"fields": {"authorUid": s(A["uid"]), "authorName": s("Rules A"),
                              "verified": b(False), "text": s("accent abuse"),
                              "authorAccent": s("x" * 60)}}))

    print("\n— Reactions (one per uid, typed) —")
    check("B reacts to A's post (fire)", True,
          fs_call(B, "PATCH", f"posts/{post_id}/reactions/{B['uid']}",
                  {"fields": {"value": b(True), "type": s("fire")}}))
    check("B changes reaction type (update, same doc)", True,
          fs_call(B, "PATCH", f"posts/{post_id}/reactions/{B['uid']}",
                  {"fields": {"value": b(True), "type": s("clap")}}))
    check("B writes a reaction under A's uid", False,
          fs_call(B, "PATCH", f"posts/{post_id}/reactions/{A['uid']}",
                  {"fields": {"value": b(True), "type": s("heart")}}))
    check("B invents a reaction type", False,
          fs_call(B, "PATCH", f"posts/{post_id}/reactions/{B['uid']}",
                  {"fields": {"value": b(True), "type": s("skull")}}))

    print("\n— Comments —")
    comment_id = f"c-{RUN_ID}"
    check("B comments on A's post", True,
          fs_call(B, "PATCH", f"posts/{post_id}/comments/{comment_id}",
                  {"fields": {"authorUid": s(B["uid"]), "authorName": s("Rules B"),
                              "text": s("solid session")}}))
    check("A deletes B's comment (not the author)", False,
          fs_call(A, "DELETE", f"posts/{post_id}/comments/{comment_id}"))
    check("B edits their published comment (immutable)", False,
          fs_call(B, "PATCH", f"posts/{post_id}/comments/{comment_id}",
                  {"fields": {"authorUid": s(B["uid"]), "authorName": s("Rules B"),
                              "text": s("edited!")}}))
    check("B deletes their own comment", True,
          fs_call(B, "DELETE", f"posts/{post_id}/comments/{comment_id}"))

    print("\n— Follow + block —")
    check("A follows B", True,
          fs_call(A, "PATCH", f"users/{A['uid']}/following/{B['uid']}", {"fields": {}}))
    check("B plants a follow edge under A", False,
          fs_call(B, "PATCH", f"users/{A['uid']}/following/{C['uid']}", {"fields": {}}))
    check("A blocks B", True,
          fs_call(A, "PATCH", f"users/{A['uid']}/blocked/{B['uid']}",
                  {"fields": {"name": s("Rules B")}}))
    check("B reads A's block list", False,
          fs_call(B, "GET", f"users/{A['uid']}/blocked/{B['uid']}"))

    print("\n— Referral receipts (referred user writes, recruiter reads) —")
    ts = {"timestampValue": "2026-07-27T12:00:00Z"}
    check("B writes own receipt into A's ledger", True,
          fs_call(B, "PATCH", f"users/{A['uid']}/referrals/{B['uid']}",
                  {"fields": {"createdAt": ts}}))
    check("B re-mints (updates) the same receipt", False,
          fs_call(B, "PATCH", f"users/{A['uid']}/referrals/{B['uid']}",
                  {"fields": {"createdAt": ts}}))
    check("C mints a receipt under a uid that isn't theirs", False,
          fs_call(C, "PATCH", f"users/{A['uid']}/referrals/forged-{RUN_ID}",
                  {"fields": {"createdAt": ts}}))
    check("A self-refers into own ledger", False,
          fs_call(A, "PATCH", f"users/{A['uid']}/referrals/{A['uid']}",
                  {"fields": {"createdAt": ts}}))
    check("C sneaks an extra key into a receipt", False,
          fs_call(C, "PATCH", f"users/{B['uid']}/referrals/{C['uid']}",
                  {"fields": {"createdAt": ts, "sneak": s("x")}}))
    check("A reads own referral ledger", True,
          fs_call(A, "GET", f"users/{A['uid']}/referrals/{B['uid']}"))
    check("C reads A's referral ledger", False,
          fs_call(C, "GET", f"users/{A['uid']}/referrals/{B['uid']}"))
    check("B deletes own receipt (account erasure)", True,
          fs_call(B, "DELETE", f"users/{A['uid']}/referrals/{B['uid']}"))

    print("\n— Telemetry (first-party, own-uid) —")
    check("A records own telemetry event", True,
          fs_call(A, "PATCH", f"telemetry/t-{RUN_ID}",
                  {"fields": {"uid": s(A["uid"]), "name": s("day_active"),
                              "day": s("2026-07-27")}}))
    check("B forges telemetry AS A", False,
          fs_call(B, "PATCH", f"telemetry/t-{RUN_ID}-f",
                  {"fields": {"uid": s(A["uid"]), "name": s("day_active"),
                              "day": s("2026-07-27")}}))
    check("B reads A's telemetry event", False,
          fs_call(B, "GET", f"telemetry/t-{RUN_ID}"))
    check("A deletes own telemetry (the policy promise)", True,
          fs_call(A, "DELETE", f"telemetry/t-{RUN_ID}"))

    print("\n— Reports (write-only) —")
    check("B files a valid report", True,
          fs_call(B, "PATCH", f"reports/r-{RUN_ID}",
                  {"fields": {"reporterUid": s(B["uid"]), "kind": s("post"),
                              "targetId": s(post_id), "targetUid": s(A["uid"]),
                              "reason": s("Spam"), "excerpt": s("live rules test"),
                              "status": s("open")}}))
    check("B files a report pre-marked resolved", False,
          fs_call(B, "PATCH", f"reports/r-{RUN_ID}-2",
                  {"fields": {"reporterUid": s(B["uid"]), "kind": s("post"),
                              "targetId": s(post_id), "targetUid": s(A["uid"]),
                              "reason": s("Spam"), "excerpt": s("x"),
                              "status": s("resolved")}}))
    check("B reads back their own report", False, fs_call(B, "GET", f"reports/r-{RUN_ID}"))

    print("\n— coachShare (consent IS the doc) —")
    check("A shares progress naming coach C", True,
          fs_call(A, "PATCH", f"users/{A['uid']}/coachShare/summary",
                  {"fields": {"coachUid": s(C["uid"]), "json": s("{}")}}))
    check("C (the named coach) reads it", True,
          fs_call(C, "GET", f"users/{A['uid']}/coachShare/summary"))
    check("B (a stranger) reads it", False,
          fs_call(B, "GET", f"users/{A['uid']}/coachShare/summary"))
    check("C writes into A's coachShare", False,
          fs_call(C, "PATCH", f"users/{A['uid']}/coachShare/summary",
                  {"fields": {"coachUid": s(C["uid"]), "json": s("tampered")}}))
    check("A revokes (deletes the doc)", True,
          fs_call(A, "DELETE", f"users/{A['uid']}/coachShare/summary"))
    check("C reads after revocation", False,
          fs_call(C, "GET", f"users/{A['uid']}/coachShare/summary"))

    print("\n— Account deletion path —")
    check("B deletes A's post", False, fs_call(B, "DELETE", f"posts/{post_id}"))
    check("A deletes their own post", True, fs_call(A, "DELETE", f"posts/{post_id}"))
    check("B deletes A's root user doc", False, fs_call(B, "DELETE", f"users/{A['uid']}"))
    check("A deletes their own root user doc (5.1.1(v))", True,
          fs_call(A, "DELETE", f"users/{A['uid']}"))

finally:
    # Best-effort but CHECKED teardown — runs even when a check or a network
    # call blew up mid-run, so production never keeps throwaway artifacts.
    # The post + comment are re-deleted here on purpose: if the delete CHECKS
    # failed (the exact case where a rules regression exists), this is what
    # removes the test post from the global feed collection.
    print("\nCleaning up throwaway data + accounts…")
    leftovers = []
    for user, path in [
        (B, f"posts/{post_id}/comments/c-{RUN_ID}"),
        (B, f"posts/{post_id}/reactions/{B['uid']}"),
        (A, f"posts/{post_id}"),
        (A, f"posts/{post_id}-a"),
        (A, f"telemetry/t-{RUN_ID}"),
        (A, f"users/{A['uid']}/state/profile"),
        (A, f"users/{A['uid']}/following/{B['uid']}"),
        (A, f"users/{A['uid']}/blocked/{B['uid']}"),
        (A, f"users/{A['uid']}/coachShare/summary"),
        (A, f"usernames/{username}"),
        (A, f"users/{A['uid']}"),
    ]:
        status = fs_call(user, "DELETE", path)
        # 2xx = deleted; 403/404 on an already-deleted doc is fine too.
        if status >= 500:
            leftovers.append((path, status))
    for user in created_users:
        response = requests.post(f"{AUTH}/accounts:delete?key={API_KEY}",
                                 json={"idToken": user["token"]}, timeout=30)
        if not response.ok:
            leftovers.append((f"auth:{user['email']}", response.status_code))
    if leftovers:
        print("  WARNING — could not remove:")
        for path, status in leftovers:
            print(f"    {path} ({status})")
    else:
        print("  all throwaway docs + users removed; the report doc stays")
        print("  (write-only by design — resolve via Tools/review_reports.py).")

failures = [r for r in results if not r[3]]
print(f"\n{'=' * 52}\n{len(results)} checks, {len(results) - len(failures)} passed, "
      f"{len(failures)} failed.")
if failures:
    for name, want, got, _ in failures:
        print(f"  FAILED: {name} (wanted {'ALLOW' if want else 'DENY'}, "
              f"got {'allowed' if got else 'denied'})")
    sys.exit(1)
print("LIVE RULES VERIFIED — every allow works, every deny holds.")
