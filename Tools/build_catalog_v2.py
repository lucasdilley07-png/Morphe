#!/usr/bin/env python3
"""Builds Resources/MorpheCatalog.json (schema v2) from Content/DiscoverLibrary.

The v2 catalog is hand-authored content-as-data: 10 category files, each
workout tagged with a result goal (weightLoss / strengthBuilding / leanOut /
recovery) and every exercise carrying sets, reps-or-duration, rest, and an
honest intensity prescription (percent1RM / rpe / bodyweight / heartRateZone /
maxEffort).

Exercise references are validated against the library in MorpheServices.swift
so the catalog can never reference an exercise that doesn't exist. Workout ids
are deterministic (UUID5 of the slug, same namespace as the retired v1
generator) so saved references survive regeneration.

Run from the repo root:  python3 Tools/build_catalog_v2.py
"""

import json
import re
import sys
import uuid
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CONTENT = REPO / "Content" / "DiscoverLibrary"
SERVICES = REPO / "Morphe" / "Core" / "MorpheServices.swift"
OUTPUT = REPO / "Morphe" / "Resources" / "MorpheCatalog.json"
NAMESPACE = uuid.UUID("8f4d9a2e-1b3c-4e5f-9a7b-6c8d0e2f4a1b")

GOAL_DISPLAY = {
    "weightLoss": "Weight Loss",
    "strengthBuilding": "Strength Building",
    "leanOut": "Lean Out",
    "recovery": "Recovery",
}


def library_ids() -> set:
    src = SERVICES.read_text()
    return set(re.findall(r'ExerciseReference\(\s*\n\s*id: "([^"]+)"', src))


def main() -> int:
    known = library_ids()
    if not known:
        print("error: no exercises extracted from MorpheServices.swift")
        return 1

    workouts, errors, slugs = [], [], set()
    files = sorted(CONTENT.glob("*.json"))
    if not files:
        print(f"error: no content files in {CONTENT}")
        return 1

    for f in files:
        data = json.loads(f.read_text())
        category = data["category"]
        for w in data["workouts"]:
            slug = w["slug"]
            if slug in slugs:
                errors.append(f"duplicate slug {slug}")
            slugs.add(slug)
            exercises = []
            for ex in w["exercises"]:
                if ex["libraryID"] not in known:
                    errors.append(f"{slug}: unknown exercise '{ex['libraryID']}'")
                entry = {"libraryID": ex["libraryID"], "sets": ex["sets"]}
                for key in ("reps", "durationSeconds", "restSeconds", "intensity"):
                    if key in ex:
                        entry[key] = ex[key]
                exercises.append(entry)
            workouts.append({
                "id": str(uuid.uuid5(NAMESPACE, f"v2:{slug}")),
                "name": w["name"],
                "focus": w["focus"],
                "trainingType": w.get("trainingType"),
                "category": category,
                "goalTag": w["goal"],
                "level": w["level"],
                "durationMinutes": w["durationMinutes"],
                "equipmentProfile": w["equipmentProfile"],
                "goal": GOAL_DISPLAY[w["goal"]],
                "notes": w["notes"],
                "collection": None,
                "exercises": exercises,
            })

    if errors:
        print(f"FAILED ({len(errors)} errors):")
        for e in errors:
            print("  -", e)
        return 1

    OUTPUT.write_text(json.dumps({"version": 2, "workouts": workouts},
                                 indent=2, ensure_ascii=False) + "\n")
    cats = {}
    for w in workouts:
        cats[w["category"]] = cats.get(w["category"], 0) + 1
    print(f"wrote {len(workouts)} workouts across {len(cats)} categories to {OUTPUT.relative_to(REPO)}")
    for c, n in sorted(cats.items()):
        print(f"  {c}: {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
