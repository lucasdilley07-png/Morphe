# Investor-lens audit — Morphe (2026-07-30)

Written as a seed-stage diligence memo. Sources: live telemetry
(Tools/metrics_report.py), the full codebase, docs/PAYMENTS.md,
docs/COACH-PILOT.md, AppStore/LAUNCH_CHECKLIST.md, and the four
July audits.

## Verdict, up front

Not fundable today — and unusually well-positioned to become fundable
in one 90-day window. The traction table is empty (1 account: the
founder; 0 activations), so every thesis is still a hypothesis. But
the preparation layer — instrumentation, pricing benchmarks, a written
proof-window with investor-grade targets, security rules verified
against production — is what funded seed decks usually fake. The
binding constraint is not code. It is that the $99 Apple gate is
unpaid, so the clock has never started.

## What's working (real assets)

1. **Execution velocity with quality.** 263 automated tests, 50
   live-verified Firestore security checks, release-config builds,
   privacy manifest, App Store metadata + screenshots done. The July
   log shows 15+ shipped waves in days, each tested and deployed. For
   a solo founder this is the strongest signal in the deal.
2. **A real wedge, not a vibe.** "TRAIN HONEST" is enforced in code:
   every number derives from logs, badges are earned, fake-AI surfaces
   were found and deleted. In a category drowning in AI slop and
   inflated stats, verifiable honesty is a defensible brand position —
   and it's cheap to keep and expensive for incumbents to copy.
3. **The coach wedge is a business, not a feature.** Coach-created
   client profiles, claim-code handoff, consented progress sharing,
   roster tooling — the Trainerize/TrueCoach category runs $19–290/mo
   per coach. Proposed $39/mo is benchmarked, Apple-safe (SaaS via
   IAP), and each coach imports 5–20 athletes: paid acquisition that
   pays YOU.
4. **Growth loops are plumbed, not planned.** Referral links with an
   earned reward, share cards, challenges, universal-link scaffold,
   first-party telemetry with named targets (activation ≥40%, D30
   ≥10–12%, k>0) and a weekly report script. Most seed companies
   bolt this on after the raise.
5. **COGS discipline.** The read-diet work means ~300 users fit in
   near-zero infra spend; coach SaaS revenue lands on software
   margins from day one.
6. **Retention scaffolding.** Streaks, duo streaks, presence, weekly
   boards, comeback flow — the mechanics that drive the D30 number
   exist and are honest (no dark patterns to unwind later).

## What's missing (deal-breakers as of today)

1. **Traction: zero.** One account, zero activation events, no cohort
   old enough for D7. Nothing — retention, coach willingness-to-pay,
   virality — is validated. This is pre-proof, full stop.
2. **Distribution is locked and the key is $12/month.** No Apple
   Developer Program → no TestFlight → no strangers → no data. Every
   week of further polish has negative information value compared to
   25 strangers using the app.
3. **Revenue: $0 and unpriceable.** Payment rails are deliberately
   unwired (correctly — the decisions doc is good), but pricing is
   PROPOSED, not signed. Willingness-to-pay can't be measured without
   a price in front of a coach.
4. **No moat yet, only moat design.** Network effects at n=1 are
   zero; proprietary training data at n=1 is zero. The design is
   right; the asset doesn't exist until users do.
5. **Solo-founder concentration risk.** One person is product, eng,
   brand, and (planned) sales. The content system exists on the
   personal-brand side but is unproven as an app funnel.
6. **The "AI" story needs a straight answer.** Today it's an honest
   rule-based assistant. That's fine for users, but investors will
   price "AI fitness" claims; the roadmap needs the server-proxied
   real-model milestone (post-Blaze) stated plainly, or the word AI
   dropped from the pitch.

## What needs improvement (ranked, all fixable)

1. **Start the clock this week.** Pay the $99, host the
   already-written privacy policy (5-minute GitHub Pages step),
   upload to TestFlight, invite 10. The 90-day proof window in
   LAUNCH_CHECKLIST §5 is the investor milestone sheet — it is
   currently a plan with no start date.
2. **Run the coach pilot as THE company.** 10–25 paying coaches at
   ≥60% athlete attach (docs/COACH-PILOT.md) is the fundable number.
   Consumer D30 is supporting evidence, not the headline.
3. **Onboarding vs the activation target.** 13 steps against a
   stated activation bar of ≥40% is a self-inflicted risk; the
   trimmed flow shipped, but the step-count cut is still pending a
   product decision — make it before strangers arrive.
4. **Sign the pricing.** $39/mo coach, $5.99/mo Pro are benchmarked
   proposals; commit or revise, then instrument the paywall views.
5. **Cosmetic credibility:** placeholder "M" icon, iPad pass, full
   accessibility sweep — TestFlight-fine, App-Store-review risky.
6. **Metrics hygiene:** weekly metrics_report on a fixed day into a
   cohort sheet; the empty table is the deck's appendix A.
7. **Post-Blaze security:** App Check before any public scale (one
   hostile client can drain the project quota today).

## The 90-day fundability test (already written, restated)

Week 0: TestFlight live. Weeks 1–12: coach pilot. The bar that
changes conversations: D30 ≥ 10–12% (3x category), activation ≥40%,
organic k > 0, and ≥10 coaches paying real money. Hit those and this
memo's verdict flips; miss them and the honest answer is bootstrap on
coach revenue, not raise.
