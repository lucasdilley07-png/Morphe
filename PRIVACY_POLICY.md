# Morphe Privacy Policy

**Effective date:** July 26, 2026
**Developer:** Lucas Dilley
**Contact:** lucasdilley.07@gmail.com

Morphe is a fitness tracking and training community app. This policy says
exactly what Morphe collects, where it goes, and what control you have.
Plain language on purpose — if anything here is unclear, email us.

## What Morphe collects

**Account data.** Morphe uses accounts (Firebase Authentication, a Google
service). When you sign up we collect your **email address** and store the
display name and @username you choose. Your @username is globally unique
and visible to other users.

**Training data you create.** Workouts you log (exercises, sets, reps,
weights, effort ratings, session notes), body-weight readings, recovery
check-ins, nutrition entries, goals, and profile details. This data is
stored on your device and backed up to your account in Google Firebase
(Firestore) so you can restore it on a new phone.

**Community content.** Posts, comments, reactions, reposts, who you follow,
who you block, challenge and leaderboard entries (opt-in), Train Together
party participation, and photos you choose to post, and private messages (with a connected coach or any member you start a chat with). Posts and
comments are visible to other signed-in users; messages are visible only to
the two people in the conversation.

**Coach sharing (optional).** If you turn on "Share with coach," a summary
of your real training progress (streak, weekly volume, recent sessions,
PRs, and — only on days you check in — your readiness) is shared with the
one coach you're linked to. Turning it off deletes the shared summary
immediately.

**Verification selfies (optional).** If you request a verified badge, the
selfie you submit is uploaded for human review by the Morphe team and used
for no other purpose.

**Abuse reports.** If you report content, we store the report (what was
reported, the reason you chose, and a text excerpt) so a human can review it.

**Product usage signals (first-party).** To understand whether Morphe
actually works — do people come back, does the first workout happen — the
app records a small set of named milestone events (for example "active
today," "first workout logged," "shared a card") tied to your account id
and a date. This is our own measurement: **no third-party analytics SDK is
involved, nothing is fingerprinted, and no advertising identifiers exist
in the app.** These events are deleted with your account.

## Creator Coach applications (website, optional)

If you apply for a Creator Coach account on the Morphe website, you sign in
with your Morphe account and send your name, username, email, what you
coach, credentials, experience, links, and what you would publish. That
application is stored with your account, read only by you and by the person
reviewing it, and used only to decide the application. A Creator Coach's
published workouts, notes and open challenges carry their name and are
visible to every signed-in member. You can withdraw an application, and
remove anything you published, at any time.

## Apple Health (optional, off by default)

- **Writing:** with "Sync to Health" on, each workout you log is saved to
  Apple Health so it counts toward your Activity rings.
- **Reading:** with "Sleep from Health" on, Morphe reads last night's sleep
  to pre-fill your morning check-in slider.

- **Apple Watch heart rate:** during a workout, the watch app reads your
  heart rate and active energy to show them on your wrist. Morphe does
  not store them or send them anywhere, and the watch app never saves a
  workout of its own.

Health data is used only for the features above. It is **never** used for
advertising, never sold, and never shared with third parties. Both toggles
live in Profile → Settings and are off until you turn them on.

## Device permissions

- **Camera** — Form Check (movement analysis and rep counting happen
  entirely on your device; Form Check video never leaves your phone),
  shooting photos or short clips in the capture camera (a photo is
  uploaded ONLY when you tap Post, and then appears on the community
  feed; clips are never uploaded), and scanning
  Morphe connect/party QR codes.
- **Photo library (add-only)** — saving clips you record, only when you
  tap Save. Morphe cannot read your library. Photos you pick through the
  system photo picker are the only ones the app receives.
- **Progress photos** — photos you take or pick for the Progress screen
  are stored on your iPhone only. They are never uploaded, never shown to
  anyone, and no analysis is run on them. Deleting your account or the app
  removes them.
- **Food and water log, imported history** — what you log, and any workout
  file you import from another app, is saved with the rest of your
  training data under your own account.
- **Microphone & speech recognition** — recording audio for clips you
  capture in video mode, dictating messages to the in-app assistant, and
  the optional "Hey Morphe" wake phrase. While Hey Morphe is on and the
  app is open, the microphone listens for the wake phrase using Apple's
  on-device speech recognition; nothing is stored or sent anywhere until
  you say the phrase and make a request. Audio is processed for
  transcription only. Hey Morphe is off until you turn it on in Profile →
  Voice.
- **Notifications** — local reminders you control (appointments, daily
  session, streak risk, comeback, weekly leaderboard and recap). Morphe
  currently sends no remote push notifications.

Every permission is requested only when the feature needs it, and declining
never breaks the rest of the app.

## What Morphe does NOT do

- No advertising, and no advertising SDKs.
- No selling or renting of your data — to anyone, ever.
- No location tracking.
- No contact-list access.
- No third-party analytics trackers. The only third-party service Morphe
  itself uses is Google Firebase (authentication and database hosting),
  which processes your data on our behalf under
  [Google's terms](https://firebase.google.com/support/privacy). The AI
  providers below are reached only with a key you add yourself.

## AI assistant with your own key (optional)

The in-app assistant works offline out of the box. If you add your own
API keys in Profile → Voice:

- **Anthropic** — the text of your chat messages, plus a short summary of
  your recent training that the assistant needs to answer, is sent to
  Anthropic's API using your key, under
  [Anthropic's privacy policy](https://www.anthropic.com/privacy). Usage
  is billed to your key, not to Morphe.
- **ElevenLabs** — if you also add an ElevenLabs key, the assistant's
  spoken replies are generated by sending the reply text to ElevenLabs
  under [their privacy policy](https://elevenlabs.io/privacy). Billed to
  your key.

Keys are stored in the iOS Keychain on your device and are never backed
up to your Morphe account or sent to us. Remove a key at any time to stop
all traffic to that provider.

## Where your data lives

On your device, and — for account-backed data — in Google Firebase
(Firestore), protected by security rules so that only you (and, where you
explicitly opted in, your linked coach) can read your data. Community
content you publish is readable by signed-in users by design.

## Your controls

- **Export** — Profile → Your data → Export Data produces a single JSON file
  with every workout you've logged and your weight history.
- **Delete your account** — Profile → Login → Delete Account permanently
  removes your sign-in, cloud backup, weight history, and @username, and
  wipes the app's local data. Posts and comments you shared remain on the
  feed unless you delete them first (long-press any of yours); after
  account deletion they are no longer connected to a live account.
- **Delete individual content** — long-press your own posts and comments to
  delete them at any time.
- **Block and report** — available on every post and comment; blocking is
  instant and reports are reviewed by a human.

## Children

Morphe is not directed at children under 13, and we do not knowingly
collect data from them.

## Changes

If this policy changes, the effective date above changes with it and the
current version ships inside the app repository and on the app's website.

## Contact

Questions, requests, or complaints: **lucasdilley.07@gmail.com**.
