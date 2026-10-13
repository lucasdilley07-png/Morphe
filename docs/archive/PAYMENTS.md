# Morphe Payments — design decisions before any code

Payments touch Apple policy, tax law, and real money — this document exists so
the build starts AFTER the business decisions, not before. Nothing here is
wired; BookingView's payment copy remains explicitly "no charge" until this
lands.

## The two money flows (Apple treats them oppositely)

| Flow | What it is | Apple's rule | Rails |
|---|---|---|---|
| Coach services | A client pays a coach for real-world coaching (sessions, programming) | **External payments ALLOWED** (physical/real-world service, like Uber/ClassPass) | Stripe Connect |
| Morphe Premium | App features (advanced analytics, AI tools, content) | **Must use Apple In-App Purchase** (30%/15% cut) | StoreKit 2 |

Mixing these up is an App Review rejection. Coach payments must never unlock
app features; Premium must never be purchasable outside IAP.

## Coach payments (Stripe Connect) — the marketplace flow

- Coaches onboard via Stripe Connect Express (Stripe handles KYC, payouts,
  1099s). The "Payouts" button in BookingView becomes the Express onboarding
  link.
- Clients pay per booking (or per package) with Apple Pay/card via
  PaymentSheet; Morphe takes an application fee.
- **PROPOSED DECISIONS (2026-07-27, benchmarked — Lucas signs off before
  any App Store Connect / Stripe setup):**
  - **Phase 1 is SaaS, not marketplace:** coaches pay a flat
    **$39/mo or $349/yr** ("Morphe Coach", IAP product ids
    `app.morphe.coach.monthly/yearly`, already scaffolded in PremiumGate)
    for the roster/programs/coachShare/messaging tooling. Benchmark:
    Trainerize/TrueCoach/Everfit run $19-290/mo per coach, with real
    bills 40-60% above sticker. Flat SaaS is simpler than a take rate,
    entirely Apple-safe (app features via IAP), and monetizes the moat
    (roster import + consented progress) on day one.
  - **Phase 2 marketplace take rate: 10% platform fee** on Stripe-billed
    coaching payments, Stripe's ~2.9%+30c passed through — only after
    ≥25 paying coaches prove the SaaS layer.
  - **Consumer "Morphe Pro": $5.99/mo, $39.99/yr** — anchored above
    Hevy's $2.99/$23.99 floor (don't fight the free-tier king on price),
    below Fitbod's $15.99/$95.99, gated on programs + advanced analytics
    + nothing safety-related.
  - **Refunds:** full refund for sessions cancelled ≥24h ahead; inside
    24h at the coach's discretion; disputes adjudicated from the booking
    record (Stripe evidence API).
- Requires: Firebase **Blaze** plan + Cloud Functions (create PaymentIntents,
  Connect webhooks — the client app must never hold secret keys), and the
  booking flow writing appointments to Firestore (see SCHEDULING work).
- Refund policy, dispute handling, and the platform-fee % are business
  decisions — pick before building.

## Morphe Premium (if/when) — StoreKit 2

- One subscription group ("Morphe Premium" monthly/annual) via StoreKit 2;
  entitlement mirrored to users/{uid} by a server notification (App Store
  Server Notifications → Cloud Function) so rules can gate premium content.
- Decide what's premium vs free BEFORE building the paywall: candidate
  premium set = advanced Progress charts, AI coach depth, form-check history.
  Everything safety-related stays free (honest-app rule: never paywall
  safety).

## Prerequisites checklist (in order)

1. Apple Developer Program ($99) — also unblocks TestFlight.
2. Firebase Blaze plan (pay-as-you-go; Functions + outbound network).
3. Stripe account + Connect platform profile approval.
4. Decisions: platform fee %, refund policy, what (if anything) is Premium.
5. Then: Functions repo scaffold, PaymentSheet integration, webhook →
   Firestore entitlements, rules update, publish.

## What can ship BEFORE payments

The scheduling/appointments system works fully with free bookings ("Request
Booking — no charge", exactly today's honest copy). Payments bolt onto
confirmed appointments later without changing the calendar model.
