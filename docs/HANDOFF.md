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
- GitHub push works (2026-10-12): a personal access token sits in the macOS
  keychain; when it expires, Lucas makes a new one (repo scope) and enters
  it at the HTTPS password prompt.
- Machine is slow: ~10 min device builds; run them in the background.

## Next session — start here (saved 2026-10-13, evening)

The `ef3c563` phone build is installed on Lucas's iPhone and iPhone (4).
The three queued requests are BUILT (this commit):

1. **Morphe AI button bounce** — `FloatingAIAgentButton` (RootView) hops
   once every 2–3 min at random; skipped under Reduce Motion, in the
   background, with the AI open, or mid Hey Morphe exchange.
2. **Profile → Connections** (Training group, `ConnectionsSettings` in
   ProfileView): Bluetooth heart-rate strap (`HeartRateMonitor`, now in
   MorpheServices; one instance on the store; samples reset at session
   start; avg/peak saved at finish as `lastSessionHeartRate`), live BPM
   strip at the top of the workout console, Apple Health + Apple Watch
   status rows (`WatchBridge.status`), supplement stack with a daily check
   (extras `supplements`, export, cleared on sign-out/delete), a private
   enhancements note (on-device only — NOT in extras), and **Add an app**
   (`AddAppSheet`): one Apple Health read permission brings in other apps'
   workouts (Strava, Garmin, WHOOP…) from the last 90 days as imported
   logs (`importKey "health:<uuid>"`, no XP), re-run on every foreground
   at most every 30 min; Morphe's own Health writes are skipped by bundle
   id. Bluetooth usage string in both app configs; Health read string
   updated.
3. **Morphe AI uses everything** — `profileSignalsForPrompt()` feeds both
   the chat prompt and the builder: height/weight, sports, styles,
   schedule, supplements + taken today, devices + live/last HR, top-five
   engagement. Enhancements go in only as context with a hard no-dosing
   rule. Engagement counters (`noteEngagement`): Discover categories +
   workout starts, Feed/Workouts tab, lessons, food checks; Discover's
   families and tiles sort by them. Consent sheet, PRIVACY_POLICY.md and
   docs/privacy.html list every new field.

**Gender is deliberately NOT sent**: the onboarding step was cut and
Profile has no gender editor, so `clientProfile.gender` is always the
`.male` default. Needs a Your Details row with an "answered" flag before
it can go in the prompt.

Also fixed on the way: the data export wrote extras as base64 plists
(unreadable) — they now decode to JSON; the builder's `Int(d.rounded())`
trap.

**Audit + fix wave (same evening)**: two fresh-eyes reviews of this
session's diff. Fixed: deleted Health imports no longer come back
(`healthImport.dismissed`); imports stay off boards (`competitionTotals`
skips `isImported`); Health read permission is asked per device (restored
"connected" shows "allow Health on this iPhone"); import uses the real
end time and bails if the account changes mid-query; the heart-rate
monitor rewrite (15 s scan / 12 s connect timeouts, Stop/Cancel buttons,
no auto-connect without a tap, reconnect on a dropped link, power-off
clears state, `bluetooth-central` background mode so the strap keeps
reading when the phone locks); swipe-back works from anywhere on the page
(Lucas chose this over edge-only, knowing a long drag on a chip row can
also go back); the hop loop restarts when Reduce Motion / scene phase
change; the no-dosing rule is always in both prompts; supplement text is
quoted in the prompt; trainingDays outside 1–7 can't trap; engagement
isn't counted before onboarding; the export decodes the workout library;
44pt targets, a Done button and honest copy across Connections, the
consent sheet and the policy.

**Morphe AI online (2026-10-14, Lucas: Sonnet 5.5, $50/month cap)**: the
app no longer needs a per-user key. `MorpheIntelligence.credential()` picks
a personal key first, else the relay (`BACKEND/functions`, see
BACKEND/PLAN.md) with the Firebase ID token; `relayEligibility` /
`relayTokenProvider` are wired by the store in `loadTrainingPreferences`.
Store: `onlineAIEnabled` + `aiImprovementOptIn` in the training-prefs blob
(reset on sign-out), `onlineAIBlockedReason` (signed out / no age / under
18), `rateAIAnswer` → `aiFeedback` only when opted in. Settings: "Morphe AI
online" toggle with its own consent sheet, "Help improve Morphe AI" toggle;
thumbs under answers in the chat. Form Check's dev coaching note and the
food check use the same doors; the web search tool is `web_search_20260209`.
Rules published (aiUsage denied, aiFeedback create-only). **Not deployed
yet**: the function needs Node 22 + the Firebase CLI on this Mac, Blaze,
`firebase login`, and the `ANTHROPIC_API_KEY` secret — steps in
`BACKEND/functions/README.md`. Until it is deployed, turning the toggle on
yields the honest "hit a snag" line. Decisions taken for Lucas: 18+ only,
30/day, $45 relay budget under the $50 key cap.

**Relay audit fix wave (2026-10-14)**: two reviews (server, app). Server:
each request holds its worst-case cost against the month before Claude is
called (`worstCaseMicroUSD`, settled to the real cost after), total input
capped at 150k chars, one request in flight per member, refund of the day's
slot when Anthropic fails, abort on client disconnect, 300 s timeout,
cumulative usage from `message_delta`, web searches priced, HEIC dropped,
pass-through blocks assistant-only and rebuilt without `cache_control`,
explicit cache breakpoint on the system block, `concurrency 10 /
maxInstances 2` until App Check. App: the relay door is `@MainActor`
(the `assumeIsolated` version trapped on the first real request), App Check
token sent as `X-Firebase-AppCheck` (`MorpheIntelligence.appCheckTokenProvider`,
set in MorpheApp), offline reads as a connection problem not "sign in",
door-neutral copy, age pushes to the cloud immediately, one rating per
answer, `aiFeedback` erased with the account (rules allow the author to
list their own), 44pt thumbs, policy lines that still said "your key".
413 app tests, 7 relay tests.

**AI rebuild — decisions (Lucas 2026-10-14)**: background Hey Morphe YES
(must never cut the user off mid-sentence); Foundation Models on iPhone
15 Pro+ OK; plate photos keep web search ON; memory default OFF for
health-type facts; Form Check says "estimated" and never "injury risk".
Report + 4-wave order: `docs/AI-REVERSE-ENGINEERING-2026-10-14.md`.

**Wave 0 shipped (2026-10-15)**: `audio` background mode + the app no
longer stops Hey Morphe on background when the toggle is on (mic indicator
copy in settings, usage string, policy); adaptive settle window
(`HeyMorpheEngine.settleWindow(for:)` — 1.6 s, 2.8 s when the last word is
a continuation word); a recognizer pass that ends mid-capture CONTINUES the
capture (`activeStreamEnded`) instead of firing half a sentence; barge-in
re-arms when its pass ends; the 2.5 s breath floor applies only when
nothing was said with the wake; food photo downscale at scale 1 (was 3×
the vision tokens); calories template uses null; the Morphe AI chat
persists per profile (device-only, cap 200); the system prompt is two
blocks (`intelligenceSystemBlocks` → `MorpheIntelligence.SystemPrompt`
stable/live, cache breakpoint on stable, shared by voice and chat; strap
bpm and the relative strap date moved out of the cached part); the relay
accepts system blocks and caches the first. 416 tests, 8 relay tests.
Not done from Wave 0: structured-output schema through the relay (Wave 3).
**Wave 1a shipped (2026-10-15)**: `VoiceIntentRouter` (end of
MorpheIntelligence.swift) — Apple's on-device Foundation Models (iOS 26,
iPhone 15 Pro+) reads a sentence into a `Reading` and emits the CANONICAL
door phrase ("8 at 135", "next exercise", "rest for 2 minutes"); the store
runs it only when the regex doors returned nil (`handleVoiceCommand`),
re-applies the wake-word mutation guard to the canonical, and falls to the
brain on `question`/`unplaced`. Prewarmed in `startVoiceIfEnabled`.
Headless Siri intents `SiriLogSetIntent` / `SiriStartRestIntent` /
`SiriNextExerciseIntent` (`supportedModes = .background` on iOS 26) run
`sessionVoiceReply` on the live store (`IntentStore.store`, set in
MorpheApp) and speak the door's line. API verification: Apple's
`SpeechDetector` reports NO speech start/end (results stay empty by
design), so endpointing stays Morphe's adaptive window; `SpeechTranscriber`
has no contextual-strings bias, so the wake scan stays on
SFSpeechRecognizer. Streaming TTS parked on purpose: the pipeline already renders sentence
N+1 while N plays, and true PCM streaming means re-plumbing the engine
that also runs the mic — not shippable unheard. 419 tests.

