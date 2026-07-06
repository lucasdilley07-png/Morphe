#!/usr/bin/env python3
"""Generates Resources/MorpheCatalog.json — the bundled workout catalog.

Reads the exercise library straight out of MorpheServices.swift so the catalog
can never reference an exercise that doesn't exist, then builds structurally
sound "Morphe Program" workouts across facets:

    focus (full body / push / pull / legs / core / conditioning / recovery)
  x level (Beginner / Moderate / Advanced)
  x duration (20 / 30 / 45 min)
  x equipment (Bodyweight / Dumbbells / Full Gym)
  x 2 exercise-selection variants where the pool allows

Workout ids are deterministic (UUID5 of the combo key) so saved references
survive regeneration. Honest labeling: these are Morphe Programs, not
coach-authored content — creator attribution arrives with the marketplace.

Run from the repo root:  python3 Tools/generate_catalog.py
"""

import json
import re
import uuid
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SERVICES = REPO / "Morphe" / "Core" / "MorpheServices.swift"
OUTPUT = REPO / "Morphe" / "Resources" / "MorpheCatalog.json"
NAMESPACE = uuid.UUID("8f4d9a2e-1b3c-4e5f-9a7b-6c8d0e2f4a1b")

# ---------------------------------------------------------------- extraction

def extract_exercises(source: str):
    """Pulls (id, name, muscleGroup, equipment, difficulty) for every
    ExerciseReference literal in the library."""
    pattern = re.compile(
        r'ExerciseReference\(\s*'
        r'id:\s*"(?P<id>[^"]+)",\s*'
        r'name:\s*"(?P<name>[^"]+)",\s*'
        r'muscleGroup:\s*\.(?P<muscle>\w+),.*?'
        r'equipment:\s*"(?P<equipment>[^"]*)",\s*'
        r'difficulty:\s*\.(?P<difficulty>\w+),',
        re.DOTALL,
    )
    seen = {}
    for match in pattern.finditer(source):
        entry = match.groupdict()
        seen.setdefault(entry["id"], entry)  # first declaration wins
    return list(seen.values())

# ------------------------------------------------------------------- facets

FOCI = {
    "Full Body":    {"muscles": ["legs", "chest", "back", "core"],      "category": "Strength"},
    "Push":         {"muscles": ["chest", "shoulders", "arms"],          "category": "Strength"},
    "Pull":         {"muscles": ["back", "arms"],                        "category": "Strength"},
    "Legs":         {"muscles": ["legs", "core"],                        "category": "Strength"},
    "Core":         {"muscles": ["core"],                                "category": "Strength"},
    "Conditioning": {"muscles": ["conditioning", "legs", "core"],        "category": "Conditioning"},
    "Recovery":     {"muscles": ["core", "conditioning"],                "category": "Recovery"},
}

LEVELS = {
    "Beginner": {"allowed": {"beginner"},                        "sets": 3, "reps": 10, "rest": "75 sec"},
    "Moderate": {"allowed": {"beginner", "moderate"},            "sets": 4, "reps": 8,  "rest": "90 sec"},
    "Advanced": {"allowed": {"beginner", "moderate", "advanced"},"sets": 4, "reps": 6,  "rest": "120 sec"},
}

DURATIONS = {20: 4, 30: 5, 45: 7}  # minutes -> exercise count

def equipment_bucket(equipment_text: str) -> str:
    text = equipment_text.lower()
    if "none" in text or "bodyweight" in text or text.strip() == "":
        return "Bodyweight"
    if "dumbbell" in text or "kettlebell" in text or "backpack" in text or "band" in text:
        return "Dumbbells"
    return "Full Gym"

EQUIPMENT_PROFILES = {
    "Bodyweight": {"Bodyweight"},
    "Dumbbells":  {"Bodyweight", "Dumbbells"},
    "Full Gym":   {"Bodyweight", "Dumbbells", "Full Gym"},
}

GOALS = {
    "Full Body": "Build strength across your whole body",
    "Push": "Build pressing strength and shoulder stability",
    "Pull": "Build pulling strength and a stronger back",
    "Legs": "Build lower-body strength and drive",
    "Core": "Build a core that holds up under load",
    "Conditioning": "Raise your engine and work capacity",
    "Recovery": "Move, breathe, and recover on purpose",
}

