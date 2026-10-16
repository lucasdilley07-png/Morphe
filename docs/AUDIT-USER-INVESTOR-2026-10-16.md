# Morphe — real-user audit + investor audit + fix plan (2026-10-16)

Walked live on a fresh install (iPhone 17 Pro simulator, local mode, no
backend): onboarding → first-run welcome → first session (3 sets logged,
finished early) → debrief → Today done-state → Share Win → Discover →
Network → Learn → Morphe AI → Profile → Progress. Then re-read as a
seed investor against the July memo, the launch gameplan, the business
priors, and the repo. Nothing in the app was changed by this audit.

---

## Part 1 — as a real user

### What works (and is genuinely good)

- **Install → first logged set in ~12 taps**, no dead end. The new
  onboarding (one question per screen, cards, plan beat, welcome page)
  reads like an Apple flow. Every first tap lands.
- **The console is honest and fast.** Auto-advance after the last set,
  the set row with edit/delete, the rest timer auto-starts at the plan's
  rest, "This hurts" one tap away, partial-finish confirmation that says
  exactly what you did ("2 of 5 exercises").
- **The debrief is short and earns its keep** (intensity + 0–10 + a note).
- **Today's done-state** is a real peak-end: "You're done for today",
  Share Win / View Progress / Go Again.
- **Progress tells the truth**: 1/4 this week, 1-day streak, the actual
  sets in history, score formula is sessions×10 + streak×3 and the AI
  says so when asked.
- **Morphe AI offline answers from the log** ("What did I do today?" →
  the real session) and routes the user.

### What's broken or wrong (ranked by how much it costs a new user)

| # | Finding | Where | Why it matters |
|---|---|---|---|
| U1 | **"How much should I squat next time?" → a technique lecture.** The brain has the logged 5×50 lb and the plan's rule ("add load when all sets move cleanly") and answers with form cues instead. | Morphe AI, offline | This is the single most-asked question after a session and the one the "Morphe picks weights" promise is built on. |
| U2 | **The weight promise isn't kept on day one.** Welcome page: "Morphe fills in reps and weight from last time." Second exercise (Barbell Back Squat) opens at "BW" with "First time with this one? Pick a weight…". | Live set row | First session is exactly when the user has no "last time". The app has bodyweight (onboarding doesn't ask it) — it can't suggest, so it shouldn't promise. Either ask bodyweight + experience and seed a conservative starting load, or reword the promise to "from your second session on". |
| U3 | **Rest timer starts below the fold.** After Log Set the 3:00 timer is running in the Live Session card, off-screen. A new user sees nothing happen. | Train, after logging | The "Morphe times rest" promise is invisible; users will start their own phone timer. Surface a compact countdown at the top of the console (or in the toast) the moment a set logs. |
| U4 | **Toasts sit on top of the page title.** "Today's workout is ready in Train" over "Active Workout"; "10 reps logged…" over the title; "Bodyweight Squat complete…" over the plan name. | Every toast on Train | Looks broken on first contact. Anchor toasts below the status band, above content, with a solid backdrop. |
| U5 | **Two contradictory save messages at once.** Behind the debrief sheet: "Not saved yet — tap Log Workout below to keep this session." In front: "Save". | Finish flow | Users read "not saved" and panic-dismiss. The banner should hide while the debrief sheet is up (the sheet IS the save). |
| U6 | **"Great session" / "You closed the loop on Day A" after 2 of 5 exercises, 1 minute.** | Train header + Today done card | The honest-numbers brand says what happened: "Short day logged: 2 of 5 exercises, 3 sets." Celebrate consistency, don't inflate the session. |
| U7 | **Morphe AI orb overlaps content.** Over the Progress tile on Today; over "Session tools" on Train. The orb design changes from pill to bare helmet mid-session with no reason the user can see. | Today, Train | Known open item; still open. Reserve a bottom inset for the orb on every scroll view, keep one orb design. |
| U8 | **Share Win has no preview.** Tap → straight to the system share sheet with a generic text icon. | Today done card | Strava/Whoop show the card first. Users won't share a thing they haven't seen. Show the card, then the share sheet. |
| U9 | **"NEW THIS WEEK 032" on a static catalog.** The four categories are hardcoded (comment says so). For a strength athlete it leads with Barre. | Discover | Invented freshness is the one thing this brand cannot do. Rename "New in the library" until the catalog has `publishedAt`, and rank the shelf by the user's sport. |
| U10 | **Voice hint says "10 at 135" on a bodyweight exercise.** | Train composer | Cheap fix: "10 reps" for bodyweight rows, "10 at 135" only when load applies. |
| U11 | **Stale hints after the session.** Train still shows "Tap Start and log each set"; Today still shows the "This is Today" hint above the done card; Profile's "Replay the guide" lists "Train Together, fuel, the ladder" — stops the 5-stop tour no longer has. | Train, Today, Profile | Noise on the most important screen of the day. Hints should retire on the event they describe. |
| U12 | **Learn leads with 19 locked grey quiz cards** and a Plutarch quote. The "lessons" tab is quizzes. | Learn | A new user reads it as content that isn't there. Show today's quiz + the next one; keep the rest behind "20 in the series". |
| U13 | **Notifications prompt with no pre-prompt.** The system dialog appears after the first workout with no card saying what Morphe will send. | After first session | Right timing, wrong framing — Apple's own guidance is a pre-permission screen. Accept rates roughly double with one. |
| U14 | **Network is empty by construction.** No chats, no boards, no connections, "chats couldn't load" in local mode. | Network | Not a bug — the cold-start problem. It needs a day-one job (see A3 below) or it's a tab that teaches "nothing here". |

