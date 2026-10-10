# Simplification & coordination pass — plan + dispositions (2026-07-31)

Three user-lens audits (density/hierarchy, interaction grammar,
duplicate doors/engagement). Constraint: no feature loss — consolidate,
demote, one-door. Status updated as fixes land.

## ENGAGEMENT (highest leverage)
- E1 CRITICAL: notification permission requested ONLY in appointment
  scheduling → solo users get ZERO retention notifications. FIX: shared
  permission request fired at first workout log; reminders refresh after.
- E2 No daily workout reminder exists. FIX: one "next session" reminder
  (5pm, skips logged days) scheduled on log/launch, off switch in prefs.
- E3 No tomorrow-hook after day-1 log. FIX: TodayDoneCard names the next
  session + confirms the reminder.
- E5 logWorkout yanks user to Progress tab. FIX: stay in place;
  celebration + Today's done-card carry the moment.
- E7 Network camera opens Form Check contextless. FIX: pass the active
  exercise when a session is live.
- E8 QuickAdd "Log Workout" = third door to same button. FIX: remove tile.
- E9 QuickAdd "Browse Exercises" lands on Learn library (not Discover).
  FIX: rename "Exercise Library".
- E11 Network hosts a full second board+challenges UI. FIX: slim
  "you're #N — see the board" chip deep-linking to Progress.
- E12 Challenge join celebration is terminal. FIX: land on Progress
  compete after join.
- E4 DEFERRED: rest-day hero needs a day-level schedule model (only
  days-per-week exists) — product decision.
- E13 DEFERRED: search-result teleport (works, toast explains).
- E14 REJECTED after verify: tier-0 check-in card and tier-1 planner
  are mutually exclusive (tier gates), can't coexist.

## DENSITY
- D1 Progress tier-2 = ~18 cards, 10 study-charts flat. FIX: keep hero/
  Strength/TrainedDays/PRTimeline visible; rest behind "Deep Stats"
  disclosure.
- D2 Profile settings = 19-row monolith. FIX: five grouped cards
  (Account / Training / Sharing & Privacy / Health / Data & Account).
- D3 Post-finish review renders planning page underneath. FIX: review
  state suppresses planning cards; Log Workout stands alone.
- D4 DailyCheckInPlannerCard = 13 controls at once. FIX: confidence
  first, Plan-B options disclosed on "not confident".
- D5 todayWinText repeats the hero's job. FIX: habit-only copy.
- D7 Today tail = 3 look-alike link cards. FIX: merge PlanBy+Goal into
  one context card.
- D8 Feed legend caption permanent. FIX: tap-to-reveal info button.
- D9 Discover: QR connect card leads catalog + 4-control filter row.
  FIX: connect card below grid; filters behind "Filters (N)" expander.
- D10 Hero carries 4 CTAs at tier 1+. FIX: assist chips demoted to the
  AI pill (same answers live there); hero = Start + Switch.
- D-x Circuit Mode floats naked mid-session. FIX: into Session tools.
- D6 DEFERRED: 6→5 tabs (demote Discover) — contradicts Lucas's own
  explicit tab/page spec; his call.

## GRAMMAR
- G2 Coach "Done" renders system BLUE (unstyled) — one-liner.
- G4 Deleting your own post/comment = one tap, NO confirm (while
  reversible block confirms). FIX: confirmation dialogs.
- G1/G8 Dismiss grammar: 5 forms, word drift. FIX: editors say Done
  (white), viewers Close; kill off-pattern X squares where cheap.
- G3 Back affordance: breadcrumb vs bare circles (2 sizes). FIX:
  shared HUDBackRow, convert circles.
- G5 Sport selection uses 3 different controls (one off-palette).
  FIX: SportModeSelector chips everywhere.
- G6 Destructive confirms split alert vs dialog. FIX: confirmationDialog
  for all destructive.
- G7 Fetch-state pair used on ONE surface of a dozen. FIX: comments +
  auth spinner adopt house idiom (board/challenges already have states).
- G10 Two hand-rolled section headers. FIX: SectionTitleView.
- G9/G11 DEFERRED: dismiss-style extraction + spacing-token migration
  (~1,460 magic gaps — grew since July; schedule as background debt).

## Debt-tier closeout (2026-08-01)
- W/SS tag legend: SHIPPED (one line in Session tools).
- G10 hand-rolled headers: VERIFY-REJECTED — one is already shared
  chrome (sectionHeader func), the other a deliberate compact variant;
  converting would change semantics for zero user value.
- B20 CHATS/FOR YOU purpose copy: REJECTED as covered — both panes'
  empty states already name their purpose; adding permanent captions
  re-clutters what the density pass just cleaned.
- G11 spacing migration: stays parked deliberately — a week of
  mechanical churn with regression risk and no user-visible payoff
  pre-launch. Revisit post-TestFlight.

Verified-status legend maintained in commits.
