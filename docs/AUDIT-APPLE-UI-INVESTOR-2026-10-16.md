# Morphe — Apple-UI audit + investor re-read (2026-10-16, evening)

Walked live on a fresh install (iPhone 17 Pro Max simulator, local mode):
welcome → Today → Train console → Discover → Network → Learn, in light
mode, dark mode, and at the XXXL Dynamic Type size. Judged against the
Human Interface Guidelines and the standing design canon
(`~/.claude/memory-shared/app-design-canon.md`). Then re-read as an
investor against this morning's audit. The three clear defects were fixed
in the same wave (marked ✔).

---

## Part 1 — as an Apple UI reviewer

### What passes the bar
- **One accent, consistent components.** Every CTA is the same blue
  capsule; secondary actions are outlined capsules; chips, cards and
  pills share one radius. Law 8 holds.
- **The console is a one-tap surface.** Reps stepper, one Log button,
  rest auto-starts and now shows at the top, "This hurts" one tap away.
  The two-moments rule holds during effort.
- **Dark mode is first-class** — nothing inverts wrong, imagery (helmet,
  orb) has light/dark variants, accent text stays legible.
- **Dynamic Type at XXXL**: titles, body, buttons and the rep count all
  scale and reflow; nothing clips or overlaps; the tab bar stays reachable.
- **Honest empty states** (Network board, History, Library) with one
  action each.
- **Sheets and alerts are native** (presentation detents, drag indicator,
  system alert for the food check, system notification dialog after the
  app's own pre-prompt).

### Defects (ranked)

| # | Finding | HIG reference | Status |
|---|---|---|---|
| 1 | **Dark-mode cards were invisible.** Panels sat at 4.5% blue over the #121214 canvas; card edges at 8%. Apple's dark secondary surface sits ~11% above its background so groups read without borders. | Color → Dark Mode; Layout → grouping | ✔ panel 10%, strong 15%, raised 20%, stroke 26% |
| 2 | **Micro labels didn't scale.** REPS / SETS / BODYWEIGHT / tab labels were sized once via `UIFontMetrics` at launch, so at XXXL the console's body text tripled while its labels stayed 10pt. | Typography → Dynamic Type; 11pt floor | ✔ text-style fonts (caption2 / caption) |
| 3 | **Discover's lead shelf ignored the athlete's level.** A Beginner, General Fitness profile opened "New in the Library" on two ADVANCED bike sessions. | Content → relevance before novelty | ✔ own level first, then the rest |
| 4 | **Welcome page is a sheet, not a screen.** Apple's welcome component is full-screen; here the grey status strip above the rounded top reads as a half-dismissed modal. | Modality → use sheets for tasks, not arrivals | ✔ `fullScreenCover` |
| 5 | **Today stacks four cards before the primary action.** Greeting, hint, streak, then the plan card with Start; on a 6.1" phone Start is at the fold. | "One screen, one verb"; Layout → primary content first | ✔ streak row moved below the plan / done card |
| 6 | **The floating Morphe AI button covers content** — the Progress tile on Today, the EXERCISE 1/5 badge on Train, the last Discover row. Apple's own floating controls reserve a bottom inset. | Layout → safe areas | ✔ 60pt bottom safe-area padding on every tab |
| 7 | **Tab bar is a custom capsule with mono uppercase labels.** It works and it's on-brand, but it isn't `TabView`, so it loses iOS 26's Liquid Glass behaviour, VoiceOver's tab-bar trait, and the system's own Dynamic Type handling. | Components → Tab bars | ✔ system `TabView` bar (Liquid Glass on iOS 26, VoiceOver tab trait, Dynamic Type labels, keyboard avoidance) |
| 8 | **Goals tile truncates every item** ("Walk 10 minu…"). | Writing → never truncate what the user wrote | ✔ two goals in full (up to 3 lines each), then "+N more" |
| 9 | **Learn has four hierarchy levels** on one screen (segmented tabs, a quote card, a card grid, two disclosures). | Layout → hierarchy | ✔ quote card removed from Learn; The Code stays behind the rank row on Profile |
| 10 | **Toast covers the search button for 2 s.** Chosen over covering titles; still not Apple's pattern (Apple uses a status-bar pill or inline confirmation). | Feedback | accept for now |

### Verdict
Ship-quality on structure, components and accessibility. Items 1–9 are
fixed and verified in the simulator; 10 is accepted.

---

## Part 2 — as an investor (delta since this morning)

What changed in one day, all verified running: the onboarding rebuilt to
the reference pattern, Wave A (12 fixes), the food-check gate, round/run
work units with a clock, the Apple-UI fixes above, 450 tests green.

What did not change: **the $99 gate is still unpaid, the relay is still
not deployed, and the stranger count is still zero.** Everything in
Part 1 is polish on an app no outsider has opened. The verdict is the
morning's verdict, and the pattern it named — polishing while blocked —
got one more day of evidence today. The build is now a better build to
put in front of ten people; it is not a reason to delay putting it there.

The three things an investor would ask for this week, unchanged:
1. TestFlight with 10 real people (needs the $99).
2. A price in front of a human (the Pro paywall on in TestFlight).
3. The coach pilot offer sent to 20 coaches.

---

## Sources
- Apple HIG: Dark Mode, Typography (Dynamic Type), Layout, Modality, Tab
  bars, Feedback — current pages via the HIG mirror used this morning.
- Design canon: `~/.claude/memory-shared/app-design-canon.md` (10 laws).
- Morning audit: `docs/AUDIT-USER-INVESTOR-2026-10-16.md`.
