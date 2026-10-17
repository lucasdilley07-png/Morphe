#!/usr/bin/env python3
"""Step-by-step form diagram prompts for every library exercise.

One prompt per instruction step, for all 595 exercises (401 in
Resources/MorpheCatalog.json + 194 built into MorpheServices.swift).
The prompt is the exercise's OWN instruction text restated as visual
direction under the house style wrapper — nothing invented. Output:
Content/DiscoverLibrary/FormDiagrams/prompts-steps.json, consumed by
Tools/make_form_diagrams.py.
"""
import json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "Content/DiscoverLibrary/FormDiagrams/prompts-steps.json"
STYLE = json.load(open(ROOT / "Content/DiscoverLibrary/FormDiagrams/prompts.json"))["styleWrapper"]

exercises = []
cat = json.load(open(ROOT / "Morphe/Resources/MorpheCatalog.json"))
for e in cat["exercises"]:
    exercises.append({"id": e["id"], "name": e["name"], "equipment": e.get("equipment", ""),
                      "steps": e.get("instructions", [])})

src = open(ROOT / "Morphe/Core/MorpheServices.swift").read()
for m in re.finditer(r'ExerciseReference\(\s*id:\s*"([^"]+)",\s*name:\s*"([^"]+)".*?equipment:\s*"([^"]*)".*?instructions:\s*\[(.*?)\]', src, re.S):
    steps = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(4))
    exercises.append({"id": m.group(1), "name": m.group(2), "equipment": m.group(3), "steps": steps})

seen = set(); prompts = {}
for e in exercises:
    if e["id"] in seen: continue
    seen.add(e["id"])
    n = len(e["steps"])
    for i, step in enumerate(e["steps"], 1):
        gear = f" Equipment: {e['equipment']}." if e["equipment"] and e["equipment"].lower() not in ("none", "bodyweight") else ""
        prompts[f"{e['id']}-{i}"] = (
            f"{STYLE} Exercise: {e['name']}.{gear} This is step {i} of {n}. "
            f"Show the figure exactly in this position: {step} "
            "One golden-yellow arrow marks the motion of this step and nothing else. "
            "Same figure, same camera angle and same framing as the other steps of this exercise."
        )

OUT.write_text(json.dumps({
    "note": "One prompt per instruction step for every library exercise. Generate with Tools/make_form_diagrams.py "
            "(fal-ai/nano-banana-2 by default, 1:1 / 1K); the app loads <id>-<step>.heic.",
    "styleWrapper": STYLE,
    "exercises": len(seen),
    "frames": len(prompts),
    "prompts": prompts,
}, indent=1))
print(f"{len(seen)} exercises, {len(prompts)} frames → {OUT.relative_to(ROOT)}")
