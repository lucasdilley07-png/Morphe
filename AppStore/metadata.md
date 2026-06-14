# Morphe — App Store metadata

Copy/paste these into App Store Connect. Fields are length-limited as noted.

---

## App name (≤30 chars)
**Morphe**

> Optional keyword variant (helps search): `Morphe: Workout Tracker` (23 chars)

## Subtitle (≤30 chars)
**Workout builder & tracker**

## Promotional text (≤170 chars, editable any time without review)
Build your own workouts, log real weight and reps, and see a Morphe Score that reflects what you actually did. Private by design — everything stays on your phone.

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

PRIVATE BY DESIGN
• Everything stays on your device. No account, no sign-up, no tracking, and nothing ever leaves your phone.

Built for beginners and anyone rebuilding momentum. Small wins. Real transformation.

## What's New (release notes, first version)
First release of Morphe. Build your own workouts, log real sets with weight and reps, track honest progress, learn the why behind training, and check your recovery — all private, all on your device.

---

## App Store Connect settings

- **Primary category:** Health & Fitness
- **Secondary category:** (optional) Lifestyle
- **Age rating:** 4+ (no objectionable content; not medical advice)
- **Price:** Free
- **Bundle ID:** com.lucas.Morphe
- **Version:** 1.0
- **Privacy Policy URL:** _<your hosted policy URL — see docs/ and LAUNCH_CHECKLIST.md>_
- **Support URL:** _<a page or email you control, e.g. a simple site or mailto>_
- **Marketing URL:** (optional)

## App Privacy questionnaire (the "nutrition label")
Answer: **Data Not Collected.**
Morphe has no backend, no analytics, no third-party SDKs, and no tracking — nothing leaves the device. This matches the bundled `PrivacyInfo.xcprivacy` manifest. When asked "Do you or your third-party partners collect data from this app?", choose **No**.

## TestFlight (internal beta) — minimum needed
TestFlight does NOT require screenshots or the full description. You need:
- An app record in App Store Connect (bundle id com.lucas.Morphe)
- An uploaded build (see LAUNCH_CHECKLIST.md)
- "Test Information" → Beta App Description + your email as feedback contact
- Add yourself/testers under Internal Testing
