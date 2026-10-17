# Morphe — multi-persona audit (2026-10-17, 2 AM)

Fresh install walked end to end in local mode (intro → account →
questions → loading → activation pop-up → Today → Train session → Network
chats / board / calendar → Discover Fitness / Explore → Learn lessons /
nutrition / library → Quick Add → Search → Hey Morphe chat mode), then
re-read through six lenses. Verified live unless marked *(code read)*.
What was fixed tonight is marked ✔; everything else is the list.

## What works (verified)
- First run: [ TAP TO BEGIN ] → light → Morphe asks for a handle and a
  birthday → Build my profile / Get started → five questions → Morphe
  loading screen → activation pop-up (bottom-up buttons) → Today.
- Today: identity strip, daily directive, four doors, editor mode (hold
  to move, eye to hide, tab reorder, follows tabs, Done).
- Train: Start → tracker (flow / rounds / holds, rest timer in accent,
  voice bar), resume alert inside the app only.
- Network: Board · Chats · Calendar swipe; chats in place with the new
  header and the mic composer; Morphe chat and the floating chat share
  one conversation; the AI button slides off on chats and back elsewhere;
  it parks into a chevron on a swipe.
- Discover: Fitness styles on tap only, Explore grid + viewer, pinned
  search on a scroll up, swipe wraps.
- Learn: LESSONS · NUTRITION · LIBRARY tabs, each with an edit option,
  nutrition history pop-ups, Search / Photo / Enter doors.
- Hey Morphe stage: hold-to-record mic, chat mode, the swipe-down close
  that brings the orb home and says "Chat inactive".
- Suite: 94 + 9 + the rest, 0 failures on every chain tonight.

## What's not working / missing (ranked, all lenses)

| # | Lens | Finding | Fix |
|---|---|---|---|
| 1 | Foreign user | **English only.** No `.xcstrings`, no `String(localized:)`; every string is a literal. A Spanish or Hindi speaker gets nothing in their language. | Add a String Catalog, wrap the ~40 first-run and Today strings first, let Xcode's catalog pick up the rest; ship es/pt/fr/de/hi/ja/zh via machine draft + review. Dates already localize. |
| 2 | Foreign user | **Units default to pounds.** `weightUnit = .pounds` regardless of locale; kg is a Profile toggle. | ✔ metric locales start in kg |
| 3 | 12–18 | **The age gate accepts 13+, but the first-run copy, the privacy line and Morphe AI online (18+) never say so.** A 15-year-old sees "Turn on Morphe AI online" in Nutrition with no reason it is greyed. | ✔ "unlocks at 18" copy + a day-one line for 13–17 |
| 4 | 12–18 / 41–80 | **Dense mono micro-labels (10–11 pt tracked caps) on the identity strip, the kicker and section headers.** Dynamic Type scales them, but at the default size a 60-year-old reads "0 DAYS LOGGED" squinting. | ✔ microLabel floor raised to caption at 10–11 pt |
| 5 | 41–80 | **Hold-to-record and the 2-second hold-to-move have no spoken affordance for VoiceOver** (labels exist; the gesture itself does not). | ✔ VoiceOver Move up/down on boxes, left/right on tabs |
| 6 | 26–40 | **Morphe speaks on seven pages; none of it is tunable.** A commuter who reads at a glance and a user who wants the brain to shut up get the same volume. | ✔ Profile → Training → Morphe's voice: Quiet / Normal / Coach |
| 7 | Engineer | **Two nested `GeometryReader`/preference-key scroll trackers per page** (Discover, Chats, Quick Add) and a window-level pan recognizer per paging view. They work, but each is hand-rolled. | One `ScrollTracker` modifier with a shared key; one `PageSwipeRecognizer` instance owned by the shell. |
| 8 | Engineer | **`MorpheStore.swift` is ~19k lines, `RootView.swift` ~6k, `ChatView.swift` ~5k.** Compile times showed it (type-checker timeouts earlier today). | Split by feature folders (Voice, Network, Nutrition, Layout). No behaviour change. |
| 9 | Engineer | **Voice memos ride the message text as a marker** (`[voice:id|m:ss] transcript`) and the clip stays on the sender's phone. | Upload the clip to Storage, send a `voiceMemo` field; the marker stays as the offline fallback. |
| 10 | Investor | **Zero strangers have used the app.** Every number tonight is a local-mode account. The Apple Developer gate ($99) and the relay deploy are still the blockers. | Pay the gate, ship TestFlight to 10 people this week, read the first-run funnel from real taps. |
| 11 | Investor | **Explore is an empty grid** until coaches publish; Network's chats error in local mode. Day one of a real user is two empty social pages. | ✔ Explore seeds Morphe's reports and news (chats card unchanged) |
| 12 | 19–25 | **No sharing of a logged session to Explore from the finish screen** (the share card exists; it goes to the system sheet). | "Post to Explore" on the finish sequence — one tap, the card becomes a tile. |
| 13 | All | **Personalization reads data but not feedback.** The hint cards have "Got it"; the directives have no thumbs; the layout proposes once. Nothing learns from a dismissal. | ✔ long-press any page line → More / Less of this; bucket weights shape the pick |
| 14 | 12–18 | **Quizzes and XP exist but there is no visible level-up moment on Today** beyond the LEVEL tile counting. | ✔ a level change raises the celebration banner |

## How to make it adapt in real time (steps 1–3 built in the fix wave; 4–6 not)
1. **A feedback bus.** Every Morphe line, hint, nudge and layout proposal
   carries an id. Long-press → "More like this / Less of this / Not now."
   Store counts per id and per bucket (tip / task / cheer) per user.
2. **Weighted picks.** `pageDirective` and `morpheDirective` already pick
   from buckets; weight the buckets by the counts. Dismissed twice → that
   bucket sleeps for a week on that page.
3. **Volume dial.** Quiet / Normal / Coach in Profile (finding 6); Quiet
   is also what two "Less of this" in a day flips to for that page.
4. **Register per user.** The onboarding has age and goal; add one
   question later ("How should Morphe talk to you?" — Plain / Hype /
   Coach) that selects the line set. Lucas writes the three sets
   (sourcing law — not generated).
5. **Locale-first defaults.** Units, date order, first day of week from
   the device; language from a String Catalog (finding 1).
6. **Engagement-aware surfacing.** Pages the user never opens get their
   door demoted on Today after two weeks; pages they open daily get a
   task line first. The engagement counter (`noteEngagement`) already
   records the opens.

## Honest notes
- The foreign-language pass is a code read: there is no localization to
  test. Numbers and dates do follow the locale.
- The 41–80 lens is a read at default Dynamic Type; AX sizes were not
  walked tonight.
- The investor read has not changed since the 16th: the product moved a
  lot, the distribution did not.
