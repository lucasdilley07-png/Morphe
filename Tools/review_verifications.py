#!/usr/bin/env python3
"""Morphe verification review — local admin page.

Run:  python3 Tools/review_verifications.py

Lists pending verification requests with each selfie rendered as a photo,
and Approve / Decline buttons. Approve sets users/{uid}.verified = true
(the server-granted badge the app trusts) and marks the request approved.

Needs the Firebase service-account key at BACKEND/serviceAccount.json
(gitignored): Firebase console -> Project settings -> Service accounts ->
Generate new private key. The key is a project master credential — it
stays on this Mac, never in git, never in the app.
"""
import base64
import json
import sys
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KEY_PATH = REPO / "BACKEND" / "serviceAccount.json"
PORT = 8787

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


def pending_requests():
    query = {
        "structuredQuery": {
            "from": [{"collectionId": "verificationRequests"}],
            "where": {
                "fieldFilter": {
                    "field": {"fieldPath": "status"},
                    "op": "EQUAL",
                    "value": {"stringValue": "pending"},
                }
            },
        }
    }
    rows = fs("POST", ":runQuery", query)
    out = []
    for row in rows:
        doc = row.get("document")
        if not doc:
            continue
        fields = doc.get("fields", {})

        def s(key):
            return fields.get(key, {}).get("stringValue", "")

        out.append(
            {
                "uid": doc["name"].rsplit("/", 1)[-1],
                "name": s("name"),
                "username": s("username"),
                "role": s("role"),
                "note": s("note"),
                "selfie": s("selfieJPEG"),
                "createdAt": fields.get("createdAt", {}).get("timestampValue", ""),
            }
        )
    return out


def decide(uid: str, approve: bool):
    if approve:
        # The grant the whole feature hinges on: server-side verified=true.
        fs(
            "PATCH",
            f"/users/{uid}",
            {"fields": {"verified": {"booleanValue": True}}},
            "?updateMask.fieldPaths=verified",
        )
    fs(
        "PATCH",
        f"/verificationRequests/{uid}",
        {"fields": {"status": {"stringValue": "approved" if approve else "declined"}}},
        "?updateMask.fieldPaths=status",
    )


PAGE = """<!doctype html><meta charset="utf-8">
<title>Morphe — Verification Review</title>
<style>
body { background:#141519; color:#E9E7E2; font: 15px/1.5 -apple-system, sans-serif;
       margin:0; padding:32px 24px; }
h1 { font-size:22px; margin:0 0 4px; } .sub { color:#9BA1A8; margin:0 0 24px; }
.grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(260px,1fr)); gap:16px; }
.card { background:#1E2126; border:1px solid #2C3036; border-radius:12px; overflow:hidden; }
.card img { width:100%; aspect-ratio:1; object-fit:cover; display:block; background:#000; }
.meta { padding:12px 14px; } .meta b { font-size:16px; }
.meta .u { color:#F0C22E; font-size:13px; } .meta .d { color:#9BA1A8; font-size:12px; }
.row { display:flex; gap:8px; padding:0 14px 14px; }
button { flex:1; border:0; border-radius:8px; padding:10px 0; font-weight:600;
         font-size:14px; cursor:pointer; }
.ok { background:#2F6FE4; color:#fff; } .no { background:#33373D; color:#E9E7E2; }
.empty { color:#9BA1A8; padding:48px 0; text-align:center; }
</style>
<h1>Verification Review</h1>
<p class="sub">Approve grants the server-side blue check. This page is local to your Mac.</p>
<div class="grid" id="grid"></div>
<div class="empty" id="empty" hidden>No pending requests. &#127881;</div>
<script>
async function load() {
  const requests = await (await fetch('/api/pending')).json();
  const grid = document.getElementById('grid');
  grid.innerHTML = '';
  document.getElementById('empty').hidden = requests.length > 0;
  for (const r of requests) {
    const card = document.createElement('div'); card.className = 'card';
    card.innerHTML = `
      <img src="data:image/jpeg;base64,${r.selfie}" alt="selfie">
      <div class="meta"><b>${r.name || '(no name)'}</b>
        <div class="u">@${r.username || '—'} · ${r.role}</div>
        <div class="d">${r.createdAt.slice(0, 10)}${r.note ? ' · ' + r.note : ''}</div></div>
      <div class="row">
        <button class="ok">Approve</button>
        <button class="no">Decline</button>
      </div>`;
    card.querySelector('.ok').onclick = () => act(r.uid, true);
    card.querySelector('.no').onclick = () => act(r.uid, false);
    grid.appendChild(card);
  }
}
async function act(uid, approve) {
  await fetch('/api/decide', { method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({ uid, approve }) });
  load();
}
load();
</script>"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, body: bytes, content_type="text/html"):
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/api/pending":
            self._send(json.dumps(pending_requests()).encode(), "application/json")
        else:
            self._send(PAGE.encode())

    def do_POST(self):
        if self.path != "/api/decide":
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length))
        decide(body["uid"], bool(body["approve"]))
        self._send(b"{}", "application/json")


if __name__ == "__main__":
    print(f"Morphe verification review -> http://localhost:{PORT}  (Ctrl+C to stop)")
    webbrowser.open(f"http://localhost:{PORT}")
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
