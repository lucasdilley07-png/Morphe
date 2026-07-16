# Morphe Discover Library v2 — authoring spec

Content-as-data for the next Discover catalog. NOT yet wired into the app.
Each category ships as one JSON file in this folder. A build step will later
merge these into `Resources/MorpheCatalog.json` (schema v2) and new exercises
into the exercise library in `MorpheServices.swift`.

## File shape

```json
{
  "version": 2,
  "category": "Strength & Powerlifting",
  "workouts": [ ... ],
  "newExercises": [ ... ]
}
```

## Workout shape

```json
{
  "slug": "strength-sb-heavy-lower-a",       // kebab-case, unique, prefixed by category shorthand
  "name": "Heavy Lower A — Squat Day",
  "goal": "strengthBuilding",                 // weightLoss | strengthBuilding | leanOut | recovery
  "focus": "Legs",                            // Full Body | Push | Pull | Legs | Core | Conditioning | Recovery
  "trainingType": "Strength training",
  "level": "Moderate",                        // Recovery | Beginner | Moderate | Advanced
  "durationMinutes": 60,
  "equipmentProfile": "Full Gym",             // Bodyweight | Dumbbells | Full Gym
  "notes": "1-2 sentence coach note: who this is for, what result it drives, how to progress.",
  "exercises": [
    {
      "libraryID": "barbell-back-squat",
      "sets": 5,
      "reps": 5,                              // OR "durationSeconds": 45 for timed work (never both)
      "intensity": { "type": "percent1RM", "value": 80 },
      "restSeconds": 180
    }
  ]
}
```

`workouts` array MUST be ordered by goal: all weightLoss, then strengthBuilding,
then leanOut, then recovery (a category may have zero of a goal if it truly
doesn't fit, but spread across at least 3 goals).

## Intensity types (be honest — no fake precision)

- `{"type": "percent1RM", "value": 80}` — ONLY for barbell/machine lifts where a 1RM is real (squat, bench, deadlift, OHP, rows, leg press, etc.)
- `{"type": "rpe", "value": 8}` — dumbbell/kettlebell/cable work (RPE 1–10)
- `{"type": "bodyweight"}` — calisthenics, planks, stretches
- `{"type": "heartRateZone", "value": 2}` — steady cardio (zones 1–5)
- `{"type": "maxEffort"}` — sprint/HIIT intervals

## Programming standards (results-first, evidence-based)

- Strength: 3–6 sets of 3–6 reps @ 75–90% 1RM, rest 150–240s, compounds first.
- Hypertrophy/lean out: 3–4 sets of 8–15 reps @ 60–75% 1RM or RPE 7–9, rest 60–120s.
- Weight loss: circuits/intervals, higher density, rest 30–90s, big movements.
- Recovery: RPE ≤ 4, stretches use durationSeconds, level = "Recovery".
- 4–8 exercises per workout. Warm-up movements allowed as first 1–2 entries.
- Duration must be plausible for the sets×rest prescribed.

## Exercise references

`libraryID` MUST come from this list (the app's real exercise library):

arm-swing-circles, arnold-press, back-extension, barbell-back-squat,
barbell-bench-press, bear-crawl, bent-over-row, bicep-curl, bicycle-crunch,
bird-dog, bodyweight-squat, box-jump, broad-jump, bulgarian-split-squat,
burpee, cable-crossover, cable-curl, cable-lateral-raise, calf-raise, cat-cow,
chest-doorway-stretch, chest-supported-row, childs-pose, chin-up,
close-grip-bench-press, concentration-curl, conventional-deadlift, dead-bug,
decline-push-up, diamond-push-up, dip, dumbbell-bench-press,
dumbbell-chest-fly, dumbbell-row, dumbbell-shrug, face-pull, farmer-carry,
front-raise, front-squat, glute-bridge, goblet-squat, hammer-curl,
hamstring-curl, hanging-knee-raise, high-knees, hip-flexor-stretch,
hip-thrust, hollow-hold, incline-dumbbell-press, incline-push-up,
inverted-row, jump-rope, jump-squat, jumping-jack, kettlebell-swing,
lat-pulldown, lateral-raise, lateral-shuffle, leg-extension, leg-press,
machine-chest-press, mountain-climber, overhead-cable-extension,
overhead-press, overhead-tricep-extension, pike-push-up, plank,
preacher-curl, pull-up, push-up, rear-delt-fly, reverse-lunge,
romanian-deadlift, rowing-machine, russian-twist, seated-cable-row,
seated-dumbbell-press, shadow-boxing, shoulder-press, side-plank,
single-leg-glute-bridge, single-leg-rdl, sit-up, skater-jump, skullcrusher,
sprint-interval, standing-hamstring-stretch, stationary-bike, step-up,
straight-arm-pulldown, sumo-deadlift, thread-the-needle, treadmill-walk,
tricep-pushdown, v-up, walking-lunge, wall-sit, worlds-greatest-stretch

If a category genuinely needs an exercise not in the list (e.g. downward dog,
boxer's jab-cross combo, kettlebell clean), add it to `newExercises` with the
FULL form-guide shape below and reference its new kebab-case id from workouts.
Prefer library exercises; only add what the category can't work without.
Keep newExercises ≤ 10 per file.

## newExercises shape (matches ExerciseReference + form guide)

```json
{
  "id": "downward-dog",
  "name": "Downward Dog",
  "muscleGroup": "Core",              // Chest | Back | Legs | Shoulders | Arms | Core | Conditioning
  "movementPattern": "Hinge + overhead reach",
  "musclesWorked": "Hamstrings, calves, shoulders, lats",
  "equipment": "None (mat optional)",
  "difficulty": "Beginner",           // Recovery | Beginner | Moderate | Advanced
  "videoPlaceholder": "demo-downward-dog",
  "instructions": ["Step 1 ...", "Step 2 ...", "Step 3 ...", "Step 4 ..."],
  "formCue": "One short cue you'd shout across a gym.",
  "commonMistakes": "The 1–2 mistakes that ruin the movement.",
  "beginnerModification": "How to regress it.",
  "alternatives": ["cat-cow", "childs-pose"],
  "whyThisMatters": "One sentence on the payoff.",
  "formGuide": {
    "description": "2–3 sentence plain-English walkthrough for the form guide screen.",
    "diagramPrompt": "Prompt to later generate the demonstration diagram/image."
  }
}
```

`formGuide.diagramPrompt` is the placeholder for the diagram/image demo the
app will add later — write it as a concrete image-generation prompt
(viewpoint, body position, what to highlight).

## Goal meanings

- weightLoss — maximize energy expenditure & adherence; circuits, intervals, big movements.
- strengthBuilding — add kilos to main lifts; heavy, low-rep, long rest.
- leanOut — keep/build muscle while dropping fat; hypertrophy volume + short rest / finishers.
- recovery — restore: mobility, blood flow, low intensity; never grindy.
