# Network — TikTok-lens audit + scale plan (2026-08-01)

Auditor stance: what a TikTok feed engineer would say about Morphe's
Network, split honestly into NOW (buildable today, shipped in this
wave) and GATED (impossible until Lucas flips Blaze + $99 + the
App Store 1.2 moderation commitment — same three unlocks documented
in NETWORK-SNAP-PLAN.md).

## The verdict

Morphe's Network has social-graph mechanics (follows, streaks,
stories, chats) but consumes like a bulletin board: chronological,
card-list, tap-to-continue. TikTok's growth engine is none of those
mechanics — it is (1) full-screen one-item-at-a-time consumption,
(2) a ranked feed that rewards engagement, (3) zero-friction
continuation, (4) one-gesture engagement. All four are buildable
TODAY on our honest data-driven cards. The fifth pillar — video — is
hard-gated and pretending otherwise would be theater.

## T-fixes (this wave)

- T1 IMMERSIVE MODE: full-screen vertical pager over the feed (the
  9:16 session-card language already exists) — swipe up = next post,
  the TikTok consumption pattern on honest content. Entry chip on the
  feed; swipe-down exits.
- T2 RANKED "FOR YOU": engagement-weighted client-side ranking
  (recency decay + reactions + comments + followed-author boost +
  same-author diversity guard). Chip toggle Latest/Ranked — ranked is
  default, honestly labeled. At ≤1k users a transparent heuristic
  beats an "algorithm" and can be explained in one sentence.
- T4 DOUBLE-TAP TO REACT on feed cards (system-wide muscle memory).
- T8 INFINITE SCROLL: auto-load the next page when the last card
  appears; the Load Older button stays as the fallback affordance.

## GATED tier (the real TikTok era — needs Lucas's unlocks)

1. VIDEO: capture (Form Clips already record) → upload requires
   Cloud Storage (Blaze) → full-screen video feed slots into T1's
   pager unchanged. Architecture: clips ≤30s, HLS not needed at this
   scale, storage rules mirror posts, thumbnails client-generated.
2. PUSH ENGAGEMENT LOOP: "X reacted to your session" requires FCM +
   Cloud Functions (Blaze). Until then T5 (client-side activity diff)
   is the honest substitute — planned next wave.
3. REAL RANKING SERVICE + App Check + rate limits: Functions-gated.
4. Moderation pipeline for UGC media: App Store 1.2 commitment —
   operational, not code.

Everything in the gated tier has its socket built by this wave: the
pager renders any full-screen content, the ranker is a swappable
function, the reaction wiring is one-per-uid docs that FCM can fan
out from later.
