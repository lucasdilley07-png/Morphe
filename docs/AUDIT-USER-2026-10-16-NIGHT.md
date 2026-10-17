# Morphe — real-user audit, night pass (2026-10-16)

Third user of the day: **a beginner runner who wants to lose weight, 3
days a week.** Fresh install, local mode: onboarding → welcome → Today
(the new strip + sticker) → Start → first exercise. Read-only except one
layout fix noted below.

## What works
- Onboarding holds: every first tap lands, the sport placeholder gives
  way to Running, the review banner reads ENDURANCE BUILD / Running.
- The identity strip reads as a greeting: MORPHE ONLINE · @handle, four
  tiles rolling up, then the question, then Start. The order is right.
- The glass calendar sticker reads as a magnet at a glance; drag works.
- The electric sweep is subtle enough to miss on the first pass and
  catches the eye on the second — that's the brief.
- A beginner HIIT session opens on a 60 s Cat-Cow hold with the clock
  and one button. Nothing to decide.

## What's wrong (ranked)

| # | Finding | Why it matters | Fix |
|---|---|---|---|
| 1 | **The sticker's default spot overlaps the @handle.** With a long handle (@verifyathlete55) the magnet sits on the last characters of the kicker. | Shipped today; a long name hits it on day one. | ✔ parked level with the greeting line and the greeting block keeps a 56pt gutter on both sides when the sticker is shown |
| 2 | **The review promises things the app doesn't track.** "Lose weight" lists *7,000 steps per day* and *Weekly weigh-in* — Morphe reads no step count and has no weigh-in flow (there's a free-text weight field in Profile). | Same class as this evening's "Readiness check-ins": a promise the first week can't keep, on the honesty brand. | Drop *7,000 steps per day*; make *Weekly weigh-in* read "Log your weight in Profile" or wire a real weekly reminder. |
| 3 | **Three empty tiles on day one.** READINESS —, ENERGY —, SCORE 0. The strip is meant to feel over-powered; a fresh account reads as "nothing here yet". | First impression of the feature. | On day one replace the dashes with a one-tap "Check in" pill in the READINESS tile (the sheet is a 20 s form) and let SCORE say "day 1" instead of 0 / rebuilding. |
| 4 | **The "This is Today" hint pushes Start below the fold** on a 6.1" phone (it's 150pt tall). | This morning's #5 fix put the plan card first; the hint undoes it on a fresh account. | Collapse the hint to one line with a `+` or show it under the plan card. |
| 5 | **"Today's workout is ready in Train" toast fires on the Train page**, over the search button. | The user just tapped Start; the toast tells them what they're looking at. | Skip the toast when the Train tab is already selected. |
| 6 | **HOLDS 0/1 for a 60 s Cat-Cow.** Correct by the unit rules, but "1 hold · 60 sec" above "HOLDS 0/1" is the same fact twice, and a mobility drill isn't held. | Reads like the app counting itself. | Hide the unit pill when the target is 1; call mobility work a "flow" (the hold unit already covers stretches — add a `flow` label for cat-cow / inchworm / world's greatest). |
| 7 | **Morphe AI orb covers the voice bar's right edge** on Train. | The 98pt clearance clears the tab bar but not the pinned voice bar. | Reserve the orb's footprint in the voice bar's trailing padding, or lift the orb above it on Train. |
| 8 | **"Say your hold — done"** is right for a round; for a hold the clock stops it. | Minor copy. | Holds: "Say "done" to stop the clock". |

## Honest notes
- #1 is mine from an hour ago — the handle gutter wasn't tested with a
  long handle. Fixed in this pass, not yet pushed.
- The sweep timing (every 2–3 min) can't be verified in a short walk;
  only the first pass was observed.
- Nothing was logged, so the finish sequence and the streak sheet's week
  read weren't re-checked tonight (both verified earlier today).

## Order
1 (done) → 2 → 3 → 4 → 5 → 7 → 6 → 8. Items 2–5 are an hour; 6 is a
small model change; 7 is layout.
