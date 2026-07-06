#!/usr/bin/env python3
"""Generates Resources/MorpheCatalog.json — the bundled workout catalog.

Organized by TRAINING TYPE (the product's primary taxonomy):
Strength, Hypertrophy, Muscular endurance, Cardiovascular endurance, HIIT,
Power, Speed & agility, Mobility, Flexibility, Functional, Calisthenics,
Circuit, Cross-training, Plyometric, Balance & stability, Core, Recovery.
(Sport-specific training is filled app-side from the authored sport templates.)

Reads the exercise library straight out of MorpheServices.swift so the
catalog can never reference an exercise that doesn't exist. Workout ids are
deterministic (UUID5 of the combo key) so saved references survive
regeneration. Honest labeling: generated entries are Morphe Programs; the
Legends collection is era-named classic routines (license celebrity names
before ever attaching them).

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
        seen.setdefault(entry["id"], entry)
    return list(seen.values())

def equipment_bucket(equipment_text: str) -> str:
    text = equipment_text.lower()
    if "none" in text or "bodyweight" in text or "doorway" in text or text.strip() == "":
        return "Bodyweight"
    if "dumbbell" in text or "kettlebell" in text or "backpack" in text or "band" in text:
        return "Dumbbells"
    return "Full Gym"

# --------------------------------------------------------------- vocabulary

SPLIT_MUSCLES = {
    "Full Body": ["legs", "chest", "back", "core"],
    "Push": ["chest", "shoulders", "arms"],
    "Pull": ["back", "arms"],
    "Legs": ["legs", "core"],
}

# Exercises that must never be programmed as lifting work.
NON_LIFTING = {
    "cat-cow", "worlds-greatest-stretch", "thread-the-needle",
    "hip-flexor-stretch", "standing-hamstring-stretch", "chest-doorway-stretch",
    "childs-pose", "high-knees", "lateral-shuffle", "jump-squat", "broad-jump",
    "skater-jump", "bird-dog", "treadmill-walk", "stationary-bike",
    "rowing-machine", "jump-rope",
}

POOLS = {
    "cardio":       ["rowing-machine", "stationary-bike", "treadmill-walk", "jump-rope",
                     "burpee", "mountain-climber", "high-knees", "lateral-shuffle", "kettlebell-swing"],
    "hiit":         ["burpee", "mountain-climber", "jump-squat", "kettlebell-swing",
                     "jump-rope", "high-knees", "skater-jump", "bodyweight-squat"],
    "plyo":         ["jump-squat", "broad-jump", "skater-jump", "burpee", "high-knees"],
    "power":        ["jump-squat", "broad-jump", "kettlebell-swing", "skater-jump", "step-up", "push-up"],
    "speed":        ["high-knees", "lateral-shuffle", "skater-jump", "jump-rope", "mountain-climber", "broad-jump"],
    "mobility":     ["cat-cow", "worlds-greatest-stretch", "thread-the-needle",
                     "glute-bridge", "dead-bug", "walking-lunge", "bird-dog"],
    "flexibility":  ["hip-flexor-stretch", "standing-hamstring-stretch", "chest-doorway-stretch",
                     "childs-pose", "cat-cow", "thread-the-needle"],
    "balance":      ["single-leg-rdl", "bird-dog", "single-leg-glute-bridge",
                     "bulgarian-split-squat", "step-up", "side-plank"],
    "calisthenics": ["push-up", "incline-push-up", "pull-up", "inverted-row", "dip",
                     "bodyweight-squat", "walking-lunge", "plank", "hanging-knee-raise",
                     "mountain-climber", "burpee", "glute-bridge"],
    "functional":   ["farmer-carry", "kettlebell-swing", "goblet-squat", "walking-lunge",
                     "step-up", "reverse-lunge", "romanian-deadlift", "push-up", "single-leg-rdl"],
    "crosstrain":   ["goblet-squat", "push-up", "kettlebell-swing", "jump-rope",
                     "dumbbell-row", "mountain-climber", "walking-lunge", "burpee", "farmer-carry"],
    "recovery":     ["cat-cow", "childs-pose", "worlds-greatest-stretch", "thread-the-needle",
                     "glute-bridge", "dead-bug", "treadmill-walk", "standing-hamstring-stretch"],
}

DURATION_COUNTS = {20: 4, 30: 5, 45: 7}
LEVEL_ALLOWED = {
    "Beginner": {"beginner"},
    "Moderate": {"beginner", "moderate"},
    "Advanced": {"beginner", "moderate", "advanced"},
}
LEVEL_SETS = {"Beginner": 3, "Moderate": 4, "Advanced": 4}

# Modality definitions. kind:
#   split — muscle-split lifting generation across equipment profiles
#   pool  — fixed exercise pool
MODALITIES = {
    "Strength training":         dict(kind="split", reps=5,  durations=[30, 45], levels=["Beginner", "Moderate", "Advanced"],
                                      equipment=["Dumbbells", "Full Gym"], focus=None,
                                      goal="Build maximal strength with heavy, clean sets",
                                      notes="Low reps, full rest. The last rep should look like the first."),
    "Hypertrophy training":      dict(kind="split", reps=10, durations=[30, 45], levels=["Beginner", "Moderate", "Advanced"],
                                      equipment=["Dumbbells", "Full Gym"], focus=None,
                                      goal="Build muscle with controlled volume in the 8-12 zone",
                                      notes="Control the lowering, squeeze the target muscle, and chase quality volume."),
    "Muscular endurance":        dict(kind="split", reps=18, durations=[20, 30], levels=["Beginner", "Moderate"],
                                      equipment=["Bodyweight", "Dumbbells"], focus=None,
                                      goal="Train your muscles to keep producing force rep after rep",
                                      notes="High reps, short rest. Slow down before form breaks — never after."),
    "Cardiovascular endurance":  dict(kind="pool", pool="cardio", reps=40, sets=3, durations=[20, 30, 45],
                                      levels=["Beginner", "Moderate", "Advanced"], equipment="Bodyweight", focus="Conditioning",
                                      goal="Build the engine: steady, repeatable aerobic work",
                                      notes="Treat reps as seconds on machine work. Conversational pace — you should be able to talk."),
    "HIIT":                      dict(kind="pool", pool="hiit", reps=20, sets=4, durations=[20, 30],
                                      levels=["Moderate", "Advanced"], equipment="Bodyweight", focus="Conditioning",
                                      goal="Short, sharp intervals that spike the heart rate and recover",
                                      notes="Work hard ~40 seconds, rest ~20 between exercises. Rounds = sets."),
    "Power training":            dict(kind="pool", pool="power", reps=5, sets=5, durations=[20, 30],
                                      levels=["Moderate", "Advanced"], equipment="Dumbbells", focus="Conditioning",
                                      goal="Produce force FAST — every rep explosive, every rep fresh",
                                      notes="Full rest between sets. Speed is the point; stop a set the moment reps slow down."),
    "Speed & agility training":  dict(kind="pool", pool="speed", reps=15, sets=4, durations=[20, 30],
                                      levels=["Beginner", "Moderate"], equipment="Bodyweight", focus="Conditioning",
                                      goal="Quick feet, clean direction changes, sprint mechanics",
                                      notes="Quality over fatigue: crisp fast reps, full recovery, stop while you're still quick."),
    "Mobility training":         dict(kind="pool", pool="mobility", reps=8, sets=2, durations=[20, 30],
                                      levels=["Beginner", "Moderate"], equipment="Bodyweight", focus="Recovery",
                                      goal="Move every joint through range it can actually control",
                                      notes="Slow, breathing-paced reps. Range you control beats range you force."),
    "Flexibility training":      dict(kind="pool", pool="flexibility", reps=3, sets=2, durations=[20],
                                      levels=["Beginner"], equipment="Bodyweight", focus="Recovery",
                                      goal="Lengthen tight tissue with patient, held stretches",
                                      notes="Treat each rep as a 30-second hold. Ease in on the exhale — never bounce."),
    "Functional training":       dict(kind="pool", pool="functional", reps=10, sets=3, durations=[20, 30, 45],
                                      levels=["Beginner", "Moderate", "Advanced"], equipment="Dumbbells", focus="Full Body",
                                      goal="Carry, hinge, lunge, push — strength that shows up in real life",
                                      notes="These patterns are how you move outside the gym. Own each one under load."),
    "Calisthenics":              dict(kind="pool", pool="calisthenics", reps=12, sets=3, durations=[20, 30, 45],
                                      levels=["Beginner", "Moderate", "Advanced"], equipment="Bodyweight", focus="Full Body",
                                      goal="Master your bodyweight: push, pull, squat, hold",
                                      notes="Bodyweight skill work — full range, strict reps, no momentum."),
    "Circuit training":          dict(kind="circuit", reps=12, sets=3, durations=[20, 30, 45],
                                      levels=["Beginner", "Moderate", "Advanced"], equipment="Dumbbells", focus="Full Body",
                                      goal="One station per muscle group, minimal rest, maximal flow",
                                      notes="Move station to station with little rest; rest 1-2 minutes between rounds. Rounds = sets."),
    "Cross-training":            dict(kind="pool", pool="crosstrain", reps=12, sets=3, durations=[30, 45],
                                      levels=["Beginner", "Moderate", "Advanced"], equipment="Dumbbells", focus="Full Body",
                                      goal="Strength and cardio in one blended session",
                                      notes="Alternate the strength moves with the cardio bursts to keep the heart rate honest."),
    "Plyometric training":       dict(kind="pool", pool="plyo", reps=8, sets=4, durations=[20],
                                      levels=["Moderate", "Advanced"], equipment="Bodyweight", focus="Conditioning",
                                      goal="Jump, land, absorb — reactive power for athletes",
                                      notes="Land soft and stick every rep. Volume is low on purpose; intensity is the stimulus."),
    "Balance & stability training": dict(kind="pool", pool="balance", reps=10, sets=3, durations=[20, 30],
                                      levels=["Beginner", "Moderate"], equipment="Bodyweight", focus="Core",
                                      goal="Single-leg control and a core that keeps you steady",
                                      notes="Slow is the skill. Wobbling is the training — breathe and fight for stillness."),
    "Core training":             dict(kind="split-core", reps=15, durations=[20, 30], levels=["Beginner", "Moderate", "Advanced"],
                                      equipment=["Bodyweight", "Dumbbells"], focus="Core",
                                      goal="A trunk that braces, resists, and transfers force",
                                      notes="Quality tension beats rep counts — keep the low back quiet on every rep."),
    "Recovery training":         dict(kind="pool", pool="recovery", reps=10, sets=2, durations=[20, 30],
                                      levels=["Beginner", "Moderate"], equipment="Bodyweight", focus="Recovery",
                                      goal="Easy movement that speeds up tomorrow's training",
                                      notes="This should feel BETTER when you finish than when you started. Nothing here is hard."),
}

# ------------------------------------------------------------ legends corpus
# Era-named, NOT athlete-named — see module docstring.

LEGENDS = [
    dict(name="The Golden Six", focus="Full Body", trainingType="Strength training", level="Moderate", durationMinutes=45,
         goal="The classic six-exercise full-body program from the Golden Era",
         notes="Run it three days a week. Add weight only when every set is clean — this exact routine built champions.",
         exercises=[("barbell-back-squat", 4, 10), ("barbell-bench-press", 3, 10), ("pull-up", 3, 8),
                    ("overhead-press", 4, 10), ("bicep-curl", 3, 10), ("bicycle-crunch", 3, 15)]),
    dict(name="Golden-Era Chest & Back", focus="Full Body", trainingType="Hypertrophy training", level="Advanced", durationMinutes=45,
         goal="The legendary antagonist superset day: press, then pull, no filler",
         notes="Inspired by Golden-Era volume training — pair a chest set with a back set and keep rest short.",
         exercises=[("barbell-bench-press", 4, 8), ("pull-up", 4, 8), ("dumbbell-chest-fly", 3, 10),
                    ("bent-over-row", 4, 8), ("dumbbell-bench-press", 3, 10), ("seated-cable-row", 3, 10)]),
    dict(name="Golden-Era Shoulders & Arms", focus="Push", trainingType="Hypertrophy training", level="Moderate", durationMinutes=45,
         goal="Cannonball delts and sleeve-filling arms, the classic way",
         notes="Golden-Era pump work: moderate loads, full range, and chase the squeeze on every rep.",
         exercises=[("overhead-press", 4, 8), ("lateral-raise", 3, 12), ("rear-delt-fly", 3, 12),
                    ("bicep-curl", 4, 8), ("skullcrusher", 4, 8), ("tricep-pushdown", 3, 12)]),
    dict(name="Golden-Era Legs & Core", focus="Legs", trainingType="Hypertrophy training", level="Moderate", durationMinutes=45,
         goal="Classic quad-dominant leg training with honest core work",
         notes="Front squats keep you upright and humble. Golden-Era rule: never skip calves.",
         exercises=[("front-squat", 4, 8), ("romanian-deadlift", 4, 8), ("walking-lunge", 3, 12),
                    ("calf-raise", 4, 15), ("hanging-knee-raise", 3, 12)]),
    dict(name="Mass-Monster Leg Day", focus="Legs", trainingType="Strength training", level="Advanced", durationMinutes=45,
         goal="Heavy power-bodybuilding legs in the spirit of the mass monsters",
         notes="Built like the 90s pros trained: heavy barbell work first, then volume until the legs give out. Lightweight, baby.",
         exercises=[("barbell-back-squat", 5, 6), ("leg-press", 4, 10), ("walking-lunge", 3, 12),
                    ("leg-extension", 3, 12), ("hamstring-curl", 4, 10), ("calf-raise", 4, 15)]),
    dict(name="Mass-Monster Back & Power", focus="Pull", trainingType="Strength training", level="Advanced", durationMinutes=45,
         goal="Deadlift-led back thickness, power-bodybuilding style",
         notes="Heavy pulls first while you're fresh, then rows from every angle. Nobody built a big back with light weights.",
         exercises=[("conventional-deadlift", 4, 6), ("bent-over-row", 4, 8), ("seated-cable-row", 4, 10),
                    ("pull-up", 3, 8), ("dumbbell-row", 3, 10)]),
    dict(name="Arm Blaster Specialization", focus="Push", trainingType="Hypertrophy training", level="Moderate", durationMinutes=45,
         goal="A dedicated arm day in the tradition of the sport's great arm specialists",
         notes="Volume arm specialization: strict preacher work, no swinging, and triceps get equal billing.",
         exercises=[("preacher-curl", 4, 10), ("bicep-curl", 4, 8), ("hammer-curl", 3, 12),
                    ("skullcrusher", 4, 10), ("tricep-pushdown", 4, 12), ("dip", 3, 10)]),
]

# ---------------------------------------------------------------- generation

def stride_pick(pool, count, variant):
    if len(pool) < count:
        return None
    picked, seen, index = [], set(), variant
    stride = max(1, len(pool) // count)
    guard = 0
    while len(picked) < count and guard < len(pool) * 3:
        entry = pool[index % len(pool)]
        if entry["id"] not in seen:
            seen.add(entry["id"])
            picked.append(entry)
        index += stride
        guard += 1
    extras = [e for e in pool if e["id"] not in seen]
    while len(picked) < count and extras:
        picked.append(extras.pop(0))
    return picked if len(picked) == count else None

def make_workout(key, name, modality, focus, level, minutes, equipment_label, goal, notes, picked, sets, reps):
    return {
        "id": str(uuid.uuid5(NAMESPACE, key)),
        "name": name,
        "focus": focus,
        "trainingType": modality,
        "level": level,
        "durationMinutes": minutes,
        "equipmentProfile": equipment_label,
        "goal": goal,
        "notes": notes,
        "exercises": [{"libraryID": e["id"], "sets": sets, "reps": reps} for e in picked],
    }

def build_catalog(exercises):
    for entry in exercises:
        entry["bucket"] = equipment_bucket(entry["equipment"])
    by_id = {e["id"]: e for e in exercises}
    workouts = []

    equipment_sets = {
        "Bodyweight": {"Bodyweight"},
        "Dumbbells": {"Bodyweight", "Dumbbells"},
        "Full Gym": {"Bodyweight", "Dumbbells", "Full Gym"},
    }

    for modality, config in MODALITIES.items():
        short = modality.replace(" training", "").replace(" & ", " ")
        if config["kind"] in ("split", "split-core"):
            splits = SPLIT_MUSCLES if config["kind"] == "split" else {"Core": ["core"]}
            for focus, muscles in splits.items():
                muscle_rank = {m: i for i, m in enumerate(muscles)}
                for level in config["levels"]:
                    allowed = LEVEL_ALLOWED[level]
                    for minutes in config["durations"]:
                        count = DURATION_COUNTS[minutes]
                        for profile in config["equipment"]:
                            pool = [e for e in exercises
                                    if e["muscle"] in muscles
                                    and e["difficulty"] in allowed
                                    and e["bucket"] in equipment_sets[profile]
                                    and e["id"] not in NON_LIFTING]
                            pool.sort(key=lambda e: (muscle_rank[e["muscle"]], e["id"]))
                            variants = 2 if len(pool) >= count + 2 else 1
                            for variant in range(variants):
                                picked = stride_pick(pool, count, variant)
                                if not picked:
                                    continue
                                suffix = "" if variants == 1 else f" {'AB'[variant]}"
                                # Duration + equipment live in the name: the same split
                                # at 30/45 min x Dumbbells/Full Gym otherwise ships four
                                # identically-named cards (and breaks name-keyed lookups).
                                base = f"{level} {short} {focus}" if config["kind"] == "split" else f"{level} Core"
                                name = f"{base} • {minutes} min {profile}{suffix}"
                                key = f"{modality}|{focus}|{level}|{minutes}|{profile}|{variant}"
                                workouts.append(make_workout(
                                    key, name, modality, focus, level, minutes, profile,
                                    config["goal"], config["notes"], picked, LEVEL_SETS[level], config["reps"]))
        elif config["kind"] == "pool":
            pool_entries = [by_id[i] for i in POOLS[config["pool"]] if i in by_id]
            for level in config["levels"]:
                allowed = LEVEL_ALLOWED[level]
                usable = [e for e in pool_entries if e["difficulty"] in allowed]
                for minutes in config["durations"]:
                    count = min(DURATION_COUNTS[minutes], len(usable))
                    if count < 3:
                        continue
                    variants = 2 if len(usable) >= count + 2 else 1
                    for variant in range(variants):
                        picked = stride_pick(usable, count, variant)
                        if not picked:
                            continue
                        suffix = "" if variants == 1 else f" {'AB'[variant]}"
                        name = f"{level} {short} • {minutes} min{suffix}"
                        key = f"{modality}|{level}|{minutes}|{variant}"
                        workouts.append(make_workout(
                            key, name, modality, config["focus"], level, minutes, config["equipment"],
                            config["goal"], config["notes"], picked, config["sets"], config["reps"]))
        elif config["kind"] == "circuit":
            station_groups = ["legs", "chest", "back", "core", "conditioning", "shoulders", "arms"]
            for level in config["levels"]:
                allowed = LEVEL_ALLOWED[level]
                for minutes in config["durations"]:
                    count = DURATION_COUNTS[minutes]
                    for variant in range(2):
                        picked = []
                        for group in station_groups[:count]:
                            candidates = sorted(
                                [e for e in exercises
                                 if e["muscle"] == group and e["difficulty"] in allowed
                                 and e["bucket"] in {"Bodyweight", "Dumbbells"}
                                 and e["id"] not in NON_LIFTING or
                                 (e["muscle"] == group and e["id"] in POOLS["hiit"] and e["difficulty"] in allowed)],
                                key=lambda e: e["id"])
                            if candidates:
                                picked.append(candidates[variant % len(candidates)])
                        if len(picked) < min(count, 4):
                            continue
                        suffix = f" {'AB'[variant]}"
                        name = f"{level} Circuit • {minutes} min{suffix}"
                        key = f"{modality}|{level}|{minutes}|{variant}"
                        workouts.append(make_workout(
                            key, name, modality, config["focus"], level, minutes, config["equipment"],
                            config["goal"], config["notes"], picked, config["sets"], config["reps"]))
    return workouts

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
            "trainingType": routine["trainingType"],
            "level": routine["level"],
            "durationMinutes": routine["durationMinutes"],
            "equipmentProfile": "Full Gym",
            "goal": routine["goal"],
            "notes": routine["notes"],
            "collection": "Legends",
            "exercises": [{"libraryID": lib, "sets": s, "reps": r} for lib, s, r in routine["exercises"]],
        })
    return workouts

def main():
    source = SERVICES.read_text()
    exercises = extract_exercises(source)
    if len(exercises) < 60:
        raise SystemExit(f"Only extracted {len(exercises)} exercises — parser drifted from MorpheServices.swift?")
    catalog = build_legends({e["id"] for e in exercises}) + build_catalog(exercises)
    ids = [w["id"] for w in catalog]
    assert len(ids) == len(set(ids)), "duplicate workout ids"
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps({"version": 2, "workouts": catalog}, indent=1) + "\n")

    from collections import Counter
    counts = Counter(w["trainingType"] for w in catalog)
    print(f"exercises: {len(exercises)}  workouts: {len(catalog)}  -> {OUTPUT.relative_to(REPO)}")
    for modality, count in sorted(counts.items()):
        print(f"  {modality}: {count}")

if __name__ == "__main__":
    main()
