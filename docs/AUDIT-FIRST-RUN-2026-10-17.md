# Morphe — first-time-user audit (2026-10-17, 12:30–1:05 AM)

Fresh install, local mode, every first-run step tapped one by one:
[ TAP TO BEGIN ] → the light → Morphe's intro → @username + birthday →
Build my profile → 5 questions → Create Plan → loading → activation
pop-up → Take the tour → Today → Train → Start → tracker → relaunch →
resume alert → Network (Chats / Board / Calendar) → Discover (Fitness /
Explore) → Learn (Lessons / Nutrition / Library). Fixed in the same pass
where marked ✔; the rest is the recommendation list.

## What works (verified live)
- The intro beats land in order and the orb fades on; the username and
  birthday gate the two buttons; Build my profile is the obvious door.
- The five questions, the plan, the Morphe loading screen, then the
  activation pop-up ("Welcome, name." / "Thanks for activating me…") with
  Take the tour · Edit my profile · Train · Other, bottom-up.
- Today: LEVEL · SCORE · ENERGY · READINESS, the directive, the four doors
  (Network · Discover / Nutrition · Train), the pinned pieces.
- Train → Start → a 60 s Cat-Cow flow with one button; relaunch mid-session
  asks "Continue your workout?" inside the app, never over sign-in.
- Network: Board · Chats · Calendar with Chats in the middle; the swipe
  between them (UIKit pan now); search + pencil above Morphe; Morphe first.
- Discover: FITNESS / EXPLORE swipe; Explore's three sections and its edit
  option; the search bar and filters pin on a scroll up.
- Learn: LESSONS · NUTRITION · LIBRARY in the tabs grammar.
- Suite: 94 + 9 + 7 + 7 + 7 + 6 + 6 + 6 + 5 + 5 tests, 0 failures.

## Findings (ranked) and what was done

| # | Finding | Fix |
|---|---|---|
| 1 | **"Take the tour" did nothing.** The tour sheet was raised in the same transaction as the pop-up cover's dismissal and never presented. | ✔ presents 650 ms after the answer |
| 2 | **The name step re-asked the birth year** the intro had just taken, and read "1 OF 5" on the second question too. | ✔ no birth-year field after the intro; the counter counts the question itself |
| 3 | **Chats did not swipe to Board / Calendar.** The chats list's scroll view swallowed the SwiftUI drag. | ✔ `PageSwipeRecognizer` — a UIKit pan on the window, simultaneous with every scroll view, filtered to the page's frame; Discover uses it too |
| 4 | **The Network hint sat above the BOARD · CHATS · CALENDAR row** after the chats restructure. | ✔ under the header |
| 5 | **The review step still shows a terms toggle** the intro already agreed to (prefilled on). Harmless, one more thing to read. | Hide the toggle when `introSuppliedIdentity`; keep "Read the full terms". |
| 6 | **The review card says "Build Consistency / Build consistency"** (title and subtitle are the same goal). | Subtitle should carry the sport + level line instead. |
| 7 | **A consistency-goal beginner was handed "Beginner Low-Impact HIIT · Weight Loss".** The catalog has no "consistency" lane, so the picker fell to a weight-loss tag the user never chose. | Map `buildConsistency` → short general-fitness sessions (the "Lean Out"/"General" tags) and hide the goal tag on the card when it does not match a chosen goal. |
| 8 | **The first Today has three dashes and a "Check in" tile with nothing explained.** The directive says "Do your 20-second check-in" but the tile does not say what it unlocks. | One hint under the tiles on day one only: "Check in once and these fill in." |
| 9 | **Day one asks for a weight before the first session.** The directive rotates to "Log your weight in Profile for real targets" within the first hour. | Gate the weight directive until the first session is logged — ask for the hard things later, little by little. |
| 10 | **The Network chats card shows a connection-error card on day one** in local mode. Production shows the Morphe row alone when there are no chats. | Verify on the phone with the real backend. |
| 11 | **"Edit Chats's layout" / "Edit Board's layout"** — the possessive reads oddly on names ending in s. | "Edit the Chats layout". |
| 12 | **No pop-up on the second cold open** within the throttle window. Expected by the throttle rule, but a day-one user who answered "Take the tour" and came back five minutes later got nothing from Morphe. | Exempt the first day from the throttle. |

## Efficiency / retention recommendations (not built)
- **One tap to the first set.** Today → Train → Start → "Start the clock" is three taps and a page. The activation pop-up's Train button should start the session directly (it already does when answered); the Train door on Today could do the same on day one.
- **Defer the account to after the first session.** Email + password sit between the intro and the questions. Local-first with a "Back up your account" nudge after the first logged session would shorten day one by a screen and the thing most users abandon on.
- **Morphe nudges, not forms, for the optional data:** weight, equipment, injuries, meal prep. Each gets one line in the directive slot on the day it becomes useful (after the first session, the first week, the first PR), and each opens the single field, not Profile.
- **Collapse the five questions to three on Get started.** Goal, days a week, level. Sport defaults to general fitness and asks itself after the first session ("Was that the kind of training you want more of?").
- **The tracker's "Add load" and "More options" are the only tedious controls** a beginner meets in week one. Both are fine, but "Add load" should default to the bodyweight suggestion already computed instead of an empty field.

## Honest notes
- The "Create your account" screen seen twice during the walk was a
  launch-timing flake of the simulator (terminate and launch too close
  together), not an app bug; a paced relaunch booted signed in every time.
- #10 is local mode; the production backend was not exercised tonight.
- The Hey Morphe stage's chat bar, the parked AI button and the Discover
  pinned bar were verified earlier tonight, not re-walked here.
