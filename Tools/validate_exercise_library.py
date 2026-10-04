#!/usr/bin/env python3
"""Validates Content/ExerciseLibrary/*.json and Content/DiscoverLibrary/v3-*.json.

Run from the repo root:  python3 Tools/validate_exercise_library.py
"""
import json, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LIB = REPO / "Content" / "ExerciseLibrary"
WORK = REPO / "Content" / "DiscoverLibrary"
SERVICES = REPO / "Morphe" / "Core" / "MorpheServices.swift"

DISCIPLINES = {
    "Strength & Powerlifting", "Olympic Weightlifting", "Bodybuilding & Hypertrophy",
    "Calisthenics & Bodyweight", "Kettlebell & Dumbbell", "HIIT & Conditioning",
    "Functional & CrossFit-Style", "Strongman & Odd-Object", "Running & Cardio",
    "Cycling, Rowing & Swim", "Boxing & Combat Conditioning", "Dance & Aerobics",
    "Sport Performance", "Yoga, Mobility & Flexibility", "Pilates & Core Control",
    "Barre & Low-Impact", "Recovery & Longevity",
}
MUSCLES = {"Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Conditioning"}
LEVELS = {"Recovery", "Beginner", "Moderate", "Advanced"}
GOALS = ["weightLoss", "strengthBuilding", "leanOut", "recovery"]
FOCUS = {"Full Body", "Push", "Pull", "Legs", "Core", "Conditioning", "Recovery"}
EQUIP = {"Bodyweight", "Dumbbells", "Full Gym"}
INTENSITY = {"percent1RM", "rpe", "bodyweight", "heartRateZone", "maxEffort"}
STR_FIELDS = ["id", "name", "muscleGroup", "movementPattern", "musclesWorked", "equipment",
              "difficulty", "formCue", "commonMistakes", "beginnerModification", "whyThisMatters"]


def existing():
    src = SERVICES.read_text()
    rows = re.findall(r'ExerciseReference\(\s*\n\s*id: "([^"]+)",\s*\n\s*name: "([^"]+)"', src)
    return {i for i, _ in rows}, {n for _, n in rows}


