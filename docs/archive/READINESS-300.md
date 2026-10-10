# Readiness: 300 users in 1 month (2026-07-29)

Two audits (AI features, backend scale) distilled into one execution
plan. Verdict up front: **two hard gates are Lucas's, everything else
is code and already sequenced.**

## Gate 0 — Lucas's unlocks (nothing reaches 300 users without these)

1. **$99 Apple Developer Program.** The free team's 7-day provisioning
   means every install dies weekly and re-signs over a cable. With the
   paid program: TestFlight external testing covers 10,000 testers
   after one Beta App Review — 300 fits comfortably.
2. **Firebase Blaze upgrade + budget alert.** The Spark plan's 50k
   reads/day is project-wide. Today's client costs ~174 reads per cold
   launch (~580/day for an active user): the quota saturates at
   **~85–290 users** — under the target even with minimal usage — and
   when it trips, feed/threads/board go down for EVERYONE until
   midnight PT. Blaze turns an outage into a small metered bill; a
   budget alert caps surprise. (App Check comes with this: without it
   one hostile client can drain the whole project's quota.)

## Tier R — read-quota diet (code, biggest levers first)

Current per-feed-load cost ~165 reads; these cut per-user daily reads
by 60–75% and are worth it even on Blaze (cost + latency):

- **R1 Staleness-gated feed refresh.** refreshFeed fires on cold
  launch AND tab .task AND pull — three full loads for one session.
  Load once, refetch only on pull or after a staleness window.
- **R2 Reaction-count N+1.** One count() aggregation per post per
  load (50/load). Fetch counts lazily for visible posts + session
  cache.
- **R3 My-reactions N+1.** One getDocument per post (50/load) →
  single per-user reactions map fetched once.
- **R4 Feed pagination.** fetchRecent(50) → 15–20 with a cursor;
  every post-keyed call scales down with it.
- **R5 pushLogs debounce.** Full history re-uploads on every log
  mutation, and restore triggers an immediate echo push. Debounce
  like the profile push; suppress during restore.
- **R6 Extras push debounce** (each push = 1 read + 1 write today).
- **R7 Message listener limit** (currently unbounded history
  re-delivery per change).
- **R8 Leaderboard staleness window** (50 reads per Progress visit).
- **R9 Launch fetch gating** (verification/appointments re-checked
  every cold launch; daily is enough).

## Tier AI — the assistant, honest and useful

The "Morphe AI" agent is a local keyword matcher (no LLM ships; the
only real Claude call is DEBUG-gated in Form Check). Plan:

- **AI-1 (honesty, first).** Coach "AI photo parse" fabricates logs
  from templates and stamps them "Morphe AI parsed a workout photo" —
  a direct house-rule violation. Remove the surface (coach manual
  entry already exists); strip the AI-review dashboard states and
  "Morphe AI" provenance counts built on it.
- **AI-2 One brain.** Delete the dead second pipeline
  (sendClientPrompt → inert inbox thread); the pill/cover action
  layer is the only entry point.
- **AI-3 The commands users actually expect:** log a set by text
  ("log 3x10 at 135"), start a NAMED workout, "what's next",
  rest-timer control. All local, all real actions.
- **AI-4 Discoverability:** quick-command chips inside the cover
  (capabilities shouldn't hide behind typing "help").
- **AI-5 Matching quality:** word-boundary matching + last-intent
  context so follow-ups resolve; kill the mis-fires ("learn proper
  form" → Lessons nav).
- **AI-6 Truthful narratives:** trend claims gated on the actual
  delta; insights derived from the user's real logs instead of 8
  rotating hardcoded tips.
- **AI-7 Coach parity:** wire real coach actions or stop advertising
  them in quick prompts.
- **Branding note:** keep "Morphe AI" naming honest — it's an
  assistant, not a model; when a backend LLM lands (post-Blaze,
  server-proxied), this surface is the socket it plugs into.

## Payload & abuse (watch list)

- state/logs is ONE doc holding full history (~1–2 KB/session, 1 MiB
  hard cap ≈ 500–1,000 sessions) and the push is fire-and-forget —
  add failure surfacing + chunking before heavy users hit it.
- Profile photo rides base64 in the profile doc; move to Storage
  post-Blaze.
- selfieJPEG and managedClients.logsJSON have no server-side size cap.
- No rate caps on posts/comments/reports (Spark has no Functions);
  App Check + Blaze-side controls are the real fix.

## Sequencing

Week 1: Gate 0 (Lucas) + R1–R4 + AI-1/AI-2 (me).
Week 2: R5–R9 + AI-3/AI-4/AI-5 (me); TestFlight external review out.
Week 3: AI-6/AI-7, App Check, payload hardening; invite waves begin.
Week 4: buffer — metrics_report.py watch, moderation SLAs, fixes.
