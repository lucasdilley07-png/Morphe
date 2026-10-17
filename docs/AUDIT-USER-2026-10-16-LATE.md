# Morphe — real-user audit, late pass (2026-10-16, 10:55 PM)

Fresh install, local mode, after the editor/doors/header wave. Walked:
welcome card → Today → Train (via the welcome pop-up) → editor mode on
Today and Learn (scroll, hold-lift-slide on a box and on a tab, Done) →
Discover door → Network → Nutrition door → Profile. Read-only; nothing
below was fixed in this pass.

## What works (verified live)
- Header: the wordmark sits dead center between the avatar and the
  search/quick-add icons on every page; the kicker under it reads
  `@verifyathlete · ● ONLINE · 0 DAYS LOGGED` with the dot flickering.
- Welcome pop-up: "Hello, Verify." / "Here's what I have for you today." /
  Train Beginner Linear Progression — Day A / Other workout / Log a meal /
  Other…. Train lands in a live session with the first exercise up.
- Today: the directive line ("Do your 20-second check-in.") under the
  tiles; the Train door is accent-filled; Nutrition / Network / Discover
  doors open the right pages.
- Editor mode: the banner slides down over the icon row and the editor
  tab bar replaces the system bar; the page scrolls; a 2-second hold lifts
  a box (Lessons moved above Quizzes on Learn) and a tab (Learn moved to
  second); Done slides both away and the system bar comes back in the new
  order; the mode follows a tab switch.
- Suite: 94 + 9 + 7 + 7 + 7 tests, 0 failures.

## What's wrong (ranked)

| # | Finding | Why it matters | Fix |
|---|---|---|---|
| 1 | **The Discover door lands on an empty Feed.** Day one, no Creator Coach has posted: the user taps "Feed, new workouts, programs" and gets "Nothing published yet." The Workouts section one tab over is full. | The door is the fourth of four on Today; a dead end on first tap. | Land on Feed only when it has posts; otherwise Workouts. Or the door's detail stops promising a feed. Lucas asked for the feed — his call. |
| 2 | **"Continue your workout?" fires over the Create-account screen.** Relaunching with an open session, the resume alert appeared on top of sign-in before the account restored. Seen in local mode; the alert is gated on the saved session, not on being inside the app. | An alert about a workout on a screen with no workout; "End without saving" is one tap from losing it. | Gate `showResumeWorkoutPrompt` on the app shell being up (authed + onboarded). |
| 3 | **Network on a fresh account shows an error, not an empty state.** "Your chats couldn't load — check your connection" + Retry under the Guardian message. Local mode has no backend, so this may be environment — but a first-run user with zero chats should see "No chats yet. Search a username to start one." | First visit to a social tab reads as broken. | Distinguish "no chats" from "fetch failed"; verify against the live backend. |
| 4 | **The 2-second hold gives no feedback while it charges.** Nothing changes for two seconds, then the box lifts. iOS home screen lifts in ~0.5 s with a visible press. A user who lets go at one second thinks it doesn't work. | The feature's first use decides whether it's "discovered". | A press state at touch-down (slight scale + outline brightening) that completes at 2 s, or shorten `holdSeconds` to ~0.8. |
| 5 | **Pinned Today pieces can't be moved, but the banner says "Hold a box to lift it."** Schedule, Goals, Nutrition, Progress only hide/show; holding them scrolls. | The instruction lies for four of the boxes on the page the user edits first. | Make the pinned four reorderable among themselves, or say "tap the eye to hide the pinned boxes" on Today. |
| 6 | **Day-one Today has nothing to reorder.** The movable list (insight, adjustments, support) is empty on a fresh account, so Edit Today's layout offers only four eyes. | Editor mode feels pointless on the page it opens from. | Falls out of #5. |
| 7 | **The Nutrition door lands under a LEARN kicker.** Tap "Nutrition", read "LEARN" at the top. | Small, but the second door on Today. | Hub pages take the section name as their kicker (NUTRITION), or the door says "Learn · Nutrition". |
| 8 | **The Morphe AI pill rests on the Progress tile's corner** at Today's default scroll position (6.1" phone). | Covers the tile's chevron; reads as an overlap. | Nudge the pill's rest position up 12 pt or give the tiles a bottom inset equal to the pill. |

## Honest notes
- #2 was produced by my own relaunch over an open session; it is real
  but I only saw it in local mode. Worth a check on the phone: start a
  session, kill the app, relaunch.
- The flicker and the editor transitions were observed in single frames;
  the feel on device is Lucas's call.
- Not re-walked tonight: finish sequence, check-in, food check, voice.

## Order
2 → 1 → 4 → 5 (+6) → 3 → 7 → 8.
