# Morphe — Project Handoff

One-file briefing for a fresh session. Last updated 2026-07-21, at commit
`8c4a72c` ("Roadmap complete"). 179 automated tests green. App deployed to
Lucas's iPhone 17 Pro Max.

## What Morphe is

iOS fitness app (SwiftUI, iOS 17, Firebase Auth + Firestore) — a workout
tracker + fitness social hybrid. Two roles: athlete and coach. House rule
that governs every feature: **honest engineering** — no fake AI claims, no
fabricated data on real accounts, no trust signals a client can forge,
empty states name their unlock condition.

## Feature inventory (all built, tested, shipped)

**Training**: 150-workout catalog across 13 categories (incl. Pilates,
Dance & Aerobics, 6 sport packs), authored as content-as-data in
`Content/DiscoverLibrary/*.json` → merged by `Tools/build_catalog_v2.py`.
140 exercises, each with a generated form diagram (bundled HEICs +
regeneration prompts in `Content/DiscoverLibrary/FormDiagrams/prompts.json`).
Live set tracking with superset/dropset-as-one-set, Circuit Mode (guided
intervals), Form Check (on-device camera pose/rep counting), rest timer.

**Personalization** (all deterministic, real data): plans ranked by sport +
training styles + equipment + injury keywords; nutrition targets from body
weight + goal; meal-prep tips from onboarding; RPE feeds progression
suggestions; 7 coaching-tone voices; 30/60/90-day targets editable on
Profile; 7 accent palettes (gold default = brand #FFD600).

**Social/multi-user (real, Firestore-backed)**: coach-managed clients with
claim codes (history transfers on signup), coach↔claimed-client messaging
(immutable threads), For You feed (posts/reactions/saves/reposts; Network
tab), opt-in weekly leaderboards + code-joinable challenges, Train Together
parties (live buddy sessions), verification (selfie → human review →
server-granted blue check; review tool: `python3 Tools/review_verifications.py`),
usernames, per-account appointments with local reminders.

**Deliberately deferred**: stories (no Firebase Storage/moderation),
payments (`docs/PAYMENTS.md` — build gated on Stripe-fee/IAP decisions),
global-rank ladders, Sign in with Apple (button removed until wired).

## Architecture cheat sheet

- God-store: `Morphe/Core/MorpheStore.swift` (@MainActor @Observable, ~10k
  lines). Services injected via init; **new services nil-infer Firebase iff
  `partyService is FirebasePartyService`** — no MorpheApp edits needed.
- Firestore services live in `Core/CloudBackup.swift` + `Core/WorkoutParty.swift`
  (manual [String:Any], tolerant per-field decodes, fire-and-forget writes).
- Persistence: JSON snapshots in App Support; `LocalProfileSnapshot` and
  `WorkoutSessionSnapshot` MUST decode tolerantly (decodeIfPresent+defaults) —
  a synthesized decoder wipes user data on schema change.
- Adding a Swift FILE needs hand-editing project.pbxproj (prefer adding code
  to existing files). Resources/FormDiagrams is a folder reference — new
  files auto-bundle.
- 2-word max on button labels (exception: "Sign in with Apple").

## Environment gotchas (will bite you)

- **Desktop is iCloud-synced** → builds inside the repo fail CodeSign with
  "detritus". Always build with
  `-derivedDataPath "$HOME/Library/Developer/Xcode/MorpheCLI"`.
- Deploy: `xcodebuild -destination 'id=00008150-0016512A3428401C'
  -allowProvisioningUpdates build` → `xcrun devicectl device install/launch`.
  Free-team signing expires every 7 days — redeploy weekly. Team 8P47H3XRN3.
- **Firestore rules console keeps its LAST text** — every rules change needs
  `cat BACKEND/firestore.rules | pbcopy` → console select-all → paste →
  Publish, and then a live REST verification (throwaway Auth users pattern,
  see session history / verify scripts).
- Fal.ai (form diagrams): key in ~/.zshrc (LAST export wins), $0.15/image,
  card-on-file ≠ credits.
- Xcode GUI open can revert CLI pbxproj edits; parallel Claude sessions may
  edit concurrently — check mtimes before assuming corruption.

## OPEN ITEMS (the next session's first moves)

1. ⚠️ **Rules publish pending**: the five newest blocks (appointments,
   leaderboards, challenges, threads, posts) are NOT live — Lucas published
   a stale clipboard. Re-copy `BACKEND/firestore.rules` (408 lines, 22 match
   blocks), have him paste+publish, then rerun the 17-point live rules test.
   Until then those five features fail-secure.
2. Weekly redeploy clock: all three devices (Lucas's 17 Pro Max, the 16 Pro
   Max, the unnamed 17 Pro Max; Colt's needs its own team/bundle switcheroo).
3. Payments: awaiting Lucas's decisions per `docs/PAYMENTS.md`; also the $99
   Apple Developer Program (TestFlight) remains the single best unlock.
4. Post-claim managed-client removal needs store support (TODO in
   ManagedClientDetailSheet).
5. Feed/messaging/leaderboards have no moderation/blocking tools yet — needed
   before real strangers share a feed.

## Working relationship notes

Lucas: ship-fast founder, tests on his own iPhone constantly. Standard loop
per feature: build → full test suite → commit (explanatory message) → push
origin main → deploy to phone. He values honest scoping — say what's real,
what's deferred, and why.
