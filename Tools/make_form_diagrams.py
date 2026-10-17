#!/usr/bin/env python3
"""Generate the step-by-step form diagrams and bundle them as 640px HEICs.

    FAL_KEY=... python3 Tools/make_form_diagrams.py            # everything missing
    python3 Tools/make_form_diagrams.py --dry-run              # count + cost, no spend
    FAL_KEY=... python3 Tools/make_form_diagrams.py --only barbell-back-squat --model fal-ai/nano-banana-pro

Resumable: a frame whose PNG already exists is skipped. Source PNGs land in
Content/DiscoverLibrary/FormDiagrams/steps/, the app bundle gets
Morphe/Resources/FormDiagrams/<id>-<n>.heic (converted with sips).
"""
import argparse, json, os, pathlib, subprocess, sys, time, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROMPTS = ROOT / "Content/DiscoverLibrary/FormDiagrams/prompts-steps.json"
PNG_DIR = ROOT / "Content/DiscoverLibrary/FormDiagrams/steps"
HEIC_DIR = ROOT / "Morphe/Resources/FormDiagrams"
PRICE = {"fal-ai/nano-banana-2": 0.06, "fal-ai/nano-banana-pro": 0.15}  # $/image, fal.ai list price 2026-10

ap = argparse.ArgumentParser()
ap.add_argument("--model", default="fal-ai/nano-banana-2")
ap.add_argument("--only", help="exercise id prefix")
ap.add_argument("--dry-run", action="store_true")
ap.add_argument("--limit", type=int, default=0)
args = ap.parse_args()

data = json.load(open(PROMPTS))
todo = [(k, v) for k, v in data["prompts"].items()
        if (not args.only or k.startswith(args.only + "-")) and not (PNG_DIR / f"{k}.png").exists()]
if args.limit: todo = todo[:args.limit]
price = PRICE.get(args.model, 0.1)
print(f"{len(todo)} frames to generate with {args.model} ≈ ${len(todo) * price:,.2f}")
if args.dry_run or not todo: sys.exit(0)

key = os.environ.get("FAL_KEY")
if not key: sys.exit("FAL_KEY is not set — export it and rerun.")
PNG_DIR.mkdir(parents=True, exist_ok=True); HEIC_DIR.mkdir(parents=True, exist_ok=True)

def generate(prompt):
    body = json.dumps({"prompt": prompt, "aspect_ratio": "1:1", "num_images": 1, "output_format": "png"}).encode()
    req = urllib.request.Request(f"https://fal.run/{args.model}", data=body,
                                 headers={"Authorization": f"Key {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as r:
        out = json.load(r)
    url = out["images"][0]["url"]
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read()

for n, (frame, prompt) in enumerate(todo, 1):
    png = PNG_DIR / f"{frame}.png"
    for attempt in range(3):
        try:
            png.write_bytes(generate(prompt)); break
        except Exception as e:
            print(f"  retry {attempt + 1} for {frame}: {e}"); time.sleep(3 * (attempt + 1))
    else:
        print(f"FAILED {frame}"); continue
    heic = HEIC_DIR / f"{frame}.heic"
    subprocess.run(["sips", "-Z", "640", "-s", "format", "heic", "-s", "formatOptions", "70",
                    str(png), "--out", str(heic)], check=True, capture_output=True)
    print(f"[{n}/{len(todo)}] {frame}")
print("done — add any new HEICs to the FormDiagrams folder reference if Xcode doesn't pick them up.")
