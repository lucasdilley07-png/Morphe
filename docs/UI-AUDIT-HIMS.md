# Hims UI Audit → Morphe Interface Revamp — 2026-08-09

Hims' identity (stable, well-documented): warm cream surfaces, large serif
display type in sentence case, deep-charcoal text, softly rounded cards
(16–24pt), full-pill dark CTAs, one decision per screen, radical whitespace,
calm clinical-but-human copy. What it FEELS like: considered, trustworthy,
unhurried.

## What Morphe adopted (shipped through the token layer — every screen)
1. **Soft geometry**: MorpheTheme.radius 3 → 16; chipRadius 2 → 8. Cards, fields, tiles, and sheets round with it; sub-52pt chrome uses
   radiusSmall (8) and legacy 2pt literals were migrated in the follow-up
   polish wave. Circular avatars stay circles by design.
2. **Pill CTAs in sentence case**: Primary/Secondary button styles are now
   full capsules with humanist rounded type — Hims' "one obvious next
   step" control replaces the shouted mono-caps command bar.
3. Already aligned before this pass (kept): one-decision-per-screen
   onboarding, calm non-shouty reminder policy, generous single-column
   card layouts, honest unhurried copy.

## What Morphe deliberately did NOT adopt, and why
- **Cream/light editorial surfaces + serif display**: Morphe's ink-black +
  gold TRAIN HONEST identity is the brand (docs/BRAND-AUDIT-2026-07.md),
  matches the app icon/launch mark, and a light conversion would touch
  hundreds of hardcoded .white/.black text styles — a multi-day,
  high-regression rework days before launch. If wanted, it should ship as
  a selectable "Calm" appearance post-launch, not a pre-launch rewrite.
- **Muted photography-led screens**: Morphe's content is data the user
  earned, not lifestyle imagery — posters over photos stays.

## Result
The app keeps its identity (ink + gold + mono telemetry labels) and gains
Hims' softness and calm: rounded, breathing, sentence-case actions. The
full light-editorial conversion is scoped and parked as a post-launch
appearance option.