def main():
    errors = []
    old_ids, old_names = existing()
    ids, names = {}, {}
    new_exercises = []
    for f in sorted(LIB.glob("*.json")):
        try:
            data = json.loads(f.read_text())
        except Exception as e:
            errors.append(f"{f.name}: invalid JSON ({e})"); continue
        if data.get("discipline") not in DISCIPLINES:
            errors.append(f"{f.name}: unknown discipline {data.get('discipline')!r}")
        for ex in data.get("exercises", []):
            tag = f"{f.name}:{ex.get('id')}"
            for key in STR_FIELDS:
                if not isinstance(ex.get(key), str) or not ex[key].strip():
                    errors.append(f"{tag}: missing {key}")
            eid, name = ex.get("id", ""), ex.get("name", "")
            if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", eid):
                errors.append(f"{tag}: id is not kebab-case")
            if eid in old_ids: errors.append(f"{tag}: id already in the original library")
            if name in old_names: errors.append(f"{tag}: name already in the original library")
            if eid in ids: errors.append(f"{tag}: duplicate id (also in {ids[eid]})")
            if name in names: errors.append(f"{tag}: duplicate name (also in {names[name]})")
            ids[eid] = f.name; names[name] = f.name
            if ex.get("muscleGroup") not in MUSCLES: errors.append(f"{tag}: bad muscleGroup")
            if ex.get("difficulty") not in LEVELS: errors.append(f"{tag}: bad difficulty")
            steps = ex.get("instructions")
            if not (isinstance(steps, list) and 3 <= len(steps) <= 5 and all(isinstance(s, str) and s.strip() for s in steps)):
                errors.append(f"{tag}: instructions must be 3-5 non-empty strings")
            alts = ex.get("alternatives")
            if not (isinstance(alts, list) and 1 <= len(alts) <= 3):
                errors.append(f"{tag}: alternatives must list 1-3 names")
            src = ex.get("source") or {}
            if not (isinstance(src.get("name"), str) and src["name"].strip()):
                errors.append(f"{tag}: missing source.name")
            if not (isinstance(src.get("url"), str) and src["url"].startswith("https://")):
                errors.append(f"{tag}: source.url must be an https URL")
            text = json.dumps(ex)
            if "!" in text: errors.append(f"{tag}: exclamation mark")
            new_exercises.append((f.name, ex))
    all_ids = old_ids | set(ids)
    all_names = old_names | set(names)
    for fname, ex in new_exercises:
        tag = f"{fname}:{ex.get('id')}"
        if ex.get("variationOf") and ex["variationOf"] not in all_ids:
            errors.append(f"{tag}: variationOf {ex['variationOf']!r} is not a known id")
        for alt in ex.get("alternatives") or []:
            if alt not in all_names:
                errors.append(f"{tag}: alternative {alt!r} is not an exercise name in the library")

    slugs = set()
    n_workouts = 0
    for f in sorted(WORK.glob("v3-*.json")):
        try:
            data = json.loads(f.read_text())
        except Exception as e:
            errors.append(f"{f.name}: invalid JSON ({e})"); continue
        if data.get("category") not in DISCIPLINES:
            errors.append(f"{f.name}: unknown category {data.get('category')!r}")
        order = [GOALS.index(w["goal"]) if w.get("goal") in GOALS else -1 for w in data.get("workouts", [])]
        if -1 in order: errors.append(f"{f.name}: bad goal value")
        if order != sorted(order): errors.append(f"{f.name}: workouts not ordered by goal")
        if len(set(order)) < 3: errors.append(f"{f.name}: fewer than 3 goals used")
        for w in data.get("workouts", []):
            n_workouts += 1
            tag = f"{f.name}:{w.get('slug')}"
            slug = w.get("slug", "")
            if not slug.startswith("v3-"): errors.append(f"{tag}: slug must start with v3-")
            if slug in slugs: errors.append(f"{tag}: duplicate slug")
            slugs.add(slug)
            for key in ("name", "trainingType", "notes"):
                if not isinstance(w.get(key), str) or not w[key].strip(): errors.append(f"{tag}: missing {key}")
            if w.get("focus") not in FOCUS: errors.append(f"{tag}: bad focus")
            if w.get("level") not in LEVELS: errors.append(f"{tag}: bad level")
            if w.get("equipmentProfile") not in EQUIP: errors.append(f"{tag}: bad equipmentProfile")
            if not isinstance(w.get("durationMinutes"), int) or not 5 <= w["durationMinutes"] <= 120:
                errors.append(f"{tag}: bad durationMinutes")
            exs = w.get("exercises") or []
            if not 4 <= len(exs) <= 8: errors.append(f"{tag}: needs 4-8 exercises")
            if "!" in json.dumps(w): errors.append(f"{tag}: exclamation mark")
            for e in exs:
                if e.get("libraryID") not in all_ids: errors.append(f"{tag}: unknown exercise {e.get('libraryID')!r}")
                if not isinstance(e.get("sets"), int) or e["sets"] < 1: errors.append(f"{tag}: bad sets")
                if ("reps" in e) == ("durationSeconds" in e): errors.append(f"{tag}: {e.get('libraryID')} needs reps OR durationSeconds")
                it = e.get("intensity") or {}
                if it.get("type") not in INTENSITY: errors.append(f"{tag}: {e.get('libraryID')} bad intensity type")
                if not isinstance(e.get("restSeconds"), int): errors.append(f"{tag}: {e.get('libraryID')} missing restSeconds")

    if errors:
        print(f"FAILED ({len(errors)} errors):")
        for e in errors: print("  -", e)
        return 1
    print(f"OK — {len(ids)} new exercises, {n_workouts} v3 workouts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
