# Audit: Apple's Liquid Glass + motion, and Siri — what Morphe mirrors

Researched live 2026-10-09 (Apple HIG Materials + Motion, Apple's
"Adopting Liquid Glass" overview, WWDC25/26 SwiftUI sessions, the iOS 27
MacStories review, two open-source Siri-glow reconstructions). Morphe side
read from the repo at `10cde73`. Lucas's iPhone 17 Pro Max runs **iOS 26.6**;
the Mac has **Xcode 26.6 / iOS 26.5 SDK**. The app deploys to iOS 17, so
every glass call is `if #available(iOS 26.0, *)` with the current
`.ultraThinMaterial` as the fallback.

---

## 1. Apple's laws (verbatim where it matters)

**Where glass lives.** "Liquid Glass forms a distinct functional layer for
controls and navigation elements — like tab bars and sidebars — that floats
above the content layer." And the rule that decides most of this audit:
**"Don't use Liquid Glass in the content layer."** Cards, lists, media:
never glass. Exception: transient controls inside content (a slider or
toggle takes on glass only while a finger is on it).

**Two variants.** *Regular* "blurs and adjusts the luminosity of background
content to maintain legibility" — "most system components use this
variant"; use it wherever there is real text. *Clear* is "highly
translucent" and is only for components "that appear over visually rich
backgrounds" (photos, video); if that background is bright, "consider adding
a dark dimming layer of 35% opacity."

**Sparingly.** "Use Liquid Glass effects sparingly… overusing this
material in multiple custom controls can provide a subpar user experience by
distracting from that content. Limit these effects to the most important
functional elements in your app." Don't layer glass on glass ("glass cannot
sample other glass"); put sibling glass views in one `GlassEffectContainer`
so they share a sampling region, render in one pass, and can morph into
each other (`glassEffectID` in a `Namespace`).

**Touch.** "The movement of Liquid Glass responds to direct touch
interaction with greater emphasis to reinforce the feeling of a tactile
experience." In code: `.glassEffect(.regular.interactive())` — the glass
scales/brightens under the finger. System buttons: `.buttonStyle(.glass)`
and `.glassProminent`, with `.buttonBorderShape(.capsule / .circle)`.

**Motion.** "Add motion purposefully… Don't add motion for the sake of
adding motion." "Aim for brevity and precision." "Generally avoid adding
motion to UI interactions that occur frequently." "Let people cancel
motion." "Make motion optional" — haptics and audio as the alternatives.
Glass-specific: morphing between shapes is the signature move (a pill
becomes a menu, a button becomes a sheet), lensing comes free, and
continuous animation *over* glass is called out as a battery/thermal drain.

