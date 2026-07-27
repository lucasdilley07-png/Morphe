# Morphe — App Store metadata

Copy/paste these into App Store Connect. Fields are length-limited as noted.

---

## App name (≤30 chars)
**Morphe**

> Optional keyword variant (helps search): `Morphe: Workout Tracker` (23 chars)

## Subtitle (≤30 chars)
**Workout builder & tracker**

## Promotional text (≤170 chars, editable any time without review)
Log real sets, follow real training programs, and share honest wins with a community that trains. No ads, no trackers — your numbers are yours.

## Keywords (≤100 chars, comma-separated, no spaces)
`workout,gym,fitness,tracker,exercise,log,strength,reps,sets,training,lifting,recovery,builder`

## Description (≤4000 chars)
Morphe is a fitness app for people who want to build the habit, not chase perfection. Plan your workouts, log every set with real weight and reps, and watch a Morphe Score that reflects what you actually did — not a number someone made up.

TRANSFORM. EVOLVE. BECOME.

BUILD YOUR OWN WORKOUTS
• Create custom workouts from a library of 50+ exercises
• Add your own exercises when something's missing
• Set your target sets and reps

LOG WHAT MATTERS
• Track weight, sets, and reps for every exercise
• Switch between lb and kg
• A rest timer and in-session tracker keep you moving

SEE REAL PROGRESS
• Your Morphe Score, streak, and trends are computed from your actual workouts
• Weekly consistency and activity at a glance

KNOW WHY
• Learn muscle anatomy, recovery, and training intensity (RPE)
• Short lessons and quick quizzes to make it stick

CHECK YOUR RECOVERY
• A quick daily check-in reads your sleep, energy, soreness, and mood
• Morphe adjusts the day around how you actually feel

TRAIN TOGETHER
• Follow athletes, share sessions as honest stat cards, and react and comment
• Weekly leaderboards and code-joinable challenges — opt-in, real scores only
• Live buddy sessions: train the same workout together in real time
• Coaches: manage your roster, message clients, and see consented live progress

YOUR DATA, YOUR CALL
• Your account backs up your training so a new phone restores everything
• Optional Apple Health sync: workouts count toward your rings, sleep pre-fills your check-in
• Export everything as one file, or delete your account — both in the app
• No ads, no analytics trackers, and your data is never sold

Built for beginners and anyone rebuilding momentum. Small wins. Real transformation.

## What's New (release notes, first version)
First release of Morphe. Build workouts, log real sets, run multi-week programs, and share honest progress with a community that trains — with opt-in Apple Health sync, cloud backup, and full data export/deletion built in.

---

## App Store Connect settings

- **Primary category:** Health & Fitness
- **Secondary category:** (optional) Lifestyle
- **Age rating:** answer the questionnaire honestly — with user-generated content and social features expect **12+** (infrequent/mild UGC exposure); Morphe ships report + block + filter as 1.2 requires
- **Price:** Free
- **Bundle ID:** com.morpheapp.Morphe
- **Version:** 1.0
- **Privacy Policy URL:** _<your hosted policy URL — see docs/ and LAUNCH_CHECKLIST.md>_
- **Support URL:** _<a page or email you control, e.g. a simple site or mailto>_
- **Marketing URL:** (optional)

## App Privacy questionnaire (the "nutrition label")
Answer: **Data IS collected** — declare it honestly; the bundled `PrivacyInfo.xcprivacy` matches.
When asked "Do you or your third-party partners collect data from this app?", choose **Yes**, then declare (all "Linked to the user", none "Used for tracking", purpose App Functionality):
- **Contact Info → Email Address** (account sign-in)
- **Contact Info → Name** (display name)
- **Identifiers → User ID** (account id)
- **Health & Fitness** (workouts written to / sleep read from Apple Health, training logs)
- **User Content → Other User Content** (posts, comments, messages, coach-share summaries)
- **User Content → Photos or Videos** (verification selfie, profile photo)
No advertising, no analytics SDKs, no tracking — `NSPrivacyTracking` is false.

## TestFlight (internal beta) — minimum needed
TestFlight does NOT require screenshots or the full description. You need:
- An app record in App Store Connect (bundle id com.morpheapp.Morphe)
- An uploaded build (see LAUNCH_CHECKLIST.md)
- "Test Information" → Beta App Description + your email as feedback contact
- Add yourself/testers under Internal Testing
