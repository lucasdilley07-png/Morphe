# Network Page — Snapchat-Mechanics Plan (2026-07-28)

Goal: make Network feel as alive as Snapchat does — while staying
legally clean and visually MORPHE. The line that keeps both true:

**Copy the MECHANICS, never the EXPRESSION.** Interaction patterns —
stories rows, tap-to-advance viewers, streaks between friends,
ephemerality, camera-first capture — are functional ideas used across
Instagram/WhatsApp/YouTube and are not ownable. What IS protectable is
Snap's expression: the ghost mark, Bitmoji's look, their icon set,
their specific screen arrangements traded on as identity, and names
tied to their brand (Snapstreak, Bitmoji, Snap Map). None of that ever
enters Morphe. Everything below wears the HUD skin — ink, mono
micro-labels, corner ticks, gold accents. (Working notes, not legal
advice; have a lawyer sanity-check before launch marketing leans on
any of it.)

The strategic unlock: Snapchat's soul is "what are my people doing
RIGHT NOW," expiring daily. Morphe already generates that content
automatically — every logged session renders an honest, branded,
story-shaped card. **Data-driven stories need no photo uploads, no
Storage bucket, no moderation pipeline** — the exact reason
photo/video stories were deferred stops applying.

---

## Where the page is today

Composition (ChatView): title → text composer ("Share a win…") →
athlete search card → filter chips (All/Following/Saved) → post cards
→ weekly board card. Solid plumbing after this week's work (real
Firestore feed, load/failed states, typed reactions, comments, author
push, repost, session stat cards) — but it reads as a text-first
timeline: no presence ("who trained today?"), no full-screen content
moment, reactions hidden behind long-press, search and composer
occupying the hero position that energy should own.

---

## S1 — Today Row + Story Viewer (no backend changes)

The centerpiece. All from data already on the device.

1. **"TRAINED TODAY" bubble row** at the very top (replaces search as
   the hero; search moves behind the header magnifier that already
   exists). Horizontal avatars of followed athletes whose posts are
   <24h old, derived from the loaded feed. Unseen = 2px gold ring
   (HUD square-ish ring, not a soft gradient circle); seen = hairline
   white. Your own bubble first — tapping it with no post today opens
   the composer ("your people can't see a session you didn't share").
2. **Full-screen story viewer**: tapping a bubble presents their
   <24h session cards full-screen — the SAME 9:16 stat-card layout
   the share cards use (ink, corner ticks, TRAIN HONEST footer), so
   the viewer looks like Morphe's own posters, not like anyone's
   photo story. Mechanics: tap right = next card, tap left = back,
   segmented progress ticks across the top (thin mono rectangles, not
   rounded pill segments), swipe down to dismiss, auto-advance ~5s.
3. **Quick-react bar** inside the viewer: the four existing typed
   reactions (heart/fire/power/clap) as one visible row — no
   long-press discovery problem — writing the same one-per-uid
   reaction docs as the feed. Plus "Reply" → comment composer inline
   (and the coach/claimed thread where one exists).
4. **Ephemerality, honestly**: the row only shows the last 24h; the
   permanent feed below is unchanged. Nothing is deleted — the row is
   a lens, not a shredder (matches the no-fake-data house rule).

## S2 — Buddy streaks + presence depth

5. **Training streaks with a buddy** — the Snapstreak mechanic,
   Morphe-honest: for mutual follows, count consecutive days BOTH
   posted a session (derivable from feed history; deeper truth comes
   from party/coachShare data where consented). Flame + count chip on
   feed rows and story bubbles. Name it something ours: "Duo Streak"
   / "Tandem". Never "Snapstreak".
6. **Board strip in the row**: the weekly leaderboard's top mover as
   a final bubble ("board" tile) — tap = board story card.
7. **Reply-to-session → thread**: swipe-up-style reply routes to the
   coach/claimed thread when linked, else drops a comment — one
   gesture, honest destinations.

## S3 — split into the honest-now half and the gated half

**SHIPPED (2026-07-29): Form Clips.** The Form Check camera records
≤30s clips with the pose overlay running (movie output on the same
capture session, mirrored to match the preview), then hands the file
to the SYSTEM share sheet — Photos, Messages, IG, TikTok. The clip
never touches Morphe's backend, so there is no Storage bucket and no
moderation surface: capture-in-Morphe, share-anywhere. Telemetry:
`form_clip_captured`.

**STILL GATED: in-app photo/video stories.** Three unlocks, all
Lucas's to make — none of them code:
1. **Blaze billing** — new Firebase projects require the paid plan
   for a Cloud Storage bucket; uploads are impossible without it.
2. **The $99 Apple account** — UGC media isn't even TestFlight-able
   without it.
3. **The moderation commitment** — App Store 1.2 for user photo/video
   means a review pipeline, image-capable report tooling, and takedown
   SLAs. That's an operational promise, not a feature.
Once those flip: Storage rules + upload path + story-media documents +
image moderation queue (extend Tools/review_reports.py), and Form
Clips gain a "to your story" destination next to the share sheet.

9. Avatar identity upgrades (Morphe's own HUD-style avatar system —
   angular, mono-accented; never Bitmoji-adjacent rounded cartoon
   people) — unchanged, post-launch.

## Do-not-copy list (expression, not mechanics)

- Ghost logo or any silhouette-in-yellow-square app iconography
- Bitmoji look-alikes; cartoon avatar marketplaces
- Their names: Snap, Snapstreak, Bitmoji, Snap Map, Discover-as-
  branded-layout
- Their exact chrome: rounded story rings + white pill progress bars +
  their caption typography as a set (any ONE generic element is fine;
  the recognizable ensemble is what trade dress protects)
- Camera-first APP entry (mechanically fine, but it's also wrong for
  Morphe — Today's mission is the right home screen)

## Sequencing

S1 is one focused session (bubble row + viewer + react bar), pure
client, feeds existing telemetry (`post_published`, reactions). S2
adds the streak derivation + tests. S3 waits for the $99 account,
Storage, and moderation — same gate the handoff already set.
