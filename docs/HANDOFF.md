# Morphe — Project Handoff

One-file briefing for a fresh session. Last updated 2026-07-27 end of
session: 4 engineering audits + 1 investor audit all executed, milestone
sheet shipped (first-party telemetry live, coach pilot playbook, pricing
proposals). 207 automated tests green. Deployed to Lucas's iPhone 17 Pro
Max 2026-07-27. Free-team signing expires ~2026-08-03. Rules ruleset
f862d86e live, 39/39 behavioral checks.

## What Morphe is

iOS fitness app (SwiftUI, iOS 17, Firebase Auth + Firestore) — a workout
tracker + fitness social hybrid. Two roles: athlete and coach. House rule
that governs every feature: **honest engineering** — no fake AI claims, no
fabricated data on real accounts, no trust signals a client can forge,
empty states name their unlock condition.

## Feature inventory (all built and tested)

**Training**: 150-workout catalog (13 categories, content-as-data in
`Content/DiscoverLibrary/*.json`), live set tracking with auto-starting
per-exercise rest timer (Live Activity/Dynamic Island), inline RPE chips,
plate calculator (barbell-gated), mid-session add/reorder (session-scoped,
template untouched), superset/dropset/Circuit Mode, Form Check (on-device
camera pose/reps), multi-week **programs** (3 starters, count-based
advance, deload weeks that scope to program sessions and never poison the
progression baseline).

**Intelligence (all deterministic)**: progression suggestions from RPE +
session feel, plateau ("stalled") detection, e1RM chart toggle, muscle
balance, weight-trend smoothing, recovery + nutrition daily series with
trend cards, day-7 first-week arc, PR detection celebrated at log time.

**Social (real, Firestore-backed)**: auto-share workouts to feed (opt-in,
per-session opt-out, rich stat cards), follow graph + @username search,
comments, typed reactions, weekly leaderboards + challenges surfaced in
the feed, Train Together parties, coach↔claimed-client messaging,
**coachShare** (athlete-consented live progress for the coach; consent IS
the doc), story share-card images (ImageRenderer), morphe:// referral
deep links (also routes party/connect QRs), report/block/content-filter
(App Store 1.2), server-granted verification.

**Measurement (first-party, disclosed)**: telemetry/ collection — 10
milestone events (day_active deduped, activation_first_log, shares,
referral_consumed, coach_claimed…), erased with account deletion;
`python3 Tools/metrics_report.py` = activation + D1/D7/D30 weekly
cohorts + loop counts. No third-party analytics ever (brand promise).

**Ecosystem**: HealthKit write (workouts) + read (sleep pre-fill, opt-in),
home/lock-screen widgets (App Group group.com.morpheapp.Morphe), cloud
backup (profile/logs/weightHistory with merge-on-push), JSON data export,
**in-app account deletion** (5.1.1(v)), XP-gated accent palettes,
StoreKit 2 shell (dormant behind PremiumGate.storefrontEnabled=false).

**Deliberately deferred**: stories/media (needs Storage + moderation
pipeline), food database, Apple Watch app, Cloud Functions push, server
follower counts, payments activation (`docs/PAYMENTS.md`).

## Architecture cheat sheet

- God-store: `Morphe/Core/MorpheStore.swift` (@MainActor @Observable,
  ~12k lines). Services injected via init; new services nil-infer Firebase
  iff `partyService is FirebasePartyService`.
- Firestore services: `Core/CloudBackup.swift` + `Core/WorkoutParty.swift`
  (manual [String:Any], tolerant per-field decodes, fire-and-forget).
- Per-profile UserDefaults blobs (documented exception): training prefs,
  competition, bodyWeightHistory, recovery/nutrition series, program state.
  **Gotcha:** anything persisted during onboarding BEFORE
  `resetToFreshUser()` lands under the seeded demo id and is lost — stamp
  after the mint (see the firstWeekStart fix).
- Persistence: JSON snapshots in App Support; tolerant decoders mandatory.
- Adding a Swift FILE needs hand-editing project.pbxproj (prefer adding to
  existing files). Entitlements exist: HealthKit + App Group (both
  targets).
- 2-word max on button labels.
- Tests: `MorpheTests/PersistenceTests.swift` (one big file, many suites).
  Test-ordering gotcha: `MorpheAppStore.init` flushes the PREVIOUS store's
  pending writes — absorb with a throwaway store in setUp before clearing
  files (see BookingTests).

## Environment gotchas

- Desktop is iCloud-synced → build with
  `-derivedDataPath "$HOME/Library/Developer/Xcode/MorpheCLI"`.
- Deploy: `xcodebuild -destination 'id=00008150-0016512A3428401C'
  -allowProvisioningUpdates build` → `xcrun devicectl device install/launch`.
  Free-team signing expires every 7 days. Team 8P47H3XRN3. First device
  build after 2026-07-26 registers the new HealthKit/App Group capabilities.
- **Rules publish is one command now**: `python3 Tools/publish_rules.py`
  (Rules API via the service account; compiles first, byte-verifies the
  live ruleset after). The old console copy-paste routine is retired.
- Fal.ai (form diagrams): key in ~/.zshrc, $0.15/image.

## OPEN ITEMS (next session's first moves)

1. ✅ **Rules published 2026-07-26** (ruleset 277f97a6, byte-verified) AND
   **behaviorally verified live**: `python3 Tools/verify_rules_live.py` —
   35/35 checks with throwaway auth users. Rerun after every publish.
2. ✅ **Deployed to Lucas's phone 2026-07-26** — weekly re-sign due
   ~2026-08-02. On-device to verify by hand: Health prompt (Sync to
   Health toggle), widget gallery add, share-card render, a full
   program session, account-deletion flow on a throwaway account.
3. **$99 Apple Developer Program** — gates TestFlight, IAP flag-flip, and
   Universal Links. THE remaining unlock; every clock in
   AppStore/LAUNCH_CHECKLIST.md §5 (90-day proof window) starts here.
3b. **Retake App Store screenshots** — AppStore/screenshots/ are from
   June 14, two header redesigns old. Retake after the UI settles.
3c. **Pricing sign-off** — docs/PAYMENTS.md now carries PROPOSED numbers
   (coach SaaS $39/mo/$349/yr, phase-2 take rate 10%, consumer Pro
   $5.99/$39.99; coach IAP ids scaffolded dormant). Lucas approves or
   overrides BEFORE App Store Connect setup.
3d. **Coach pilot** — docs/COACH-PILOT.md: 10-25 paying coaches in 90
   days, weekly Tools/metrics_report.py numbers, explicit kill criteria.
   This is the fundable-wedge experiment from the investor audit.
4. ✅ **docs/index.html regenerated 2026-07-26** from the new policy —
   ready to host via GitHub Pages (LAUNCH_CHECKLIST step 1).
5. Compliance is otherwise launch-ready: privacy policy rewritten
   (2026-07-26), PrivacyInfo.xcprivacy populated, App Store metadata
   corrected to declare collected data, in-app account deletion shipped,
   EULA has the zero-tolerance clause.

## Working relationship notes

Lucas: ship-fast founder, tests on his own iPhone. Standard loop per
feature: build → full test suite → commit (explanatory message) → push
origin main → deploy to phone. He values honest scoping — say what's real,
what's deferred, and why. Session history + full audit trail:
`docs/AUDIT-2026-07.md` and the memory file morphe-2026-07-audit.