NOTES = {
    "Beginner": "Leave 2-3 reps in the tank on every set. Clean reps beat heavy reps.",
    "Moderate": "Work around RPE 7-8: hard but every rep stays clean.",
    "Advanced": "Push the top sets, keep the last rep honest, and rest fully between sets.",
}

# ------------------------------------------------------------ legends corpus
#
# Faithful classic routines from bodybuilding's history, named by era/style —
# NOT by athlete. Training methods aren't protectable, but celebrity names
# implying endorsement are a right-of-publicity risk; license real names
# before ever attaching them.

LEGENDS = [
    {
        "name": "The Golden Six",
        "focus": "Full Body",
        "level": "Moderate",
        "durationMinutes": 45,
        "goal": "The classic six-exercise full-body program from the Golden Era",
        "notes": "Run it three days a week. Add weight only when every set is clean — this exact routine built champions.",
        "exercises": [
            ("barbell-back-squat", 4, 10),
            ("barbell-bench-press", 3, 10),
            ("pull-up", 3, 8),
            ("overhead-press", 4, 10),
            ("bicep-curl", 3, 10),
            ("bicycle-crunch", 3, 15),
        ],
    },
    {
        "name": "Golden-Era Chest & Back",
        "focus": "Full Body",
        "level": "Advanced",
        "durationMinutes": 45,
        "goal": "The legendary antagonist superset day: press, then pull, no filler",
        "notes": "Inspired by Golden-Era volume training — pair a chest set with a back set and keep rest short.",
        "exercises": [
            ("barbell-bench-press", 4, 8),
            ("pull-up", 4, 8),
            ("dumbbell-chest-fly", 3, 10),
            ("bent-over-row", 4, 8),
            ("dumbbell-bench-press", 3, 10),
            ("seated-cable-row", 3, 10),
        ],
    },
    {
        "name": "Golden-Era Shoulders & Arms",
        "focus": "Push",
        "level": "Moderate",
        "durationMinutes": 45,
        "goal": "Cannonball delts and sleeve-filling arms, the classic way",
        "notes": "Golden-Era pump work: moderate loads, full range, and chase the squeeze on every rep.",
        "exercises": [
            ("overhead-press", 4, 8),
            ("lateral-raise", 3, 12),
            ("rear-delt-fly", 3, 12),
            ("bicep-curl", 4, 8),
            ("skullcrusher", 4, 8),
            ("tricep-pushdown", 3, 12),
        ],
    },
    {
        "name": "Golden-Era Legs & Core",
        "focus": "Legs",
        "level": "Moderate",
        "durationMinutes": 45,
        "goal": "Classic quad-dominant leg training with honest core work",
        "notes": "Front squats keep you upright and humble. Golden-Era rule: never skip calves.",
        "exercises": [
            ("front-squat", 4, 8),
            ("romanian-deadlift", 4, 8),
            ("walking-lunge", 3, 12),
            ("calf-raise", 4, 15),
            ("hanging-knee-raise", 3, 12),
        ],
    },
    {
        "name": "Mass-Monster Leg Day",
        "focus": "Legs",
        "level": "Advanced",
        "durationMinutes": 45,
        "goal": "Heavy power-bodybuilding legs in the spirit of the mass monsters",
        "notes": "Built like the 90s pros trained: heavy barbell work first, then volume until the legs give out. Lightweight, baby.",
        "exercises": [
            ("barbell-back-squat", 5, 6),
            ("leg-press", 4, 10),
            ("walking-lunge", 3, 12),
            ("leg-extension", 3, 12),
            ("hamstring-curl", 4, 10),
            ("calf-raise", 4, 15),
        ],
    },
    {
        "name": "Mass-Monster Back & Power",
        "focus": "Pull",
        "level": "Advanced",
        "durationMinutes": 45,
        "goal": "Deadlift-led back thickness, power-bodybuilding style",
        "notes": "Heavy pulls first while you're fresh, then rows from every angle. Nobody built a big back with light weights.",
        "exercises": [
            ("conventional-deadlift", 4, 6),
            ("bent-over-row", 4, 8),
            ("seated-cable-row", 4, 10),
            ("pull-up", 3, 8),
            ("dumbbell-row", 3, 10),
        ],
    },
    {
        "name": "Arm Blaster Specialization",
        "focus": "Push",
        "level": "Moderate",
        "durationMinutes": 45,
        "goal": "A dedicated arm day in the tradition of the sport's great arm specialists",
        "notes": "Volume arm specialization: strict preacher work, no swinging, and triceps get equal billing.",
        "exercises": [
            ("preacher-curl", 4, 10),
            ("bicep-curl", 4, 8),
            ("hammer-curl", 3, 12),
            ("skullcrusher", 4, 10),
            ("tricep-pushdown", 4, 12),
            ("dip", 3, 10),
        ],
    },
]

