# Morphe backend — build plan (Firebase)

Decision: **Firebase** (Auth + Firestore + later Cloud Functions/Storage), chosen for
best-in-class offline support (gym wifi), fastest path to real-time coach↔client, and
least backend code for a solo developer.

## Architecture
- **Auth:** Firebase Auth — Sign in with Apple + email/password. The signed-in `uid` is
  the user's identity (replaces the on-device minted UUID).
- **Database:** Cloud Firestore, with **offline persistence ON** — writes save locally
  and sync when back online. This is how a gym app stays usable without wifi.
- **Client architecture:** a thin repository/service layer (`AuthService`, `ProfileRepository`,
  `WorkoutRepository`) sits between the store and Firestore. The on-device JSON persistence
  we built becomes the **offline cache**; Firestore is the source of truth. This is also the
  moment we split the 5.8k-line `MorpheAppStore` into async domain stores.
- **Privacy:** data now leaves the device, so the privacy policy + App Store "App Privacy"
  label MUST be rewritten before release (currently "Data Not Collected" — no longer true).

## Phases
1. **Accounts** ← we are here. Auth (Apple/email), a real cloud user doc, the on-device
   profile becomes cloud-backed, and the athlete-vs-coach choice returns at sign-up.
2. **Cloud workout data.** Logs/workouts/custom library sync per user, offline-first.
3. **Coach ↔ client.** Reusable coach codes, coach-approved link requests, full-profile
   read access for linked coaches. Designed 2026-07-06 — see the Phase 3 section below.
4. **Networking.** Real user discovery, connections/follows, an activity feed.
5. **Payments + scheduling.** Coach payments (Stripe) and appointment booking.

## Phase 1 — Firestore data model
```
users/{uid}
  role: "athlete" | "coach"
  name, displayName, username, gender
  createdAt
  athlete: { sportMode, selectedSports[], selectedGoals[], goal, fitnessLevel,
             equipment, injuries, weightUnit, currentProgram, currentPhase }   // when athlete
  coach:   { headline, bio, specialties[] }                                    // when coach

usernames/{username}  -> { uid }        // uniqueness check

// Phase 2+ (placed now so the model is coherent):
users/{uid}/workoutLogs/{logId}         // the user's own logs
users/{uid}/customWorkouts/{id}
connections/{connId}  { coachUid, clientUid, status: pending|active, createdAt }
```

## Phase 3 — Coach ↔ client design (decided 2026-07-06)

**Product decisions (Lucas):**
- **Access scope:** a linked coach sees the athlete's **full profile** — logs, streak,
  readiness, goals, injury notes, body metrics. Chosen for coaching quality; the athlete's
  consent moment is the link itself, and revoking kills access instantly.
- **Linking:** every coach gets **one reusable shareable code** (e.g. `MORPHE-4X2K9`).
  An athlete enters the code → a **pending request** is created → **the coach approves**
  (or declines) in the Athletes tab. Either side can revoke later.
- **Coach signup:** **open** — anyone can pick Coach at sign-up. The schema reserves
  `users/{uid}.coach.verified` (never client-settable to true) so credential checks or
  manual approval can be added later without a migration.

**Firestore additions:**
```
users/{uid}
  coach: { headline, bio, specialties[], code, verified: false }   // when coach

coachCodes/{code}        -> { coachUid, createdAt }    // resolve code → coach; immutable
connections/{coachUid}_{athleteUid}
  { coachUid, athleteUid, status: "pending"|"active"|"declined"|"revoked",
    createdAt, respondedAt }
```
Deterministic connection ids make the rules check (`isActiveCoachOf`) a single doc
lookup and prevent duplicate requests for the same pair.

**Client flows:**
- *Athlete:* Profile → "Link with a coach" → enter code → resolves via `coachCodes` →
  writes pending connection → sees "Request sent to <coach>" → can revoke any time from
  the same place.
- *Coach:* Athletes tab leads with pending requests (approve/decline). Approving flips
  `status: active`; the client list is a query on
  `connections where coachUid == me && status == active`, and each row hydrates from the
  athlete's now-readable user doc + logs.
- *Revoke:* either side sets `status: revoked`; the coach's read access dies with it.

**Coach v1 scope (keep the surface uncluttered):**
- Tabs: **Home (dashboard) · Athletes · Inbox** — `CoachTab.visibleCases` is trimmed to
  these three. Build (programs) and Network stay in code but hidden until coach v2;
  booking/payments remain in Phase 5.
- The existing `CoachDashboardView` runs on seeded demo data; before launch it needs the
  same honesty pass the athlete side got (real data or empty states — "Share your code
  to add your first client" — plus full HUD styling).

## Security rules (Phase 1 shape)
- A user can read/write **only their own** `users/{uid}` doc.
- `usernames/*` readable by all (for uniqueness), writable only via a transaction that
  claims an unused handle.
- (Phase 3) a coach can read a client's data only when an `active` connection exists — enforced
  in rules + Cloud Functions.

## What needs YOU (one-time, ~15 min) vs me
**You (Firebase console + Apple):**
1. Create a Firebase project, add an **iOS app** with bundle id `com.lucas.Morphe`.
2. Download **`GoogleService-Info.plist`** and hand it to me (drop it in `Morphe/`).
3. In Firebase → Authentication, enable **Apple** and **Email/Password** providers.
4. (For Sign in with Apple) in the Apple Developer portal, enable the *Sign in with Apple*
   capability for the app id — I'll add the capability in Xcode; you approve in the portal.

**Me (once I have the plist):**
- Add the Firebase SDK (Swift Package Manager), `FirebaseApp.configure()`.
- Build Sign in with Apple + email auth UI and the `AuthService`.
- Migrate the profile to the cloud user doc (with the offline cache as fallback).
- Re-introduce the athlete/coach choice at sign-up and wire the role through.
- Firestore security rules for Phase 1.

Until the plist exists I can't compile/verify Firebase code, so step 1–2 above is the gate
(same situation as TestFlight signing).
