# Morphe AI features vs the reference systems — reverse-engineering report

Date: 2026-10-14. Four parallel reviews, each reading Morphe's code and
researching the reference live (sources in each section). Goal: make every
AI feature launch-ready, and say plainly where "Apple-level" is reachable and
where it is not.

## The headline, honestly

| Feature | Reference | What Morphe runs today | Can match the reference? |
|---|---|---|---|
| Hey Morphe (voice) | Siri: always-on wake chip, VAD endpointing, LLM intents, App Intents | Regex over a rolling transcript for the wake word, a fixed 1.4 s silence timer + 2.5 s floor, regex "doors" for intents, Claude for the rest, per-sentence ElevenLabs | **In-app: yes** (same on-device speech models, better answers). **Background / lock-screen wake word: no** — no API; the only route is the `audio` background mode with a permanent red mic pill and App Review risk. Recommend no. |
| Form Check (camera) | Vision 3D pose, ARKit body tracking, validated thresholds | 2D pose, EMA + median smoothing, hand-written thresholds, front-view squat depth *estimated from hip drop* | **Rep count, tempo, holds, ROM trend, side-view angles: yes.** **Front-view "knees caved" as an injury call and absolute depth from the front: no** — 2D geometry can't support it. Apple itself ships no camera form tracking (Fitness+ has none). |
| Food Check (photo) | ChatGPT/Claude vision + on-device OCR + database match + portion confirm | One 1024 px photo → Claude invents calories/macros as integers, web search on every call | **Label reading: near-exact with on-device OCR.** **Plate calories: ±35–40 % at best from any photo** (published LLM studies); depth sensors get ±16 %. Honest ranges, not points. |
| Personalization | ChatGPT/Claude memory: extracted facts + retrieval + user control | Derived counters in a stuffed system prompt; chat history lost on relaunch; ratings write-only | **Yes, fully** — "learns you" means memory + retrieval, not training weights per user. Nobody does per-user fine-tuning; it's a privacy liability. Morphe can beat them on transparency. |

