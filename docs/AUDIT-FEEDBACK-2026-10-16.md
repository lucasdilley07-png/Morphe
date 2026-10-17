# Morphe — interaction feedback audit: animation, sound, haptics (2026-10-16)

What the app does at each moment a user touches it, measured against how
Apple, Nintendo, PlayStation, Xbox, TikTok and Instagram do feedback. The
"now" column is read from the code (haptics can't be felt in the
simulator, so every claim here is a code fact, not a guess). Read-only;
the plan at the end is what to change.

---

## The reference bar (what the six actually do)

| Reference | The rule they live by | Source |
|---|---|---|
| **Apple (HIG)** | Haptics must match a visible change or a user action — never a surprise; don't overuse (overuse dulls it); never make a haptic the only feedback — pair it with a visual or a sound. Motion is purposeful and optional (Reduce Motion), never decoration. System types: `success`/`warning`/`error` for outcomes, `selection` for value changes, `impact` for collisions. | HIG Playing haptics, Motion; SwiftUI `sensoryFeedback` (iOS 17+) |
| **Duolingo (the Apple-platform exemplar)** | A bouncy chime on every correct answer, a descending tone on a miss; haptics composed "as an instrument" that carries the bass under the sound; feedback animations 200–300 ms. | Designer's Next / 60fps Design teardowns |
| **Nintendo (HD Rumble → HD Rumble 2, 2025)** | Vibration as texture, not buzz: two resonant frequencies, short response time; Switch 2 made it stronger, more realistic, and faster — "quicker response" is the headline improvement. | Nintendo Ask the Developer Vol. 16 (Apr 2025) |
| **PlayStation (DualSense)** | Haptics are generated from the sound waveform (Sony's audio-to-haptics tool), so touch and sound are one event; audio designers join at the start, not the end. | Sony / SIE developer tooling coverage |
| **Xbox** | Latency is a design value (Dynamic Latency Input syncs input to output); Impulse Triggers put the feedback where the finger is. | Xbox Series controller docs |
| **TikTok / Instagram** | One hero action (the like) gets the whole budget: <100 ms response, a 200–300 ms scale/bounce, a burst (Instagram's fill-and-burst heart, TikTok's floating hearts) and a light haptic. Everything else is quiet. | Micro-interaction teardowns |
| **Game feel (the shared grammar)** | Every meaningful action gets primary feedback (confirms it happened: sound + visual) and secondary feedback (personality: a bounce, a flash, a haptic); hit-stop 50–100 ms; juice stays readable or it hurts. | Game Feel survey (arXiv), Wayline, Easton |

The through-line: **one grammar, few events, every event hits three
senses at once, the hero action gets a signature.**

---

## What Morphe has (code inventory)

- **Haptics**: a `Haptics` enum over UIKit generators — `impact` ×77,
  `selection` ×49, `success` ×36, `error` ×5, plus `wake` (heavy + the
  system vibrate) and `personalRecord` (heavy, then success 110 ms later,
  timed to the PR cue). No Core Haptics, no `sensoryFeedback`, no custom
  patterns. Generators are created per call (no `prepare()` ahead of the
  moment, so the first hit can land late).
- **Sound**: no audio files; three cues synthesized in memory —
  `star` (completion), `ding` (contribution), `pr` (record) — plus three
  voicings (Classic / Minimal / Impact). `.ambient` session, mixes with
  the user's music, respects the silent switch. ~20 play sites.
- **Animation**: 89 `withAnimation`, 18 `contentTransition` (numeric
  counters), 12 `symbolEffect`, 2 `matchedGeometry`; no
  `phaseAnimator`/`keyframeAnimator`. Reduce Motion is respected in 27
  places (good). Primary button press = opacity 1 → 0.78 over 120 ms, no
  scale.

That is a real feedback layer — more than most fitness apps ship. The
problems are in the grammar, not the plumbing.

---

## Moment by moment

| Moment | Visual now | Sound now | Haptic now | Reference bar | Verdict |
|---|---|---|---|---|---|
| **Log Set** (the hero action, ~20×/session) | Set row appears with no animation; counter ticks; toast | — | `impact(.light)` | TikTok's like: scale/bounce 200–300 ms + burst + haptic; Hevy: inline flash | **The hero action is the quietest thing in the app.** |
| Round / run reaches 0:00 | Clock stops | — | `success` | Duolingo chime + bass haptic; Nintendo: a *shaped* buzz, not a tick | No sound on the one moment the user is *waiting* for |
| Rest timer reaches 0:00 | Clock stops | `ding` | `success` | Same | Correct pairing — the only three-sense moment in the session |
| Hold reaches target | Colour turns accent | — | `success` | Same | Silent |
| Stepper +/− (reps, weight) | Number changes | — | **none** | Apple: `selection` tick on value change (Duolingo, Clock, Health all do it) | Missing the most common interaction |
| Primary button press | Opacity dip, 120 ms | — | — | Apple: scale 0.97 + opacity; Instagram: 0.9 spring | Flat — reads as a web button |
| Finish session → debrief → save | Sheet; "Noted" toast | `star` (XP) | `success` | Strava/Ladder: the publish moment — summary rises, trophies land one by one, streak increments with its own sound | Celebration exists (`CelebrationOverlay`) but it's a banner with a symbol bounce; no sequence, no build |
| **PR** | `RecordStampOverlay` (full-screen stamp) | `pr` chord | heavy + success (110 ms) | Apple benchmark; this IS the signature | **Right** — the best-designed moment in the app |
| Quiz answer | Option recolours; text says "Correct." | **—** | **—** | Duolingo: chime / descending tone + haptic + bounce, every single answer | Silent and still — the one gamified surface has no game feel |
| Streak increments | Number eases 200 ms | — | — | Snapchat/Duolingo: flame bounce + sound | Nearly invisible |
| Hey Morphe heard | Orb | system vibrate | heavy | Siri: rise tone + glow | The vibrate is right for a phone on the floor; no rise tone |
| Share Win | Preview sheet | — | — | Instagram: shutter-style confirm on share | Fine (sharing is deliberate, not reflexive) |
| Tab switch | System bar | — | system | — | Fine now (system) |
| Errors | Toast | — | `error` | Apple `error` + a visible shake on the field | Haptic is right; no visual counterpart on fields |
| Pull to refresh (8 lists) | System spinner | — | — | System | Fine |
| Hint "Got it", chips, filters | — | — | `selection` ×49 | Apple: selection tick | Fine; borderline overuse on chips that don't change a value |

---

## Findings (ranked)

1. **The hero action has no signature.** Log Set fires a light impact and
   nothing else; the set row pops in with no motion. Every reference
   spends its feedback budget on exactly this kind of action (the like,
   the correct answer, the trigger pull). Morphe spends it on PRs, which
   happen once a week.
2. **Sound and touch are separate systems.** Of ~20 sound sites and ~167
   haptic sites, only three moments fire both together (rest end, PR,
   workout logged). Sony derives haptics *from* the sound; Duolingo
   composes them as one track. Morphe's are two lists that occasionally
   overlap.
3. **Steppers are silent.** Reps and weight +/− (dozens of taps per
   session) give no `selection` tick. This is the Apple-standard value
   change feedback and the single cheapest fix in this doc.
4. **Rounds/runs/holds end without a sound**, while rest does. Same
   "you were waiting for this" moment, inconsistent grammar.
5. **The quiz has no game feel at all** — the one surface that calls
   itself a game ("earn XP") is silent and motionless on both outcomes.
6. **Button press feedback is flat** (opacity only). Apple's own buttons
   and both social apps scale on press; the finger expects give.
7. **Haptic generators aren't prepared.** Each call constructs a
   generator and fires; Apple's guidance is `prepare()` ahead of the
   expected moment so the first impact isn't late — the Nintendo/Xbox
   principle (latency is the feel).
8. **Selection haptic is overused on chips** that only filter a list
   (49 sites) — Apple's "don't overuse" warning; the tick should mean "a
   value changed".
9. **No `sensoryFeedback`.** The iOS 17+ modifier ties the haptic to the
   state change it reflects (HIG's "must match a visual change") and
   handles Reduce Haptics; the UIKit path can't.
10. **Celebrations are banners, not sequences.** `CelebrationOverlay` is
    a panel with one bounce; the finish moment has no build (summary →
    streak → trophies) and no pause between beats.

What is already right and must not be touched: the PR signature (heavy →
success timed to the chord), the `.ambient` mixing/silent-switch policy,
the "Hey Morphe" vibrate-for-a-phone-on-the-floor, Reduce Motion in 27
places, the three-voice sound packs with fixed meanings.

---

## Fix plan — one grammar, applied

**The grammar (write it once, then every moment obeys it):**

| Tier | When | Visual | Sound | Haptic |
|---|---|---|---|---|
| **Tick** | a value changes (stepper, toggle, picker) | number `contentTransition` | — | `selection` |
| **Confirm** | an action lands (set logged, meal logged, saved) | 220 ms scale 0.96→1 on the control + the new row slides in | `ding` | `impact(.light)` prepared |
| **Complete** | a unit the user was waiting on finishes (round/run/hold/rest at 0:00, quiz correct, exercise done) | accent flash 160 ms | `star` (short voicing) | `success` |
| **Signature** | rare and earned (PR, program finished, streak milestone) | stamp / sequence | `pr` | `personalRecord` pattern |
| **Miss** | wrong answer, failed save, pain flag | 300 ms horizontal shake, 3 cycles | descending tone (new, 2 notes) | `error` |

Everything not in the table gets nothing. That is the Apple rule and the
TikTok rule at once.

### Wave F1 — the hero action and the ticks (one day) — ✔ shipped 2026-10-16
- **Log Set signature**: press → button scales 0.96 → 1 (spring, 220 ms);
  the new set row slides in from the trailing edge with `.move + .opacity`;
  `ding` + `impact(.light)`; the SETS pill counter bounces once
  (`symbolEffect(.bounce)` on the check). Under Reduce Motion: opacity only.
- **Steppers**: `selection` on every +/−, `impact(.light)` on the coarse
  ±25. Via `sensoryFeedback(.selection, trigger: value)`.
- **Round / run / hold at target**: `star` (Minimal voicing) + `success`
  + a 160 ms accent flash on the clock — the same event as rest-end.
- **Prepared generators**: a shared `UIImpactFeedbackGenerator`/
  `UISelectionFeedbackGenerator` kept alive per screen with `prepare()`
  called when the console appears and after each use.

### Wave F2 — the game surfaces (one day) — ✔ shipped 2026-10-16
- **Quiz**: correct → card scales 1.04 + `star` + `success`; wrong →
  shake + a two-note descending tone (the first new sound in the app;
  synthesized like the others) + `error`. XP line counts up with
  `contentTransition(.numericText)`.
- **Streak increment**: flame `symbolEffect(.bounce)` + `impact(.medium)`
  the first time the number changes on screen; milestones (7, 30, 100)
  escalate to the Signature tier.
- **Finish sequence**: debrief Save → 400 ms: summary card rises →
  600 ms: streak row bounces and increments → 900 ms: PRs stamp in one by
  one (each `pr`) → done card settles. Hit-stop between beats, 80 ms.
  One sequence, not a banner.

### Wave F3 — migrate to the system (half a day) — ✔ shipped 2026-10-16
- Replace `Haptics.*` call sites that reflect a state change with
  `sensoryFeedback(_:trigger:)` so the haptic is bound to the change it
  reports and respects the user's haptics settings.
- Audit the 49 `selection` sites: keep it where a value changes
  (segmented pickers, steppers, toggles); drop it from list filters and
  chips that only scroll content.
- Button styles: `scaleEffect(isPressed ? 0.97 : 1)` with a 0.25 spring
  across `PrimaryCTAButtonStyle` / `SecondaryCTAButtonStyle`.

### Not needed (and why)
- **Screen shake, confetti, particles on every action** — the canon's
  dated pattern #2 (celebration inflation); Strava's data says earned
  beats handed. Keep bursts for the Signature tier only.
- **Core Haptics custom patterns** — the UIKit types plus timing already
  give the PR its signature; custom waveforms are a Sony-grade investment
  for a Watch/controller product, not a phone app at n=1.
- **Bundled audio files** — the synthesized cues are consistent and
  tiny; adding samples would fragment the voice.
- **Ambient UI music** (PS5 menus) — a gym app shares the speaker with
  the user's playlist; the `.ambient` policy is the right call.

### Order
F1 first (the console is where the user spends 95% of touches), verify on
the phone — the simulator cannot feel any of this — then F2, then F3.

---

## Sources
- Apple HIG, Playing haptics: https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- Apple HIG, Motion: https://developer.apple.com/design/human-interface-guidelines/motion
- SwiftUI `sensoryFeedback`: https://developer.apple.com/documentation/swiftui/sensoryfeedback ; https://useyourloaf.com/blog/swiftui-sensory-feedback/
- Nintendo, Ask the Developer Vol. 16 — Switch 2 (HD Rumble 2): https://www.nintendo.com/au/news-and-articles/ask-the-developer-vol-16-nintendo-switch-2-part-2/
- Sony audio-to-haptics for DualSense: https://www.techradar.com/news/the-ps5-dualsense-controllers-haptic-feedback-wont-burden-developers ; https://wccftech.com/ps5s-dualsense-haptics-can-be-created-almost-automatically-via-a-games-sound/amp/
- DualSense vs HD Rumble actuators: https://actronika.com/post/dualsense-towards-realistic-haptics-sony-playstation-5-controller-review-actronika
- Xbox Dynamic Latency Input: https://devdocs.xbox.com/build/core-features/common/input/advanced/input-synchronization
- Instagram / TikTok like micro-interactions: https://thisisglance.com/learning-centre/what-are-the-best-examples-of-micro-interactions-in-popular-apps ; https://octet.design/journal/microinteractions
- Duolingo feedback design (chime, descending tone, haptics as bass): https://samstoof.beehiiv.com/p/duolingo-mastered-app-design ; https://60fpsdesign.substack.com/p/fun-in-every-frame
- Game feel survey: https://arxiv.org/pdf/2011.09201 ; juice restraint: https://www.wayline.io/blog/juice-overload-sensory-feedback-hurts-gameplay ; feedback layers: https://eastondev.com/blog/en/posts/dev/20260521-game-feedback-feel/
- Design canon (10 laws, dated patterns): `~/.claude/memory-shared/app-design-canon.md`
