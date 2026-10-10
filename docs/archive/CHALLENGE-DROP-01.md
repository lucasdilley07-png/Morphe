# DROP 01 — Show Up August

The first public Morphe challenge drop: one branded, code-joinable
challenge per month, announced on social, scored by the app's real
leaderboard. Zero new backend — this is the existing challenge system
(Progress → Challenges) used as a public ritual.

Every mechanic below fits what the system enforces: title ≤60 chars,
metric = sessions or sets, duration capped at 30 days, the challenge
STARTS the moment it's created (no future scheduling), the 6-char code
is generated at creation, joining needs only a signed-in account, and
every score is computed from logged workouts inside the window — nobody
can type a number in.

## The challenge

| Field | Value |
|---|---|
| Title | `DROP 01 — Show Up August` |
| Metric | **Workouts** (sessions logged — the momentum metric, not a volume grind) |
| Duration | **30 days** (the cap), created the morning of **Aug 1** |
| Community bar | **20 sessions in 30 days** — the "finisher" line used in content; the in-app leaderboard simply ranks logged sessions, which is exactly what we say |
| Code | Generated at creation — goes in every caption, comment, and bio |

Why sessions, not sets: the brand sells momentum over perfection. A
5-minute Minimum Win day counts the same as a 2-hour block — that IS
the message, say it out loud in the launch post.

## Launch-day runbook (Aug 1, ~15 minutes)

1. In Morphe (your real account): **Progress → Challenges → create** —
   title exactly `DROP 01 — Show Up August`, metric **Workouts**,
   **30 days**. The moment it exists, the clock runs.
2. Copy the 6-char code from the challenge card. It's the drop's whole
   identity — treat it like a merch code.
3. Log your own session and share the session card. The host should be
   on the board with a score before the first stranger arrives.
4. Publish the launch content (below) with the code + install path.
   Pin the code comment.
5. That's it. Weekly cadence takes over.

## Join instructions (paste anywhere, keep exact)

> Install Morphe → create your account → Progress → Challenges →
> enter code **[CODE]**. Every session you log counts automatically.
> Real logs only — there's no way to type a score in.

## Content calendar

**T-3 to T-1 (Jul 29–31) — the tease**
- Story/TikTok: "First Morphe drop lands Friday. 30 days. One number.
  Anyone can join with a code." No details — the code IS the reveal.

**Day 0 (Aug 1) — launch reel** (~30s, raw)
- Hook on screen: "20 sessions. 30 days. Zero excuses typed in."
- Beat 1: create the challenge on camera, code fills the screen.
- Beat 2: "Every score on this board is a logged workout. You can't
  fake it — the app won't let you."
- Beat 3: "Rest days don't break you here. Short days count. Showing
  up is the whole game."
- CTA: "Code's in the caption. See you on the board. TRAIN HONEST."

**Weekly (every Monday in Aug) — the board post**
- Screenshot the challenge leaderboard (it's real, it's branded, it's
  content). Caption: "Week N. [LEADER] leads with [X] sessions.
  [MEMBER COUNT] athletes on the board. Code [CODE] still works."
- Pairs with your own Week-in-Review card from Progress.

**Final week (Aug 25–31) — the push**
- "6 days left. The bar is 20. If you're at 14, that's one session a
  day — Minimum Win days count."
- DM everyone at 17+ sessions: "You're 3 away. Finish it."

**Wrap (Sep 1) — finishers post**
- Name every athlete at ≥20 sessions (with their consent — DM first).
  Repost their streak/session cards. "DROP 02 drops Oct 1."
- Post-mortem note in this file: joins, finishers, what to change.

## Coach tie-in (kit §4 add-on)

Pilot coaches run their whole roster in the drop: "My clients are all
on the DROP 01 board — join code [CODE], try to out-show-up them."
A coach whose roster fills the top ten is the best ad the pilot has.

## Measurement

- `challenge_created` / `challenge_joined` telemetry now fire (this
  commit) — `python3 Tools/metrics_report.py` shows drop joins next to
  the other loops (share / referral / coach).
- The member count and board live on the challenge card in-app.
- Success bar for DROP 01 (first public ritual, pre-App-Store): any
  joins beyond your own network is signal; 25+ members = make it
  monthly forever; <5 = the ritual needs the App Store listing first —
  rerun as DROP 02 at launch.

## Rules honesty (say this in content, it's the differentiator)

- Scores come from logged sessions inside the window. No manual entry.
- Joining is free, no opt-ins beyond an account.
- The community "20" is an editorial bar, not an in-app gate — the
  board just ranks. Never claim the app "awards finishers" (it doesn't,
  yet — if drops work, a finisher badge is a fine roadmap item).
