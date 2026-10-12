# GitHub audit: open-source leverage for Morphe

Researched live 2026-10-12 (four parallel sweeps; every star count, license
and last-commit date came from a page fetched that day). Re-sweep rather
than trust after 2027-01.

Constraints every pick was judged against: SwiftUI, iOS 17+, closed-source
App Store app (GPL/AGPL/SSPL code and non-commercial model weights are
blockers; MIT/Apache/BSD/MPL fine), user's own API keys for anything
hosted, speech and video stay on the phone, the AI never invents numbers,
app size matters (a voice model over ~150 MB is a hard sell).

## The ten that matter, in build order

| # | Repo | License | Stars | Last push | Lane | What it buys Morphe | Cost |
|---|---|---|---|---|---|---|---|
| 1 | [livekit/livekit-wakeword](https://github.com/livekit/livekit-wakeword) | Apache-2.0 | 285 | 2026-09-30 | Voice | A trained "Hey Morphe" model (YAML → synthetic data → ONNX), iOS 16+, 0.08 false wakes/hour in their benchmark vs string-matching partials today | 1–2 days + one training run |
| 2 | [FluidInference/FluidAudio](https://github.com/FluidInference/FluidAudio) | Apache-2.0 | 3.0k | 2026-10-12 | Voice + Voices | Silero VAD (ends the capture on real silence), LocalVQE noise suppression, Parakeet EOU streaming ASR, **and** Kokoro-82M TTS on the ANE — one package for the whole voice stack | 1–2 days |
| 3 | [hexgrad/Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) | Apache-2.0 | — | v1.0 2025-01 | Voices | The only quality on-device neural voice under the size ceiling (~88–180 MB, on-demand download); persona = voice × rate | via #2 |
| 4 | [yuhonas/free-exercise-db](https://github.com/yuhonas/free-exercise-db) | Unlicense | 2.0k | 2026-09-27 | Fitness | 800+ exercises with force/mechanic/muscles, public domain incl. images — fill gaps in the 595-exercise library | one script |
| 5 | [gymcoach-app/gymcoach](https://github.com/gymcoach-app/gymcoach) | MIT | 43 | 2026-10-09 | Fitness | Closest open peer to Morphe's design (rules engine + BYO-key Claude): intra-set autoregulation, deload, return-to-training rules, four grounded system prompts | 1–2 days port |
| 6 | [microsoft/SwiftStreamingMarkdown](https://github.com/microsoft/SwiftStreamingMarkdown) | MIT | 380 | 2026-09-25 | UI | Streaming Markdown renderer built for LLM output (tables, citation pills) for the chat and the Monday report | ~1 day |
| 7 | [EmergeTools/Pow](https://github.com/EmergeTools/Pow) | MIT | 4.4k | 2026-04-13 | UI | Seal / PR / rank-up moments with haptics in one line each; gate on Reduce Motion yourself | hours |
| 8 | Apple `VNDetectHumanBodyPose3DRequest` (iOS 17) → [google-ai-edge/mediapipe](https://github.com/google-ai-edge/mediapipe) Pose Landmarker | Apple / Apache-2.0 | — / 37k | — / 2026-10-12 | Fitness | 3D joint angles, ROM in degrees and tempo for Form Check with video still on-device; try Apple's 17-joint 3D first (zero deps), MediaPipe's 33 landmarks second | days |
| 9 | [Aeastr/UniversalGlass](https://github.com/Aeastr/UniversalGlass) | MIT | 170 | 2026-10-11 | UI | One Liquid Glass API across iOS 17/18/26 instead of `#available` forks; pin a commit (branch-only install) | 1–2 days |
| 10 | [mladenjovanovic/STMr](https://github.com/mladenjovanovic/STMr) | MIT (confirm LICENSE file) | 7 | 2026-01-21 | Fitness | Reps-max / RIR / progression tables and set-rep scheme generators for the difficulty engine and plan builder; cite Jovanović | port formulas |

## Lane 1: UI + AI interface

Worth depending on, after the table above:
- [Livsy90/IntelligenceGlow](https://github.com/Livsy90/IntelligenceGlow) (MIT, 143★, iOS 17+): Apple-Intelligence-style edge glow for the Hey Morphe stage; fork it (18 commits, solo author) and drive intensity from the mic RMS we already compute.
- [twostraws/Inferno](https://github.com/twostraws/Inferno) (MIT, 2.9k★): copy the *bubble* and *warping loupe* Metal shaders for orb refraction on iOS 17/18 where `glassEffect` doesn't exist; *circle wave* driven by mic level; *shimmer* as the "thinking" state. Teaching repo: copy files, own them.
- [Lakr233/ColorfulX](https://github.com/Lakr233/ColorfulX) (MIT, 475★, 2026-10-03): Metal mesh-gradient backdrop under the orb (rank accent + ink, speed from mic level); keep `renderScale` ≤ 0.5 behind glass.
- [dmrschmidt/DSWaveformImage](https://github.com/dmrschmidt/DSWaveformImage) (MIT, 1.3k★): a ring waveform around the orb bubble is a one-liner.
- [anthropics/ClaudeForFoundationModels](https://github.com/anthropics/ClaudeForFoundationModels) (Apache-2.0, 324★, iOS 26 only): Claude as a `LanguageModel` with `@Generable` typed output — a structural way to enforce "numbers come from the logs" (the report becomes a struct whose numeric fields are filled from Firestore). iOS 26 path only.

Read for patterns, never copy (AGPL): [Lakr233/FlowDown](https://github.com/Lakr233/FlowDown) (best open iOS LLM client: tool-call rows, thinking collapsibles, Markdown re-layout throttling) and [Dimillian/IceCubesApp](https://github.com/Dimillian/IceCubesApp) (SwiftUI app architecture). FlowDown's MIT-extracted pieces, [LanguageModelChatUI](https://github.com/Lakr233/LanguageModelChatUI) and [MarkdownView](https://github.com/Lakr233/MarkdownView) (has a watchOS product), are usable.

Rejected: GetStream/stream-chat-swift-ai (proprietary license), mattt/chat-ui-swift (no license), swift-markdown-ui (maintenance mode, no streaming), SSCoachMarks (TipKit covers it). Charts, numeric transitions and haptics: native iOS 17 APIs already cover them.

## Lane 2: Hey Morphe (voice activation)

Headline: **Picovoice Porcupine is no longer free.** Free-tier keys were disabled 2026-06-30 and there is no non-commercial tier; paid plans reportedly start around $6k/year (secondary source; their pricing page blocks fetching). Treat it as a vendor, not OSS. openWakeWord's pretrained models are CC-BY-NC-SA (blocker); its code is Apache and LiveKit's engine is its productized successor.

The stack that can make Hey Morphe reliable in a noisy gym with no audio leaving the phone:
1. **Wake word:** livekit-wakeword trained on "Hey Morphe" with noise/reverb augmentation and a low target false-positive rate, run on our existing AVAudioEngine tap (so the HFP route-recovery code stays in charge of the mic). Replaces string-matching SFSpeechRecognizer partials, which is structurally the wrong tool for a wake word in noise.
2. **Gate + endpoint:** Silero VAD (MIT, ~2 MB) via FluidAudio: the wake engine only runs on speech (battery), and the capture window ends on real silence instead of the hand-rolled timeout.
3. **Denoise:** FluidAudio LocalVQE or sherpa-onnx GTCRN ahead of everything.
4. **Command ASR:** [moonshine-ai/moonshine](https://github.com/moonshine-ai/moonshine) Small Streaming (MIT incl. weights, ~134 MB, 7.84% WER, streaming-native; Swift package is thin, verify its API) or FluidAudio Parakeet EOU (Apache, built-in end-of-utterance). [WhisperKit](https://github.com/argmaxinc/WhisperKit) (MIT, 6.4k★) is the most mature wrapper but Whisper hallucinates on silence and custom vocabulary is paid.

Single-dependency fallback: [k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) (Apache-2.0, 15k★, iOS 13+): open-vocabulary keyword spotting (3 MB model) + VAD + streaming ASR + denoise. No published noise or false-positive numbers, and its TTS path embeds espeak-ng (GPL) — use its no-TTS build.

iOS 18-only alternative: [soniqo/speech-swift](https://github.com/soniqo/speech-swift) (Apache, 1.2k★, pure Swift/CoreML, ~4 MB KWS at 88% recall but a high false-positive rate on clean speech).

Intent parsing ("log 3 by 10 at 135"): nothing reusable exists; every open project relays to an LLM. Keep ours deterministic: spelled-number table, by/for/x synonyms, lbs/kg, exercise names via `contextualStrings`, read-back confirmation. That serves "never invents numbers" better than any NLU library.

Honest caveat: no project publishes gym-noise or iPhone battery figures. The decision needs a device test with a real gym recording and an HFP headset. Nothing changes the iOS rule: no background or lock-screen wake word for third-party apps.

## Lane 3: AI fitness, training and nutrition

Data and science:
- free-exercise-db (#4) is the safe library supplement. **Never import wger or exercemus exercises** (CC-BY-SA share-alike would pull the 595-exercise library under it); never ship [hasaneyldrm/exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset) GIFs (Gymvisual media needs its own license, and 22.7k stars in seven months on a data dump is a velocity to distrust). ExerciseDB API is AGPL plus a paywall.
- gymcoach (#5): port its autoregulation (last set reps + RIR + rest → fatigue rate → load change 1–5% per rep gap, readiness gate blocks increases), deload and return-to-training into the offline brain; cite "adapted from GymCoach (MIT)". Heuristics are one author's, not peer-reviewed.
- STMr (#10) for the e1RM / RIR / progression math. ACWR ([JorgeDelro/ACWR](https://github.com/JorgeDelro/ACWR), MIT) is 20 lines of Swift for a 7:28-day load ratio feeding readiness, but the science is contested: use it as a "load is spiking" flag, never as a risk number the AI quotes. Banister fitness/fatigue (τ≈42 d / 7 d) is an afternoon in-house, cite Banister 1975.
- [radupana/openweight](https://github.com/radupana/openweight) (Apache, tiny): vendor-neutral workout JSON schema with Hevy/Strong CSV mappings already done; adopt for the import feature.
- [astashov/liftosaur](https://github.com/astashov/liftosaur) (AGPL): the most readable spec of real 5/3/1, GZCLP, nSuns progression logic; re-express from the original public program write-ups, never copy.

Form Check: try Apple's `VNDetectHumanBodyPose3DRequest` first (same Vision pipeline, 17 joints in 3D), then MediaPipe Pose Landmarker (33 landmarks + world coordinates in meters) side-by-side per pattern. [quickpose/quickpose-ios-sdk](https://github.com/quickpose/quickpose-ios-sdk) (Apache but key-gated) is a benchmark harness and a source of angle-threshold state machines, not a dependency. RTMPose has the highest accuracy ceiling but no iOS docs and 14 months stale.

Nutrition: USDA FDC is CC0 (Foundation Foods is a free upgrade over SR Legacy). **Open Food Facts is ODbL:** API use with attribution is fine, but any cached OFF rows we bundle must stay in a separable cache, never merged with the proprietary library. Photo calorie estimation stays Claude + web search: Nutrition5k is archived and cafeteria-only; CalorieCLIP's MIT weights were trained on Food-101 (Foodspotting images, non-commercial). TDEE/macros (Mifflin-St Jeor, Katch-McArdle) are one-liners, no library needed.

AI coaching evals: no open "AI personal trainer" repo publishes one. The literature says keep the rules-based brain primary and the LLM as explainer (10 coaches rated GPT/Gemini plans "moderate"; repeated prescriptions vary wildly across models) — which is already Morphe's law.

## Lane 4: AI voices per training style

License traps confirmed: Fish Speech / OpenAudio (CC-BY-NC-SA), F5-TTS weights (CC-BY-NC; code is MIT, don't be fooled), piper1-gpl (GPL; MIT rhasspy/piper archived 2025-10), KittenTTS 2 (custom license; only the nano/micro ONNX models are Apache), Coqui XTTS (non-commercial), Supertonic (archived 2026-09, company dissolved). sherpa-onnx TTS embeds espeak-ng (GPL) for G2P: prefer FluidAudio's dictionary G2P or [mlalma/kokoro-ios](https://github.com/mlalma/kokoro-ios) (MIT, Misaki G2P, Apache).

Size reality: Kokoro-82M is the only quality model inside the ceiling. Pocket TTS CoreML ~600 MB, Chatterbox-Nano ~700 MB, Orpheus' promised small models are still unreleased.

Kokoro's own voice grades: af_bella A−, af_nicole and bf_emma B−, **every male American/British voice C–D**. A Spartan male register needs an ear test before committing. Latency (Core ML port, iPhone 15 Pro Max): ~0.7 s for a 3-second clip, so a laconic reply is ~0.5–1 s to audio. No emotion control: "drill" vs "calm" comes from rate and text only.

Recommended tiering:
- **Tier 0, this week, 0 MB:** AVSpeechSynthesizer with four persona prosody presets (rate/pitch/volume); surface user-downloaded Enhanced/Premium system voices in Make it yours; Personal Voice opt-in as a novelty.
- **Tier 1, default on-device neural, on-demand download:** Kokoro-82M via FluidAudio (iOS 18+ for the ANE path, gate to A15+ until iPhone numbers are published). Persona = voice × rate.
- **Tier 2, premium BYO key, streamed:** OpenAI gpt-4o-mini-tts first (~$0.015/min; a plain-English `instructions` field is the persona switch), Cartesia Sonic (lowest latency; $5/mo Pro unlocks commercial use; no Swift SDK, hand-roll the WebSocket), ElevenLabs v3/v4 with audio tags ([measured], [shouts]) which is already wired. Azure has the richest deterministic style markup (shouting, calm, sports_commentary) but is one more key. Hume is the expensive one.
- **Tier 3, research:** design four branded persona voices from text with [QwenLM/Qwen3-TTS](https://github.com/QwenLM/Qwen3-TTS) VoiceDesign (Apache, 13.8k★) on the Mac → embeddings for Pocket TTS (CC-BY-4.0) or Chatterbox-Nano (MIT) once either fits under 150 MB. Designing from text sidesteps the consent problem real-person cloning has.

Persona datasets / coach voice packs: nothing shippable; every expressive corpus is non-commercial.

## Suggested order of work

1. **Tier 0 voices** (an afternoon): prosody presets per persona in Make it yours. Zero risk, visible today.
2. **Hey Morphe rebuild** (one week + a device test): livekit-wakeword "Hey Morphe" + Silero VAD + LocalVQE via FluidAudio; keep SFSpeechRecognizer for the command window until Moonshine/Parakeet is measured on the phone. This is the most-asked-about feature and the current design is wrong in noise.
3. **free-exercise-db diff** (a script) and **gymcoach rules port** (two days) into the offline brain, with citations.
4. **SwiftStreamingMarkdown + Pow** (two days): the chat, the Monday report and the seal/PR/rank-up moments.
5. **Form Check 3D** (a week): Apple 3D pose first, MediaPipe only where it misses.
6. **Kokoro via FluidAudio** (two days, after an ear test of the male voices).
7. **UniversalGlass / Inferno / ColorfulX** as the Liquid Glass polish wave.

Each step gets its own build → fresh-eyes audit → fix wave → verify on device.
