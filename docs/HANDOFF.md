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