### What's missing (a user would expect it and it isn't there)

- **A starting-weight estimate.** Bodyweight × experience → conservative
  first loads for the big four. Every serious strength app does this.
- **A visible session summary at finish** (sets, volume, PRs, time)
  before the debrief. Today's done card does part of this, one tab away.
- **An "undo last set" affordance on the console** (there is edit/delete
  in the row, but a logged-by-mistake set needs one tap).
- **Form Check on the first exercise** is a button labelled "Form" with
  no hint of what happens; the welcome page promised "the camera counts
  your reps" and nothing on the console repeats it.

---

## Part 2 — as an investor

Re-read against the July memo (`docs/archive/INVESTOR-AUDIT-2026-07.md`),
the 2026-10-13 master audit, the launch gameplan, and the repo today.

### Where it stands (facts, not claims)

- **Product**: 90.8k lines of Swift, 526 commits since 2026-06-13, 443
  unit tests green, 319 workouts / 595 exercises, live-verified Firestore
  rules, crash reporting, a relay designed (not deployed), Watch target,
  share cards, referral links, boards, coach tooling.
- **Distribution**: Apple Developer Program still unpaid. Store checklist
  0 of 23 items checked. Relay not deployed (Blaze pending). Site is live
  (200) with a waitlist.
- **Users**: the founder. Zero cohorts. Zero strangers.
- **Revenue**: $0. Pro paywall is built and gated off (`storefrontEnabled
  = false`). Pricing ($5.99/mo Pro, $39/mo coach) is still a proposal.

### The verdict

**Same as July: not fundable today; fundable inside one 90-day window —
and the window still hasn't opened.** Eleven weeks have passed since the
memo named the $99 gate as the binding constraint. In those weeks the
product got materially better (honesty holes closed, AI surfaces,
onboarding rebuilt, brand shipped) and the traction table stayed empty.
An investor reads that sequence as: *the founder polishes when blocked
instead of unblocking.* It's the one pattern in this deal that is both
visible and fixable in a day.

### What an investor would price positively

1. **Execution rate and quality** — still the strongest signal. Waves ship
   daily, tested, verified on device, documented. Few solo founders do this.
2. **The honesty wedge is now real in code** (July's "holes" are closed
   per the master audit) and it is cheap to keep and expensive for
   incumbents to copy.
3. **Coach as channel** is still the business. The tooling exists.
4. **Growth loops plumbed** before the raise (share, referral, boards,
   universal links, telemetry with named targets).
5. **COGS discipline** — near-zero infra to ~300 users; AI relay costs
   capped at $50.

### What an investor would price negatively (deal-breakers today)

1. **Zero traction after eleven weeks of being able to buy it.** Nothing
   else on this list matters until TestFlight has 25 strangers in it.
2. **No price in front of a customer.** The paywall is hidden. You can't
   learn willingness-to-pay from a feature flag.
3. **The AI story is honest but thin.** Offline it's a rule-based router
   that can't answer "how much should I squat" (U1). Online needs a relay
   that isn't deployed. Investors will test it with one question.
4. **Solo founder, two companies, a production company and school.** The
   priors file still has "two startups, one founder — what's the split?"
   as an open question. It is still open.
5. **Network effects at n=1 are zero**, and the Network tab ships empty.
   The product has no day-one social job, so the loops have nothing to
   amplify.
6. **No cost side anywhere.** Runway and burn are unrecorded. "Fundable"
   has no denominator.

### The fundable number (unchanged, restated)

Week 0 = TestFlight live. By week 12: ≥10 coaches paying real money,
≥60% athlete attach, activation ≥40%, D30 ≥10–12%, organic k>0. Hit
those and the memo flips. Miss them and the honest path is bootstrap on
coach revenue — which also requires the gate to be paid.

---

## Part 3 — the fix plan

Ordered by what moves the two audits most per hour. Each item says ADD,
IMPROVE, or CUT.

### Wave A — this week, before any stranger sees it (product)

