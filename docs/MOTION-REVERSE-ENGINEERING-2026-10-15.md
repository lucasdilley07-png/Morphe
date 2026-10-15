# Motion reverse-engineering: two reference Shorts → Morphe's onboarding, tour and demo

Date: 2026-10-15. Source: frame-by-frame decode (every 0.25 s) of the two
Shorts Lucas sent. Both are After Effects renders, not app recordings:
"Google Gemini App Animation" (motion designer arun, 10 s) and "SaaS product
demo video (UI animation)" (Motion Swell, 11.5 s, 339k views). Nothing
below is their code — it is the shot list, the motion grammar, and the
SwiftUI equivalents, read off the frames.

## 1. Shot-by-shot decode

### A. Gemini app animation (10 s)

| Time | Shot | Motion technique |
|---|---|---|
| 0.0–0.5 | Pale blue→pink gradient wash. The spark logo **morphs in from a blob** (0.1 s), scales up; a thin **ring stroke expands outward** past the frame edge; "Meet / Gemini" **rises in** under it. | Shape morph + scale-in with a mild overshoot; ring = circle stroke scaling 0.3→2.5× while its opacity fades; text y-offset 20→0 with opacity. |
| 0.9–1.1 | Logo + wordmark **blur out** (Gaussian blur ramps as opacity drops); the logo **shrinks to a small pill chip**, then the chip **stretches horizontally into an input field** with a motion-blur smear. | Exit transition = blur(0→12) + opacity; the chip-to-field is one view whose width animates 44→320 pt with a brief `scaleEffect(x: 1.15)` stretch on the way. |
| 1.25–1.75 | **Typewriter** into the field ("Plan 3 days in Kyoto"); a send button appears on the first character; on tap it **pulses** (ripple ring). | Character-by-character reveal (~14 chars/s), caret blink; button = scale 0.8→1 + a ring stroke scaling 1→1.8 with opacity → 0. |
| 1.9–2.4 | The field **morphs into the user bubble** (gradient pill) that flies up-right with smear; a white **response card scales in** below; the answer **streams word by word**, each word blurring in; rows ("Day 1 · Fushimi Inari…") appear staggered. | `matchedGeometryEffect` field→bubble; card scale 0.9→1 + opacity; streamed text with per-word blur-in; row stagger 80–120 ms. |
| 2.6–3.75 | "Create with **Text / Image / Code / Voice**": a 2×2 card grid; the headline **word swaps** (old word blurs out, new word blurs in); the matching card gets a **gradient outline** and its icon turns gradient, ~0.6 s each. | Headline = content transition with blur; card highlight = stroke gradient opacity 0→1 + icon `foregroundStyle` gradient; 4 beats of 0.6 s. |
| 3.9–4.4 | On "Voice", a **dark radial vignette grows out of the card** until the whole screen is dark; an **orb** with a blue→coral gradient ring; a **constellation** of dots joined by thin lines; "Thinking ···". | Mask: a circle scaling from the card centre to 3×; orb = gradient-stroke circle with a soft inner glow; constellation = `Canvas` dots + lines; "Thinking" with a 3-dot loop. |
| 4.4–4.75 | Ring **particles orbit**; "Ready"; **concentric rings radiate** outward; the logo returns, then the background goes light. | `TimelineView` rotation of a dashed arc; radiating rings = 6 circles scaling with staggered delay and fading. |
| 4.9–5.5+ | Stacked tagline "**Ask. Create. Explore.**" appears **one word per beat** with blur-in; "Google Gemini" lockup fades in; hold. | Three staggered blur-in text lines (0.25 s apart); then static hold for the loop. |

### B. SaaS product demo (11.5 s)

| Time | Shot | Motion technique |
|---|---|---|
| 0.0–0.75 | Warm gradient. A **thin white dash expands into a card** (width first, then height); text **types** ("GPT-5 / Flagship model"); a **check icon pops** in. | Card = `RoundedRectangle` animating width then height (two chained animations); typewriter; icon scale 0 → 1.1 → 1. |
| 0.9–2.0 | Hard cut to white. An **input field draws in** from a line; typewriter "Our smartest, fastest model yet"; mic and waveform icons sit right. | Same chip→field stretch; typewriter ~12 chars/s. |
| 2.0–3.0 | "Think **deeper**" — the second word gets a **colour sweep** (a gradient wipes left→right across the word); then it swaps to "Think **faster**". | Text masked with a `LinearGradient` whose start/end points animate across; word swap with crossfade. |
| 3.0–3.6 | Blue gradient scene; **three file cards drop in, staggered**; "Analyzing…" with a **shimmer**; then the cards **shrink and lift away**. | `.transition(.move(edge: .top).combined(with: .opacity))` with 100 ms stagger; shimmer = moving highlight gradient; exit = scale 0.85 + offset −40 + opacity. |
| 3.75–4.75 | White page; the **summary streams** paragraph by paragraph; then a **camera push** (the text scales up ~1.6× from a top-left anchor) while it scrolls up. | Streamed text; a container `scaleEffect(1.6, anchor: .topLeading)` with a simultaneous y-offset. |
| 4.9–11.5 | Warm gradient; the CTA pill "**Available now ↗**" **types in**; long hold. | Typewriter in a capsule; static hold (the loop seam). |