Two platform facts shape everything below:
- **Foundation Models** (Apple's on-device ~3B model, iOS 26) gives free, offline,
  no-key intent parsing and answers — but only on iPhone 15 Pro and newer with
  Apple Intelligence on, and with a 4,096-token context.
- **SpeechAnalyzer / SpeechDetector** (iOS 26) gives real voice-activity
  endpointing on device, replacing the silence timer.

---

## 1. Voice — "Hey Siri" vs "Hey Morphe"

### How Morphe works today (RootView.swift `HeyMorpheEngine` ~1324; MorpheStore `handleVoiceCommand` ~12498)
- Wake word: continuous on-device `SFSpeechRecognizer`; the transcript is regex-matched against a 30-spelling table (morphe/murphy/morphine/"more fee"…). No acoustic keyword model. False accepts in a gym are real ("hi Murphy"), and each one pauses the user's music.
- Chain: wake hit → claim audio session → **hard 2.5 s floor** → 1.4 s fixed timer endpointing → regex doors → else Claude stream → ElevenLabs per sentence (non-streaming endpoint) or AVSpeech. ~2.8 s to a door reply, ~4–5 s to first Claude audio.
- Intents: 100 % keyword/regex. Question detection relies on `"?"` which the recognizer never emits.
- System exposure: 4 App Intents, all open the app and pass a UserDefaults flag; nothing runs headless; Siri never speaks an answer.

### Reference (live, Oct 2026)
- Siri wake = two-stage DNN on the always-on processor; no third-party API. LLM Siri slipped to WWDC 2026; third-party actions go through App Intents + App Entities. No fitness Assistant Schema exists.
- `SpeechAnalyzer` + `SpeechTranscriber` + `SpeechDetector` (VAD with speech start/end events). No `contextualStrings` equivalent — keep SFSpeechRecognizer for the wake scan.
- Foundation Models: `@Generable` structured output, `Tool` calls, streaming; 4,096-token context; iOS 26.4 added `contextSize`.
- ChatGPT voice is end-to-end speech-to-speech (~320 ms); Claude voice is turn-based with tap-to-interrupt. Morphe's barge-in design (AEC + echo guard) is in the same class.

### Build plan
1. **SpeechDetector endpointing** replaces the timer and the 2.5 s floor (`beginListening`, `resumeActiveCapture`, `armBargeInRecognition`, `installMicTap`). Keep SFSpeechRecognizer for the wake scan and <iOS 26.
2. **Foundation Models intent router** (new `Morphe/Core/VoiceIntentRouter.swift`): `@Generable enum VoiceIntent { logSet(reps, weight), startRest(seconds), nextExercise, swapExercise, openProgress, question(String) … }`, one `LanguageModelSession` with ≤600-token instructions; the existing doors become executors, not parsers. Fallback to regex when the model is unavailable.
3. **Real App Intents**: `LogSetIntent`, `StartRestIntent`, `NextExerciseIntent` with `openAppWhenRun = false` and `ProvidesDialog` so Siri speaks; `@AppEntity` for Exercise/Workout. Siri on a free-ID build works on device; TestFlight needs the paid account.
4. **Streaming TTS**: ElevenLabs `/stream` endpoint + `AVAudioEngine` PCM playback, pipeline sentence N+1 while N plays.
5. **Offline brain** on Foundation Models instead of `athleteAgentReply` string ladders.
6. Background wake word: **recommend no** (red pill, battery, review risk).

### Bugs (file:line)
- RootView.swift:2772–2775 — in `.speaking`, a recognizer error/final returns without re-arming → barge-in dies during answers longer than ~5 s.
- RootView.swift:1650 — wake table accepts "morphine", "morph", "murphy".
- RootView.swift:2826 — the 2.5 s floor applies even when the command arrived with the wake.
- MorpheStore.swift:13074 — `contains("?")` is dead for voice.
- MorpheStore.swift:12683 — `\bfinish\b` / `\blog\b` in the mutation guard swallow follow-up *questions*.
- MorpheIntelligence.swift:511 — non-streaming ElevenLabs endpoint.
- RootView.swift:3122 — `DictationEngine` only requests on-device recognition when supported; settings copy promises on-device.

---

## 2. Body tracking — Apple Vision vs Form Check

### How Morphe works today (FormCheckView.swift)
- `VNDetectHumanBodyPoseRequest` (2D) every frame, `.high` preset, no fps cap. Per-joint confidence floor 0.5 (no hysteresis), EMA α 0.55, 5-frame median on the primary angle.
- Calibration: 15 still frames → torso, shoulder width, leg length, standing hip Y; front/side decided by one ratio (0.42). Refreshed only after 45 frames of absence.
- 13 patterns with hard-coded turn/reset/range angles. Rep = hysteresis state machine + 0.45 s minimum. Front-view squat depth is **not a knee angle**: `180 − 2·acos(1 − hipDrop/legLength)`, assuming a level camera and symmetric fold.
- Valgus = knee spread / ankle spread < 0.85 (front only); torso lean from foreshortening (sign-blind: can't tell forward from backward).

### Reference (live)
- `VNDetectHumanBodyPose3DRequest` (iOS 17+): 17 joints in metres, `bodyHeight`, optional depth/LiDAR; iOS 26 added only the Swift async API. ARKit body tracking: rear camera, 91 joints.
- One-Euro filter is the standard for pose (low lag when fast, low jitter at rest).
- Published validity: side-view sagittal knee angle from 2D reaches ICC 0.96–0.99; MediaPipe knee flexion error −2.3 ± 6.4° lateral vs −13.9 ± 15.1° overall. Front-view valgus from a phone is noise at oblique angles.
- Kemtai claims a lab validation; Peloton Guide (the hardware rep counter) was discontinued July 2025; Apple Fitness+ has no form tracking.

### Build plan
1. **One-Euro filter** on raw joints (replace L1541–1552): minCutoff 1.0 Hz, beta 0.02. Half a day, biggest felt improvement.
2. **Placement guard**: continuous view angle from shoulder/torso + hip width → front / oblique / side; refuse valgus and front-lean reads when oblique; `CMMotionManager` gravity to warn when the phone is >15° off level; guidance in `FramingState` (L742–811).
3. **Per-set recalibration** when standing hip Y or leg length drifts >10 % (L1556–1563).
4. **3D pose for standing patterns** on LiDAR phones: `VNDetectHumanBodyPose3DRequest` with `AVCaptureDepthDataOutput`, true knee/hip angles, 10–15 fps on every 2nd–3rd frame; keep 2D for the overlay. Replaces `frontViewKneeAngle`.
5. **Validated thresholds + clip harness**: 10–20 recorded clips per pattern (good / shallow / caved / leaned) run through `RepDetector` + `FormAnalyzer` in a unit test via `AVAssetReader`. Only then move numbers.
6. **Honesty copy**: "side view: measured angle" vs "front view: estimated from hip drop"; valgus labelled "knees drifted in on camera", never a risk call.

### Bugs (file:line)
- L1470–1478 vs L1572 — `resetGeneration` written on main, read on the video queue, unsynchronised.
- L1521–1524 — `recognizedPoints(.all)` called twice per observation per frame.
- L389–396 — front-view depth breaks with heel rise or phone tilt; no bound.
- L427–431 — torso lean is sign-blind yet feeds "chest dropped" cues.
- L1330 — `.high` (1080p) with no `activeVideoMinFrameDuration`; 720p at 30 fps halves the load.
- L1607–1613 — hold "stillness" judged on smoothed joints.
- L1535 — hard 0.5 confidence cutoff with no hysteresis → flicker.

---

## 3. Photo reading — ChatGPT/Claude vision vs Food Check

### How Morphe works today (`FoodCheckService`, MorpheIntelligence.swift ~476+; MoreView)
- One camera shot → `jpeg(from:maxSide:1024)` → Claude with a prose JSON template → `extractJSONObject`. Integer point estimates for calories/macros; template literally shows `"calories":0`. Web search ×5 on **every** call (20–60 s, 1–5 searches billed). Portion = a ×0.25–4 stepper after the fact. Photo numbers never touch the bundled USDA library or Open Food Facts.
- Barcode path is database-grounded and fine.

### Reference (live)
- Claude Sonnet 5.5 vision: long edge up to 2576 px, cost `⌈w/28⌉×⌈h/28⌉` visual tokens (max 4,784); image before text; label multiple images.
- Structured outputs are GA (`output_config.format` with a JSON schema) — the relay currently drops `output_config.format`.
- Accuracy studies 2025–26: GPT-4o / Claude ~36 % MAPE on energy, 42–110 % on macros, large portions systematically under; supplying ingredients cuts error from 123 → 53 kcal. SnapCalorie (LiDAR volume) ±80–130 kcal on a 500-kcal plate. Cal AI and MyFitsnessPal: recognise → match a database → user confirms food + portion. Nothing beats a scale.
- Apple on-device OCR: `RecognizeDocumentsRequest` (iOS 26) returns text + **tables** and is built for nutrition labels; `DataScannerViewController` does live text + barcode capture.

### Build plan
1. **Split "label" from "plate" at capture.** `DataScannerViewController` (text + barcode) replaces `FoodBarcodeSheet`; label → `RecognizeDocumentsRequest` → parse kcal/protein/carbs/fat/serving **on device** → Claude only classifies additives/NOVA. Fallback `VNRecognizeTextRequest` below iOS 26. New `Morphe/Core/LabelOCR.swift`.
2. **Structured outputs** with a strict schema (`items: [{name, grams_low, grams_high, kcal_low, kcal_high, confidence}]`); relay whitelists that one schema (`guard.ts` `sanitizeBody`).
3. **Recognise → database → confirm**: Claude names items + gram ranges only; map to `FoodLibrary` (USDA) / Open Food Facts; `FuelEstimateSheet` becomes a per-item list with gram steppers; numbers come from a cited source.
4. **Ranges in the UI**: `caloriesLow/High` on `FoodCheckRecord`; pills show "480–620".
5. **Web search off by default** for plates (keep for brand/barcode reads): ~5 s and ~$0.003 per photo.
6. **Multi-photo** (second angle) via `PhotosPicker`.

### Bugs (file:line)
- MorpheIntelligence.swift:873 — `UIGraphicsImageRenderer(size:)` uses the 3× screen scale: the "1024 px" JPEG is ~3072 px → up to 4,784 visual tokens, and the relay's flat image estimate understates cost ~3×. Fix: renderer format `scale = 1`. **(Do first — costs money today.)**
- MorpheIntelligence.swift:881/1006 — `"calories":0` template + `int()` accepting 0 → unknown shows as 0 kcal.
- MorpheIntelligence.swift:966–969 — any URL on a visited host passes the source filter.
- MorpheModels.swift:3825 — `isPer100g` keys off free text; per-100 g label numbers can be logged as a portion.
- MorpheStore.swift:5955 — the "unknown" guard skips the photo path.
- guard.ts:229 — relay drops `output_config.format`.

---

## 4. Personalization — ChatGPT/Claude memory vs Morphe

### How Morphe works today
- `refreshStyleProfile` (MorpheStore.swift:354–419) derives counters with honesty minimums; `intelligenceSystemPrompt` (~11381–11509) stuffs everything into every request; chat history = last 16 turns and **`athleteAIAgentConversation` is in-memory only** — gone on relaunch. Ratings (`aiFeedback`) are write-only. "What Morphe has learned" shows 5 rows while the prompt sends far more (engagement, supplements, devices, enhancements note).
- The relay's cache breakpoint sits on a system prompt full of volatile text (readiness, fuel today, bpm now, "2 hours ago") → cache writes at 1.25× with almost no reads.

### Reference (live)
- ChatGPT: saved memories + reference chat history; Claude: writes memory topics mid-chat (since Aug 2026), health topics **off by default**, full user edit/delete. Architecture: extract durable facts → store → inject into the prompt → user controls. No vector DB needed at this scale. **Not fine-tuning.**
- Anthropic API pieces: `memory_20250818` tool (agentic, needs a tool loop); or one post-chat extraction call with structured outputs — cheaper for a chat app; prompt caching with a stable prefix.

### Build plan
1. **Persist the chat** per profile (like `morpheInbox`, cap 200). Half a day; prerequisite for everything.
2. **`AIMemory` schema**: `facts`, `preferences`, `injuries` (since, status), `goals`, `whatWorked`, `whatDidnt` — each `{text, source: chat|debrief|log, date, userEdited}`, `summary` ≤600 chars.
3. **Extraction call** after each reply: existing memory + new turns → a *diff* (add/update/retire) under a strict schema, effort low, via the relay (`extract` op with its own small max_tokens).
4. **Storage** `users/{uid}/private/aiMemory`, owner-only rules, mirrored locally, erased with the account.
5. **Prompt restructure for caching**: [identity + rules + persona] [memory + learned profile] with the breakpoint, then live numbers uncached. Same in `makeRequest` for the personal-key path.
6. **"Morphe remembers" screen**: every item with source and date, edit, delete, "Forget everything", and show *everything* the prompt sends.
7. **Retrieval over logs**: regex the question for an exercise name / "last month" → append a compact table of matching sets. No embeddings.
8. **Rating → weekly eval**: store prompt version + model + memory hash with each rating; a Sunday script grades thumbs-downs against the house rules; keep a 30-case eval set.
9. **Consent**: "Let Morphe remember from conversations" toggle, default off for health-type facts (mirrors Claude); policy says memory text goes to Anthropic with each answer and Anthropic retains API inputs up to 30 days.

### Bugs (file:line)
- MorpheStore.swift:895, 1430 — chat never persisted.
- MorpheStore.swift:11410–11425, 11561–11563 — volatile strings inside the cached block.
- MorpheIntelligence.swift:321–326 — personal-key path has no `cache_control`.
- MorpheStore.swift:3641–3654 — builder asks for JSON in prose instead of structured outputs.
- ProfileView.swift:1769–1796 — transparency gap.

---

## Build order (one founder, in weeks)

**Wave 0 — today, hours.** Image scale bug (money); web search off by default for plates; calories-0 bug; wake table trims; the barge-in re-arm bug; the 2.5 s floor when the command arrives with the wake; persist the chat; relay forwards a whitelisted structured-output schema; prompt split for caching.

**Wave 1 — voice (3–4 days).** SpeechDetector endpointing; Foundation Models intent router with regex fallback; three headless App Intents; streaming TTS.

**Wave 2 — form (4–5 days).** One-Euro; placement + tilt guard with guidance; recalibration; honesty copy; the clip harness (needs Lucas to record ~15 clips per pattern); then thresholds; 3D pose on LiDAR phones last.

**Wave 3 — food (3–4 days).** DataScanner + on-device label OCR; structured outputs; recognise → database → per-item confirm with ranges; multi-photo.

**Wave 4 — memory (4–5 days).** Schema, extraction, storage, "Morphe remembers" screen, retrieval over logs, rating → eval loop, consent copy.

Total ≈ 3–4 weeks of build, each wave shipped and verified on the phone before the next. None of it needs the paid Apple account except TestFlight distribution of the App Intents.

## Decisions for Lucas
1. Background "Hey Morphe" with the permanent red mic pill: **no** (recommended), or yes and accept the review risk.
2. Foundation Models requires iPhone 15 Pro+ with Apple Intelligence on; older phones fall back to regex doors and Claude. OK?
3. Plate photos: web search **off** by default (fast, cheap, honest) — on only for barcode/brand reads. OK?
4. Memory default: **off** for health-type facts until the user turns it on (Claude's own posture). OK?
5. Form Check will say "estimated" on front-view depth and never call "injury risk". OK?