**Wave 2a shipped (2026-10-15, Form Check)**: One-Euro filter per joint
(`OneEuroFilter`/`JointFilter`, replaces the EMA); `FormViewAngle.oblique`
(shoulder/torso ratio 0.42–0.52 — knee-spread and front-lean reads are
refused there, the lock label asks for square or side-on; the hip-drop
depth estimate is used for any non-side view); `FramingState.tilted` from
CoreMotion gravity (>20° off upright → "LEVEL THE PHONE", not trackable);
re-calibration when the leg length drifts >10 % for 20 frames; 720p @ 30
fps; `resetGeneration` locked; one `recognizedPoints` per candidate; hold
stillness judged on RAW joints; honest copy ("knees drifted in on camera";
the review says front-on depth is estimated, side-on measured). NOT done:
the clip harness and threshold validation (needs Lucas's ~15 clips per
pattern), 3D pose on LiDAR phones. 422 tests.

**Wave 3 shipped (2026-10-15, Food Check)**: `LabelOCR` (end of
MorpheIntelligence.swift) reads a package on-device first
(`RecognizeDocumentsRequest` on iOS 26, `VNRecognizeTextRequest` below;
`LabelOCR.parse` pulls kcal/macros/serving by regex) and those numbers
OVERRIDE Claude's; `FoodCheckService.reportSchema` enforces the report via
structured outputs (`output_config.format`, GA) with `items`
(name, grams range, kcal range, confidence) + `caloriesLow/High` for
plates; a 400 with the search tool falls back once to the prose report;
each item is matched to the USDA library (`FoodLibrary.bestMatch`) so
numbers are cited where possible; `FuelEstimateSheet` shows per-item gram
steppers (default = range middle) and logs through `logPlateToFuel` with
the source named ("USDA · photo-identified" / "+ photo estimate"); the
report shows a calorie range for plates; the relay forwards a json_schema
format (≤12k chars). Web search stays ON (Lucas). Fixed: double-log guard
read the caller's copy. NOT done: multi-photo, DataScanner live capture.
427 tests.

**Motion + Wave 4 (2026-10-15)**: motion kit at the end of GlassCard.swift
(`blurIn`, `TypewriterText`, `RingPulse`, `SweepWord`, `RadialReveal`,
`BeatSequence`; all Reduce-Motion-aware); onboarding opener in
`WelcomeLandingStep` (tagline `MorpheTheme.tagline` — "TRAIN SMARTER"
since 2026-10-15; the helmet mark is `matchedGeometryEffect("brandMark")`
into `NameStep`); the tour's welcome page carries `TourTrainWithGrid`
(RootView) — Voice card opens the real `MorpheOrbView`. Wave 4 memory:
`AIMemory`/`AIMemoryItem` (MorpheModels), store section "Morphe
remembers" (extras key `aiMemory`, pref `aiMemoryEnabled` default OFF,
`scheduleMemoryExtraction` after a chat reply via `MorpheIntelligence.reply(format:)`
with `memoryExtractionSchema`, `memoryForPrompt` in the STABLE block,
`historyContext(for:)` retrieval over the logs in the live block,
`forgetAIMemory`/`deleteMemoryItem`/`addMemoryNote`), ratings carry
`promptVersion` (+ memory fingerprint; rules updated), the
`MorpheRemembersSettings` UI in Profile → What Morphe has learned, policy
section. NOT done: the weekly eval script over aiFeedback (needs data).
431 tests. Gameplan: `docs/LAUNCH-GAMEPLAN-2026-10-15.md`.

**Not verified on hardware yet**: a real strap (needs one in hand), the
bounce timing on device, a real Strava/Garmin import through Health. A phone build of this commit should be installed
first thing.

**Waiting on Lucas:** the tagline (still "TRAIN SMARTER" in app/site/store
and "TRANSFORM. EVOLVE. BECOME." on onboarding), the palette, the real
products/store, Terms v3 partner offers (current Terms ban affiliate links),
the dormant Pro tier, a trademark attorney (MORPHE beauty marks; SPARTAN),
and who pays for the AI relay. **With the Apple account:** App Check
enforcement, paid-team signing, push notifications, TestFlight.

The master audit's tracker (top of `docs/AUDIT-2026-10-13-MASTER.md`) is
current through wave 2; wave 3 closed the AI pipeline, deletion, export,
backup chunking, age gate, comments-on-private-posts, nudge/selfie limits.

## Open items (honest list)

- **Needs Lucas**: $99 Apple Developer Program (TestFlight, App Attest
  entitlement + App Check enforcement, push); business
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

### Private account: server enforcement — DONE 2026-10-12 (ruleset 3df30e19, 125/125 live)