## 2. The grammar both share (what to copy)

1. **One hero element travels the whole piece.** The logo becomes the chip, becomes the field, becomes the bubble. Continuity of one shape is what makes it feel like one product, not slides.
2. **Every entrance is blur + opacity, every exit is blur + opacity.** Almost no plain fades; nothing slides in from off-screen.
3. **Beats of ~0.6 s, held for ~0.4 s.** Four "Create with" beats = 2.4 s. Faster reads as a glitch, slower as a lecture.
4. **Typewriters for anything the user would type; streaming for anything the product answers.** The two speeds are different on purpose (type ~12–14 chars/s, stream ~2 words per 100 ms).
5. **Highlight by outline, not by colour fill.** The selected card keeps its white body and earns a gradient stroke + gradient icon.
6. **Mode changes are masked reveals**, not cuts: light→dark is a circle growing out of the thing you tapped.
7. **End on a static hold** long enough for the loop and the CTA.

## 3. What Morphe already has (read from the code)

- `OnboardingView.swift` (1,168 lines): four steps (welcome → identity → training → week), `WelcomeLandingStep`, tagline "TRANSFORM. EVOLVE. BECOME." (pending Lucas's tagline call).
- `HelloBeatOverlay` + `WelcomeExperienceView` (RootView ~4274): the welcome pop-up with narration and the star sound.
- The tour: `TourCameraMock` (RootView ~4653, a `Canvas` skeleton mock) and `TourExchange` (~4706), replayable from Profile ("Replay the guide").
- The Hey Morphe **orb** (glass, waves, rim light, rank colour) and the voice "Thinking…" stage — Morphe's own version of the Gemini orb already exists.
- Streaming text in the Morphe AI chat (word-by-word deltas) and `featureGlimmer()` (a shimmer).
- `TimelineView` + `Canvas` loops in GlassCard.swift (lines 370–486), so the engine for orbit/constellation/rings is in place.
- `docs/DEMO-SHOT-LIST.md`: the real-screen demo plan (two videos, Launch Lab lines). House rule there and here: **nothing on screen is staged** — motion graphics may frame a real recording; they may not fabricate app UI.

## 4. Mapping: the three Morphe surfaces

### 4a. Onboarding opener (the Gemini opening, 0–2.4 s, with Morphe's hero)
1. **Mark morph-in**: the helmet mark grows from a blob (0.3 s, spring 0.55 damping), a blue ring stroke expands past the edge, "Meet Morphe" + the tagline rise in. The existing launch field colour (`LaunchField`) is the wash.
2. **Mark → chip → field**: the mark shrinks to a 44 pt chip and stretches into the **name field** of the identity step ("What should Morphe call you?"). `matchedGeometryEffect(id: "mark")` between the splash mark and the field's leading icon.
3. **Typed example, then the real field**: a 1.2 s typewriter shows "Sarah" as a ghost placeholder, clears, and the keyboard rises. (The user types; the animation only demonstrates.)
4. **Answer card**: on continue, the field morphs into a user bubble that flies up; Morphe's first line streams in a card ("Sarah. Four questions and the first session is built.").
5. Each later step enters with blur + opacity; the step indicator is a dot row, not a progress bar.

### 4b. The tour / guide (the "Create with" grid, 2.6–4.75 s)
Replace the current linear tour with a **2×2 "Train with" grid**: **Voice · Form · Fuel · Morphe AI**. Four 0.6 s beats: the headline word swaps with blur, the card earns the gradient outline, and each card runs a 2 s **real micro-demo** inside it:
- **Voice**: the card's dark vignette grows into the full Hey Morphe orb stage (the real orb), "Thinking ···" → "Ready", the rings radiate — this is the Gemini voice beat almost 1:1, and Morphe already owns the orb.
- **Form**: a looping **real** Form Check clip (recorded, not drawn; replaces `TourCameraMock`) with the rep counter ticking.
- **Fuel**: a label photo → the OCR'd numbers landing in the pills (the new Wave 3 flow).
- **Morphe AI**: a question streaming into an answer (the real chat component).
Then the tagline beat: three lines blur in one per 0.25 s. `GuideHint` stays for in-context tips after the tour.

### 4c. The app demo video (the SaaS structure, keep the Shot List's rules)
Structure, 25–30 s, cut around **real screen recordings**:
1. **Hook card types in** (0–1 s): "Morphe / Train honest." check pops. (Chrome only.)
2. **Real recording**: "Hey Morphe, log eight at one thirty-five" → the console logs the set (screen recording with mic).
3. **Word sweep** (1 s): "Train **honest**." → "Train **faster**." gradient wipe.
4. **Real recording**: Form Check counting reps with the live cue.
5. **Analyzing beat**: three real cards from the app (session, Form Check, Fuel) drop in with the shimmer, then lift away.
6. **Real recording**: the recap streaming, with the camera push into the numbers.
7. **CTA**: "On the App Store ↗" types in; 3 s hold.
Produce it in After Effects or Premiere from the recordings; the only drawn elements are the hook card, the word sweep, the file-card beat and the CTA.

## 5. SwiftUI building blocks (one each; all native, 120 Hz on iPhone)

```swift
// Blur-in / blur-out transition (the grammar's default entrance and exit)
extension AnyTransition {
    static var blurIn: AnyTransition {
        .modifier(active: BlurFade(blur: 12, opacity: 0), identity: BlurFade(blur: 0, opacity: 1))
    }
}
struct BlurFade: ViewModifier {
    var blur: CGFloat; var opacity: Double
    func body(content: Content) -> some View { content.blur(radius: blur).opacity(opacity) }
}

// Typewriter (for things the user would type)
struct Typewriter: View {
    let text: String; var charsPerSecond: Double = 13
    @State private var shown = 0
    var body: some View {
        Text(String(text.prefix(shown)) + (shown < text.count ? "|" : ""))
            .task {
                for i in 0...text.count {
                    try? await Task.sleep(for: .seconds(1 / charsPerSecond)); shown = i
                }
            }
    }
}

// Expanding ring (logo reveal, send-button pulse, "Ready" radiation)
struct RingPulse: View {
    @State private var go = false
    var body: some View {
        Circle().stroke(MorpheTheme.accent.opacity(0.6), lineWidth: 1.5)
            .scaleEffect(go ? 2.6 : 0.3).opacity(go ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { go = true } }
    }
}

// Colour sweep across one word ("Train honest.")
struct SweepWord: View {
    let word: String
    @State private var phase: CGFloat = -1
    var body: some View {
        Text(word).font(.largeTitle.weight(.bold))
            .overlay(
                LinearGradient(colors: [.clear, MorpheTheme.accent, .clear], startPoint: .leading, endPoint: .trailing)
                    .offset(x: phase * 220)
                    .mask(Text(word).font(.largeTitle.weight(.bold)))
            )
            .onAppear { withAnimation(.easeInOut(duration: 1.0)) { phase = 1 } }
    }
}

// Radial reveal of a dark stage from a tapped card (the Voice beat)
struct RadialReveal<Content: View>: View {
    var origin: UnitPoint; var revealed: Bool; @ViewBuilder var content: () -> Content
    var body: some View {
        content().mask(Circle().scale(revealed ? 3.2 : 0.01).position(x: origin.x * 400, y: origin.y * 860))
            .animation(.easeInOut(duration: 0.6), value: revealed)
    }
}

// Chip → field stretch with the smear (one view, two sizes)
// width: 44 → 320 with .spring(response: 0.45, dampingFraction: 0.75);
// add .scaleEffect(x: stretching ? 1.12 : 1, anchor: .leading) for 120 ms, then release.
// Shared identity across screens: .matchedGeometryEffect(id: "mark", in: ns).
```

Rules when building: respect `accessibilityReduceMotion` (every blur/scale falls back to opacity); keep beats on the 0.6 s / 0.4 s rhythm; never animate more than one hero at a time; and no drawn UI stands in for a real feature — the tour's Form card plays a recording of Form Check, not a sketch of one.

## 6. Build order
1. Transition kit (blur-in, typewriter, ring, sweep, radial reveal, chip-stretch) in GlassCard.swift — half a day, unit-free, previewable.
2. Onboarding opener (4a) — one day; needs the tagline decision for the text.
3. Tour grid (4b) — one to two days; needs one recorded Form Check clip (Lucas) for the Form card.
4. Demo video (4c) — a shoot day per `DEMO-SHOT-LIST.md`, then the motion chrome in Premiere/After Effects.
