# Morphe pitch deck + demo video: concepts

2026-10-12. These are concepts to choose from, not final copy. Every line
in quotes comes from something you already wrote or said, and the source
is given. Anything I phrased myself is marked [DRAFT] for you to re-say in
your own words (Sourcing Law).

## What these build on

- **Morphe Launch Pitch** (CLASS/, 14 slides, presented Oct 9 at Launch Lab).
  This is the base. Its structure already matches the Semester 5 rubric:
  venture overview, GTM implementation, customer growth, launch strategy,
  future milestones.
- **Launch Funding Request** ($1,550, Oct 7) and **Semester 5 Completion
  Package** (Oct 12). These list the pitch deck as Milestone 5. The term
  ends **December 12**.
- **April one-slide pitch** (_INBOX/morphe_pitch_slide.pdf): "Not a fitness
  app — the operating system for transformation."
- Investor audit (Jul 30), market audit (Aug 26), brand audit (Jul 27), the
  ICP you set Oct 2, and docs/COACH-PITCH.md.
- The live metrics report, run today.

## Read this first: what has to change in any version

1. **Numbers on slides 4 and 7 are out of date.** As of today:

   | | Oct 9 deck | Today |
   |---|---|---|
   | Commits since June 13 | 430 | **483** |
   | Tests passing | 374 | **393** |
   | Accounts in the live table | 1 | **2** |
   | iPhones with the build installed | 1 | **3** |
   | Activated (first logged workout) | 0 of 1 | **0 of 2** |
   | Fresh-eyes audit fix waves | 32 | 32 + 10 since Oct 8 |

2. **The activation number is the slide everyone will look at, and it
   still reads zero.** The report shows no `workout_logged` events at all,
   not just no activations. Either nobody has finished a workout while
   signed in since telemetry went live, or the event is not landing.
   Five-minute check before you build any slide: log one set on your phone,
   then run `python3 Tools/metrics_report.py`. If the count doesn't move,
   it's a bug and I'll fix it. If it does, the zero is real and the deck
   says so.

3. **The tagline needs one decision from you.** There are three in play:
   - "Train smarter" is on the Oct 9 deck and in the app.
   - "TRAIN HONEST" was chosen in the brand audit, and your business priors
     cite it as the position.
   - "AI FITNESS. SPARTAN DISCIPLINE. MODERN PERFORMANCE." is on the brand
     kit you supplied Oct 5.

   A deck can carry only one. Every concept below works with any of them,
   but Concept A is built on the honesty line.

4. **New since Oct 9, and worth a slide.** Each of these is shipped and on
   your phone:
   - **Food check:** scan a barcode or photograph a meal.
   - **The nutrition chart:** your whiteboard chart, turned into data.
   - **Build with Morphe AI:** a questionnaire that becomes a workout.
   - **The Morphe chat:** a weekly report every Monday, built from your
     own logs.
   - **The human-only policy:** Terms v2, and server-enforced pacing that
     limits how fast posts and messages can go out.
   - **Boards with join codes**, **military ranks with an accent color
     per rank**, and **the beginner console**.

   The human-only policy matters most. It is a differentiator nobody else
   claims, and it is your line: "Morphe ai is the only good ai" (your
   message, Oct 10).

5. **The demo in docs/COACH-PITCH.md is stale.** It walks through the
   coach dashboard, which was deleted Sept 9. Don't rehearse from it.

---

## Pitch deck: three concepts

### Concept A: "This number cannot be typed in"

**Spine:** honesty as the product. Every slide ends on a number a
journalist could check. The close is your own line from slide 14:
"This number cannot be typed in."

**Why it fits:**
- Your priors say "A sharp honest position beats a polished generic one."
- Your brand already posts losses with the same card as wins.
- A deck built on honesty can show 2 accounts and 0% activation without
  flinching. A growth-story deck can't.

**Flow (10 slides):**
1. **Title.** "Every number is earned." (your slide 1)
2. **The lie in fitness apps.** Fake score deltas, "AI coaching" that is a
   rules engine, an honor-system feed of 15M users. (your slide 2, market
   audit)
3. **The product.** Talk, log, count, adjust. Embed the 60-second demo
   here.
4. **Humans only.** Morphe AI is the only AI allowed. Show the Terms v2
   rules and the server pace limits.
5. **What exists.** Slide 4, with today's counts.
6. **The table.** Screenshot of the live metrics report, exactly as it
   prints, zeros included.
7. **Launch rings + channels.** Your slide 8, unchanged.
8. **Business model.** Your slide 11. "Revenue today: $0" stays.
9. **Week 12 bars + kill criteria.** Your slide 12.
10. **The ask + the close line.**

**Risk:** if activation is still zero on Dec 12, this concept carries it
best, because the brand promised exactly this. It's still a zero.

### Concept B: "A beginner has three questions"

**Spine:** your slide 2, made the whole deck. The three questions are
"What do I do today?", "Am I doing it right?" and "Why come back
tomorrow?". Each one is answered by a live feature, in the order a
beginner meets them.

**Why it fits:**
- It is ICP-first: beginners, with experts as Creator Coaches (your
  Oct 2 call).
- It hits the faculty lens, "retention, not just acquisition".

**Flow:**
1. **Title.**
2. **The three questions.** Your slide 2.
3. **"What do I do today?"** The Today plan, the readiness check-in, and
   Build with Morphe AI.
4. **"Am I doing it right?"** Form Check across eleven movement patterns,
   and the seal on counted sets.
5. **"Why come back tomorrow?"** Streaks with honest outs, ranks from
   Rookie to General, and the Monday report in the Morphe chat.