Posts with `authorPrivate` read only for the author and accepted
connections; the feed queries `authorPrivate == false` plus per-connection
private queries; usernames list requires `private == false`. Indexes in
BACKEND/firestore.indexes.json (create via the console — the service
account can't). Still client-only: new-chat gating to private accounts,
comments carry no private mark. History of the decision below.

#### (original note)

Board and challenge rows are server-true (the name is replaced with
"Private athlete" before it is written). Posts and the @username are only
marked private: the rules still let any signed-in client read `posts` and
`usernames`, and the app does the hiding. Doing it on the server needs the
feed query split (a public query filtered on `authorPrivate == false`, with
every post carrying the field — backfill old posts with the service account
— plus a composite index, and a second query or per-connection path for
private posts whose rule checks an accepted `connectRequests` doc). Thread
creation to private accounts is gated in the client only, too. The privacy
policy states this limit plainly; fix it before the policy can drop the
caveat. Also open from that audit: `setAuthorPrivate` reads at most 300
posts with full images (page by createdAt), comments carry no private mark,
a private Creator Coach's published workouts stay public.

### Audit backlog carried into the next session (2026-10-10, two reports)

Fixed in the wrap-up commit: board/party codes sanitized (a "/" crashed
the Firestore path), challenge titles screened, builder prompt frames the
injury/avoid text as quotes, nutrition matcher word-bounded, "agoge"
keyword retired, sign-out clears board caches + the Morphe thread, week
rollover with the app open refreshes boards and the report, news always
lands "just now", privacy policy lists exactly what the assistant sends
(+ lastConnectAt, thread backup), Terms allow Morphe AI to name a workout
that appears on a shared recap, tour/pattern-count/bad-key copy.

Still open, in priority order:

1. **P1 — error copy persisted as history**: a failed Claude call stores
   the error line as an assistant turn in the chat thread and the Morphe
   thread; next prompt sends it back as context. Drop or tag those turns.
2. **P1 — SSE `error` events ignored** in the streaming path
   (MorpheIntelligence) — a mid-stream error reads as a silent stop.
3. **P1 — offline brain states non-log facts**: readiness without a
   check-in, "This week looks steady" with no data, pain defaults
   (Knee / Walking Lunge), streak source mismatch. Each line must come
   from a log or say nothing.
4. **P1 — food check hides a bad key** (shows a generic miss). Surface the
   `.badKey` copy.
5. **P1 — `refreshBoards` cost**: N boards × ~150 reads, also triggered
   from the Discover feed task; add a staleness gate per board and keep it
   off the feed path. Same gate for `refreshQuickAdd` /
   `refreshConnectRequests`; debounce `postBoardScores`.
6. **P1 — accessibility**: PersonRow lineLimit at AX sizes, fixed widths,
   CountBadge contrast, bubble maxWidth 320, create/join board sheets at
   `.medium` without a ScrollView, `.combine` over the Respect button.
7. **P2** (the `Int(d.rounded())` trap is fixed): `viewPerson` is dead code; NewConversationSheet torn down
   before dismiss; popup arms under sheets; popup throttle key is
   device-global (should be per profile); `customProgramDefaultsKey`
   missing from the sign-out list; directory hits store the handle as a
   name; retired global-board code + tests; `Int(d.rounded())` trap in AI
   builder parsing; web-search count wording; `web_search_20250305` tool
   version check. (Tagline settled: TRAIN SMARTER, one constant.)

## Brand marks + page frame (2026-10-15, wave 2)

- **Tagline: TRAIN SMARTER** (Lucas 2026-10-15) — `MorpheTheme.tagline`
  in the app; the Watch, site, README, store copy and brand tool carry the
  literal. "Train honest" survives only as the internal principle in code
  comments and archived audits.
- **Marks** (sources in `BrandSource/`): app icon = the bright glass tile
  (`BrandSource/light/app-icon-light.webp`, iOS + Watch; the navy tile is
  in the brand kit); Morphe AI button = the side-helmet
  glass orb (`MorpheAIButtonMark`); Hey Morphe = the front-helmet orb, cut
  into `MorpheAIOrbBase` + `MorpheAIHelmet` so `MorpheOrbView`'s motion is
  unchanged.
- **Loading screen** (`LaunchSequenceView`, OnboardingView.swift): Lucas's
  art cut into `LoadingPlate` (waves, lettering + helmet painted out) and
  `LoadingHelmet` (`Tools/make_loading_layers.py`). The plate drifts and
  breathes, a light pulse runs along its own pixels (plusLighter through a
  moving band), data motes rise; the wordmark, tagline and a glass progress
  capsule are live type. 1.4 s, cold starts only; Reduce Motion = still.
  The system splash is the same helmet on `LaunchField` navy, placed by
  `Tools/make_launch_splash.py` (236 pt wide, 110 pt above screen centre,
  `UIImageRespectsSafeAreaInsets = false`) so the handoff never jumps.
  iOS caches launch screens: reboot the simulator / reinstall to see a change.
- **Page frame: reverted** (Lucas 2026-10-15). A reformat modelled on an
  AI-generated reference (big left-aligned titles, one segmented control
  per page) was built and then rolled back at his call; the pages are the
  pre-reference UI (centred `SectionTitleView` headers, underline tabs,
  Learn's chips). Everything else from that day stays.
- **Light mode marks**: every brand asset has a light appearance from
  Lucas's light art (`BrandSource/light/`) and the asset catalog switches
  by scheme — Morphe AI button orb, Hey Morphe orb layers
  (`Tools/make_light_orb_layers.py`), loading plate + helmet, splash
  helmet and `LaunchField` (`Tools/make_light_loading_layers.py`). The
  loading screen's type, pulse blend (multiply on white), motes, glow and
  glass bar follow the scheme. The home-screen icon is his bright glass
  tile (one icon, both modes).
- **Onboarding**: Back/Next pinned above the home indicator with a solid
  backdrop and a status-bar fade; the gate is read in `body` (inset content
  sits outside observation tracking).
- **Website**: hero, product art and download panel use the loading
  screen's navy waves (`docs/assets/waves.jpg`, CSS drift, still under
  reduced motion); icon, AI bubble, helmet and share card are the new marks;
  a press strip (`#brand`) shows the dark and light vertical lockups
  (brand kit + site only, not in the app).
- **Open (personalization, untouched on purpose)**: the plan ranks workouts
  by sport, level, equipment, injuries and styles — goals aren't an input,
  so a Gain-muscle beginner can be handed a weight-loss HIIT first.


## Today block + fix wave (2026-10-15, wave 3)

- **Today**: Schedule now sits directly under today's plan (hero, done or
  rest card), followed by `TodayGlanceRow` (HomeView.swift): Goals
  (checklist preview; tap → `TodayGoalsSheet` to check/uncheck, change,
  delete, add), Nutrition (calories + protein bars → Learn → Nutrition),
  Progress (this week's sessions as a pie → Progress). Goal edits persist
  in the profile snapshot (`customTaskTitles`, `hiddenTaskTitles`,
  `taskRenames`) and re-apply every day via `personalizedDailyTasks`;
  user-added goals earn 0 XP. `.schedule` left the reorderable stack.
- **Fixes**: holds are flagged per set (`LoggedExercise.timedPerSet`,
  note fallback for old logs) — History reads "Hold 12s", and seconds never
  count as reps, e1RM or lifetime reps; a new account's back-catalogue news
  lands read (no red 6); "1 day" plurals; the duplicate "Workout logged"
  toast is gone (tier unlocks still toast, after the celebration); Morphe
  AI prompts change once today is done; Return sends in the composer.
- **Added**: offline log recall (`logRecallReply`: "how many push-ups did
  I do today", "what did I do this week", "my last workout"); a "You did
  1 of 7 exercises" check before finishing a mostly-skipped session; the
  plan ranks by the athlete's goals (`catalogGoals`), General Fitness
  matches every sport, Olympic lifting/strongman stay out of the default
  rotation unless styles ask for them.
- **Polish**: plain foods rank above breaded/fried; library rows say
  "/ 100 g"; the Fuel cameras read "Log a plate" vs "Check a photo";
  Profile's "Login" row is "Sign out".
- **Open**: the ranker doesn't know age ("Balance and Strength for Older
  Adults" can land for a 27-year-old); the live rest countdown is below the
  exercise card; Apple Health appears under Connections and Health; the
  9-page tour is long.

## Final loading screen + orb swap (2026-10-15, wave 4)

- **Loading screen** is Lucas's final art (`LoadingFinal`, source
  `BrandSource/loading-screen-final.webp`), one image for light and dark:
  scaled to fill, a 2% breathe, motes, and the glass bar + LOADING… under
  the baked tagline (`barLine` 0.815 of the art's height). The system
  splash is plain `LaunchField` navy (no image), so the art fades in on the
  same colour. The layered LoadingPlate/LoadingHelmet/LaunchHelmet assets
  were removed; `Tools/make_loading_layers.py`, `make_light_loading_layers.py`
  and `make_launch_splash.py` are retired with them.
- **Orbs swapped by mode** (Lucas): the white art (`*-light.png`) shows in
  DARK mode, the dark art (`*-dark.png`) in LIGHT mode — Morphe AI button,
  Hey Morphe base and helmet.

## Swipe, avatar, Morphe AI fallback (2026-10-15, wave 5)

- **Page swipe vs rails**: `InTabPageSwipe` ignores drags that start in a
  `.pageSwipeExempt()` area (every horizontal ScrollView on Discover,
  Network, Learn is tagged) — "New this week" scrolls, the page doesn't flip.
- **Morphe's chat avatar**: the helmet on black (`MorpheThreadRow`).
- **Morphe AI errors — root cause**: the relay is NOT deployed (Cloud
  Functions API never enabled on morphe-3c5c2 → Blaze not active); the URL
  answers 404, which mapped to "Something went wrong on my end". Now 404 →
  `.relayUnavailable`, the relay is parked for the session
  (`MorpheIntelligence.relayDown`), and every failure the athlete can't
  act on answers with the built-in brain (`onlineFallbackAnswer`).
- **Built-in brain**: technique answers from the on-device library
  (`exerciseReply`: steps, cue, muscles, mistakes, easier version, swaps;
  "how do I deadlift" → Conventional Deadlift via head-word + base-movement
  match); the last-resort line lists what it can answer.
- **Still on Lucas**: Blaze → `firebase functions:secrets:set
  ANTHROPIC_API_KEY` → `firebase deploy --only functions` for real Claude
  answers.

## Hey Morphe endpointing + audit fixes (2026-10-15, wave 6)

- **Hey Morphe no longer cuts users off**: the settle timer now checks the
  mic itself — if the user was voiced (RMS clearly above a tracked room
  floor, `HeyMorpheEngine.isVoiced`) in the last 0.45 s, it waits another
  0.5 s instead of firing (`settleOrFire`, 30 s ceiling). Sentences of six
  words or more get 2.1 s (`sentenceSettleWindow`); dangling words keep 2.8 s;
  follow-up capture ceiling raised to 16 s / 30 words. The recognizer's
  partials lag the voice, which is why a timer on text alone cut people off.
- **Onboarding**: step label matches the opener (name = STEP 1 / 4); Next
  stays disabled while the @handle is invalid (it lit up beside "Start with
  a letter" and silently did nothing); the handle field stops at 20
  characters (it took 26 and kept 20); no goal picked now defaults to
  Build consistency, not "Improve conditioning".
- **Shell**: a solid-to-clear fade sits behind the status bar and icon row
  so scrolled content no longer collides with the clock.
- **Open**: "Weight Loss" is both a sport and a goal in onboarding; the
  floating Morphe AI pill can sit over the Progress tile at one scroll spot.

## Hey Morphe: volume + calls (2026-10-15, wave 7)

- **Volume**: speaking no longer switches the session to `.voiceChat`
  (its call-style voice processing cut speaker volume to near-silent);
  it stays `.playAndRecord` / `.default` with the speaker route, utterance
  and player volume at 1.0, and the system echo-cancelled input on
  iOS 18.2+ where available. Barge-in still works (the mic stays hot);
  echo protection is the spoken-echo stripping + the 4-word barge rule.
  Watch on device for Morphe interrupting itself on loud speaker.
- **Calls**: iOS gives the microphone to phone/FaceTime calls — no app can
  listen during one. `CallWatcher` (CallKit) sees the call: Hey Morphe
  pauses, an in-app banner + a passive notification say it listens again
  after the call, and on hang-up it re-arms and clears the notification.
- The Morphe AI button no longer slides off on Today (reverted at Lucas's call).

## Loading zoom + audit wave (2026-10-15, wave 8)

- **Loading screen**: Lucas's final art cut into `LoadingFinalPlate` (field,
  mark painted out) and `LoadingFinalMark` (helmet → tagline box)
  by `Tools/make_loading_final_layers.py`. The field zooms 8% over the beat
  (ease-in, "entering Morphe"); the mark and the glass bar draw at 85%;
  the whole stack fades in as one composited layer.
- **Audit fixes**: Discover workout detail pins Start / Set for today /
  Save above the home indicator ("Train Today" relabelled — it sets the
  workout without starting); quiz options show in a stable per-question
  shuffle (`MiniQuiz.displayOrder` — the answer was 2nd in 14 of 20) as
  full-width buttons; Learn's empty "From Coaches" card sits below the
  lessons until a note exists; empty Progress has "Start today's workout".
- **Open**: Discover category lists give every card a full-width Start
  (three per screen); Calendar's empty state has only the small "Add".

## Onboarding to the reference pattern (2026-10-16, wave 9)

Audit of Apple HIG / Apple's welcome component, TikTok, Instagram and
Duolingo first-run flows against Morphe's; findings and sources in
`docs/AUDIT-ONBOARDING-REFERENCES-2026-10-16.md`.

- **One question per screen**: welcome → name → @handle → goals → sport →
  experience → days → review (7 answered steps). A thin accent progress
  bar + "3 OF 7" replaces the title card.
- **Choice cards** (`ChoiceCard` at the end of OnboardingView.swift): goals
  as icon rows with a check, sports as a two-column icon grid, experience
  as three cards with a one-line description; same selection logic.
- **Plan-building beat**: `PersonalizedPlanLoadingView` ticks three lines
  to checkmarks (~2.4 s) before `completeOnboarding()`.
- **First run = one Apple-style welcome page** (mark, "Welcome to Morphe",
  four feature rows, Continue, "Take the two-minute tour"); Profile →
  Replay the guide (`store.welcomeIsReplay`) still opens the full tour.
- **Lost first tap fixed**: each step is its own ScrollView (`.id(stepIndex)`)
  and nothing scrolls programmatically — the old `scrollTo` left the view
  tracking, so the first tap on every new step only stopped it. Walked
  live: goals, sport grid, level, days and the terms row all take the
  first tap.
- **Plan ranking**: every catalog template decodes as `.generalFitness`, so
  the sport preference never did anything and a General Fitness + Strength
  athlete opened on "Fighter Strength Base" (boxing). `templateSportAffinity`
  reads category + name; general athletes get generic plans first, sport
  athletes their own sport, then the backbone, then other sports.
- **Open**: @handle before value (Instagram's reason doesn't apply to
  Morphe; it stays because `completeOnboarding` reserves it); account
  before value (sign-in wall precedes onboarding — Duolingo's strongest
  pattern needs a design pass once TestFlight says where people drop);
  Lucas rewrites the onboarding/tour wording himself.

## Wave A from the user + investor audit (2026-10-16, wave 10)

Findings and the plan: `docs/AUDIT-USER-INVESTOR-2026-10-16.md`. Shipped:

- **A1 load suggestion** — `MorpheAppStore.loadSuggestionReply` answers
  "how much should I squat next time / should I go up / what weight" from
  the log and the plan's reps: every work set hit the target → last load +
  5 lb (2.5 kg); a missed set → repeat the load; bodyweight → add reps.
  Dispatched before log recall and technique. Tests cover both branches.
- **A2 starting load** — `suggestedStartingLoad(for:)`: bodyweight × level
  ratios per movement (squat .5/.75/1.0, deadlift .6/.9/1.25, bench
  .35/.6/.85, press .25/.4/.55, row/pull .35/.5/.7, DB/KB/curl .1/.15/.2),
  rounded to 5 lb / 2.5 kg, only when the movement has no last-session set.
  The console seeds it a beat after the exercise changes and the first-time
  caption says it's a guess; without a bodyweight the caption points to
  Profile → Your details.
- **A3 rest at the top** — the running countdown mirrors into the console
  header ("Rest 2:58 · then set 2 · Skip"); the full timer card stays below.
- **A4 toasts** sit in the icon row (6pt from the top), never on a title;
  the celebration keeps its 64pt clearance.
- **A5** the "Not saved yet" banner hides while the debrief sheet is up; the
  Train and Today hints retire once a session is logged.
- **A6** Today's done card says what was logged ("Short day on X: 2 of 5
  exercises, 3 sets, 1 min. It counts.") instead of "closed the loop".
- **A7** the Morphe AI pill compacts after the first logged session.
- **A8** `ShareCardPreviewSheet` shows the story card with one Share button
  before the system share sheet.
- **A9** Discover's shelf is "New in the Library" and ranked by sport/goals
  (`rankedPlanCandidates`); the four categories are still the hardcoded
  newest — the catalog needs a `publishedAt` before "this week" can be true.
- **A10** voice hint says "10 reps" on bodyweight moves; Profile's guide
  subtitle matches the five stops.
- **A11** `NotificationPrePromptSheet` (what Morphe sends, Turn on / Not
  now) after the first log; the system dialog only follows a yes
  (`scheduleNotificationPrePrompt` / `acceptNotificationPrePrompt`).
- **A12** Learn shows today's quiz and the next; "Show all 20" opens the wall.
- **Share card honesty** (found while verifying A8): the kicker is
  "SESSION LOGGED" (it said "complete" on a 2-of-5 day) and a first-ever
  lift no longer rides as "NEW PR" — a record needs an earlier loaded set
  of that movement (`latestSessionShareCardData`).

## Food-check gate + work units (2026-10-16, wave 11)

- **Food check refuses non-food** (Lucas): every photo is classified first
  (`subject`: food / drink / package / notFood / unrecognized — in the
  system prompt, the ask, and the structured-output schema). notFood →
  pop-up "That isn't food or a drink… It saw: X. The food check is only
  built for food and drinks"; unrecognized → "Morphe AI couldn't recognize
  that". One `.alert` in RootView bound to `store.foodCheckNotice`, so it
  fires from Log a plate and Check a photo alike. Drinks are named in the
  prompt, the items list, and the UI copy ("Check a Food or Drink").
- **Rounds, runs, intervals, laps, holds** (`WorkUnit` in MorpheModels):
  inferred from the exercise name + the workout's catalog category +
  whether the prescription is timed. The console pill, the summary line
  ("5 rounds • 3 min"), the set rows ("Round 1"), the rest bar ("then
  round 2"), the timer buttons ("Start round 1", "End round early · log"),
  the store toasts ("Round 2 of 5 done — Round 3:00") and history
  ("Round 3:00") all speak the unit. Rounds/runs/intervals/laps count
  DOWN and log themselves at zero; holds still count up. Stored label
  format: "Round 3:00" / "Run 45s" / "Hold 30s"; `WorkUnit.isTimedLabel`
  drives `timedPerSet`.

## Round-aware everywhere + Apple-UI fixes (2026-10-16, wave 12)

- **Every surface speaks the unit**: voice bar ("Say your round — done";
  "done" / "round done" / "time" logs the prescription), the same-as-last-
  time row, edit/delete labels, the complete card and recap ("All rounds
  logged"), the discard dialog, queue and detail lines, Today's done card,
  the share card ("5 ROUNDS"), the rest line ("then round 2"), Hey
  Morphe's "rounds left", Morphe AI's log recall, and history.
  `WorkUnit.word(forLabels:)` / `word(forLogged:)` give "sets", "rounds",
  or "rounds and sets" for a mix.
- **Apple-UI audit** (`docs/AUDIT-APPLE-UI-INVESTOR-2026-10-16.md`): dark
  panels lifted to 10/15/20% (they were invisible at 4.5%), micro labels
  now text-style fonts so Dynamic Type scales them, Discover's lead shelf
  puts the athlete's own level first. Then (Lucas): the welcome is a
  `fullScreenCover`, the streak row sits below the plan/done card so Start
  leads the page, every tab has 60pt bottom safe-area padding under the
  floating AI button, and the Goals tile shows two goals in full. Then: the custom
  capsule dock is retired for the system `TabView` bar (`.tabItem` +
  `.badge`, `.tint(accent)`, `popTabToRoot` on selection change; the AI
  button clears 98pt) and Learn's quote card is gone from the first screen.

## Feedback audit — animation, sound, haptics (2026-10-16)

Read-only audit in `docs/AUDIT-FEEDBACK-2026-10-16.md`: a moment-by-moment
matrix (visual / sound / haptic now vs the Apple, Nintendo, PlayStation,
Xbox, TikTok, Instagram bar), ten ranked findings, and a five-tier feedback
grammar (Tick / Confirm / Complete / Signature / Miss) with three waves:
F1 the Log Set signature + stepper ticks + round-end sound + prepared
generators; F2 quiz/streak/finish-sequence game feel; F3 `sensoryFeedback`
migration, selection-haptic pruning, button press scale. Nothing changed.

## Feedback wave F1 (2026-10-16)

- **Log Set signature**: the new set row slides in from the trailing edge
  under a spring (opacity-only under Reduce Motion); the store plays `ding`
  with the light impact on every logged set; the SETS/ROUNDS pill rolls
  its number (`contentTransition(.numericText)`).
- **Press feel**: Primary and Secondary buttons scale to 0.97 on press
  (0.25 s spring), not just dim; off under Reduce Motion.
- **Stepper ticks**: `sensoryFeedback(.selection, trigger: value)` on the
  reps/weight rows; the ±25/±10 plate jumps add a light impact.
- **Complete tier**: a round/run/hold reaching its target now plays `star`
  + success + a 160 ms accent flash on the clock; rest-end and circuit
  round-end switched from `ding` to `star` (ding = contribution, star =
  completion, pr = record — the three meanings stay fixed).
- **Prepared generators**: `Haptics` keeps one generator per style warm
  and re-prepares after each hit; `Haptics.prepare()` fires when the
  console appears. Haptics can't be felt in the simulator — verify the
  timing on the phone.

## Feedback wave F2 (2026-10-16)

- **Quiz feel**: correct → the sheet pops to 1.04 and back, `star` + success,
  the XP line counts up (`contentTransition(.numericText)`); wrong → a
  300 ms three-cycle horizontal shake, the new `miss` cue (E5 → B4, the
  chord's own notes walked down) + the error buzz. Reduce Motion: no
  travel, the cues still fire.
- **Streak increment**: the Today "days shown up" row bounces its icon
  and fires a medium impact when the number changes; 7 / 30 / 100 / 365
  add `star` + success. The training-streak flame on Today bounces on a
  change too.
- **Finish sequence** (`FinishSequenceOverlay` in GlassCard.swift, store
  `finishSequence`): after a session saves — SESSION LOGGED / SHORT DAY
  LOGGED, the workout name, the stats line rise (0 ms) → the streak lands
  with a medium tap (+500) → each real PR stamps in with a heavy strike
  (+500 each) → settles 2.2–2.8 s → dismisses. Tap anywhere skips to the
  end; Continue dismisses. The record stamp (PR / program) waits behind
  it and takes the stage when it's dismissed, so the PR chord plays once.
  The "In the books" banner still fires underneath (tests assert it).

## Feedback wave F3 (2026-10-16)

- **Pruned** the selection tick where no value changed: the
  `FilterChipStyle` press-down tick (it fired on every chip, list filters
  included, and doubled chips whose action already ticked), the quiz
  pager, the feed filter chips, the search submit, the back swipe, Profile
  section expand, and the store's cancel/dismiss paths (voice cancel,
  leave away mode, dismiss monthly challenge, dismiss day popup, the
  Morphe-ask fall-through). A feed reaction and a memory-item delete are
  light impacts now, not ticks.
- **Migrated to `sensoryFeedback(.selection, trigger:)`** at the owner so
  the tick is bound to the state it reports (and respects the user's
  haptics setting): Discover's section switch, the debrief intensity row,
  the warm-up toggle, Form Check's RPE row, the onboarding terms row, and
  the nutrition goal picker. Steppers already use it (F1).
- Button press scale shipped in F1. Haptic sites now: selection ~30 (value
  changes only), impact/success/error unchanged.

## Evening user audit fixes 1–3 (2026-10-16)

`docs/AUDIT-USER-2026-10-16-PM.md`. A boxer picking "Improve sport
performance" was getting "Dumbbell Lean-Out Circuit":
- `toggleOnboardingSport`: the General Fitness placeholder is replaced by
  the first real pick (it used to queue behind it and stay primary).
- `catalogGoals`: performance / event → Strength Building only (Lean Out
  came from the conditioning branch); sport-specific work comes from the
  sport affinity.
- Morphe AI: "give / find / want / suggest a <sport> workout" →
  `sportMentioned(in:)` + `rankedPlanCandidates` for that sport at the
  athlete's level → `setCurrentWorkout` + "say start my workout". The
  technique matcher no longer answers with a form cue.
- Then (4, 5, 7): nutrition targets carry `isStarter` and every surface
  labels the generic 2,200 / 160 g as a starter until a weight is logged;
  warm-up / mobility / stretch names infer the hold unit whatever the
  workout's category; the review's "Readiness check-ins" bullet names the
  evening check-in that exists.

## Edit option on every page but Network (2026-10-16)

Today and Train already had "Edit X's layout"; Discover and Learn now
have the same footer. `LayoutCard` protocol + `DiscoverCardID` (coaches,
new in library, most done, category families, technique library) and
`LearnCardID` (quizzes, lessons, why Morphe, personal rules, coach notes)
in MorpheModels; order/hidden persist in `StyleProfile`
(`discover…`/`learn…CardOrder/HiddenCards`); one generic
`LayoutEditorSheet` + `EditLayoutButton` in GlassCard.swift. Coach notes
still lead Learn once there are some unless the user ordered the page.
Network is deliberately left alone.

## Exercise page redesign + step-diagram pipeline (2026-10-16)

- **ExerciseDetailView** reads name → one meta line → the diagram → numbered
  steps with the cue as one accent line → Do (was "Beginner modification")
  / Don't (was "Common mistake") → Also try chips → a REFERENCE dropdown at
  the bottom holding "why this matters" + the source. Text is the library's
  own; the simplicity comes from the layout, not rewritten copy.
- **Step frames**: `FormDiagrams.frames(for:)` loads `<id>-1.heic …
  <id>-N.heic` (one per instruction) and pages them under the name; tapping
  a step pages to its frame; a single `<id>.heic` still shows alone;
  Discover thumbnails use frame 1. Only 140 of 595 exercises have any
  diagram today (the v1 built-ins); the 401 catalog exercises have none.
- **Pipeline (no spend yet)**: `Tools/build_form_diagram_prompts.py` writes
  `Content/DiscoverLibrary/FormDiagrams/prompts-steps.json` — 595
  exercises, 2,308 frames, each prompt = house style wrapper + the step's
  own instruction text. `Tools/make_form_diagrams.py --dry-run` prices it
  (nano-banana-2 ≈ $138, nano-banana-pro ≈ $346 at fal list price);
  with `FAL_KEY` set it generates resumably, saves PNGs under
  `…/FormDiagrams/steps/`, and bundles 640px HEICs. Waiting on Lucas's
  go + key.
- **Proof run through the media-gen skill (2026-10-16)**: barbell-back-squat
  steps 1–3 via `~/.claude/skills/media-gen/scripts/generate.py` —
  step 1 on `fal-ai/nano-banana-pro`, steps 2–3 on `…/edit` with step 1 as
  the reference. $0.45 (3 × $0.15 at fal list price; the skill's
  `models.json` carries no image price field — worth adding). Style held
  across all three; step 2 drifted to a rear view and a hinge rather than
  the described squat, so a full run needs a regen budget (~20%) and a
  tighter "front view, same angle as the reference" line in the edit
  prompt. Frames bundled as `barbell-back-squat-{1,2,3}.heic`; the folder
  reference picks new HEICs up automatically.

## Settings tabs, Today identity strip, streak sticker (2026-10-16)

- **Profile settings**: Profile / Training / Privacy & data / Support are
  drop-down tabs (`settingsGroup`), Profile open by default, one at a
  time, all open while searching; closed tabs list their contents.
- **Today identity strip** (`TodayIdentityStrip`): under the greeting, a
  MORPHE ONLINE · @handle kicker and four mono tiles — READINESS /100,
  SCORE (tier), ENERGY /10, LEVEL (rank) — that count up from zero on
  arrival with a staggered glow and a light tap per tile; no check-in →
  "—  check in" (tile opens the check-in). `store.todayRecoveryEntry`.
- **Streak sticker** (`StreakSticker`, replaces the DAYS SHOWN UP row): a
  74×40 magnet (calendar · flame · days) overlaid on Today, parked
  top-right under the icon row each launch, hold-and-drag anywhere
  (lifts, tilts, drops with a medium tap), tap → `StreakStickerSheet`:
  days in a row + best, sessions done/target, and the week's good and bad
  lines from the log (PRs, days shown up, missed training days so far,
  short days, a forgiven day).
- **Sticker → glass calendar tile** (Lucas): 46×50, accent header band
  carrying a drawn robot arm (`RobotArmFlex` Shape — no SF symbol or
  emoji exists), frosted body with the day count, bubble highlight,
  accent hairline; every color from the user's palette. The week sheet's
  flame became the same arm in accent.
- **Electric sweep** (`electricSweep(armed:)` on the greeting): a thin
  accent band with a white core and a fainter trailing pass, masked to the
  glyphs, sweeping ~0.9 s — once ~0.9 s after the greeting lands, then
  every 2–3 min at random while Today is on screen; a soft tap with it;
  nothing under Reduce Motion. Verified by burst capture (the band reads
  through "in" and "Verif").

## Sticker DAY tile + night audit 2–8 (2026-10-16)

- Sticker: the header reads DAY, the number is the user's accent — no arm,
  no symbol; the week sheet's icon is a calendar glyph in accent.
- Night audit (`docs/AUDIT-USER-2026-10-16-NIGHT.md`) 2–8: the Lose-weight
  review no longer promises steps or a weigh-in the app doesn't do; the
  day-one strip reads "Check in · 20 seconds" / "Day 1" / "— · after
  check-in" instead of dashes and a zero; the first-run hint sits under the
  plan card; no "ready in Train" toast when Train is already up; mobility
  work is a `flow` unit (counts up, "Start the clock") and the unit pill
  hides when the target is 1; the voice bar keeps 56pt clear of the AI orb;
  holds/flows say "Say "done" to stop the clock".
- The "Good evening, name" line is gone from Today (Lucas: it moves to the
  welcome pop-up); the page opens on MORPHE ONLINE · @handle, and the
  electric sweep now runs through the handle.
- The streak sticker is gone (Lucas): the strip's kicker is one centered
  line in one font — MORPHE ONLINE · @handle · N DAYS LOGGED — where the
  days count (sessions logged, from the log) opens the week's read sheet.
- "What workout would you like to start today?" left Today too (Lucas):
  strip → plan card. `homePrompt` still feeds the day pop-up bubble.
- Today's status strip (`TodayStatusStrip`: avatar, name, goal, readiness /
  score / energy) is deleted — the identity strip carries it. The avatar
  → Profile door in the header was never touched.
- Edit Today's layout can now hide Schedule, Goals, Nutrition and Progress
  one by one (`HomeCardID.goals/.nutrition/.progress`, `isPinnedUnderPlan`);
  they stay pinned under the plan card in that order, hide/show only.

## In-place layout editor (2026-10-16)

- No pop-up: "Edit X's layout" puts the page into editor mode
  (`store.editingPage`, `EditorModeBar` on top with Done). Every section
  gets a dashed outline and an eye; tap the eye → a rigid tap and the box
  pops away; hold a box → a medium buzz, it lifts, drag it up or down and
  the order saves on drop (`SectionEditorList` in GlassCard.swift, frames
  via `EditorFrameKey`). Today's pinned pieces (Schedule, Goals, Nutrition,
  Progress) get an eye only (`editorEye`).
- Nothing can be lost: hidden sections sit in a HIDDEN row with Show
  chips; the last visible section can't be hidden (error buzz + shake +
  "Keep at least one section on this page").
- Tabs: in editor mode a strip above the tab bar lets the user hold and
  drag an icon to reorder (`TabOrderStrip`, `styleProfile.tabOrder`,
  `store.tabLayout`); the TabView renders in that order (`tabPage(_:)`).
- The four editor sheets (`HomeLayoutEditorSheet`, `TrainLayoutEditorSheet`,
  `LayoutEditorSheet`) are no longer presented; code kept for now.
- "Your typical session runs about N minutes" is gone from the learned
  line under the greeting.
- The "Here's what I've got for you" plan card on Today is replaced by four
  doors (`doorsGrid`): Train (today's workout name · minutes), Nutrition,
  Network, Learn — Morphe says nothing there. `nextMoveCard` stays for the
  rest-day / logged states only.
- Welcome pop-up (Lucas): the greeting is "Hello, name." outside morning /
  evening (no more "Late one?"), the line under it is "Here's what I have
  for you today." (no question; yesterday's mood no longer rewrites it),
  and the standard buttons are Train <today's workout> · Other workout
  (`.otherWorkout` → the switch sheet) · Log a meal (`.logMeal` → Fuel) ·
  Other…. Rest-day, evening and logged states keep their own buttons.
- Under the strip, the learned line ("X is your most-trained exercise…")
  is replaced by **Morphe's directive** (`morpheDirective(now:)`): one
  short command from the user's own state in priority order — finish the
  live session, keep the streak, train today (N of T), days off, rest day,
  check-in, log weight, protein after 1 PM, a stalled lift, open goals,
  new in Network, today's appointment — rotating hourly through the top
  three; "All set for today. Rest up." once the day's logged; nothing
  invented. `learnedInsightLine` stays for the AI brain.
- Evening pop-up (Lucas): the "Short session tonight / Minimum win /
  Tomorrow" set is retired from the pop-up — one offer, morning or night
  (the evening card on Today still has those outs).
- Editor mode, rebuilt (Lucas 2026-10-16, three passes):
  - One banner for every page (`EditorModeBar(tab:editable:)`), an
    overlay in RootView over the avatar/search/quick-add row; it slides
    down when editing starts and up on Done; it follows the user across
    tabs (`followEditing(to:)` in the tab `onChange`) until Done.
  - The system tab bar hides while editing (`.toolbar(.hidden, for:
    .tabBar)`) and `TabOrderStrip` stands in its place: tap switches tabs,
    hold a tab ~2 s to lift it, slide left/right inside the bubble, order
    saves on drop. No second row above the real bar.
  - Every box in `SectionEditorList` uses the same hold-highlight-move:
    `HoldDragOverlay` is a `UILongPressGestureRecognizer`
    (`holdSeconds = 2.0`, `allowableMovement = 12`) so the page still
    scrolls (the old SwiftUI long-press+drag swallowed scrolling); while a
    box is lifted the enclosing `UIScrollView` is frozen. Frames are in
    `.global` space to match the UIKit point. The eye and dashed outline
    draw above the hold layer. Pinned Today pieces (Schedule, Goals,
    Nutrition, Progress) hide/show only.
- Today doors: Train is filled with the user's accent (the Start-button
  color, ink via `onFill`); the Learn door is now **Discover** and opens
  Discover on its Feed (`openFeed()`). The rest timer's Start uses
  `MorpheTheme.accent` (was `accentAlt`, near-black on Spartan).
- Saved-workout menus: "Train Today" → "Today's training".
- Header: the Morphe wordmark (template image, `textPrimary`, no glow) is
  centered on the icon row of every page (`ClientPinnedHeader` overlay).
- Today kicker order: `@handle · ● ONLINE · N DAYS LOGGED`; the dot is a
  `FlickerDot` (random dips / double-blinks; still under Reduce Motion).
- Network chats (Lucas 2026-10-16): the Morphe row is always at the top
  (a search still finds it by name) with the app icon's Spartan art as its
  avatar (`MorpheAppIconArt` imageset, a copy of AppIcon-1024). The
  Network Morphe chat and the floating Morphe AI chat are ONE
  conversation: `morpheConversation` merges `morpheInbox` (reports, news)
  with `athleteAIAgentConversation` by date (`ThreadMessage.sentAt`,
  optional so older saved turns decode; undated turns take the date of the
  turn before them); both surfaces render it with `AIAgentMessageRow`, and
  the thread composer routes through `sendAIAgentPrompt`. `chatSurfaceDepth`
  counts chat surfaces on screen (AthleteInboxView onAppear/onDisappear,
  which covers the list, an open thread and the search board);
  `chatsHaveTheStage` also covers the Contact section of the Network tab;
  the floating AI button slides off while it is true and back after.
- Discover (Lucas 2026-10-16): the sections are **Fitness** (was
  Workouts; `DiscoverSection.workouts` keeps its case name) and **Explore**
  (was Feed). Both have an edit option at the bottom: Fitness edits the
  Discover cards (`EditablePage.discover`, titled "Fitness"); Explore has
  its own layout (`ExploreCardID` workouts / blogs / challenges,
  `exploreCardOrder` / `exploreHiddenCards` on StyleProfile,
  `setExploreLayout`, `EditablePage.explore`). With the All chip the
  stream renders as sections in the user's order through
  `SectionEditorList` (hold to move, eye to hide, min 1); a hidden section
  also loses its chip. A section switch mid-edit moves the mode with it
  (`followEditingDiscoverSection`).
- Morphe AI designs (Lucas 2026-10-16): the orb base, the AI button mark
  and the helmet are single-appearance now — the darker orb/button art
  and the light-mode Spartan in every appearance (the "-light" PNGs are
  gone; the imagesets keep the one universal file). The Hey Morphe wash
  darkens the page in light mode (black 0.42) and lightens it in dark
  mode (white 0.24).
- Late-audit fix wave (docs/AUDIT-USER-2026-10-16-LATE.md): #2 the resume
  alert is gated on the app shell; #9 `planAheadReply` answers "what
  should I train (tomorrow)" with the next session before the load
  matcher; #1 `openDiscoverDoor()` lands on Explore only when coaches
  have published, else Fitness; #4 `HoldDragOverlay.onPress` gives a
  press-in (scale 0.98 / brighter outline; tabs 0.94) while the 2 s hold
  charges; #5 Today's banner says the pinned boxes hide only; #10 titled
  Morphe turns bold their first line; #11 the floating chat's nav bar has
  a material backing; #12 the GUARDIAN tag is gone. #3 is the local-mode
  fetch failure (prod shows the Morphe row alone when there are no
  chats); #8 (the AI pill over the Progress tile) is left as is.
- The orb (`MorpheOrbView`) fades on over 0.35 s wherever it mounts live
  (Hey Morphe stage, welcome pop-up) instead of appearing (Lucas
  2026-10-16); still frames (`animates: false`) are untouched.
- First run rebuilt (Lucas 2026-10-16). Routing, before the account
  exists: `IntroView` (in OnboardingView.swift) — a black screen with
  [ TAP TO BEGIN ] slowly flashing; a tap grows a white disc from the
  center until the screen is white; the orb fades on with a bubble
  ("Hello there." + a one-line intro, **[DRAFT] — Lucas re-says it**), a
  @username field, a birthday picker (13+ gate), **Build my profile**
  (accent, highlighted) and **Get started without a profile** (plain,
  muted), with the terms line under them. `completeIntro` seeds the draft
  (username, birth year, agreedToTerms) and persists `hasSeenIntro`
  (`morphe.intro.seen`) + `introChoice`. Then the Create-account screen
  (name prefilled with the handle). After auth: Build my profile → the
  questions minus welcome/username (`introSuppliedIdentity`), the handle
  reserved on Create Plan (a collision falls back to the username step);
  Get started → `quickStartOnboarding()` (general fitness, beginner, 3
  days, the handle reserved) → `completeOnboarding()`. Both end on
  `relaunchLoadingSequence()` (the Morphe launch loading screen) and then
  the app. `completeOnboarding` no longer raises the hello beat or the
  welcome sheet; it sets `activationWelcomePending`
  (`morphe.activation.pending`, on disk) so the next pop-up is the
  one-time **"Welcome, name." / "Thanks for activating me. Now we can get
  to work."** with Take the tour (`.tour` → the full replay tour), Edit my
  profile, Train, Other…. Answering or dismissing it clears the flag;
  everything after is the standard pop-up. `-MorpheLocalOnboarded` marks
  the intro seen; plain `-MorpheLocalMode` walks the intro.
- Hey Morphe stage chat bar (Lucas 2026-10-16): a short glass bar ("Type
  to Morphe") with the mic button to its right sits at the bottom of the
  stage. Focusing the bar → `openVoiceChat()`: any streaming answer is
  dropped, the engine is muted (`muteForChat` — speech stopped, listening
  torn down), the orb slides to the top (matchedGeometryEffect) with its
  bubble under it ("Chat active…" until a reply), and the user's messages
  stack up from the bar (`voiceChatUserTurns`, since the chat opened)
  fading under the orb. Typed messages go through `sendAIAgentPrompt` —
  the one conversation the floating chat and the Network thread render;
  the bubble shows `voiceChatReplyLine`. The mic button (or a tap on the
  wash) → `closeVoiceChat()` → `resumeFromChat()` (listening resumes only
  if it was on). Voice exchanges now also land in the conversation
  (`presentVoiceExchange` records heard + answer, deduplicated against
  the online path). The stage mounts while `voiceChatOpen` too.
- Nutrition (Lucas 2026-10-17): the Check Food card no longer lists recent
  checks inline and Today's Fuel no longer lists the day's meals inline.
  Each header has a small `HistoryButton` (clock, count) that opens a
  pop-up — `FoodCheckHistorySheet` / `FuelHistorySheet` — with **Today**
  boxed at the top (accent box) and earlier days below grouped by date
  (`HistoryDayBox`). Today's meals keep their remove buttons in the sheet;
  earlier days come from `nutritionSeries` (calories / protein vs target).
  Tapping a food check in the sheet opens its report.
- `-MorpheVoiceChatPreview` (local mode): opens the stage in chat mode
  four seconds after launch, for simulator verification.
- Today's Fuel (Lucas 2026-10-17): three equal log doors — Search (accent),
  Photo, Enter — sit above the meters; the old Search/Log-a-plate pair and
  the "Enter a label by hand" link are gone.
- Network header is Board · Chats · Calendar (chats in the middle); Learn
  opens on Nutrition (`selectedHubFeature` default). `resetSectionDefaults()`
  puts Network on Chats and Learn on Nutrition and pops both pages to the
  top when the welcome pop-up is answered or dismissed and on a cold open
  (`finishLaunchSequence`); between those, each page keeps the section the
  user left. The main TabView's selection binding treats a re-tap of the
  selected icon as `popTabToRoot` — the section stays (Board, Library…),
  the page rebuilds at its top (Lucas 2026-10-17).
- Discover (Lucas 2026-10-17): the Fitness search + filters and Explore's
  search + chips are store-backed (`discoverFilters`, `exploreQuery`,
  `exploreFilter`) and rendered by `DiscoverFilterBar` / `ExploreSearchBar`.
  They scroll with the page; once the page is past them (offset < -170)
  a scroll UP slides a pinned copy in under the icon row (material
  backing), a scroll DOWN slides it out, and back at the top it leaves so
  the real bar takes over. Offset comes from `DiscoverScrollOffsetKey`
  (a GeometryReader under the section tabs, iOS 17-safe).
- Page titles in the tabs grammar: `MonoSectionTabs` (GlassCard.swift) —
  Train shows TRAIN underlined with its line under it; Learn shows
  LESSONS · NUTRITION · LIBRARY (the chip row is gone) with its line
  under it.
- Edit options everywhere (Lucas 2026-10-17): Board, Chats, Calendar,
  Nutrition and Library edit through one generic store —
  `StyleProfile.sectionLayouts[page] = PageLayoutRecord(order, hidden)`,
  `pageLayout / visiblePageCards / hiddenPageCards / movePageCards /
  hidePageCard (min one) / showPageCard`, with `BoardCardID` (boards),
  `ChatsCardID` (people · morphe · conversations), `CalendarCardID`
  (schedule), `NutritionCardID` (check · fuel · chart · basics · insight),
  `LibraryCardID` (exercises · saved). `EditablePage` gained those cases;
  `editablePage(for:)` maps the Network section and the Learn feature;
  `followEditingSection()` (didSet on both) moves the mode with a section
  switch. Learn's button reads "Edit Lessons's layout".
- The floating Morphe AI button parks (Lucas 2026-10-17): swipe it right
  (not mid-hop) and it slides off; `aiButtonParked` (UserDefaults) shows
  `AIButtonParkedTab`, a small accent chevron hugging the right edge in its
  place; tap or swipe it left to bring the button back. The chats / Hey
  Morphe gate is unchanged (no chevron there).
- Page swipes (Chats ↔ Board ↔ Calendar, Fitness ↔ Explore) run on a UIKit
  pan (`PageSwipeRecognizer`, attached to the page's host view, simultaneous
  with every scroll view, `cancelsTouchesInView = false`) instead of a
  SwiftUI drag — the chats list swallowed the drag (Lucas 2026-10-17). The
  exempt frames (rails, chip rows) still apply. Today's doors are Network ·
  Discover / Nutrition · Train; the tiles read LEVEL · SCORE · ENERGY ·
  READINESS; the welcome pop-up's buttons run bottom-up (1 nearest the
  thumb); after the intro the name step no longer re-asks the birth year
  and the counter reads N OF 5; "Take the tour" presents after the pop-up
  cover has left.
- Conversations (Lucas 2026-10-17): every chat page (a user's thread, the
  Morphe chat) renders in place — the Morphe chat is no longer a sheet —
  with `ChatPageHeader` (back chevron, the name centered, dots menu with
  report/block or mark-read/open-AI). `VoiceComposer` at the bottom: the
  text field, no send button, return sends; the mic beside it is
  hold-to-record (`VoiceMemoRecorder`: buzz, AAC file under Application
  Support/MorpheStore/VoiceMemos, metered level → `RecordingWaveform` in
  the field, the mic lights accent, `VoiceEdgeGlow` on the screen's edge;
  Hey Morphe pauses meanwhile). Release → an on-device transcript
  (`SFSpeechURLRecognitionRequest`, 15 s cap) and the clip parks above the
  field as a `VoiceMemoBubble` (play, still waveform, length bottom-left,
  × top-right); return sends it. A sent clip shows a subtle chevron
  bottom-right that opens the transcript. Morphe chat: the memo rides the
  turn (`ThreadMessage.voiceMemoID`) and the brain answers the transcript.
  User threads: the wire is text-only, so the message is
  `[voice:<id>|m:ss] transcript` — the sender plays the clip, the other
  side reads the transcript (`VoiceMemoStore.parse`). Deleting the pending
  clip with the keyboard's delete key is not wired (SwiftUI's TextField
  cannot see a backspace on an empty field); the × does it.
- Hey Morphe stage (Lucas 2026-10-17): the mic is hold-to-record there too
  (`VoiceMemoRecorder`, waveform in the bar, lit mic, edge glow); release
  sends the clip into the chat (`sendVoiceChatMemo` — opens chat mode if
  needed, the brain answers the transcript, the clip shows in the turn
  list). Swipe down on the bar (or drag the mic down without recording) →
  `closeChatSequence()`: keyboard down, messages slide up behind the orb,
  then `closeVoiceChat()` brings the orb and bubble home while the bar
  stretches to full width and the mic slides off; then a buzz, Morphe
  says "Chat inactive" and the bubble reads "Voice active…" for 4 s. In
  voice mode the bar is full width with no mic. `startVoiceIfEnabled`
  refuses while `mutedForChat` so a recording's resume cannot restart
  listening mid-chat. A swipe over the keyboard itself dismisses the
  keyboard (iOS); the bar swipe is what closes the chat.
- Technique Library moved from Discover → Train, under Progress
  (`TrainCardID.technique`, a `TrainLinkCard` opening `TechniqueLibraryView`
  in a sheet); Discover's card and `DiscoverCardID.technique` are gone
  (saved orders drop the unknown id). Discover's page swipe wraps: either
  direction flips Fitness ↔ Explore; styles open on a tap only; the ALL
  STYLES chevron pops the pushed category page (`selection = nil`) and a
  right swipe there does the same (Lucas 2026-10-17).
- `voiceStageHold` keeps the Hey Morphe stage mounted through the
  close-chat sequence and the 4 s "Voice active…" beat even when the voice
  engine is off (the stage otherwise unmounts the instant chat closes);
  with the engine off, "Chat inactive" is spoken by `PopupNarrator`.
- Explore is a media grid (Lucas 2026-10-17): `ExploreGrid` — the search
  and chips, then a three-column 4:5 grid of `ExploreItem`s
  (`store.exploreItems`: photo posts as images, text posts and coach blogs
  as threads; reels are a kind with no source yet). Empty state until the
  community publishes. A tile opens `ExploreViewer` (fullScreenCover,
  tab bar hidden): posts page vertically (rotated page TabView — up = next,
  down = previous), a pull past the first refreshes the feed, back
  chevron top-left, dots menu (report/block) top-right, `EngagementStack`
  lower-right (like · replies · share · save on real posts; share on
  blogs), caption bottom-left; carousels page sideways with dots; a right
  swipe returns (from a carousel only on its first image). Threads show
  the body, the replies and a reply field. The old sectioned `CreatorFeed`
  stays in the file, unmounted. Library order is Saved → Exercise Library.
- Library (Lucas 2026-10-17): the Skill Drill Spotlight and Stretching +
  Mobility cards are gone; the page is Saved, then the Exercise Library.
- Per-page Morphe lines (Lucas 2026-10-17): `pageDirective(_:now:)` for
  train · fitness · explore · lessons · nutrition · library, rendered by
  `MorpheDirectiveLine` under each page's tabs (replacing the static
  subtitles). Three buckets per page — a navigation tip, a task from the
  user's data (open session, week count, starter targets, water, today's
  quiz, nothing saved…), an encouragement that is a logged number — and a
  day-stable pick (`ordinality(.day, .era)` + page index) so the line
  changes daily; beginners lead with tips, others with tasks/numbers.
  No quotes or invented lines (sourcing law): every "motivation" is a
  real count.
