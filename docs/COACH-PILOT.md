# The Coach Pilot — 10 to 25 paying coaches in 90 days

The investor-audit verdict, operationalized. The consumer tracker fights
Hevy at a $23.99/yr price floor; the **coach platform** monetizes at
10-100x that ARPU and is the defensible wedge. This is the door-to-door
playbook — zero ad spend, all product-led.

## Why a coach says yes (the pitch, 30 seconds)

"You're juggling spreadsheets or paying Trainerize $50-250/month. Morphe
gives you: create every client's profile before they ever install anything,
log their sessions yourself, and when a client joins, one code moves their
entire history into their own account — and they get the best free workout
tracker on the store. When they consent, you see their real streak, volume,
sessions, and PRs live. $39/month, unlimited clients, first month free."

The demo IS the product: create a managed client in front of them in 60
seconds, log a workout for it, show the claim code.

## The funnel (each step is already built)

1. **Create roster** — coach adds managed clients (no client install needed).
2. **Claim codes out** — clients install, enter code, arrive with full
   history (activation on day 0, `coach_claimed` telemetry event fires).
3. **coachShare consent** — clients flip "Share with coach"; the coach's
   dashboard goes live per client.
4. **Convert** — after the free month, the coach tier ($39/mo, product ids
   scaffolded) is the bill. Before IAP exists, invoice manually — a Stripe
   payment link is fine for the pilot; move to IAP at storefront flip.

## Where to find the first 25

- Coaches at YOUR gym (in-person demo, highest close rate).
- Instagram/TikTok fitness coaches with 1k-20k followers (small enough to
  answer DMs, big enough to have paying clients) — the content-creation
  pipeline already targets this world.
- r/personaltraining, coach Discords, local strength clubs.
- Every converted coach: ask for one referral (coaches know coaches).

## What to measure weekly (Tools/metrics_report.py + a spreadsheet)

| Metric | Target by day 90 |
|---|---|
| Coaches pitched | 100+ |
| Coaches active (roster ≥3 clients) | 25 |
| Coaches PAYING | 10-25 |
| Roster attach (clients claimed / invited) | ≥60% |
| Client D30 (coach-acquired cohort) | ≥15% (they should beat solo users) |

## The kill criteria (honesty rule applies to strategy too)

If after 90 days: <5 paying coaches OR attach <30% — the coach wedge is
disproven at this price/pitch. Fall back to the bootstrap consumer path
(Hevy/RP model) and revisit coach pricing/packaging with the interview
notes. Write down WHY each coach said no; that list is worth more than
the revenue.
