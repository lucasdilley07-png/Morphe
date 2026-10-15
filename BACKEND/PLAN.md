# Morphe backend — current state (Firebase)

Refreshed 2026-10-10. Firebase project **morphe-3c5c2** (Spark plan):
Auth (email/password; Sign in with Apple waits on the paid program) +
Cloud Firestore with offline persistence. No Cloud Functions, no Storage.
The app talks to Firestore directly under security rules; every honesty
guarantee that matters is enforced **in the rules**, not in the client.

## Collections (as the live rules define them)

```
users/{uid}                     private: owner + an ACTIVE linked coach
  verified / creator / coach.verified    server-granted flags (clients may carry, never mint)
  lastPostAt, lastCommentAt, lastMessageAt, lastConnectAt   human-pace stamps
  workoutLogs/{id}, customWorkouts/{id}, state/{profile|logs|weightHistory|extras}
  debriefs/{id}, savedPosts/{postId}, following/{uid}, blocked/{uid}
  referrals/{uid}  (the referred user writes their own receipt)
  coachShare/summary  (athlete-consented progress for one named coach)
usernames/{username}  { uid, claimedAt }      directory: get/list (≤50) signed-in
coachCodes/{code}                              resolve a coach code
connections/{coachUid_athleteUid}              coach↔client: pending → active/declined/revoked
connectRequests/{fromUid_toUid}  (2026-10-10)  member↔member: pending → accepted/declined/removed
parties/{code}  (+ nudges)                     Train Together
verificationRequests/{uid}                     selfie → human review
coachApplications/{uid}                        website form → review tool
creatorWorkouts/{id}, creatorNotes/{id}, openChallenges/{code}   Creator Coach content
managedClients/{code}                          coach-created clients + claim codes
leaderboards/{week}/entries/{uid}, challenges/{code}
threads/{a_b} + messages/{id}                  direct chats; messages immutable
posts/{id} + reactions/{uid} + comments/{id}   the feed; posts immutable
reports/{id}                                   write-only from clients
telemetry/{id}                                 first-party milestone events
```

## Rules principles

- **Honest flags**: `verified`, `creator`, `coach.verified` are granted only
  by the admin tools (service account); a client write may carry an
  existing `true`, never set one.
- **Human pace (2026-10-10)**: posts, comments, messages and connect
  requests are written in the same batch as a server timestamp on the
  writer's `users/{uid}`; `humanPaced(field, seconds)` requires the stamp
  to equal `request.time` and the previous one to be old enough (45 s /
  8 s / 1 s / 10 s). A client that skips the stamp is denied.
- **Owner-scoped lists**: every `list` is bounded and, where rows belong
  to people, constrained to the caller's own rows (connect requests,
  claimed docs, threads).
- **Immutable history**: messages, posts, comments, requests are never
  edited or deleted by clients (edit = delete + repost for posts; only the
  author deletes).
- **Blocks bite server-side**: a blocked sender cannot message or
  connect-request the blocker.

## Tooling

- `Tools/publish_rules.py` — compiles, releases, byte-verifies
  `BACKEND/firestore.rules` (needs `BACKEND/serviceAccount.json`,
  gitignored).
- `Tools/verify_rules_live.py` — 99 behavioral checks against production
  with throwaway accounts (allow cases prove features, deny cases prove
  strangers can't). Run after every publish. Leaves a few immutable docs
  per run by design (thread, message, request).
- `Tools/review_verifications.py`, `review_reports.py`,
  `review_coach_applications.py` — local admin pages on the service
  account.

## Gates that need Lucas

- **App Check** is wired in the app (App Attest, DeviceCheck fallback) but
  the entitlement can't be signed on a personal team → add
  `com.apple.developer.devicecheck.appattest-environment` after the $99
  enrolment, upload the DeviceCheck key in Firebase, then enforce.
- Blaze plan + $10 budget alert before launch traffic; restrict the web
  API key to the GitHub Pages referrer; email-enumeration protection on.
- Push notifications (needs the paid program) — none today; all reminders
  are local.

## Morphe AI online — the relay (2026-10-14)

`BACKEND/functions` (Cloud Functions 2nd gen, Node 22, TypeScript): one
HTTPS function `morpheAI` that lets members use Morphe AI on Morphe's own
Anthropic key. Firebase ID token in, Anthropic Messages API body in, the
same streaming events out. Enforced in the function, before Claude is
called: signed-in account, age ≥ 18 from `users/{uid}/state/profile`, 30
requests per member per day, a $45 estimated monthly budget (Anthropic's
own $50 cap on the key is the backstop). Model: Claude Sonnet 5.5, low
effort, cached system prompt, server-side refusal fallback. Counters in
`aiUsage/*` (client-denied). Opt-in ratings in `aiFeedback/*`
(create-only by the author). Deploy and prove: `BACKEND/functions/README.md`.
Needs Blaze and the `ANTHROPIC_API_KEY` secret. App Check verification is a
param (`MORPHE_AI_REQUIRE_APP_CHECK`) — flip it once the paid Apple
account lets App Check enforce.
