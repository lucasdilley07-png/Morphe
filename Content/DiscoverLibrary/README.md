# Morphe Discover Library v2

112 hand-authored workouts across 10 training-style categories, each tagged
with one of four result goals. **Live in the app since 2026-07-14** — this
folder is the SOURCE of truth; `python3 Tools/build_catalog_v2.py` merges it
into `Resources/MorpheCatalog.json` (schema v2) and validates every exercise
reference. The 24 new exercises are in the library in `MorpheServices.swift`.
Edit here, rerun the build script, rebuild the app. Schema and authoring
rules live in [SPEC.md](SPEC.md).

## Goals

| Goal | Programming bias |
|---|---|
| `weightLoss` | circuits/intervals, high density, short rest |
| `strengthBuilding` | heavy 3–6 rep work at honest %1RM, long rest |
| `leanOut` | hypertrophy volume, RPE 7–9, short-to-moderate rest |
| `recovery` | mobility, timed stretches, RPE ≤ 4, never grindy |

Workouts in every file are ordered weightLoss → strengthBuilding → leanOut → recovery.

## Categories (112 workouts)

| File | Category | # | WL | SB | LO | RC | New exercises |
|---|---|---|---|---|---|---|---|
| strength-powerlifting.json | Strength & Powerlifting | 11 | 2 | 6 | 2 | 1 | — |
| bodybuilding-hypertrophy.json | Bodybuilding & Hypertrophy | 12 | 2 | 5 | 4 | 1 | — |
| calisthenics-bodyweight.json | Calisthenics & Bodyweight | 11 | 3 | 4 | 3 | 1 | 3 |
| hiit-conditioning.json | HIIT & Conditioning | 12 | 6 | 2 | 3 | 1 | — |
| functional-crossfit.json | Functional & CrossFit-Style | 11 | 3 | 4 | 3 | 1 | 2 |
| kettlebell-dumbbell.json | Kettlebell & Dumbbell | 11 | 3 | 4 | 3 | 1 | 5 |
| running-cardio.json | Running & Cardio | 11 | 4 | 2 | 3 | 2 | — |
| boxing-combat.json | Boxing & Combat Conditioning | 11 | 4 | 2 | 4 | 1 | 3 |
| yoga-mobility.json | Yoga, Mobility & Flexibility | 11 | 2 | 1 | 3 | 5 | 8 |
| recovery-longevity.json | Recovery & Longevity | 11 | 2 | 2 | 2 | 5 | 3 |

Every exercise prescribes sets, reps (or a timed duration), rest, and an
honest intensity: `percent1RM` on barbell/machine lifts only, `rpe` on
dumbbell/kettlebell/cable work, `heartRateZone`/`maxEffort` on cardio,
`bodyweight` on calisthenics and stretches.

## New exercises pending form diagrams (24)

Each carries the full `ExerciseReference` shape plus a `formGuide` block with
a written description and a `diagramPrompt` ready for image generation.

- **Boxing**: jab-cross-combo, boxer-slip-and-roll, heavy-bag-rounds
- **Calisthenics**: scapular-pull-up, pull-up-negative, wall-handstand-hold
- **Functional**: wall-ball-shot, sandbag-to-shoulder
- **KB/DB**: kettlebell-goblet-clean, kettlebell-turkish-get-up, kettlebell-halo, dumbbell-thruster, dumbbell-snatch
- **Yoga**: downward-dog, cobra-pose, pigeon-pose, warrior-two, warrior-three, chair-pose, crescent-lunge, supine-twist
- **Stretches**: standing-quad-stretch, figure-four-stretch, cross-body-shoulder-stretch

The 97 existing library exercises already have instructions/formCue/video
placeholders in `MorpheServices.swift`; only these 24 need new entries.

## Validation

Run the cross-file checker before merging catalog changes — it verifies JSON
shape, enum values, exercise references, goal ordering, unique slugs, intensity
ranges, and form-guide completeness. (Current copy lives in the session
scratchpad as `validate_library.py`; move it into `Tools/` when this content
gets wired into the app.)

## Wiring status (landed 2026-07-14)

1. ✅ 24 `newExercises` added to the exercise library in `MorpheServices.swift`.
2. ✅ `CatalogWorkout.CatalogExercise` carries `intensity`, `restSeconds`,
   `durationSeconds` (schema v2) in `WorkoutCatalog.swift`.
3. ✅ 10 files merged into `Resources/MorpheCatalog.json` via
   `Tools/build_catalog_v2.py` (deterministic UUID5 ids, `v2:<slug>`).
4. ✅ Discover browses by category with a goal-chip lens.
5. ✅ 24 form diagrams generated (2026-07-15) from each JSON's
   `newExercises[].formGuide.diagramPrompt` → `FormDiagrams/<exercise-id>.png`
   (1K square, Nano Banana Pro, consistent style: gray figure on charcoal,
   gold accent cues). Not yet bundled into the app — the form guide screen
   still shows `videoPlaceholder`; wiring the images in is the next step.
