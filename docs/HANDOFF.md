# Morphe — Project Handoff

One-file briefing for a fresh session. **Refreshed 2026-10-10** (commit
8b06450): 391 automated tests green, Firestore ruleset verified live
(99/99 behavioral checks), Release build clean, latest build installed on
Lucas's iPhone. Older dated audits are in `docs/archive/`.

## What Morphe is

iOS training app (SwiftUI, iOS 17+, Liquid Glass on iOS 26; Firebase Auth +
Firestore; Claude with the user's own key). A workout tracker + an honest
social layer, with a Spartan guardian AI. One account role ships (athlete);
coaching is a by-application **Creator Coach** role granted by the admin
tool. House rules: **real scores only · nothing invented · humans only ·
safety stays free · no ads, no trackers.**

The user: beginners are the ICP; experts take the coach role.

## Feature inventory (built, tested, on device)

**Today**: day's workout hero, readiness check-in, streak + freeze,
welcome pop-up (narrated, star sound on answers, once an hour max, always
on Today, idle → Away mode), minimum-win mode, comeback moment, Hey Morphe.

**Train**: live tracker (RPE, plate calculator, supersets, Circuit Mode,
rest timer in the Dynamic Island, voice set logging), beginner console
(hold timer, "Add load", progression chips), Form Check (on-device pose,
13 patterns, holds, body calibration), Train Together parties, **Build
Workout** card (own builder · Morphe AI questionnaire → Claude builds from
the library name list, rules build without a key · multi-week programs
via the plan builder + Morphe's ready programs), My Library (saved only),
layout editor for the cards (`TrainCardID`, builder slots above library).

**Discover**: Workouts (319 catalog workouts, 595 exercises, 17 styles,
filters, detail) · Feed (Creator Coach posts, LinkedIn-style, search +
filters). Tabs are the header; equal columns.

**Network**: Chats (inbox search, **New message** picker, direct threads,
immutable messages), Board (weekly leaderboard, opt-in), Calendar
(appointments). Header: Search (empty until submitted, then
accounts/workouts/exercises), **Quick Add** (people: incoming requests,
Creator Coaches, everyone the directory/feed/creator content can name;
search; My Code / Scan; connect · hide), account pages with the shared
**Connect · Message · Invite to train · Follow** bar (also on feed author
pages), block/report.

**Learn**: Library (Exercise Library slide-up; Saved posts / workouts /
exercises / diet plans / lessons pages; bookmarks on exercises and
lessons), Nutrition (food check: barcode → Open Food Facts, photo → Claude
+ web search with key; fuel log with USDA SR Legacy + Open Food Facts
search and camera; The chart (lean out 13×BW 40/30/30, maintain 15×
45/30/25, bulk 16× 50/25/25, protein floor 0.85 g/lb) with Save this
plan; nutrition basics), Lessons (daily quote pop-up, 20 quizzes ten at a
time, lessons + Why Morphe drop-downs, personal rules).

**Progress**: score, streaks, PRs, trends, Progress Library (photos,
on-device only), challenges.

**Profile**: identity + photo, verification (live selfie → human review in
`Tools/review_verifications.py`), level card with rank (Rookie 1 · Cadet 5
· Private 10 · Corporal 15 · Sergeant 20 · Lieutenant 26 · Captain 32 ·
Major 40 · Colonel 50 · General 60; one accent per rank, Morphe Dark Blue
starter, Platinum chrome at Colonel, metallic gold at General; Custom
retired), Replay the guide, Your Details (age, experience, weight → goal,
goals, diet, styles, equipment, weakness — all read by the AI), Your
Milestones, settings (Your account first; Make it yours holds persona,
sound pack, communication style, Hey Morphe + headphones; accent picker;
notifications; privacy; Health; data export/delete; terms v2).

**Morphe AI**: chat (streaming) and voice; system prompt carries real
numbers (readiness, streak, score, level/rank, fuel) + profile details +
nutrition chart + 14 days of food memory; lore guardrail (verbatim Loeb
sayings only); offline brain answers rank/sayings/nutrition without a key.
The orb (glass, waves, rim light) and launch field take the rank's color;
the helmet never changes.

**Human-only policy (2026-10-10)**: Terms v2 (re-gate), on-phone text
screens (spam shapes, link caps, repetition, shouting, AI tells),
per-account pacer, server-side pace stamps in the rules (posts 45 s,
comments 8 s, messages 1 s, connect requests 10 s), composer pledge + paste
notice, report reasons "Spam or bot" / "AI-generated content", App Check
wired (dormant until the paid program).

## Architecture notes

- `MorpheAppStore` (Morphe/Core/MorpheStore.swift, ~19k lines) is the one
  store; views are thin. New code goes into existing files (pbxproj is
  edited by hand for new files/resources).
- Persistence: `LocalProfileSnapshot` (tolerant decode, every field
  defaulted) + per-profile UserDefaults "extras" (series, saved things,
  hidden people, known names) mirrored to the cloud (`CloudBackup.swift`).
- Services behind protocols with NoOp defaults: Auth, CloudBackup,
  FeedSyncing (posts, comments, follows, saves, reports, blocks, connect
  requests), Messaging, Party, ManagedClient, UsernameDirectory, Creator,
  Appointment, Verification. Protocol extensions provide defaults so test
  stubs don't break when a method is added.
- Theme: `MorpheTheme` (accent from the rank palette; `accentText` /
  `accentOnInk` / `onFill` for contrast; `swatchStyle` for metallics).
- Content is data: `Morphe/Resources/MorpheCatalog.json`,
  `FoodLibrary.json`, `Content/DiscoverLibrary/*.json`.

## Backend (see BACKEND/PLAN.md)

Firebase project `morphe-3c5c2`, Spark plan. Rules in
`BACKEND/firestore.rules`; publish with `Tools/publish_rules.py`, prove
with `Tools/verify_rules_live.py`. Admin pages: `review_verifications.py`,
`review_reports.py`, `review_coach_applications.py` (service-account key
gitignored).

## Repo + environment facts

- The Desktop `MORPHE` folder was evicted by iCloud on 2026-10-10 (dataless
  `.git`); the repo now lives in `~/Developer/MORPHE` and
  `~/Desktop/MORPHE` is a symlink to it. Keep repos out of iCloud.
- GitHub push needs Lucas's sign-in (keychain login gone); commits pile up
  locally until then.
- Machine is slow: ~10 min device builds; run them in the background.

## Open items (honest list)

- **Needs Lucas**: $99 Apple Developer Program (TestFlight, App Attest
  entitlement + App Check enforcement, push); GitHub sign-in; business
  items in `AppStore/LAUNCH_CHECKLIST.md` (LLC, trademark, domain, store).
- **Unverified on hardware**: the Claude paths (food check photo, Morphe
  AI workout builder) need Lucas's key on the phone; Form Check thresholds;
  Hey Morphe over a Bluetooth headset.
- **Not built**: a public profile document (Quick Add can only show what
  someone published — a member with no posts is "@handle"); video posts
  (no storage); push notifications; Spanish; form diagrams for every
  exercise; a strike ledger behind "warned, limited or closed".
- **Design calls parked**: a profile wearing Custom or pre-launch Gold
  keeps it (grandfather rule); the system splash is solid brand blue, so
  non-blue ranks see a color hand-off at launch.
