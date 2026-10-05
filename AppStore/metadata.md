# Morphe — App Store metadata

Copy/paste these into App Store Connect. Fields are length-limited as noted.

---

## App name (≤30 chars)
**Morphe**

> Optional keyword variant (helps search): `Morphe: Workout Tracker` (23 chars)

## Subtitle (≤30 chars)
**Train smarter. Log real sets.** (29 chars)

> Keyword-heavy alternative if search rank matters more than brand at
> launch: `Workout builder & tracker` — the keyword field below already
> carries workout/tracker/gym either way.

## Promotional text (≤170 chars, editable any time without review)
Train smarter. Real sets, a camera that counts your reps on your device, and a score that only states what you logged. No ads, no trackers. (161 chars)

## Keywords (≤100 chars, comma-separated, no spaces)
`workout,gym,fitness,tracker,exercise,log,strength,reps,sets,training,lifting,recovery,builder`

## Description (≤4000 chars)
Morphe is the Spartan in your pocket: a training guardian that plans the session, logs real sets, counts real reps through the camera, and never invents a number. Plan your workouts, log every set with real weight and reps, and watch a Morphe Score that reflects what you actually did.

TRAIN SMARTER — THE HOUSE RULES
• Real scores only — every stat is computed from sets you logged
• No ads, no trackers — your numbers are never sold or used to target you
• Your data, your export, and every safety feature stay free, always
• Nothing fake — no invented streaks, no padded progress

BUILD YOUR OWN WORKOUTS
• Create custom workouts from a library of 590+ exercises, or start one of 300+ ready workouts across 17 training styles
• Add your own exercises when something's missing
• Set your target sets and reps

LOG WHAT MATTERS
• Track weight, sets, reps, and RPE for every exercise
• Log a set by voice: "log 3 by 10 at 135"
• Switch between lb and kg
• A rest timer in the Dynamic Island keeps you moving

FORM CHECK
• The camera counts your reps on your device, across eleven movement patterns, and times holds
• It reads your build first, then range, tempo, symmetry, and alignment — a training aid, not a diagnosis
• Video never leaves your phone; record a clip to your own camera roll if you want one

MORPHE AI
• Ask what's next, why today's plan changed, or how your readiness looks — answered from your own logs, never invented
• Hey Morphe: hands-free with the app open, once you turn it on

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
• Weekly boards and code-joinable challenges — opt-in, real scores only
• (Feed, posts, reactions and comments ship when FeatureFlags.socialFeedEnabled is on — leave these out of the listing until then)
• Live buddy sessions: train the same workout together in real time
• Coaches: manage your roster, message clients, and see consented live progress

YOUR DATA, YOUR CALL
• Your account backs up your training so a new phone restores everything
• Optional Apple Health sync: workouts count toward your rings, sleep pre-fills your check-in
• Export everything as one file, or delete your account — both in the app
• No ads, no analytics trackers, and your data is never sold

Built for beginners and anyone rebuilding momentum. Small wins. Real transformation.

## What's New (release notes, first version)
First release of Morphe. Build workouts, log real sets by hand or by voice, let Form Check count reps on your device, and run multi-week programs — with opt-in Apple Health sync, cloud backup, and full data export and deletion built in.

---

## App Store Connect settings

- **Primary category:** Health & Fitness
- **Secondary category:** (optional) Lifestyle
- **Age rating:** answer the questionnaire honestly — with user-generated content and social features expect **12+** (infrequent/mild UGC exposure); Morphe ships report + block + filter as 1.2 requires
- **Price:** Free
- **Bundle ID:** com.morpheapp.Morphe
- **Version:** 1.0
- **Privacy Policy URL:** https://lucasdilley07-png.github.io/Morphe/privacy.html (live since 2026-10-05 — LAUNCH_CHECKLIST step 1)
- **Support URL:** https://lucasdilley07-png.github.io/Morphe/support.html
- **Marketing URL:** https://lucasdilley07-png.github.io/Morphe/

## App Privacy questionnaire (the "nutrition label")
Answer: **Data IS collected** — declare it honestly; the bundled `PrivacyInfo.xcprivacy` matches.
When asked "Do you or your third-party partners collect data from this app?", choose **Yes**, then declare (all "Linked to the user", none "Used for tracking", purpose App Functionality):
- **Contact Info → Email Address** (account sign-in)
- **Contact Info → Name** (display name)
- **Identifiers → User ID** (account id)
- **Health & Fitness** (workouts written to / sleep read from Apple Health, training logs)
- **User Content → Other User Content** (posts, comments, messages, coach-share summaries)
- **User Content → Photos or Videos** (verification selfie, profile photo)
- **Usage Data → Product Interaction** (first-party milestone events: retention/activation; purpose Analytics, not tracking)
No advertising, no analytics SDKs, no tracking — `NSPrivacyTracking` is false.

## TestFlight (internal beta) — minimum needed
TestFlight does NOT require screenshots or the full description. You need:
- An app record in App Store Connect (bundle id com.morpheapp.Morphe)
- An uploaded build (see LAUNCH_CHECKLIST.md)
- "Test Information" → Beta App Description + your email as feedback contact
- Add yourself/testers under Internal Testing
