# Creator Coach — how the account type works (2026-10-05)

A free, by-application account type. Nobody can get it from the app: the
application lives on the website, and the role is granted only by Lucas.

## The flow

1. **Apply on the website** — `docs/coach.html`. The applicant signs in with
   their existing Morphe account (email + password, straight to Firebase
   sign-in; the page's host never sees the password), fills in name,
   username, what they coach, credentials, experience, links, and what they
   would publish first. The form writes `coachApplications/{uid}` with
   `status: pending`. One application per account; a declined one can be
   edited and resent.
2. **Review** — `python3 Tools/review_coach_applications.py` opens a local
   page listing applications (pending first) with Approve / Decline / Revoke.
   Approve sets `users/{uid}.creator = true` and marks the application
   approved. Nothing in the app can set that flag (rules:
   `keepsVerifiedHonest`, same as the verified badge).
3. **In the app** — the role is mirrored on sign-in and daily
   (`refreshCreatorStatus`). An approved account sees "Creator Coach" and a
   **Creator Studio** button in Profile. A pending applicant sees one line
   saying the application was received. Everyone else sees nothing — the
   onboarding has no coach path (`isCoachFlow` is `false`).

## What a creator can publish

- **Workouts → Discover, "From Coaches"**: any of their built or saved
  workouts. Only exercises in the shared library travel (another member's
  app rebuilds the workout against its own library); custom one-offs are
  left out and the creator is told how many. Members start or save them like
  any catalog workout. Author's name on every card.
- **Notes → Learn, "From Coaches"**: title + up to 2,000 characters. Members
  can report a note; reports land in the same queue as feed reports
  (`Tools/review_reports.py`).
- **Open challenges → the board**: an ordinary challenge plus a public
  listing (`openChallenges/{code}`); members join with one tap, no code.
  Scores still come only from logged workouts.

Creators can remove their own work from Creator Studio. Revoking the role
stops new publishing; existing documents stay until removed (Firestore
console or the creator).

## Collections and rules (`BACKEND/firestore.rules`)

- `coachApplications/{uid}` — owner creates/reads/updates (status may only
  be set to `pending` by the owner); admin tool sets `approved`/`declined`.
- `users/{uid}.creator` — read by rules via `isCreator()`; never client-set.
- `creatorWorkouts/{id}`, `creatorNotes/{id}` — any signed-in member reads;
  only an approved creator creates, under their own uid, within size limits;
  the author deletes.
- `openChallenges/{code}` — listing of an existing challenge the creator
  hosts; signed-in read; author deletes.

**Rules must be published** before any of this works:
`python3 Tools/publish_rules.py` (compiles, releases, byte-verifies).

## Website key

`docs/coach.html` holds `FIREBASE_WEB_API_KEY` (added 2026-10-05 on Lucas's
call; applications are open). The key identifies the project to Google's
sign-in and database services — what a signed-in person can read or write is
decided by the published rules, not the key.
