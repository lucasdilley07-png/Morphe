# Morphe master audit, 2026-10-13

Everything: the app, the website, the backend, the docs and the business
plan, benchmarked against the fitness industry (gyms, events, services,
apparel, products, supplements, media). Nine fresh-eyes passes read the
code and the live site; the two market lanes cite a live source for every
number. The headline findings were re-checked against the code by hand.
Read-only: nothing was changed by the audit.

## Fix progress (updated as waves land)

**Waves 1–2, 2026-10-13 (honesty + activation):**

| Finding | Status |
|---|---|
| P0 1 pace stamps rewritable | Fixed — stamps may only stay or move to request time (live-checked) |
| P0 2 fakeable scores | Fixed — shape, name length and ceilings on boards, the retired global board and challenges (live-checked) |
| P0 3 fake products on the site | Fixed — removed; "Morphe gear is being made" until real products exist |
| P0 4 35-point score floor | Fixed — score is sessions + streak only |
| P0 5 "readiness is 60" | Fixed — no check-in, no number; "This week looks steady" now counts real sessions |
| P0 6 "Log it as written" | Fixed — a zero-set session never logs; the choices are keep training or discard |
| P0 7 lock-screen/Watch weight | Fixed — only weight lifted this session, else bodyweight |
| P0 8 app-open streak as a stat | Fixed — own icon and "DAYS SHOWN UP" label (kept: Lucas's Oct 4 feature) |
| P0 9 workouts never saved | Fixed — answering or skipping the debrief saves; leaving the app saves a finished session |
| P0 11 AI consent | Fixed — consent sheet naming Anthropic and the data, before a key is saved |
| P0 12 crash reporting | Fixed — MetricKit crash/hang events into first-party telemetry; payloads kept on device |
| P0 14 tour ejects at stop 3 | Fixed — every middle page is "Next"; the last opens Train |
| P0 15 no way to sign up | Partly — website waitlist (create-only); coach application still needs an account |
| P1 false "stays on your device" | Fixed |
| P1 Form Check hidden 3 sessions | Fixed — visible from session one |
| P1 est. 1RM toast / first-record stamp | Fixed — toast shows what was lifted; a first lift is a baseline |
| P1 rank copy | Fixed — "logged work and lessons" |
| P1 QR scan fakes a connection | Fixed — sends a real connect request |
| P1 food photo before key check | Fixed — asks first, offers barcode |
| P1 blocked user can open a new chat | Fixed in rules (live-checked) |
| P1 nav contrast, sitemap | Fixed |
| Stale business docs | Archived to docs/archive with the reason |

**Waiting on Lucas:** the tagline (incl. "TRANSFORM. EVOLVE. BECOME." on
screen one), the brand kit and products (store, palette), Terms v3 partner
offers, the Pro tier, a trademark attorney, who pays for the AI relay.

**Next waves:** App Check enforcement + paid-team signing (with the Apple
account), push notifications, the AI relay, data export completeness,
deletion of name-bearing docs, backup chunking, age gate, then the hub.

## The verdict, honestly

The core product works. A beginner gets from install to a logged set in
about 8 taps with no dead ends, the console is built for day one, Form Check
logs real sets with a seal, demo data is purged, and the server rules are
strict and live-verified.

But the brand promise is "every number is earned", and the audit found
**numbers that aren't earned in exactly the places an honesty brand can't
afford them**, plus four bigger gaps:

1. **The honesty promise has holes.** Fakeable leaderboards, a bypassable
   human-pace limit, a free 35-point score floor, an invented "readiness 60",
   an app-open streak shown as a training stat, sessions that log with zero
   sets, and eight fake products with specs and prices on the website.
2. **Nobody has logged a workout.** Live telemetry: 2 accounts, 22 app
   opens, zero logged workouts in 35 days — including the founder's. A
   workout only saves after Finish → debrief → recap → a separate Log
   Workout tap.
3. **The target user can't reach the AI.** Every Claude feature needs the
   user to paste a developer API key. Beginners will only ever see the
   canned replies.
4. **The "connect it all" hub doesn't exist in code** — and the app's own
   Terms ban affiliate and promotional links, which the products model needs.
5. **Name and brand risk.** MORPHE is a registered beauty brand (Forma
   Brands, classes 3/16/18/21/35 incl. retail); Spartan Race enforces SPARTAN
   hard, including in software.

## WORKING (keep)

- **First run:** auth → 4-step onboarding → Today → Start, ~8 taps, no dead
  ends; level defaults to Beginner; demo data wiped and a fresh id minted
  (MorpheStore.swift:7153-7313).
- **Today at zero:** no fake metrics; readiness "—" until a check-in; score
  0 with no logs (HomeView.swift:831; MorpheStore.swift:17917).
- **Beginner console:** Reps · Weight · Log · Rest · Next for the first three
  sessions; bodyweight hides load; weight only from the user's own logs
  (WorkoutView.swift:2867, 2894, 675).
- **Form Check:** 11 rep patterns + holds, camera-counted sets carry a seal,
  a hand edit removes it, honest when the camera can't see (FormCheckView).
- **Rest timer + Live Activity, widget, Watch:** real data; a fresh install
  says "Open Morphe to start" instead of zeros.
- **Finishing:** PRs are pure comparisons; untracked exercises never invented.
- **Network:** real chats with report/block, pinned Morphe thread with a
  weekly report computed from logs (quiet weeks say so), code-gated boards,
  paced connect requests.
- **Food check by barcode works without a key** (Open Food Facts; "not found"
  and "can't reach" kept apart).
- **Profile:** live-selfie verification, private account (server-enforced
  for posts and the directory, 125/125 live checks), account deletion with
  fresh sign-in, data export (partial).
- **Backend:** default-deny rules, verified flags unforgeable, reports and
  telemetry write-only; secrets gitignored and absent from history; privacy
  manifests present.
- **Website:** live site matches the repo; SEO basics, OG card, structured
  data; legal pages match the markdown; most feature claims verified true;
  "What Morphe leaves behind" with citations is a differentiator.
- **Costs:** roughly $0–2/month at 300 users, ~$25–40 at 10k, ~$200–350 at
  100k (estimates, feed off).

## NEEDS IMPROVEMENT

### P0 — fix before any stranger installs it

Honesty holes (each contradicts "every number is earned"):

| # | Where | Problem | Fix |
|---|---|---|---|
| 1 | firestore.rules:76-83 | The user doc's pace stamps (`lastPostAt`, `lastCommentAt`, `lastMessageAt`, `lastConnectAt`) can be rewritten, so the human-pace limit is bypassable | On update each stamp must be unchanged or equal `request.time`; or move stamps to an admin-only doc |
| 2 | firestore.rules:550, 597, 640 | Board and challenge scores only need `>= 0`: anyone can post any score and any `name` text by REST | `keys().hasOnly`, `name.size() <= 40`, a believable cap; server-computed scores later |
| 3 | docs/index.html:440-470 | Eight products that don't exist, with specs and prices ("25 g of protein", "Caffeine 150 mg", $89 belt) on a page that says "Nothing fake" | Remove; replace with "Helmet Tee — notify me" until real |
| 4 | MorpheStore.swift:17931 | Morphe Score = `35 + …`: one session reads 48; the explainer says nothing else feeds it | Drop the 35 |
| 5 | MorpheStore.swift:17116, 17899-17909 | Offline AI says "Your readiness is 60" with no check-in | Same guard the Claude path has; answer "no check-in yet" |
| 6 | WorkoutView.swift:568 | "Log it as written" turns a zero-set session into XP, a streak day, score and Apple Health minutes | Remove, or log as "planned, not tracked" with no rewards |
| 7 | MorpheStore.swift:12166 | Lock-screen and Watch "Log Set" can commit a weight nobody lifted (auto +5 lb suggestion) | Only weight from this session or the user's dial |
| 8 | HomeView.swift:112, 2319 | "1 DAY SHOWN UP" counts app opens, next to the training streak, same flame | Drop it or rename "Days opened" with another icon |

Activation, AI access, launch blockers:

| # | Where | Problem | Fix |
|---|---|---|---|
| 9 | WorkoutView.swift:966; MorpheStore.swift:9206 | A workout saves only after Finish → debrief → recap → Log Workout; telemetry shows zero logged workouts | Save on Finish; the debrief becomes optional |
| 10 | ProfileView.swift:2784 | All real AI needs a developer Anthropic key | Server relay with a per-user budget before launch, or stop calling it "AI" in beginner copy |
| 11 | ProfileView.swift:2783 | Data goes to Anthropic (logs, injuries, photos) with no consent screen (App Store 5.1.2(i)) | One-time consent sheet naming Anthropic and the data sent |
| 12 | — | No crash reporting at all | MetricKit or Crashlytics before TestFlight |
| 13 | MorpheApp.swift; Auth | App Check not enforced; unlimited sign-ups | Enforce with the Apple account (Auth + Firestore); debug token for the verify script; reCAPTCHA for the web form |
| 14 | RootView.swift:4436 | The tour's primary button on stop 3 of 9 is "Ask Morphe" — it ejects beginners into chat before "Your first workout is ready" | "Next" on every page; exits as secondary links |
| 15 | docs/index.html #download; docs/coach.html | No way to sign up today (disabled buttons, no email capture); coach applications need an account outsiders can't make | Waitlist email form; email-only coach application until release |
| 16 | RootView.swift:52; TERMS_OF_USE.md:73 | Terms ban "promotion, referral links, affiliate links" — the products/partners model needs them | Terms v3: a "verified partner offers" exception posted only by Morphe or approved coaches |

### P1 — users will hit these

- **Onboarding copy:** "It stays on your device" is false (the name syncs) —
  OnboardingView.swift:552. "TRANSFORM. EVOLVE. BECOME." (rejected in the July
  brand audit) is still the first screen (OnboardingView.swift:14,
  AuthView.swift:28). 29 chips on one page; "Personal Training" and "Hybrid
  Athlete" listed as sports.
- **Form Check is hidden for the first three sessions** behind More options,
  while the tour tells beginners to tap it (WorkoutView.swift:3024;
  RootView.swift:4346).
- **No help choosing a first weight**; logging untouched records 0 on a
  dumbbell lift. **No way to flag pain** in the simple console; the injury
  question was cut from onboarding.
- **"est. 1RM ≈ X" after every weighted set**, and "NEW RECORD — your first
  record" on day one.
- **Ranks copy is false:** "levels come only from logged work", but quizzes and
  ticked tasks ("Drink water") grant XP.
- **QR Scan fakes a connection** (local only, toasts "Connected").
- **Food check Photo opens the camera before saying a key is needed.**
- **Switch Workout is a dead end** for new users (empty library alert).
- **Starter nutrition targets (2200 kcal / 160 g)** shown before any body weight.
- **Canned message drafts sent as the user's words** (postWorkoutCoachDraft) —
  against the human-only rule.
- **Backend:** DMs ignore private accounts and blocks at the rules level;
  comments readable/writable on private posts; party nudges, selfie size and
  telemetry unbounded; deletion leaves name-bearing docs (board entries,
  messages, connect requests) and caps at 500 docs per subcollection; the logs
  backup is one JSON blob that hits Firestore's 1 MiB limit around 350–500
  workouts; camera permission text is wrong; privacy manifest missing
  app-group reason 1C8F.1; no suspension flag; no age gate; rules tests run
  against production.
- **Data export** covers only workouts and weight.
- **Website:** Coach-sharing lines in privacy.html and the App Store privacy
  answers describe a removed feature; invite links can't preview or open as
  universal links (needs the domain); nav "Get Morphe" fails contrast; title is
  just "Morphe" (competes with the cosmetics brand); sitemap stale.
- **Brand:** seven taglines in circulation (TRAIN SMARTER in app, Watch, site,
  App Store; TRAIN HONEST in docs; the brand-kit line nowhere; TRANSFORM.
  EVOLVE. BECOME. on screen one; "the honest training instrument"; "Every
  number is earned."; "The Spartan in your pocket"). Three palettes (app blue,
  kit blue never shipped, retired yellow kit still in docs/brand-kit/).
- **Docs:** PAYMENTS.md, COACH-PILOT.md, COACH-PITCH.md, COACH-KIT.md and the
  launch checklist still sell Pro $5.99 / Coach $39 and the deleted coach
  dashboard; LAUNCH-CONTENT-CALENDAR.md references removed features and has
  AI-phrased hooks without [DRAFT]. App Store screenshots are the old yellow
  brand.

### P2 — polish

Debrief starts pre-set at 7/10; streak counts protected days as trained;
holds from Form Check log nothing; voice example says "10 at 135" on push-ups;
RPE and superset jargon on day one; empty Schedule card on day zero; food count
copy says 1,195 (library has 1,758); stale "Learn → The Code" pointer; "hydration
is improving" with no data; dead Stretching rows; Leave board has no confirm;
support email is a personal Gmail; heavy images; Google Fonts on a "no
trackers" site; the model ID in MorpheIntelligence.swift is `claude-opus-5`
(Opus 5.5 is cheaper and current); local admin pages lack CSRF; usernames
squattable.

## MISSING

**To launch well:** push notifications (chats and connect requests can't reach
anyone), crash reporting, the AI relay, a waitlist, real screenshots and a demo
video on the site, a founder/about page, social links, a press kit, a custom
domain and a hello@ address, Firestore backups, a remote kill-switch, staging
and CI, an age gate.

**To be the hub (none of it exists in code today):**

| Category | Exists | Missing |
|---|---|---|
| Gyms | Equipment profile; "Same Gym" party mode | Partner-gym entity, location/map, check-in, gym pages and gym boards |
| Clothing / merch | Nothing | Shop surface (web, print-on-demand), earned drops, the Terms exception |
| Supplements / nutrition | Food check, fuel log, nutrition chart | Supplement tracking; a verified shelf (NSF / Informed Sport only) |
| Services (coaches) | Creator Coach, Studio, published workouts/notes/challenges | Directory with specialties, booking, payment, reviews |
| Events | Code challenges, open challenges, group lobby, personal calendar | Event model (venue, capacity, RSVP), tickets, event pages, check-in |
| Wearables | Apple Health write + sleep read, Watch HR | Steps/HRV reads; Garmin, Whoop, Oura, Strava |
| Media | 319 workouts, 595 exercises, 141 diagrams, lessons, share cards | Video (no Storage), creator media |
| Money rails | StoreKit IDs present but off | Any purchase flow; a decision on the dormant Pro tier vs "free core" |

## What the fitness industry teaches (live sources in the lane reports)

- **Connectors own a standard format or a place.** HYROX: €135M revenue (2025),
  ~20% EBITDA, 1.4M+ participants, ~9,000 licensed gyms paying ~$1,500/yr,
  sponsors from Amazon to Les Mills. DEKA ran a gym-vs-gym global leaderboard
  across 1,000+ gyms in October 2026. Morphe's equivalent is a **"Morphe-
  verified" score** — camera-sealed, server-checked — that gyms and coaches
  recognise.
- **Events are the acquisition engine; drops are the margin.** Gymshark's free
  LIFT events (7,500 in NYC, 20,000 in Miami) sell exclusive merch;
  Gymshark itself froze its training app — Morphe is the reverse (app first,
  goods second).
- **Keep the core free and make the store the revenue** (Nike NRC/NTC as
  membership on-ramps). Strava converts ~2% to paid; community alone won't
  pay — events and products must.
- **Supplements: only with proof.** Creator brands can be huge (Raw/Quality
  Group, Ghost) and can collapse (Prime: $1.3B → ~$300M, a $68M co-packer
  suit). An honesty brand lists only NSF Certified for Sport / Informed Sport
  products, starts as an affiliate, and never signs a minimum-volume contract.
- **Don't own hardware or a building yet.** Lululemon wrote off ~$540M on
  Mirror; Peloton's equipment revenue fell from $3.1B to $817M.
- **Apple rules:** physical goods and in-person tickets are sold outside IAP
  (3.1.3(e)); anything that unlocks app features needs IAP (3.1.1); paid
  challenge entries are digital; contests need official rules (5.3); a
  storefront-heavy app risks 4.2.2.
- **FTC:** testers given free tees must disclose when they post.

### Best-fit plays for Morphe now (solo founder, 0 users)

1. **A free monthly verified challenge, gym-vs-gym** (CrossFit Open / DEKA
   format on Morphe's code boards and camera seal). Highest fit, low effort.
2. **A weekly free in-person session in the Bay**, one code board, filmed by
   Hummingbird Pictures (run-club growth shows the demand).
3. **A partner-gym pilot with 3–5 gyms, starting with your boxing gym** —
   free leaderboard plus beginner referrals; charge nothing yet.
4. **Earned merch:** the first 30 tees gifted for verified milestones, then
   challenge-locked drops on a web print-on-demand store.
5. **A verified supplement shelf** (affiliate, certified products only) once
   the Terms allow partner offers.
6. **Media through Hummingbird Pictures** — sponsor integrations once the
   accounts have reach.
7. Later: a beginner fight-camp night through an existing sanctioned boxing
   show; "First HYROX" Creator Coach programs; Wellhub app partner.

## Decisions only you can make

1. **The tagline** — one line, then one sweep across app, Watch, site, store
   and docs.
2. **Terms v3** — allow verified partner offers (needed for products and
   supplements)?
3. **The dormant Pro tier** — kill it, or keep a paid digital tier alongside
   products/media/events?
4. **A trademark attorney** — MORPHE next to Morphe Cosmetics for apparel and
   retail; "Spartan" in brand copy and the brand-kit line.
5. **The AI relay** — who pays for beginners' AI (revenue, a raise, or a capped
   free allowance)?

## Recommended order

1. **Fix wave 1, honesty (P0 1–8):** rules for pace stamps and scores, the 35
   floor, readiness 60, log-as-written, lock-screen weights, the app-open
   streak, fake site products. About a day.
2. **Fix wave 2, activation (P0 9, 14) + onboarding copy (P1):** save on
   Finish, tour, false privacy line, rejected tagline, Form Check visible.
3. **Launch infra with the Apple account (P0 11–13):** crash reporting, AI
   consent, App Check enforcement, signing on the paid team.
4. **Website (P0 15):** waitlist, email-only coach application, real
   screenshots, remove fakes; archive the stale business docs.
5. **Then the hub, in the order above:** the free verified challenge first.
