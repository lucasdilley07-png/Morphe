#!/usr/bin/env python3
"""Morphe Creator Coach review — local admin page.

Run:  python3 Tools/review_coach_applications.py

Lists Creator Coach applications filed on the website (coachApplications),
pending first, with Approve / Decline / Revoke. Approve sets
users/{uid}.creator = true (the server-granted role the app trusts) and
marks the application approved; Decline marks it declined (the person can
resubmit); Revoke takes the role away from an approved creator. Their
published content stays until they or you remove it (see Firestore).

Needs the Firebase service-account key at BACKEND/serviceAccount.json
(gitignored). It stays on this Mac, never in git, never in the app.
"""
import json
import sys
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KEY_PATH = REPO / "BACKEND" / "serviceAccount.json"
PORT = 8789

if not KEY_PATH.exists():
    sys.exit(
        f"\nService-account key not found at {KEY_PATH}\n\n"
        "Get it: Firebase console -> (gear) Project settings -> Service accounts\n"
        "-> Generate new private key -> save the downloaded file as:\n"
        f"   {KEY_PATH}\n"
    )

import google.auth.transport.requests  # noqa: E402
import requests  # noqa: E402
from google.oauth2 import service_account  # noqa: E402

credentials = service_account.Credentials.from_service_account_file(
    str(KEY_PATH), scopes=["https://www.googleapis.com/auth/datastore"]
)
PROJECT = json.loads(KEY_PATH.read_text())["project_id"]
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
FIELDS = ["name", "username", "email", "specialty", "credentials", "experience", "links", "plan", "status"]


def token() -> str:
    if not credentials.valid:
        credentials.refresh(google.auth.transport.requests.Request())
    return credentials.token


def fs(method: str, path: str, payload=None, params=""):
    response = requests.request(
        method, f"{FS}{path}{params}", json=payload,
        headers={"Authorization": f"Bearer {token()}"}, timeout=30,
    )
    response.raise_for_status()
    return response.json() if response.text else {}


def applications():
    query = {"structuredQuery": {"from": [{"collectionId": "coachApplications"}]}}
    rows = fs("POST", ":runQuery", query)
    out = []
    for row in rows:
        doc = row.get("document")
        if not doc:
            continue
        fields = doc.get("fields", {})
        uid = doc["name"].rsplit("/", 1)[-1]
        item = {k: fields.get(k, {}).get("stringValue", "") for k in FIELDS}
        item["uid"] = uid
        item["createdAt"] = fields.get("createdAt", {}).get("timestampValue", "")
        item["updatedAt"] = fields.get("updatedAt", {}).get("timestampValue", "")
        # The role as the server holds it right now — the application's
        # status can lag a manual console change.
        try:
            user = fs("GET", f"/users/{uid}", params="?mask.fieldPaths=creator&mask.fieldPaths=verified")
            item["creator"] = user.get("fields", {}).get("creator", {}).get("booleanValue", False)
            item["verified"] = user.get("fields", {}).get("verified", {}).get("booleanValue", False)
        except requests.HTTPError:
            item["creator"] = False
            item["verified"] = False
        out.append(item)
    order = {"pending": 0, "declined": 1, "approved": 2}
    out.sort(key=lambda a: (order.get(a["status"], 3), a["createdAt"]))
    return out


def decide(uid: str, action: str):
    if action == "approve":
        fs("PATCH", f"/users/{uid}", {"fields": {"creator": {"booleanValue": True}}},
           "?updateMask.fieldPaths=creator")
        status = "approved"
    elif action == "revoke":
        fs("PATCH", f"/users/{uid}", {"fields": {"creator": {"booleanValue": False}}},
           "?updateMask.fieldPaths=creator")
        status = "declined"
    else:
        status = "declined"
    fs("PATCH", f"/coachApplications/{uid}", {"fields": {"status": {"stringValue": status}}},
       "?updateMask.fieldPaths=status")