| # | Action | Type | Closes |
|---|---|---|---|
| A1 | **Load-suggestion reply in the offline brain.** "how much / what weight / next time / go up" + exercise → last logged load & reps, plan rule, a concrete number (last load + the plan's increment when all sets hit, same load otherwise, −10% after a "This hurts"). Unit-tested. | ADD | U1, investor #3 |
| A2 | **Starting-load seed.** Add bodyweight (optional, one field) to onboarding step "name" or the first console. Seed the big four from bodyweight × level (conservative tables, labelled "a starting guess — change it"). Reword the welcome promise to match what day one does. | ADD | U2 |
| A3 | **Rest countdown at the top of the console** the moment a set logs (compact bar under the title: "Rest 2:58 · skip"). Keep the big card below. | IMPROVE | U3 |
| A4 | **Toast placement**: below the status band, above content, solid backdrop; never over a title. One fix, every toast. | IMPROVE | U4 |
| A5 | **Hide the "Not saved yet" banner while the debrief sheet is up**; after save, retire the Train hint and the Today hint. | IMPROVE | U5, U11 |
| A6 | **Honest finish copy.** Header and Today card state what was logged ("Short day: 2 of 5 exercises, 3 sets — it counts"). Keep the celebration for consistency, not the session. | IMPROVE | U6 |
| A7 | **Orb inset**: every scroll view reserves bottom space for the orb; one orb design everywhere. | IMPROVE | U7 |
| A8 | **Share card preview** sheet → then the share sheet. | ADD | U8 |
| A9 | **Rename "New This Week" → "New in the library"** and rank the shelf by the user's sport; add `publishedAt` to the catalog schema so it can become true later. | IMPROVE | U9 |
| A10 | Voice hint per exercise type; Profile guide subtitle matches the 5 stops. | IMPROVE | U10, U11 |
| A11 | **Notification pre-prompt card** ("Morphe sends one reminder on training days and a nudge when a streak is about to break — nothing else") before the system dialog. | ADD | U13 |
| A12 | **Learn**: today's quiz + next, the rest collapsed. | CUT (visual) | U12 |

### Wave B — the 90-day window (business, mostly Lucas)

| # | Action | Type | Closes |
|---|---|---|---|
| B1 | **Pay the $99 today.** Every day after is negative information value. | — | investor #1 |
| B2 | **TestFlight with 10 real people within 72 h of approval**: 5 from the gym floor, 5 from the content audience. Weekly `metrics_report.py` into a cohort sheet from day one. | ADD | investor #1 |
| B3 | **Turn the Pro paywall on in TestFlight** at $5.99 / $39.99 with a "founding" badge; count views and taps even if StoreKit is sandbox. Price in front of a human beats a flag. | ADD | investor #2 |
| B4 | **Deploy the relay** (Blaze → secret → deploy). The online AI is the demo; the offline router is the fallback. | ADD | investor #3 |
| B5 | **Day-one social job for Network**: at the end of onboarding, "Train with someone?" → one invite link; the first board is created automatically with the user in it. Empty tabs teach "nothing here". | ADD | U14, investor #5 |
| B6 | **Coach pilot outreach: 20 coaches, written offer, $39/mo, 60-day pilot.** The fundable number is coaches, not consumer D30. | ADD | investor #3-5 |
| B7 | **Write the cost side**: runway, monthly burn, what the relay costs per active user. One page. | ADD | investor #6 |
| B8 | **Answer the split question in writing**: Morphe vs Checkmate vs HBPC — hours per week, kill triggers. Investors ask it in the first meeting. | ADD | investor #4 |

### Cut — not needed before launch (stop spending hours here)

| # | What | Why |
|---|---|---|
| C1 | More onboarding/tour copy passes by me | Lucas rewrites the wording himself (Sourcing Law). Any further AI pass is wasted twice. |
| C2 | Further reformat/visual waves on Today/Train | The frames are settled; what's left is the specific bugs in Wave A, not another layout. |
| C3 | Spartan lore / "From the Record" quote card on Learn | Zero retention value for a day-one user; keep the file, drop the card from the first screen. |
| C4 | Hey Morphe polish beyond "doesn't cut off, works on calls" | Done. Voice is a demo feature, not a retention feature, until the relay exists. |
| C5 | Merch and brand-kit work before a trademark knockout search | The timeline memory already flags Morphe Cosmetics; printing before the search is a self-inflicted risk. |
| C6 | Watch target work | No one in the first cohort will be on Watch. Freeze until D7 exists. |
| C7 | Any new feature not on this page | The July memo said it: further polish has negative information value compared to 25 strangers. Still true. |

### What I'd do in order (if I'm executing)

A1 → A3 → A4/A5 → A6 → A2 → A7/A8 → A9–A12, one commit per group, phone
install after each, then stop building until B1–B2 happen.
