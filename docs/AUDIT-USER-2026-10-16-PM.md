# Morphe — real-user audit, evening pass (2026-10-16)

Fresh install, local mode, a different user than this morning: **a boxer
who picked "Improve sport performance", Boxing, Intermediate, 4 days**.
Path: onboarding → welcome → Today → Start → Learn/Nutrition → Morphe AI.
Read-only; nothing changed.

## What works
- Onboarding is quick and every first tap lands (the morning fix holds).
- The console speaks rounds for timed work ("ROUNDS 0/1", "Start round
  1", "Say your round — done").
- The nutrition card says where its numbers come from and that photo
  numbers are estimates.
- Today leads with the plan card and Start; the welcome is a full screen.

## What's wrong (ranked)

| # | Finding | Why it matters | Fix |
|---|---|---|---|
| 1 | **The sport step pre-selects General Fitness and won't let you deselect it** ("Keep at least one sport selected"). The copy says the *first* pick becomes primary, so a boxer ends with **"Primary focus: General Fitness"** and Boxing second. | The whole plan keys off `sportMode`. Day one for a boxer was **"Dumbbell Lean-Out Circuit"** — no sport-specific session, though the review promised "2 sport-specific sessions". This morning's ranking fix can't help when the sport itself is wrong. | ✔ the first real sport replaces the General Fitness placeholder; tapping General Fitness again adds it back second |
| 2 | **"Improve sport performance" maps to the Lean Out + Strength Building catalog goals** (`catalogGoals`). | An athlete asking for performance gets fat-loss circuits ranked first. | ✔ performance/event → Strength Building only; the sport affinity supplies the sport's own work |
| 3 | **Morphe AI: "give me a boxing workout for today" → a Shadow Boxing form cue.** The offline brain knows "build me a push day" but not "give me a <sport> workout", so the technique matcher wins. | The library has 20 boxing workouts; the question is exactly what the AI is for. | ✔ "give/find/want/suggest… a <sport> workout" ranks the library for that sport at the athlete's level, stages it, and says how to start |
| 4 | **Nutrition shows "0 of 2,200 cal · 0 of 160 g" and, two lines down, "log your weight in Profile for targets."** | The 2,200 is a default, not a target; the honest-numbers brand can't show an invented goal next to a line saying there isn't one. | ✔ `NutritionTargets.isStarter`: the Fuel meters read "Calories · starter target", Today's tile "of 2,200 starter", and the carbs line says the numbers are generic starters until a weight is logged |
| 5 | **A 30-second mobility warm-up ("Arm Swings & Circles") is presented as "Round 1" with "Say your round — done".** The Kettlebell & Dumbbell category maps timed work to rounds. | A warm-up isn't a round; it reads as the app not knowing what the exercise is. | ✔ warm-up, mobility, stretch and circle names are holds whatever the category |
| 6 | **The AI composer sent the first keystroke as its own message** ("G"), leaving "ive me a boxing…" in the field. | If real, every first message from a cold composer is a one-letter message. | Did not reproduce on a second run (the full sentence typed and sent cleanly) — the simulator's first-input quirk, not the app. Closed. |
| 7 | **"Readiness check-ins" is promised on the review** — the day-0 app has no check-in on the plan. | A promise the first week doesn't keep. | ✔ the bullet is now "An evening check-in on training days" — the one that exists |

## Honest notes
- One of my taps missed (the profile avatar) and opened Quick Add instead;
  nothing in the report comes from that detour.
- The AI answer in #3 is the offline router; the online relay isn't
  deployed, so this is what every user sees until it is.
- #1 and #2 together mean **every sport athlete gets a General Fitness
  plan today**. That is the finding of this pass; the rest is polish.

## Order
1 → 2 → 3 (one wave, they share the ranking code) → 4 → 5 → 7; #6 is a
phone check, not a code change yet.