PAGE = """<!doctype html><meta charset="utf-8">
<title>Morphe — Creator Coach Review</title>
<style>
body { background:#121214; color:#F2F3F7; font: 15px/1.5 -apple-system, sans-serif; margin:0; padding:32px 24px; }
h1 { font-size:22px; margin:0 0 4px; } .sub { color:#9BA1A8; margin:0 0 24px; }
.list { display:grid; gap:16px; max-width:900px; }
.card { background:#1A1A1C; border:1px solid #2C3036; border-radius:12px; padding:16px 18px; }
.card b { font-size:17px; } .u { color:#7AA2FF; font-size:13px; } .d { color:#9BA1A8; font-size:12px; }
.tag { display:inline-block; font: 600 11px/1 -apple-system, sans-serif; letter-spacing:.12em; padding:5px 8px; border-radius:6px; margin-left:8px; vertical-align:middle; }
.pending { background:#3A3A1F; color:#F2D06B; } .approved { background:#1F3A2A; color:#7CE0A3; } .declined { background:#3A1F1F; color:#F0908E; }
dl { display:grid; grid-template-columns: 140px 1fr; gap:6px 12px; margin:12px 0 0; }
dt { color:#9BA1A8; font-size:12px; letter-spacing:.08em; text-transform:uppercase; } dd { margin:0; white-space:pre-wrap; }
.row { display:flex; gap:8px; margin-top:14px; }
button { border:0; border-radius:8px; padding:10px 16px; font-weight:600; font-size:14px; cursor:pointer; }
.ok { background:#2957D9; color:#fff; } .no { background:#33373D; color:#F2F3F7; } .rv { background:#5A2323; color:#fff; }
.empty { color:#9BA1A8; padding:48px 0; text-align:center; }
</style>
<h1>Creator Coach Review</h1>
<p class="sub">Approve grants the server-side creator role. Decline lets the person resubmit. Revoke takes the role back. Local to this Mac.</p>
<div class="list" id="list"></div>
<div class="empty" id="empty" hidden>No applications.</div>
<script>
function esc(s) { return String(s || '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])); }
async function load() {
  const apps = await (await fetch('/api/applications')).json();
  const list = document.getElementById('list');
  list.innerHTML = '';
  document.getElementById('empty').hidden = apps.length > 0;
  for (const a of apps) {
    const card = document.createElement('div'); card.className = 'card';
    const role = a.creator ? ' · creator role ON' : '';
    card.innerHTML = `
      <b>${esc(a.name) || '(no name)'}</b><span class="tag ${esc(a.status)}">${esc(a.status).toUpperCase()}</span>
      <div class="u">@${esc(a.username) || '—'} · ${esc(a.email)}${a.verified ? ' · verified' : ''}${role}</div>
      <div class="d">applied ${esc(a.createdAt).slice(0, 10)}${a.updatedAt ? ' · updated ' + esc(a.updatedAt).slice(0, 10) : ''} · uid ${esc(a.uid)}</div>
      <dl>
        <dt>Coaches</dt><dd>${esc(a.specialty)}</dd>
        <dt>Credentials</dt><dd>${esc(a.credentials)}</dd>
        <dt>Experience</dt><dd>${esc(a.experience)}</dd>
        <dt>Links</dt><dd>${esc(a.links)}</dd>
        <dt>Would publish</dt><dd>${esc(a.plan)}</dd>
      </dl>
      <div class="row">
        ${a.creator ? '<button class="rv">Revoke role</button>' : '<button class="ok">Approve</button>'}
        ${a.status === 'pending' ? '<button class="no">Decline</button>' : ''}
      </div>`;
    const ok = card.querySelector('.ok'); if (ok) ok.onclick = () => act(a.uid, 'approve');
    const no = card.querySelector('.no'); if (no) no.onclick = () => act(a.uid, 'decline');
    const rv = card.querySelector('.rv'); if (rv) rv.onclick = () => { if (confirm('Take the creator role away from ' + a.name + '?')) act(a.uid, 'revoke'); };
    list.appendChild(card);
  }
}
async function act(uid, action) {
  await fetch('/api/decide', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ uid, action }) });
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
        if self.path == "/api/applications":
            self._send(json.dumps(applications()).encode(), "application/json")
        else:
            self._send(PAGE.encode())

    def do_POST(self):
        if self.path != "/api/decide":
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length))
        if body.get("action") not in ("approve", "decline", "revoke"):
            self.send_response(400)
            self.end_headers()
            return
        decide(body["uid"], body["action"])
        self._send(b"{}", "application/json")


if __name__ == "__main__":
    print(f"Morphe Creator Coach review -> http://localhost:{PORT}  (Ctrl+C to stop)")
    webbrowser.open(f"http://localhost:{PORT}")
    HTTPServer(("localhost", PORT), Handler).serve_forever()
