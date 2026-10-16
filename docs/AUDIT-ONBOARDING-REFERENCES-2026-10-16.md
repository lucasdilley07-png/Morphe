# Onboarding + tour vs Apple, TikTok, Instagram (2026-10-16)

What the three references actually do on first run, measured against
Morphe's flow as it stood this morning, and what changed in the same wave.
Live sources at the bottom; the engagement laws come from the standing
design canon (`~/.claude/memory-shared/app-design-canon.md`, 2026-09-30).

## The references, component by component

**Apple (HIG + Apple's own apps).** The rules in Apple's own words: make
onboarding "fast, fun, and optional"; "postpone nonessential setup flows";
"avoid displaying licensing details within your onboarding flow"; prefer
"context-specific tips" over a single tutorial; if you let people skip the
tutorial "don't present it again on subsequent launches", but keep it
reachable from settings. Apple's own welcome component (Fitness, Journal,
Photos; refreshed again in the iOS 27.2 beta this month) is one page: app
mark, "Welcome to X", three or four feature rows with an SF Symbol each,
one Continue button. No carousel, no tutorial.

**TikTok.** 29 screens on iOS, but one decision per screen: birthday → sign
up → interest picker (icon cards in a grid) → the feed, with permissions
asked only when the feature needs them (camera and mic at first record,
notifications last) and guidance delivered as tooltip overlays on the
real UI, not a tour. The retention mechanic is "the feed gets better the
more you use it" — the user is told their input improves their own
experience.

**Instagram.** The shortest: name, password, birthday, username, optional
photo, optional follows, notifications last. "No tutorial walls"; every
other feature is discovered in context.

**Duolingo (the pattern both fitness benchmarks copy).** A thin progress
bar at the top of every question, one question per screen as a
single-select list with an icon per row, expectation set up front ("7
quick questions"), a "building your course" screen whose visible work
earns reciprocity, and the first lesson before the account.

**The numbers.** Health & fitness D1 retention 30–35% for strong apps, D7
15–18%; apps that get the user to value within 3 minutes retain ~2x.

## Morphe before this wave — the gaps

| Reference pattern | Morphe (this morning) | Verdict |
|---|---|---|
| One decision per screen | Step 2 stacked goals + sports + experience; step 3 stacked days + a long review | Gap |
| Thin progress bar, nothing else above the question | A header card: label, title, subtitle, bar, "STEP x/4 · Account created" | Gap |
| Icon cards (single-select list / interest grid) | Text chips in a wrap | Gap |
| "Building your plan" screen that shows work | A 0.5 s flash | Gap |
| One welcome page, then tips in place | A 5-stop (was 9) paragraph tour before the app | Gap |
| Permissions asked in context | Notifications after the first workout; camera/mic at Form Check | Already right |
| Skippable, never repeats, reachable from settings | Skip tour; Profile → Replay the guide | Already right |
| Minimum required info | Name, birth year, @handle (handle pre-filled) | Acceptable — the handle is one tap |
| No licensing text in onboarding | One consent row with the full terms behind a link | Acceptable |

## What changed (shipped in commit after this doc)

1. **One question per screen, seven steps** — name, @handle, goals,
   training, experience, days, review. The composite pages are retired.
2. **Duolingo header** — a thin accent bar and "3 OF 7"; the title card is gone.
3. **Choice cards** — goals as full-width icon rows with a check; sports as
   the two-column icon grid (TikTok's interest picker); experience as three
   cards with a one-line description each. Same selection logic underneath.
4. **A real plan-building beat** — three lines (reading your goals →
   matching your sport and level → building your first week) tick to checks
   over ~2.4 s. The work is real; it was just invisible.
5. **Apple-style welcome instead of a tour on first run** — mark, "Welcome
   to Morphe", four feature rows (your program · tap the check · the camera
   counts · ask Morphe), Continue → Today. "Take the two-minute tour" is
   one tap away, and Profile → Replay the guide opens the full stop-by-stop
   tour as before.
6. **The lost first tap** — every step change scrolled the page to the top
   programmatically, which left the scroll view "tracking", so the first
   tap on the next step only stopped it. Each step now gets its own scroll
   view; no programmatic scroll at all.
7. **A ranking bug found while walking it** — General Fitness + Strength,
   gain muscle, intermediate opened on "Fighter Strength Base", a boxing
   plan. Every catalog template decodes with `sport: .generalFitness`, so
   the sport preference had never reordered anything and the alphabet
   decided. Ranking now reads the sport from the category and name:
   general athletes get generic plans first, sport athletes their own
   sport first, the backbone second, other sports last. Still a soft
   preference, never a filter.

## Still open

- **@handle before value.** Instagram asks it because the product is the
  handle; for Morphe it only matters in Network. It stays because the
  reservation is wired into `completeOnboarding` (an unclaimed handle
  collides with every other "Alex"). The field is pre-filled, so it is one
  tap — but Apple would defer it.
- **Account before value.** Duolingo's lesson-before-signup is the single
  strongest pattern and Morphe can't do it today: the sign-in wall sits
  ahead of onboarding because the plan is cloud-backed. Worth a design
  pass once TestFlight data says where people drop.
- **Tips in place.** The GuideHint cards exist (Today, Train) and now carry
  what the tour used to; TipKit would make them system-native.

## Sources

- Apple HIG, Onboarding (mirror of the current page):
  https://github.com/incrediblecrab/apple-os-documentation/blob/main/human-interface-guidelines/patterns/onboarding.md
- Apple Fitness welcome screen, iOS 27.2 beta 3 (Oct 2026):
  https://www.macobserver.com/news/ios-27-2-beta-3-apple-fitness-welcome-screen/
- TikTok iOS onboarding, screen list: https://pageflows.com/post/ios/onboarding/tiktok/
- TikTok activation mechanics: https://goodux.appcues.com/blog/tiktok-user-onboarding
- Instagram iOS onboarding, screen list: https://pageflows.com/post/ios/onboarding/instagram/
- 12 apps with great onboarding (2026), pattern names: https://uxcam.com/blog/10-apps-with-great-user-onboarding/
- Duolingo onboarding, components: https://screensdesign.com/articles/duolingo-onboarding-design/
- Duolingo teardown, reciprocity + deferred signup: https://relaunch.ai/blog/duolingo-onboarding-teardown-7-b-tests-behind-their-9-conver
- Fitness onboarding examples (2026): https://screensdesign.com/articles/fitness-app-onboarding-examples/
- Retention benchmarks 2026: https://uxcam.com/blog/mobile-app-retention-benchmarks/ and https://www.snoopr.co/blog/mobile-app-retention-benchmarks-2026-what-good-looks-like-for-fitness-ecommerce-gaming-and-more