def build_legends(exercise_ids):
    workouts = []
    for routine in LEGENDS:
        for library_id, _, _ in routine["exercises"]:
            if library_id not in exercise_ids:
                raise SystemExit(f"Legends routine '{routine['name']}' references missing exercise: {library_id}")
        workouts.append({
            "id": str(uuid.uuid5(NAMESPACE, f"legend|{routine['name']}")),
            "name": routine["name"],
            "focus": routine["focus"],
            "level": routine["level"],
            "durationMinutes": routine["durationMinutes"],
            "equipmentProfile": "Full Gym",
            "goal": routine["goal"],
            "notes": routine["notes"],
            "collection": "Legends",
            "exercises": [
                {"libraryID": lib, "sets": sets, "reps": reps}
                for lib, sets, reps in routine["exercises"]
            ],
        })
    return workouts

# ---------------------------------------------------------------- generation

def build_catalog(exercises):
    for entry in exercises:
        entry["bucket"] = equipment_bucket(entry["equipment"])

    workouts = []
    for focus, focus_config in FOCI.items():
        for level, level_config in LEVELS.items():
            if focus == "Recovery" and level == "Advanced":
                continue  # recovery days don't escalate
            for minutes, exercise_count in DURATIONS.items():
                for profile, allowed_buckets in EQUIPMENT_PROFILES.items():
                    pool = [
                        entry for entry in exercises
                        if entry["muscle"] in focus_config["muscles"]
                        and entry["difficulty"] in level_config["allowed"]
                        and entry["bucket"] in allowed_buckets
                    ]
                    # Keep muscle ordering stable: pool sorted by (muscle order, id)
                    muscle_rank = {m: i for i, m in enumerate(focus_config["muscles"])}
                    pool.sort(key=lambda e: (muscle_rank[e["muscle"]], e["id"]))
                    if len(pool) < exercise_count:
                        continue

                    variants = 2 if len(pool) >= exercise_count + 2 else 1
                    for variant in range(variants):
                        # Deterministic spread: stride through the pool with an offset
                        picked, index = [], variant
                        stride = max(1, len(pool) // exercise_count)
                        while len(picked) < exercise_count:
                            picked.append(pool[index % len(pool)])
                            index += stride
                        # de-dup while preserving order
                        unique, seen = [], set()
                        for entry in picked:
                            if entry["id"] not in seen:
                                seen.add(entry["id"])
                                unique.append(entry)
                        extras = [e for e in pool if e["id"] not in seen]
                        while len(unique) < exercise_count and extras:
                            unique.append(extras.pop(0))
                        if len(unique) < exercise_count:
                            continue

                        key = f"{focus}|{level}|{minutes}|{profile}|{variant}"
                        suffix = "" if variants == 1 else f" {'AB'[variant]}"
                        reps = level_config["reps"] if focus_config["category"] == "Strength" else min(15, level_config["reps"] + 5)
                        workouts.append({
                            "id": str(uuid.uuid5(NAMESPACE, key)),
                            "name": f"{level} {focus}{suffix}",
                            "focus": focus,
                            "level": level,
                            "durationMinutes": minutes,
                            "equipmentProfile": profile,
                            "goal": GOALS[focus],
                            "notes": NOTES[level],
                            "exercises": [
                                {"libraryID": e["id"], "sets": level_config["sets"], "reps": reps}
                                for e in unique
                            ],
                        })
    return workouts

def main():
    source = SERVICES.read_text()
    exercises = extract_exercises(source)
    if len(exercises) < 40:
        raise SystemExit(f"Only extracted {len(exercises)} exercises — parser drifted from MorpheServices.swift?")
    catalog = build_legends({e["id"] for e in exercises}) + build_catalog(exercises)
    ids = [w["id"] for w in catalog]
    assert len(ids) == len(set(ids)), "duplicate workout ids"
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps({"version": 1, "workouts": catalog}, indent=1) + "\n")
    print(f"exercises: {len(exercises)}  workouts: {len(catalog)}  -> {OUTPUT.relative_to(REPO)}")

if __name__ == "__main__":
    main()
