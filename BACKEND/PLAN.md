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
3. **Coach ↔ client.** Coaches invite clients (code/email); on accept, a connection doc links
   them. Coach can read the client's logs/progress, assign workouts, and message — the real
   coach workspace.
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
