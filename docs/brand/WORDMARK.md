# The Morphe wordmark

Final (basic) text logo, supplied by Lucas on 2026-10-13. It replaces every
typed "MORPHE" / monospaced-tracking treatment.

## Files

| File | Use |
|---|---|
| `morphe-wordmark-source.png` | The original Lucas supplied (white on black, 1254 × 1254). Never edit. |
| `morphe-wordmark-white.png` (+ @2x, @3x) | Transparent, white. Dark backgrounds. 824 × 157 at native resolution. |
| `morphe-wordmark-ink.png` (+ @2x, @3x) | Transparent, Midnight Navy #0A1A3A. Light backgrounds. |
| `../assets/morphe-wordmark.png` | The website's copy (used as a CSS mask, so it takes the text color). |
| `Morphe/Assets.xcassets/MorpheWordmark.imageset` | The app's copy, a template image (takes the color of its context). |

The @2x/@3x files are upscaled from the 824 px cut, so the mark stays sharp
up to about 275 pt in the app and 410 px on the web. For anything larger
(billboard, merch print), get the vector original from the designer.

## Rules

- **The name as a logo is always this mark, never typed text.** In the app
  use `MorpheWordmark(height:)`; on the web use `<span class="wordmark"
  role="img" aria-label="Morphe">`.
- **Color comes from context:** white on dark, navy ink on light, the rank
  accent only where a screen already speaks in the accent.
- **A slight blue glow underneath, in the app and on the website** (Lucas,
  2026-10-13): Spartan blue #2957D9 at about 55%, set just below the letters
  and scaled to the mark (app: shadow radius 0.35 × height, offset 0.18 ×
  height; web: `drop-shadow(0 3px 7px rgba(41,87,217,0.55))` on a
  `.wordmark-glow` wrapper, because a CSS mask clips its own filter). Not on
  the pitch deck or print.
- **Size by height.** The mark is about 5.25 : 1. Smallest use in the app is
  9 pt (assistant kickers); the launch beat is 30 pt.
- **Clear space:** at least the height of the "o" on every side.
- **Don't** stretch it, add tracking, outline it, recolor it to anything but
  the palette, or set the name in another typeface as a logo.
- The word "Morphe" in a sentence stays plain text.

## Where it's applied (2026-10-13)

App: launch beat, plan-loading screen, sign-in, the sheet header, the AI
insight kickers (Today and two cards), the celebration kicker, and the share
card header. Website: the header on every page (home, coaches, support,
privacy, terms, invite) and the social preview card. Pitch deck: cover and
close.

Still pending Lucas's decisions: the tagline, the palette, and the store.