**What iOS 27 changed (shipped 2026-09, not on Lucas's phone yet).** A
readability pass, not a redesign: darker edges, a user transparency slider,
layered app icons, cheaper rendering on older devices, nested containers
without seams. **No new or deprecated glass APIs** — `glassEffect`,
`GlassEffectContainer`, `glassEffectID` are unchanged, and Xcode 27 drops
the opt-out, so system chrome is glass whether an app likes it or not.
New SwiftUI that touches us: `toolbarMinimizeBehavior(.onScrollDown)`,
`Tab(role: .prominent)`, swipe actions on any view.

**Accessibility is automatic for glass** (Reduce Transparency → more
frost, Increase Contrast → borders, Reduce Motion → calmer morphs); custom
Canvas animations stay ours to gate.

---

## 2. What Siri actually looks like now

| | iOS 18 → 26 (Lucas's phone today) | iOS 27 (where Apple is going) |
|---|---|---|
| Entry | A pink glow erupts from the side button and becomes a **rainbow border around the whole screen**; the screen behind distorts briefly | A **dark Liquid Glass orb descends from the Dynamic Island**; on iPad it drips out of the bezel like a drop of liquid and refracts what's under it |
| Listening | The border breathes | The orb **pulses slightly** |
| Speaking | — | The **multicolor waveform reacts in real time** — the one element carried over |
| Answer | Translucent panel | "A dark, translucent overlay" with text, images and inline app cards |
| Exit | Border fades | Orb retracts |

How the glow is built in the open-source reconstructions (for the record):
an inset rounded rectangle stroked ~5–7 pt with an angular/mesh gradient
of 7 colors, a second copy blurred ~4 pt for bloom, gradient stops
reshuffled every 0.25–0.3 s with `easeInOut`; mesh-gradient versions use a
3×3 `MeshGradient` whose points ride sine waves in a `TimelineView`. CPU
cost of the naive version is 40–60 % of a core; the "low-power" variant
halves it. That cost is why the orb won: a small glass disc with a
Canvas waveform inside is cheaper than a full-screen animated border.

---

## 3. Morphe today, element by element

| Element (file) | Today | Apple's law | Verdict |
|---|---|---|---|
| Tab dock `MorpheTabBar` (GlassCard.swift:1816) | `.ultraThinMaterial` capsule + 1 pt hairline + two shadows, icons + mono labels, 4 pt dot for selection | Navigation layer → glass; glass draws its own edge and lift | **Glass on 26** (`regular.interactive()` in a `Capsule`), drop the hairline and shadows there, keep material on 17–25. Selection becomes a **morphing glass pill** behind the active tab (`glassEffectID`) — this is the one Apple-signature move the app lacks |
| Header buttons `HeaderCircleButton` (RootView.swift:~780) | Solid `MorpheTheme.ink` rounded squares + hairline, floating over scroll content | Controls floating over content are exactly the functional layer | **Glass circles** on 26 (`.buttonStyle(.glass)` + `.buttonBorderShape(.circle)`); one `GlassEffectContainer` for the row. Avatar stays a photo tile |
| AI button `FloatingAIAgentButton` | Compact: the helmet image + shadows (fine). Wide intro pill: solid ink capsule + accent hairline | Floating control → glass | Wide pill → `glassProminent`-style with the brand tint; compact stays as is (an image over glass would be glass-on-glass) |
| Voice pills `VoiceTranscriptPill` / `VoiceExchangeChip` (GlassCard.swift:343/388) | `.ultraThinMaterial` + hairline | Text-heavy → *regular* glass | Glass on 26 |
| **`GlassCard`** (198 uses) | Flat tinted panel + hairline + HUD corner ticks — not glass at all | **Content layer: never glass** | **Keep flat. Do not convert.** The name is the only thing wrong with it. The corner ticks are the one memorable element — keep them |
| `PremiumBackground` | Flat ink + faint engineering grid | Content canvas | Keep; the grid is what glass refracts, so the chrome will look *more* alive over it, not less |
| Sheets (15× `presentationCornerRadius(28)` + custom background) | Forced radius, opaque `PremiumBackground` | "Audit the backgrounds of sheets… remove custom background views"; on 26 the system draws the glass edge and its own radius | Keep the content background (it is content) but **stop forcing the radius on 26**; let the system sheet chrome through |
| `PrimaryCTAButtonStyle` / `SecondaryCTAButtonStyle` | Solid tinted capsule / outlined capsule, 0.12 s press fade | In-content actions are not glass in Apple's own apps (only toolbar actions are) | Keep. Add the press scale Apple's glass has (0.97, spring 0.2) so content buttons feel like the same family |
| Day popup + Hey Morphe scrims | `Color.black.opacity(0.6)` | Dimming under translucent chrome: 35 % is Apple's number for clear glass over bright media; a modal scrim can be darker | Keep 60 % for the popup (a modal); **drop to 35 % for Hey Morphe** once the orb is glass — the app should stay visible under a voice exchange, like Siri |
| Hey Morphe overlay (RootView.swift:~386) | Full dim + a 240 pt centered frequency ring + transcript pill at the top | Siri 27: orb from the island, pulse, real-time waveform, dark translucent answer | **Rebuild as the orb** — section 4 |
| Motion vocabulary | 22× `easeInOut 0.2`, 11× `0.25`, 9× `0.3`; 8 different ad-hoc springs; 0 uses of `.sensoryFeedback`; haptics via `Haptics.*` | "Brevity and precision"; system components already animate; don't animate frequent interactions | Consolidate to **three named springs** and two eases in `MorpheTheme`; stop hand-animating tab switches (glass morph does it); keep `Haptics` (declarative `.sensoryFeedback` is a wash) |
| Light/dark | Follows the iPhone | Glass adapts automatically | Nothing to do |
| App icon | Lucas's glass tile, flat PNG | iOS 26 icons are **layered** (Icon Composer) so the system can render default / dark / clear / tinted variants | Lucas's task: rebuild the icon as layers in Icon Composer (Xcode 26 ships it). Until then the system flattens it — looks fine, just not glass |

Net: Morphe is already *structured* the way Apple wants — flat content,
floating chrome, a canvas that refracts. What's missing is the material on
the five chrome surfaces, the one morph, and a Hey Morphe that looks like
2026 instead of 2024.

---

## 4. Hey Morphe → the Siri pattern, in Morphe's identity

**Entry.** On the wake, a **dark glass orb (64 pt) descends from the
Dynamic Island** (spring, response 0.5, damping 0.8) to ~110 pt from the
top. The orb is `glassEffect(.regular.tint(black 0.45), in: Circle())` with
the **white helmet** inside at 28 pt — the character is in the glass, which
is the part Siri can't copy. A **thin brand-blue edge glow** (2 pt stroke +
6 pt blurred twin, blue → glass-blue → white gradient, *not* rainbow) rides
the screen edge at 40 % while listening — the iOS 26 cue Lucas's phone
users already recognize, kept quiet. Haptic: the existing `Haptics.wake()`.

**Listening.** The orb **pulses** with the mic (scale 1.0 → 1.06 on real
RMS, the same `voiceLevel` the ring uses). The dim drops from 60 % to
**35 %** so the app stays visible. The transcript appears in a glass pill
directly under the orb, growing word by word (it already does, just moves).

**Speaking.** The **frequency ribbons become the waveform** — the existing
Canvas, now 120 pt and drawn *under* the orb rather than as a 240 pt
centerpiece, still driven by real audio energy (Apple's own rule, and ours
since 2026-09). Blue/white ribbons, never multicolor.

**Answer.** The reply lands in a **dark translucent glass panel** below the
waveform (regular glass, black 0.5 tint, 20 pt radius, max 340 pt wide),
text only; the exchange chip we have becomes this panel.

**Exit.** Any touch (kept) — the orb **retracts up into the island** (spring
0.35/0.85), the glow fades in 0.2 s, the panel fades. Reduce Motion: the orb
fades in place, no descent, no pulse, no glow; the waveform renders static.

**Cost.** One glass disc + one glass pill + one glass panel = three glass
views in one container; the only continuous animation is the Canvas, which
is not glass. No full-screen animated border, so none of the 40–60 % CPU
the reconstructions pay.

**iOS 17–25 fallback.** Same layout with `.ultraThinMaterial` and the dark
tint drawn as a fill; the descent animation is plain SwiftUI and works
everywhere.

---

## 5. Build plan

| Phase | What | Files | Size |
|---|---|---|---|
| **1 — Chrome goes glass** | Dock (container + morphing selection pill), header buttons, AI intro pill, voice pills; sheets stop forcing the radius on 26; `MorpheTheme.Motion` with three springs | GlassCard.swift, RootView.swift, MorpheTheme.swift, the 15 sheet call sites | half a day |
| **2 — Hey Morphe orb** | Section 4 end to end, Reduce Motion path, fallback | RootView.swift overlay + `HeyMorpheEngine` state hooks (no engine logic changes), GlassCard.swift (ring size/waveform mode) | one day |
| **3 — Motion consolidation** | Replace the 8 ad-hoc springs and the 0.2/0.25/0.3 spread with the named set; press scale on CTAs; `toolbarMinimizeBehavior` equivalent for the floating header (hide on scroll down, return on scroll up) | app-wide, mechanical | half a day |
| **Lucas** | Layered app icon in Icon Composer (so the 26/27 clear/tinted icon variants render as glass) | Assets | 30 min |

**Not doing, on purpose:** glass on `GlassCard` (HIG violation and 198
sites of visual noise); rainbow Siri colors (brand is blue/white); a
full-screen animated border as the main cue (cost, and Apple just retired
it); any iOS 27-only API (nothing we need is 27-only, and the SDK here is
26.5).

**One decision for Lucas:** the orb (iOS 27 Siri, where Apple is going)
or the full edge glow (iOS 26 Siri, what his phone shows today). The plan
above builds the orb and keeps a thin edge glow as the listening cue — both
cues, Apple's newer one in front.

---

## Sources (retrieved 2026-10-09)

- Apple HIG — Materials (Liquid Glass): developer.apple.com/design/human-interface-guidelines/materials
- Apple HIG — Motion: developer.apple.com/design/human-interface-guidelines/motion
- Apple — Adopting Liquid Glass: developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass
- WWDC26 — What's new in SwiftUI: developer.apple.com/videos/play/wwdc2026/269/
- MacStories — iOS and iPadOS 27 review, Siri section: macstories.net/stories/ios-and-ipados-27-review/5/
- Spaceport — Liquid Glass in SwiftUI, iOS 27 practical guide: spaceport.build/blog/liquid-glass-swiftui
- conorluddy/LiquidGlassReference (API signatures, pitfalls): github.com/conorluddy/LiquidGlassReference
- jacobamobin/AppleIntelligenceGlowEffect (glow reconstruction, costs): github.com/jacobamobin/AppleIntelligenceGlowEffect
- Rudrank Riyam — Creating the new Siri animation in SwiftUI: rudrank.com/exploring-swiftui-creating-new-siri-animation
- AppleInsider — iOS 26 release (Siri glow description): appleinsider.com/articles/25/09/15/apple-releases-ios-26-with-liquid-glass-and-more-intelligence