6. **Who it's for.** Beginners, with experts entering as Creator Coaches.
7. **GTM, customer growth, launch roadmap.** Slides 6, 7 and 9.
8. **Business model.**
9. **Milestones.**
10. **Ask.**

**Risk:** the answer to question 2, Form Check, is still tuned on paper
(your funding request, risk 5). If the live count misfires on stage,
the middle of the deck falls in.

### Concept C: "Complete on every axis money can't buy"

**Spine:** your funding request's own sentence: "Morphe is complete on
every axis that money cannot buy and blocked on every axis that money
can." Two columns run the whole way through, what code did and what the
gate blocks. The deck ends on the $300 / $1,250 two-part release tied to
proof.

**Why it fits:**
- Use it if the audience includes funders (there's an SFBU Funding
  Tracker in CLASS/).
- It turns "1 user" from a weakness into the thesis: the gate, not the
  product, is the blocker.

**Flow:**
1. **Title.**
2. **The two columns.**
3. **The product, in one slide.**
4. **The gate.** $99, then TestFlight, then the 90-day clock.
5. **Use of funds.**
6. **What each dollar unlocks.**
7. **Bars + kill criteria.**
8. **Accountability.** The shared sheet, biweekly updates.
9. **The ask.**

**Risk:** it expires the day you pay the $99 this week. After that the
blocker really is users. Use C only if you pitch before TestFlight is
live.

### Recommendation

Use **A as the spine, with B's three questions as the product section**.
That means slides 3–5 of B replace slide 3 of A.

It holds up whether the Dec 12 numbers are good or bad, it uses the
human-only policy as a differentiator, and it ends on your strongest
line. Drop C once TestFlight is live.

---

## Demo video: three concepts

House rules that apply to all three:
- Real screens only.
- Rituals stay raw; cinematic polish goes only on the outcome (your media
  law 3).
- The hook is about the viewer and lands inside 2 seconds (your notebook,
  Jul 11).
- Record at your real rank and color. No staged level.

### Video 1: "One set, one take" (60–75 s) — the master demo

**Concept:**
- One continuous real set at your gym: the phone on a stand, plus an
  over-the-shoulder camera.
- No cut during the count. The single take is the proof.
- It is literally your Working Backwards answer 5 (Semester 5 package):
  "Open the app, hear what is next, log a set by voice, watch the camera
  count, and end on your own score."

**Beats:**
1. **0–3 s.** Your face, gym noise. "Hey Morphe, what's next?" The orb
   lights the screen.
2. **3–12 s.** Morphe answers out loud with today's first movement.
   Screen-record audio stays in the mix.
3. **12–40 s.** The set. Form Check counts on screen, uncut. The counted
   set gets its seal.
4. **40–50 s.** Log the next set by voice: "log 3 by 10 at 135" (your
   slide 3).
5. **50–65 s.** The outcome, and the only polished shot: the score moves,
   then the share card.
6. **End card.** The tagline you pick.

**Production:**
- Shoot with your HBPC kit and LUT pipeline.
- Screen-record on the phone with mic on (Control Center), and slate a
  clap to sync it with the camera.

**Risk + fallback:** Form Check thresholds are unverified on a real set.
Rehearse 3 sets on the phone first. If the count misses, your funding
request's mitigation applies: demo a recorded clip where live counting is
unreliable. The voice step needs your Anthropic key only for open
questions; "what's next" and voice logging run without it.

### Video 2: "The number that can't be typed" (30–45 s) — the opener / social cut

**Concept:** a contrast cut.
- Try to fake it: type a big PR by hand, and the seal disappears ("a hand
  edit removes it", your slide 3).
- Then earn it: the camera counts the real set and the seal stays.
- Close on "This number cannot be typed in."

**Why:**
- Works as the deck's cold open and as the Lucas_Dilley post.
- It demonstrates instead of advising (your LD credibility law), and names
  what it replaces: honor-system feeds.

**Risk:** the rule is in code (`droppingEditedCameraMarks` clears the
seal when reps, weight or sets change in an editor). Run it once on the
phone before the shoot day anyway.

### Video 3: "First week" (90 s) — a beginner's real seven days

**Concept:** one real beginner, filmed across a week:
- Day 1: the Today plan and the check-in.
- Day 3: a rest day that doesn't break the streak.
- Day 7: the Monday report in the Morphe chat, read on camera.

**Why:** this is the strongest possible evidence for the ICP. Your Semester
6 plan already asks for "a progress report with a quoted beginner in it."

**Blocked on:** a consenting beginner tester (one of the 25). Don't shoot
it with yourself; you're not a beginner, and the brand can't pretend.

### Recommendation

1. **Shoot Video 1 first.** It's the deck's slide 3 and the coach-pitch
   demo.
2. **Cut Video 2 from the same shoot day.** It's the opener, and the
   Day 0 post in your launch calendar.
3. **Video 3 is for Semester 6,** once a tester exists.

---

## Decisions only you can make

1. **Audience and date.** Is this the practice launch pitch (Milestone 5),
   the Dec 12 term-end version, or a funder pitch? That picks between A
   and C.
2. **The tagline.** Train smarter, TRAIN HONEST, or the brand-kit line.
3. **Whether the deck shows the live metrics table as-is** (Concept A's
   slide 6).
4. **Who Video 3's beginner is, if anyone.** Do you want me to keep it
   parked?

Once you pick, I'll produce:
- the final slide-by-slide deck, with your lines only and anything new
  marked [DRAFT];
- the shoot-day shot list, saved to Apple Notes for on set, to this
  folder, and to memory.
