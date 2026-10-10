# Morphe — UI / UX / Feature Audit (2026-07-27)

Third audit in the set (engineering: AUDIT-2026-07, brand: BRAND-AUDIT-
2026-07). Lens: a senior app developer reviewing craft — information
architecture, interaction states, accessibility, performance, and core-
loop feature depth vs Hevy/Strong/Fitbod. Method: three parallel code
sweeps (IA/flows, states/polish/a11y, live-logging inventory).

---

## Verdict

The core loop is genuinely competitive where it counts: **1 tap from
"Start" to a logged set, 1 tap to repeat a set**, a real ActivityKit
rest timer with Dynamic Island, hold-to-ramp steppers, inline plate
math, RPE-driven progression suggestions, and ~81 haptic call sites.
The shell animations are tasteful and the visual system is disciplined.

Three structural debts hold the app below its ceiling:

1. **The app has no navigation stack.** Zero `NavigationLink`s and zero
   `navigationDestination`s — all depth is 60 modals plus in-place
   state swaps. That means no edge-swipe-back anywhere, custom back
   buttons, sheet-on-sheet fragility (with 0.6s-delay workarounds in
   code), and two flat-out dead ends (feed post → author profile,
   PR row → exercise history).
2. **Async states don't exist.** The whole social/competition layer
   fails silently: feed/leaderboard/challenges/referral fetches swallow
   network errors, there are no loading indicators for background
   fetches, and empty states render *during* the first fetch ("be the
   first to post" flashing before content pops in).
3. **System accessibility is unhandled.** Dynamic Type: zero support,
   55 fixed font sizes. Reduce Motion: zero handling. Destructive
   28×28pt tap targets in the live session.

None of these are hard to fix, and all three are the kind of thing App
Review, TestFlight testers, and power users hit in the first session.

---

## What's already strong (don't touch)

- 1-tap repeat-set fast path; hold-to-repeat steppers with ramp
  (WorkoutView.swift:1657-1695)
- Rest timer auto-start + Live Activity/Dynamic Island wall-clock sync
- Haptics coverage (~81 sites) and the two synthesized sound cues
- Tab-shell transitions, celebration/stamp springs (RootView:260-268)
- LazyVStack in long lists; no oversized fixed frames in layouts
- Draft auto-save of an in-progress set; discard confirmation shows
  the logged-set count
- Deterministic progression notes ("Morphe suggests +5 — last time
  felt easy")

---

## P0 — before TestFlight (each is hours-to-a-day, high user impact)

**1. Let athletes edit and delete their own finished workouts.**
Today a logged workout is immutable for the athlete (history is
display-only, ProgressView:1769-1804; edit/delete exists coach-side
only in JournalScheduleView:261-279). Fat-fingered 500-lb bench stays
forever — which corrupts PRs, e1RM, and the honesty story. Table
stakes in every competitor. Reuse the coach-side edit path with an
athlete-owns-their-log rule.

**2. Show "last time" on the live console.**
The signature tracker feature. `lastSessionWeight` only reads the
current session (MorpheStore:5629-5631); prior-session reps×weight
never render. Add one muted mono line per exercise — "LAST: 3×8 @
185 LB" — sourced from the same logs the progression engine reads.
Cheap, and it makes every suggestion legible.

**3. Async state machine for the social layer.**
One enum (idle/loading/loaded/empty/failed) driven by the store for
feed, leaderboard, challenges, referral count. Failed gets a retry
row + error haptic; loading gets redacted placeholder cards; empty
copy only renders in a true empty. Kills the silent-failure pattern
(refreshFeed MorpheStore:8391 and friends) and the fake-empty flash
(ChatView:1439, ProgressView:1886).

**4. Fix sub-44pt targets in the live session.**
Edit/delete-set at 28×28 (WorkoutView:1445,1457), plus 26-36pt
buttons in Progress/Home. `.frame(minWidth:44,minHeight:44)` +
`.contentShape` — a mechanical pass.

**5. Make "Finish Session" safe.**
Finish doesn't persist; the log only lands after a second "Log
Workout" tap several cards later (WorkoutView:947 → 502-506). A user
who leaves after Finish silently loses the session. Either persist a
draft log at Finish (upgraded by the second tap) or collapse to one
commit with the recap cards after.

**6. Reconnect the dead ends — the pieces already exist.**
- Feed author → profile: avatar/name have no tap target
  (ChatView:1583-1648) while `NetworkProfilePreviewSheet` sits built
  but flag-gated. Wire the tap.
- PR row → that exercise's StrengthOverTime chart (pre-select the
  picker, ProgressView:1388 vs 1049).
- `UniversalSearchSheet` is fully built with zero callers
  (RootView:1104-1423, opener MorpheStore:6529) — give it an entry
  point (search icon in the header) or delete it. Shipping dead code
  you already paid for is the worst of both.

---

## P1 — the level-up wave (days each; do before/during early TestFlight)

**7. Introduce a real NavigationStack for drill-ins.**
Keep tabs + the live session as-is, but make Discover→detail,
feed→profile, Progress→exercise history genuine pushes. Restores
edge-swipe-back, kills custom back buttons, and lets you retire the
most fragile sheet nesting (the 0.6s AI-cover delay, per-sheet
EmptyView isolation, WorkoutView:65-73). Migrate incrementally —
one tab at a time.

**8. Accessibility floor: Dynamic Type + Reduce Motion.**
- Swap the 55 fixed `.font(.system(size:))` (33 in GlassCard.swift)
  to `@ScaledMetric`-backed or text-style-relative fonts. HUD numerals
  can cap at `.accessibility2` to protect layouts.
- Gate springs/scale transitions and the grid overlay behind
  `@Environment(\.accessibilityReduceMotion)`.
- Coach dashboard VoiceOver pass (5 labels across 4,109 lines).
- Yellow-on-black is good contrast, but add non-color state signals
  where color alone differentiates.

**9. Console ergonomics parity.**
- Tap the weight/reps value to type (decimal pad inline, not just in
  the More sheet).
- Warm-up set type: a per-set warm-up/working flag that excludes
  warm-ups from PR/e1RM math — honest-engineering relevant, since
  today a heavy warm-up single could be indistinguishable.
- True superset grouping (linked A1/A2 alternation) instead of
  label-encoded supersets; keep the label path for dropsets v1.
- Let swap show its alternatives as tappable choices — the list is
  already computed; `swapExercise` just auto-picks first
  (MorpheStore:5996-6028).

**10. Performance pass (one afternoon).**
- Move ShareCardRenderer + UIGraphicsImageRenderer off the main
  thread (GlassCard:1931; ProfileView:622) — the share moment
  currently hitches, and it's the growth loop.
- Memoize ProgressView aggregates; never allocate DateFormatter in a
  body-computed property (ProgressView:100,180). Cache keyed on
  logs.count/latest-date.
- Animate data arrival: wrap feed/board/challenge assignment in
  `withAnimation`, add `.transition(.opacity)` on cards.

**11. Tame the AI pill and the entry-point sprawl.**
- The "Morphe AI" capsule overlaps bottom-right content on 5 of 6
  tabs (compact-only in Train, RootView:548). Compact it everywhere
  after first use, or reserve a bottom gutter.
- Collapse start-workout verbs: "Start" and "Queue" side by side in
  the Discover sheet confuse (WorkoutView:2955/2964) — rename Queue
  to "Stage for Today" or demote it into a menu.
- Pick ONE canonical messaging door per role; make the others route
  to it.

**12. Onboarding trim.**
- Fix "STEP 0 / 12" (index vs count, OnboardingView:289).
- Cut the ceremony after Create Plan: the 2.1s scripted loading +
  Welcome sheet are two gates before first value — fold the welcome
  content into Today's first-run hero (the FirstWeekCard already
  exists).
