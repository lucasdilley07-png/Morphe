# Morphe

**TRAIN SMARTER.** An iOS training app with a Spartan guardian inside it:
it plans the session, logs real sets, counts real reps through the camera,
checks what you eat, and never invents a number. Human-only by law — no
bots, no spam, no AI-written content; Morphe AI is the only AI in Morphe.

Built end to end by Lucas Dilley (solo founder, Bay Area) with Claude
Code. Pre-launch: the gate is the Apple Developer Program, not code.

This file is the current map (refreshed 2026-10-10). The fresh-session
briefing with every feature and decision is `docs/HANDOFF.md`.

## Run it

1. Open `Morphe.xcodeproj` in Xcode 26, scheme **Morphe**.
2. Drop your Firebase `GoogleService-Info.plist` next to `Morphe/`
   (gitignored — the app signs in to Firebase project `morphe-3c5c2`).
3. Run on a simulator or on Lucas's iPhone (free personal team, 7-day
   installs). CLI build and install, as the sessions do it:

```bash
xcodebuild -project Morphe.xcodeproj -scheme Morphe -configuration Debug -destination 'id=<device udid>' -derivedDataPath "$HOME/Library/Developer/Xcode/MorpheCLI" -allowProvisioningUpdates build
```

```bash
xcrun devicectl device install app --device <device udid> "$HOME/Library/Developer/Xcode/MorpheCLI/Build/Products/Debug-iphoneos/Morphe.app"
```

Tests (391, ~20 s once built):

```bash
xcodebuild test -project Morphe.xcodeproj -scheme Morphe -destination 'id=<simulator udid>' -derivedDataPath "$HOME/Library/Developer/Xcode/MorpheCLI-Popup"
```

## What it does (October 2026)

**Today** — the day's workout, readiness check-in (sleep, energy,
soreness, mood), streak with honest outs, the welcome pop-up (read aloud,
at most once an hour, always lands on Today; two and a half minutes of
silence → Away), Hey Morphe voice.

**Train** — today's session with a beginner console (hold timer, load-free
bodyweight moves, rest presets from the plan), Form Check (on-device pose
tracking, 13 movement patterns, video never leaves the phone), Train
Together live sessions, **Build Workout** (build it yourself · build with
Morphe AI from a questionnaire · multi-week program), My Library (saved
workouts), Progress door.

**Discover** — Workouts (319 ready workouts, 595-exercise technique
library, filters) and the Creator Coach Feed (LinkedIn-style posts with
search and filters).

**Network** — Chats (with New message), the weekly Board, Calendar.
**Quick Add** (header) is people: requests, coaches, everyone the app can
name — connect, message, invite, hide. Account pages share one action bar.

**Learn** — Library (Exercise Library slide-up; saved posts / workouts /
exercises / diet plans / lessons), Nutrition (food check by barcode or
photo, fuel log with USDA + Open Food Facts search and camera, the chart
for lean out / maintain / bulk, nutrition basics), Lessons (quote of the
day, 20 quizzes ten at a time, lessons and Why Morphe as drop-downs).

**Profile** — identity, verification (live selfie, human review), level +
rank (Rookie → General, one accent color per rank, platinum and metallic
gold at the top), Your Details (age, experience, weight → goal, goals,
diet, styles, equipment, weakness), Your Milestones, settings.

**Morphe AI** — chat and Hey Morphe (orb in your rank's color), answers
from your own logs and details; with your Anthropic key it also reads
food photos, searches the web for a brand's supply chain, and builds
workouts. Without a key everything still works by Morphe's own rules and
says so.

## Laws that govern every feature

- **Real scores only.** Every stat comes from sets you logged.
- **Nothing invented.** No fabricated data, no trust signal a client can
  forge, empty states name their unlock.
- **Humans only** (2026-10-10). No bots, spam or AI-generated content;
  text is screened on the phone, posts/comments/messages/connect requests
  are paced on the server, reports are reviewed by a human.
- **Safety stays free.** Export, delete, every safety feature — free.
- **No ads, no trackers.**

## Repository

```
Morphe/                 the app (SwiftUI, iOS 17+, Liquid Glass on 26)
  Core/                 MorpheStore (the one store), models, persistence,
                        Firebase services, intelligence (Claude), catalog
  Features/Client/      Profile, Form Check, capture camera, exercise detail
  Features/Shared/      Auth, onboarding, QR connect
  HomeView/WorkoutView/ChatView/MoreView/ProgressView/RootView/GlassCard
  Resources/            MorpheCatalog.json (workouts + exercises),
                        FoodLibrary.json (1,758 USDA foods)
MorpheWatch/, MorpheWidgets/   companion targets
MorpheTests/            391 tests (PersistenceTests.swift)
BACKEND/firestore.rules the live security rules (see BACKEND/PLAN.md)
Tools/                  publish_rules.py, verify_rules_live.py (99 live
                        checks), review_* admin pages, build_privacy_page.py,
                        catalog builders, icon/brand asset makers
docs/                   GitHub Pages site (index, privacy, terms, support,
                        coach) + living docs (HANDOFF, BRAND-SPARTAN,
                        SPARTAN-LORE, CREATOR-COACH, COACH-*, PAYMENTS,
                        UNIVERSAL-LINKS, LAUNCH-CONTENT-CALENDAR); dated
                        audits live in docs/archive/
AppStore/               metadata.md (listing + App Privacy), LAUNCH_CHECKLIST.md
PRIVACY_POLICY.md, TERMS_OF_USE.md   sources of docs/privacy.html, docs/terms.html
```

Conventions: new code goes into existing files (adding files means
editing `project.pbxproj` by hand); resources are registered in the
pbxproj; `GoogleService-Info.plist` and `BACKEND/serviceAccount.json`
stay gitignored; commits end with the Claude co-author line.

## Where things stand

- Launch: waiting on the $99 Apple Developer Program (TestFlight, App
  Attest/App Check enforcement, push). Everything else in
  `AppStore/LAUNCH_CHECKLIST.md`.
- Backend: Firebase Auth + Firestore on Spark, rules published and verified
  live (`Tools/verify_rules_live.py`).
- Open follow-ups are listed in `docs/HANDOFF.md`.
