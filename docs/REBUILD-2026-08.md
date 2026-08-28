# Interaction-Layer Rebuild — 2026-08-27

Two live audits (ChatGPT's UI/UX + voice surface; Apple's Hey Siri stack)
distilled into one rebuild of Morphe's interaction layer. Not a rewrite:
sixteen audit cycles of hardened code stayed; the findings landed on top.

## What the audits agreed on

1. **Voice is an input mode, not a destination.** ChatGPT's single biggest
   voice lesson (Nov 2025): they killed the full-screen orb and merged
   voice into the chat surface. Morphe already mutates the live session in
   place — the rebuild upgraded the *feedback*, never the surface.
2. **Eyes-free needs an audible wake confirmation.** Siri chimes only when
   the screen is off/eyes-free; a gym is *always* eyes-free, so Morphe now
   always chimes (soft two-note cue in the Milestone voice) + haptic.
3. **Live transcription is the trust signal.** Both ship it. Morphe now
   shows the words as they land in a top pill while capturing — seeing
   "10 at 135" appear is what makes voice logging believable.
4. **Follow-ups shouldn't need a re-wake.** Siri's back-to-back pattern:
   after Morphe speaks, a ~6s window accepts a bare command ("next
   exercise") with no wake phrase. Doors-only in that window — ambient
   gym chatter earns silence, never an AI reply.
5. **Misfires must cost nothing.** Bare wake + silence already collapsed
   free; now "never mind / cancel / forget it" collapses the capture
   silently too.
6. **A rules engine can beat an LLM on acknowledgment latency.** Doors
   stay first and instant. The Claude brain only answers what no door
   claimed — and the chip shows "Thinking…" the moment the ask lands.

## What was deliberately NOT copied

- Full-screen voice orb as primary surface (ChatGPT retreated from it).
- Open-mic barge-in / full duplex — a loud gym stays wake-word-gated.
- Verbosity, trailing questions, suggestion chips, personality depth.
- LLM-first parsing: free-form natural language is the fallback, never
  the primary path — the visible grammar + tap fallback stay.

## What shipped

- **Morphe Intelligence** (`Core/MorpheIntelligence.swift`): optional
  Claude brain behind the user's own Anthropic API key (Keychain-stored,
  Settings → Morphe Intelligence). Raw Messages API, `claude-opus-5`,
  low effort for fast spoken replies, refusals surfaced honestly. No key
  → the built-in instant replies run unchanged, offline and free.
- **One conversation per role**: voice answers write into the chat
  thread, so a gym-floor exchange survives the chip's 8s fade.
- **Voice feel**: wake chime + haptic, live transcript pill, 6s
  follow-up window (doors-only), silent voice cancel.
- **App Intents**: "Start my workout in Morphe" via Siri / Shortcuts /
  Action Button — Apple requires the app name in the phrase, which is
  exactly why the in-app wake word carries everything else.

## Verified

331/331 tests green (4 new: cancel phrases, follow-up doors-only gating,
no-key fallback parity, intent flag consumption). Installed and launched
on Lucas's iPhone 2026-08-27.