- Search (top-right icon, Lucas 2026-10-17): the sheet is just the bar
  (focused on open) with results below once a search runs — no title,
  no Done; pull down to leave.
- Quick Add (Lucas 2026-10-17): title on top, Morphe's line under it
  (`pageDirective(.connect)` — scan/search tips, "connect with one person"
  task, a connections count), the invite link under My Code · Scan and
  above People, no Done (pull down to leave), and the search field pins on
  a scroll up (`pinnedBar` modifier + `PinnedBarOffsetKey`). The universal
  Search sheet's bar sits above its result pager, so it never scrolls off;
  nothing to pin there.
- Quick Add → Requests (Lucas 2026-10-17): a drop-down row under My Code ·
  Scan · invite with the pending count on the right (accent pill when
  > 0); opens itself when requests exist; lists up to 12
  `incomingConnectRequests` with Accept / × per person (`PersonRow`), and
  a "Show more (N)" that adds 12 at a time. Data is the existing
  connectRequests collection — nothing new on the wire.
- Morphe AI design (Lucas 2026-10-17): the new Spartan orb image (helmet
  baked in, glass sphere with wave ribbons) is the single source for
  `MorpheAIOrbBase` (the orb on the pop-up and the Hey Morphe stage),
  `MorpheAIButtonMark` (the floating button) and `MorpheAppIconArt` (the
  Morphe chat avatar). `MorpheOrbView` no longer layers `MorpheAIHelmet`;
  the whole orb scales with the voice level and the drawn ribbons sit at
  half opacity over the art. The helmet imageset stays for `MorpheHelmetMark`.