- Consider deferring username claim to first social action; it's the
  only network-blocking step mid-onboarding (OnboardingView:312-326).

---

## P2 — depth features (post-launch, prioritized by pilot feedback)

- Per-set notes + RIR option alongside RPE chips
- Plate/bar configuration (per-exercise bar weight, plate inventory;
  today barbell detection is a name substring, WorkoutView:1355-1362)
- Library search + folders/collections (only source filters today)
- Session-time PR/e1RM feedback ("this set = est. 1RM 245, +5")
  — mind the Pro paywall boundary for e1RM
- Rest timer: +15s/skip actions on the Live Activity
- Drag-handle reorder (arrows only today); insert/delete animations
- Mid-session add-exercise: bring the muscle-group filter + custom
  creation the builder picker already has (WorkoutView:1823 vs 5709)
- Editable session duration + optional free-text session note at
  finish
- Spacing-token adoption sweep (tokens defined, zero uses vs 366
  magic paddings, MorpheTheme:35-47) — mechanical, do it gradually
  per-file with any other change
- iPad/size-class pass once phone UX settles

---

## Suggested sequencing

Week 1 (pre-TestFlight): P0 items 1-6.
Week 2-3 (early TestFlight): P1 items 8, 9, 10 — testers will file
Dynamic Type and "can't edit my log" first.
Then: 7 (NavigationStack migration, incremental) and 11-12 informed
by real usage, P2 by pilot demand.

The through-line: the app's *identity* (honest data, HUD look, 1-tap
logging) is already right. The level-up is making the system around
that identity behave like the rest of iOS — real navigation, real
states, real accessibility — and closing the three or four core-loop
gaps a Hevy user checks in their first workout.
