# Morphe — start-up class pitch notes (2026-10-16)

Every number below is from the repo, the docs, or the audits; nothing invented.
The one-line pitch is marked [DRAFT] — say it your way.

## Lead with the real state, not the dream
- What it is: an iOS training app. You log honestly, Morphe builds and
  adjusts the program, picks weights, times rest, counts reps on camera,
  tracks everything. Tagline: TRAIN SMARTER.
- [DRAFT] one-liner: "Every number in Morphe is earned — the app can't
  be gamed, so the progress is real."
- Where it is today: built and verified on device. ~90k lines of Swift,
  526 commits since June 13, 447 automated tests, 319 workouts / 595
  exercises in the library, security rules live-verified.
- Where it is NOT: zero users besides me. Not on the App Store yet.
  The blocker is a $99 Apple Developer account, not code.

## The wedge (why this and not Hevy / Strong / Fitbod)
- Honesty enforced in code: no fakeable leaderboards, no invented
  "readiness" scores, scores = sessions + streak only, a first lift is a
  baseline not a PR. Cheap for me to keep, expensive for incumbents to
  copy (their growth loops depend on inflated numbers).
- The AI is honest too: offline it answers from YOUR log ("how much
  should I squat next time" → last load + the plan's increment);
  online it's Claude behind a relay. No fake coach persona.

## Business model (benchmarked, not signed)
- Coach SaaS: $39/mo per coach. Trainerize/TrueCoach run $19–290/mo.
  Each coach brings 5–20 athletes — distribution that pays me.
- Consumer Pro: $5.99/mo or $39.99/yr (Hevy is $2.99 — don't fight the
  free-tier king on price). Export, data, and safety features stay free.
- Both prices are proposals until a human says yes to one.

## What I learned from auditing it as an investor (say this out loud)
- Verdict: not fundable today; fundable inside one 90-day window.
- The fundable number is coaches, not consumer retention:
  10–25 paying coaches, ≥60% athlete attach, activation ≥40%,
  D30 ≥10–12% (3× category), organic k > 0.
- My own mistake: eleven weeks polishing while the $99 gate stayed
  unpaid. Further polish has negative information value compared to
  25 strangers using the app. That's the lesson of the project so far.

## Next steps (in order)
1. Pay the $99 today → TestFlight within 48 h of approval.
2. 10 real testers in 72 hours: 5 from the gym floor, 5 from my content
   audience. Weekly metrics report from day one.
3. Turn the Pro paywall on in TestFlight — a price in front of a person.
4. Deploy the AI relay (built, waiting on billing approval).
5. 20-coach outreach with a written $39/mo, 60-day pilot offer.
6. Write the cost side (runway, burn, AI cost per active user) and the
   split between Morphe, Checkmate, and the production company.

## If they ask
- "Why you?" — I build, film, and sell it myself; 15+ shipped waves a
  week with tests and device verification. Solo-founder risk is real;
  the answer is the coach channel, not a hire.
- "What if the 90 days miss?" — bootstrap on coach revenue, keep the
  audience, don't raise. Decided before I get attached.
- "What's the moat?" — none yet, only moat design. Network effects and
  training data start at user one.