- Loading screen (Lucas 2026-10-17): the inactive Spartan orb (dark
  visor) is the mark's helmet now — `MorpheAIOrbIdle` imageset, composited
  into `LoadingFinalMark.png` over the old helmet box with the wordmark
  and TRAIN SMARTER untouched (`Tools/make_loading_final_layers.py` would
  regenerate the old one; the composite was done in place).
- The Spartan wakes (Lucas 2026-10-17): `SpartanWakeView` crossfades
  `MorpheAIOrbIdle` (dark visor) → `MorpheAIOrbWaking` (half-lit) →
  `MorpheAIOrbBase` (eyes lit) with a light buzz and a 4% pop on the last,
  over ~1–1.3 s; Reduce Motion shows the awake frame. Used on the loading
  screen (over the helmet box; `LoadingFinalMark.png` is now wordmark +
  tagline only), on the intro right after [ TAP TO BEGIN ] (then the live
  `MorpheOrbView` takes over), and on the Hey Morphe stage when it
  arrives in voice mode (then `MorpheVoiceRingHost`).
- Glass bubble buttons (Lucas 2026-10-17): `MorpheGlass` /
  `.morpheGlass(shape, tint:)` in MorpheTheme — Liquid Glass
  (`glassEffect`, interactive) on iOS 26, ultraThinMaterial + hairline on
  17/18. Primary CTA = accent-tinted glass; Secondary = clear glass; filter
  chips glass (tinted when selected); Quick Add pills, header buttons,
  pop-up choices (tinted with their solid fill for legibility over the
  scrim), the Train door, the Fuel doors and the history button all route
  through it. `VoiceGlass` on the stage is the same idea, kept private.
