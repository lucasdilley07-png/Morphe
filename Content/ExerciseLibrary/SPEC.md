# Morphe Technique Library (v3) — authoring spec

The exercise library grows as content-as-data. Each discipline ships one JSON
file in this folder; `python3 Tools/build_catalog_v2.py` merges them into
`Morphe/Resources/MorpheCatalog.json` under `exercises`. The 194 original
exercises stay in `Morphe/Core/MorpheServices.swift`; their ids and names are
listed in `existing-library.tsv` — never duplicate one of them.

## File shape — `Content/ExerciseLibrary/<discipline-slug>.json`

```json
{
  "discipline": "Olympic Weightlifting",
  "exercises": [ { ... }, { ... } ]
}
```

`discipline` must be exactly one of:

Strength & Powerlifting · Olympic Weightlifting · Bodybuilding & Hypertrophy ·
Calisthenics & Bodyweight · Kettlebell & Dumbbell · HIIT & Conditioning ·
Functional & CrossFit-Style · Strongman & Odd-Object · Running & Cardio ·
Cycling, Rowing & Swim · Boxing & Combat Conditioning · Dance & Aerobics ·
Sport Performance · Yoga, Mobility & Flexibility · Pilates & Core Control ·
Barre & Low-Impact · Recovery & Longevity

## Exercise shape

```json
{
  "id": "hang-power-clean",                  // kebab-case, globally unique, NOT in existing-library.tsv
  "name": "Hang Power Clean",                // unique display name
  "variationOf": "power-clean",              // optional: id of the base movement (existing or new) this is a variation of
  "muscleGroup": "Legs",                     // Chest | Back | Legs | Shoulders | Arms | Core | Conditioning
  "movementPattern": "Hinge",                // see list below
  "musclesWorked": "Glutes, hamstrings, traps, upper back",
  "equipment": "Barbell",
  "difficulty": "Advanced",                  // Recovery | Beginner | Moderate | Advanced
  "instructions": ["Step 1.", "Step 2.", "Step 3.", "Step 4."],   // 3–5 steps, each one sentence, setup → execution → finish
  "formCue": "One short cue a coach would say mid-set.",
  "commonMistakes": "The 1–2 faults that most often ruin it.",
  "beginnerModification": "How to regress it.",
  "alternatives": ["Kettlebell Swing", "Power Clean"],            // 1–3 exercise NAMES that exist (existing-library.tsv or this wave)
  "whyThisMatters": "One sentence on the payoff.",
  "source": {
    "name": "USA Weightlifting",             // the organisation / publication the technique was checked against
    "url": "https://..."                     // a page you ACTUALLY opened or saw in search results this session
  }
}
```

### movementPattern

Use one of these where it fits (the camera Form Check reads them): `Squat`,
`Hinge`, `Split stance`, `Push`, `Press`, `Pull`, `Curl`, `Raise`, `Jump`,
`Brace`, `Rotation`, `Loaded carry`, `Crawl`, `Sprint`, `Conditioning`,
`Striking / footwork`, `Static stretch`, `Dynamic stretch`, `Accessory`.
Anything else is allowed when none fits (e.g. `Balance`, `Flow`).

## Sourcing law (non-negotiable)

1. Every exercise is CHECKED AGAINST a real coaching source you looked up this
   session: certifying bodies and federations (NSCA, ACE, NASM, ACSM, USA
   Weightlifting, USA Boxing, StrongFirst, IPF/USAPL, World Athletics, Pilates
   Method Alliance, Yoga Alliance, CrossFit, US Rowing, USA Swimming, British
   Cycling…), established coaching references (ExRx.net, ACE Exercise Library,
   NASM exercise library, Catalyst Athletics, Stronger By Science, Yoga
   Journal, Physiopedia), or peer-reviewed/position-stand material.
2. `source.url` must be a URL that appeared in your search results or that you
   fetched. NEVER construct or guess a URL. If you cannot find a real source
   for a movement, drop the movement.
3. Write every instruction and cue IN YOUR OWN WORDS. Do not copy sentences
   from sources (copyright). Do not quote or name individual coaches. Do not
   invent statistics or study results.
4. Technique must be the mainstream, safe consensus. Where sources disagree,
   use the conservative version. No medical claims ("cures", "fixes pain").
5. Voice: plain, short, direct. No exclamation marks, no emoji, no hype.

## Workouts — `Content/DiscoverLibrary/v3-<discipline-slug>.json`

Same shape as `Content/DiscoverLibrary/SPEC.md` (read it) WITHOUT `newExercises`:

```json
{ "version": 2, "category": "<discipline>", "workouts": [ ... ] }
```

- `slug` starts with `v3-` and is globally unique.
- `libraryID` may be any id in `existing-library.tsv` or any new id from this wave's files in this folder.
- Order workouts weightLoss → strengthBuilding → leanOut → recovery; use at least 3 of the 4 goals.
- 4–8 exercises each, honest intensity types, plausible duration.

## Validate before you finish

```
python3 Tools/validate_exercise_library.py
```

It checks every file in this folder plus every `v3-*.json` workout file. It
must print `OK` for your files.
