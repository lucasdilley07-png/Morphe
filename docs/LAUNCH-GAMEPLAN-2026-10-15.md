# Morphe — launch gameplan (2026-10-15)

The one page that says what is done, what is being built now, what waits
on Lucas, and the order. Dates from Lucas's targets: Apple launch the
weekend of 10/17 or the week after; funding, merch and content producing
by 10/31. Honest framing on funding: by 10/31 it is a pipeline and first
conversations, not a close — the investor audit's 90-day proof window
starts at TestFlight.

## Done this week (all pushed, 427 tests green, on Lucas's phone)
- Morphe AI online: the relay (Cloud Function, Sonnet 5.5, $45 budget under
  the $50 key cap, 18+, 30/day, worst-case cost held before each call),
  the app's two doors, consent, ratings opt-in, policy, audited twice.
- AI rebuild Waves 0–3: Hey Morphe in the background and never cut
  mid-sentence; on-device intent router + headless Siri intents; Form
  Check filter, angle/tilt guards, honest copy; Food Check on-device label
  OCR, strict report schema, plate items with ranges, USDA matching.
- Connections (strap, Health, Watch, supplements, "Add an app"),
  Discover sorting, prompt split for caching, chat persistence.
- Reverse-engineering docs: AI features vs references; motion grammar of
  the two Shorts mapped onto onboarding, tour and demo.

## Building now, in this order (me)
1. **Transition kit + onboarding opener** (today): blur-in/out, typewriter,
   ring pulse, colour sweep, radial reveal, chip→field stretch; the helmet
   mark morphs in, ring, "Meet Morphe · TRAIN HONEST", the mark becomes
   the name field; Reduce Motion fallbacks. (Tagline is one string.)
2. **Tour grid** "Train with Voice · Form · Fuel · Morphe AI" with the real
   orb stage for Voice; the Form card needs ONE recorded Form Check clip
   from Lucas (placeholder until then — never a drawn mock).
3. **Wave 4 — memory** (3–4 days): `AIMemory` schema, post-chat extraction
   with a strict schema via the relay, `users/{uid}/private/aiMemory`,
   "Morphe remembers" screen (edit/delete/forget all), retrieval over logs,
   rating → weekly eval, consent default off for health-type facts.
4. **Release audit** (1 day): fresh-eyes pass on everything since 10/13,
   Release build, crash-free run on the phone, accessibility sizes,
   App Store metadata + privacy answers updated for the relay, OCR,
   Health read, background audio.
5. **Screenshots + demo video chrome**: screenshots once a signed-in
   simulator session exists (Lucas signs in on the Pro Max sim); the demo
   per `docs/DEMO-SHOT-LIST.md` on a shoot day, motion chrome after.
6. **Form Check clip harness**: when Lucas records ~15 clips per movement
   (good / shallow / knees in / leaning), the harness runs them in the
   test suite and the thresholds get validated against reality.

## Waits on Lucas (in order of what unblocks the most)
1. **Blaze approval** → `firebase functions:secrets:set ANTHROPIC_API_KEY`
   then `firebase deploy --only functions` (both in BACKEND/). Tell me
   "deployed" and I run the live checks. Until then the online toggle
   shows the honest "hit a snag" line; the own-key path works.
2. **Apple Developer Program ($99)** — pay today; approval 24–48 h. Then:
   switch the four targets to the paid team, App Attest entitlement back,
   enforce App Check (flip `MORPHE_AI_REQUIRE_APP_CHECK=true`), archive →
   TestFlight → 10 testers → submit. The 90-day clock starts at TestFlight.
3. **Tagline** — "TRAIN HONEST" is used everywhere in the build from today;
   say the word if it should be something else.
4. **One Form Check clip** for the tour card; **~15 clips per movement** for
   the harness (can be the same session).
5. **Sign in on the Pro Max simulator** once so I can take the store
   screenshots.
6. Business items (unchanged from the 10/14 plan): Anthropic key $50 cap
   (done), trademark knockout search before any merch print, seller's
   permit, print-on-demand with two SKUs, investor list of 20–30, deck from
   real artifacts, coach pilot outreach, content from real artifacts only.

## Launch checklist (the gate for "submit")
- [ ] Relay deployed and live-checked (401 / 403 age / stream / 429 limit).
- [ ] App Check enforced; `MORPHE_AI_REQUIRE_APP_CHECK=true`.
- [ ] Release build, 0 crashes across: onboarding, a full session with
      voice, Form Check, a label and a plate check, chat with the relay,
      sign-out/in, background Hey Morphe for 10 min.
- [ ] Accessibility: AX text sizes on Connections, Fuel, Form review, tour.
- [ ] Privacy policy + App Privacy answers match the code (relay, OCR,
      Health read, background audio, ratings, memory).
- [ ] Age gate + relay 18+ verified on a fresh account.
- [ ] Screenshots (6) + demo video on the site; store URLs pasted.
- [ ] TestFlight: 10 testers, one week, fixes shipped.
- [ ] Submit with the reviewer account and the review notes in
      `AppStore/LAUNCH_CHECKLIST.md`.

## Weekly rhythm until launch
Build → fresh-eyes audit → fix wave → verify on the phone, per wave.
Metrics report every Monday from TestFlight day (`Tools/metrics_report.py`).
