#!/usr/bin/env python3
"""Morphe abuse-report review — local admin page.

Run:  python3 Tools/review_reports.py

Lists open reports (reports/ collection) with the reported excerpt, reason,
and reporter. Buttons per report:
  Resolve          - mark reviewed, content stays (report was unfounded)
  Delete + Resolve - delete the reported post/comment, then mark resolved

Same credential model as review_verifications.py: needs the Firebase
service-account key at BACKEND/serviceAccount.json (gitignored). The key is
a project master credential - it stays on this Mac, never in git, never in
the app.
"""
import html
import json
import sys
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

REPO = Path(__file__).resolve().parent.parent
KEY_PATH = REPO / "BACKEND" / "serviceAccount.json"
PORT = 8788

if not KEY_PATH.exists():
    sys.exit(
        f"\nService-account key not found at {KEY_PATH}\n\n"
        "Get it: Firebase console -> (gear) Project settings -> Service accounts\n"
        "-> Generate new private key -> save the downloaded file as:\n"
        f"   {KEY_PATH}\n\n"
        "It's gitignored; it never leaves this Mac.\n"
    )

import google.auth.transport.requests  # noqa: E402
import requests  # noqa: E402
from google.oauth2 import service_account  # noqa: E402

credentials = service_account.Credentials.from_service_account_file(
    str(KEY_PATH), scopes=["https://www.googleapis.com/auth/datastore"]
)
PROJECT = json.loads(KEY_PATH.read_text())["project_id"]
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"


def token() -> str:
    if not credentials.valid:
        credentials.refresh(google.auth.transport.requests.Request())
    return credentials.token


def fs(method: str, path: str, payload=None, params=""):
    response = requests.request(
        method,
        f"{FS}{path}{params}",
        json=payload,
        headers={"Authorization": f"Bearer {token()}"},
        timeout=30,
    )
    response.raise_for_status()
    return response.json() if response.text else {}


def field(doc: dict, name: str, default: str = "") -> str:
    value = doc.get("fields", {}).get(name, {})
    return value.get("stringValue", default)


def open_reports() -> list:
    """All reports with status == open, newest first."""
    query = {
        "structuredQuery": {
            "from": [{"collectionId": "reports"}],
            "where": {
                "fieldFilter": {
                    "field": {"fieldPath": "status"},
                    "op": "EQUAL",
                    "value": {"stringValue": "open"},
                }
            },
            "limit": 200,
        }
    }
    rows = fs("POST", ":runQuery", query)
    docs = [row["document"] for row in rows if "document" in row]
    return sorted(docs, key=lambda d: d.get("createTime", ""), reverse=True)


def resolve(report_name: str):
    fs(
        "PATCH",
        "/" + report_name.split("/documents/")[1],
        {"fields": {"status": {"stringValue": "resolved"}}},
        params="?updateMask.fieldPaths=status",
    )


def delete_target(kind: str, target_id: str):
    """Deletes the reported content. Posts: posts/{id} (+ its subcollections
    stay orphaned but unreadable once the post is gone from the feed query).
    Comments: target_id is '{postId}/{commentId}'."""
    if kind == "post":
        fs("DELETE", f"/posts/{target_id}")
    elif kind == "comment" and "/" in target_id:
        post_id, comment_id = target_id.split("/", 1)
        fs("DELETE", f"/posts/{post_id}/comments/{comment_id}")
    # kind == "user": no automatic action - account measures are a manual
    # console decision (disable in Auth), never a one-click script.


PAGE = """<!doctype html><meta charset="utf-8"><title>Morphe reports</title>
<style>
body {{ font: 15px -apple-system, sans-serif; background: #0a0a0c; color: #eee; margin: 2rem auto; max-width: 760px; padding: 0 1rem; }}
.report {{ border: 1px solid #333; padding: 1rem; margin-bottom: 1rem; border-radius: 4px; }}
.meta {{ color: #999; font-size: 12px; margin-bottom: .5rem; }}
.excerpt {{ background: #17171a; padding: .6rem; border-radius: 3px; white-space: pre-wrap; }}
button {{ background: #ffd600; color: #000; border: 0; padding: .5rem .9rem; border-radius: 3px; font-weight: 700; cursor: pointer; margin-right: .5rem; margin-top: .6rem; }}
button.danger {{ background: #b3261e; color: #fff; }}
h1 {{ font-size: 20px; }} .empty {{ color: #888; }}
</style>
<h1>Open reports ({count})</h1>
{rows}
"""

ROW = """<div class="report">
<div class="meta">{kind} · reason: <b>{reason}</b> · target {target} · author {author} · reporter {reporter} · {created}</div>
<div class="excerpt">{excerpt}</div>
<form method="post" style="display:inline">
<input type="hidden" name="doc" value="{doc}">
<input type="hidden" name="kind" value="{kind}">
<input type="hidden" name="target" value="{target}">
<button name="action" value="resolve">Resolve</button>
<button name="action" value="delete" class="danger">Delete + Resolve</button>
</form>
</div>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        reports = open_reports()
        rows = "".join(
            ROW.format(
                doc=html.escape(doc["name"]),
                kind=html.escape(field(doc, "kind", "?")),
                reason=html.escape(field(doc, "reason", "?")),
                target=html.escape(field(doc, "targetId", "?")),
                author=html.escape(field(doc, "targetUid", "?")[:12]),
                reporter=html.escape(field(doc, "reporterUid", "?")[:12]),
                created=html.escape(doc.get("createTime", "")[:19]),
                excerpt=html.escape(field(doc, "excerpt", "(no excerpt)")),
            )
            for doc in reports
        ) or '<p class="empty">Nothing open. Clean feed.</p>'
        body = PAGE.format(count=len(reports), rows=rows).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        form = parse_qs(self.rfile.read(length).decode())
        doc = form["doc"][0]
        action = form["action"][0]
        if action == "delete":
            delete_target(form["kind"][0], form["target"][0])
        resolve(doc)
        self.send_response(303)
        self.send_header("Location", "/")
        self.end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"Morphe report review on http://localhost:{PORT} (project {PROJECT})")
    webbrowser.open(f"http://localhost:{PORT}")
    HTTPServer(("localhost", PORT), Handler).serve_forever()
