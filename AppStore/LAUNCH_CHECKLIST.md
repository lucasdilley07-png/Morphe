# Morphe — Launch checklist

What's ready in this repo, and the exact steps that need your Apple,
GitHub and business accounts. **Refreshed 2026-10-10** (build 8b06450 on
the phone, 391 tests, rules 99/99 live). The Friday 10-09 target passed;
the gate is still the Apple Developer Program.

## ✅ Ready in the repo

- App: every feature in `docs/HANDOFF.md`, Release build clean, 391 tests.
- Listing: `AppStore/metadata.md` (name, subtitle, keywords, description,
  what's new, App Privacy answers, three URLs).
- Site: `docs/index.html` (marketing), `docs/privacy.html`,
  `docs/terms.html` (generated from the `.md` sources by
  `Tools/build_privacy_page.py`), `docs/support.html`, `docs/coach.html`.
- Policy: Terms of Use v2 (human-only), privacy policy current, in-app
  report/block/filter, human review tools.
- Compliance: `PrivacyInfo.xcprivacy` (app + widget), usage strings
  (camera, microphone, speech, Photos add-only, Health), encryption
  exemption, Live Activities, iPhone-only portrait, app icon + launch
  screen.
- Backend: rules published and verified; admin tools.

## ⏳ Needs you — in order

**1. Apple Developer Program ($99)** — developer.apple.com/programs/enroll.
Everything below waits on approval (24–48 h). Individual enrolment is
fine now; it can move to the LLC later.

**2. While it processes**
- [ ] Firebase console → upgrade `morphe-3c5c2` to Blaze, $10 budget alert.
- [ ] Google Cloud → Credentials → restrict the web API key to
      `https://lucasdilley07-png.github.io/*`.
- [ ] Firebase Auth → Settings → "Email enumeration protection" on.
- [ ] GitHub: sign in once in the Terminal tab so the ~30 local commits
      push (git asks for username + a personal access token).
- [ ] Create the reviewer account in the app: sign up, accept the terms,
      log 2–3 sessions, join the weekly board; keep the email + password
      for App Review Information.
- [ ] Decide the store name: `Morphe` first, `Morphe: Workout Tracker`
      fallback (cosmetics brand conflict — see Trademark below).
- [ ] Decide whether the website Store section ships hidden or "coming
      soon" (placeholder prices today).
- [ ] Sign in on the Pro Max simulator, then say "take the screenshots"
      (1320×2868: Today, Train, Form Check, Morphe AI, Progress, Learn).

**3. When Apple approves**
- [ ] Xcode → Signing: switch the four targets to the paid team; add the
      App Attest entitlement back (`Morphe/Morphe.entitlements`,
      `com.apple.developer.devicecheck.appattest-environment` =
      `production`); reinstall on the phone.
- [ ] Firebase → App Check: register the app, upload the DeviceCheck key,
      watch tokens flow, then enforce for Firestore.
- [ ] App Store Connect → new app record: name, bundle
      `com.morpheapp.Morphe`, SKU `morphe-001`, the three URLs, App
      Privacy per `metadata.md` (Data IS collected), age rating 12+.
- [ ] Archive (Release, Any iOS Device) → Distribute → TestFlight.
- [ ] TestFlight internal group = your Apple ID; install; run one full
      session + a Form Check + a food check with your key.
- [ ] App Review Information: Sign-in required = YES with the reviewer
      account; review notes below.
- [ ] Submit for review (24–72 h).

**4. After the links exist**
- [ ] Paste the App Store / TestFlight URLs into `APP_STORE_URL` /
      `TESTFLIGHT_URL` at the bottom of `docs/index.html`, push.
- [ ] If the name changed: `AppStore/metadata.md` + the site `<title>`.

## Review notes (paste into App Review Information)

Every feature is tied to a synced account, so there is no account-free
mode. Form Check runs entirely on-device; video never leaves the phone.
Morphe AI answers from the user's own logs without any key; with the
user's own Anthropic key it can also read a food photo or build a
workout. To try Train Together with one device: Train → Train Together,
host a session and note the code; a second account joins by typing it.
Community content is human-only by policy: posts, comments and messages
are screened and paced; anyone can report; a human reviews every report.
Account deletion is Profile → Login → Delete Account; export is Profile →
Your data.

## Open code items (not blockers)

- Four hard-width buttons may clip at accessibility text sizes.
- Public profile document (names/bylines for members who haven't posted).
- Video posts (storage), push notifications, Spanish, form diagrams for
  every exercise, a strike ledger for repeat policy breaches.

## Business side (researched 2026-10-08; (est.) = verify at checkout)

**Entity — do first, the rest attach to it**
- [ ] California LLC with a neutral holdco name (Morphe becomes a DBA):
      Articles online $70 → Statement of Information (90 days) $20 → EIN
      free → calendar the $800 franchise tax (15th day of the 4th month,
      yearly) → county fictitious business name ~$30–60 + publication
      ~$40–100 (est.) → business bank account; Apple + Firebase on the
      LLC card.

**Trademark — after the LLC**
- [ ] Knockout search (tmsearch.uspto.gov): Morphe LLC (cosmetics) holds
      Reg. 4967948 + 5756672 in Class 3/35 — different classes, but a
      known brand; pick the fallback name before filing.
- [ ] Word mark MORPHE, Class 9 + Class 41, $350/class DIY ($700);
      optional attorney ~$500–1,500 (est.); 12–18 months; ™ now.
- [ ] Claim one handle everywhere (@trainmorphe / @morpheapp).

**Domain + footprint**
- [ ] Buy trainmorphe.com (~$12–20/yr est.; morphe.fit second); point at
      GitHub Pages (docs/CNAME + DNS); hello@ via Cloudflare Email
      Routing; update the three App Store URLs before submitting; SEO
      basics on the site; Search Console + Bing.

**Products (website store)**
- [ ] Gear only for launch (print-on-demand: Fourthwall or Printful +
      Shopify); 2 SKUs max (Helmet Tee, Field Cap), one sample each;
      real prices; seller's permit before the first sale. Supplements
      stay "coming soon".

**Content** — sourcing law: every post cites a real artifact
(`docs/archive/LAUNCH-CONTENT-CALENDAR.md`): the audits, the $99 gate, the
human-only policy, the 595-exercise library, the rank ladder.

**Posters / flyers** — one design (helmet + TRAIN HONEST + QR); 100
flyers ~$25–50, 50–100 posters ~$36–85; ask the gym owner, pitch the
coach pilot (`docs/archive/COACH-PITCH.md`) in the same conversation.

**Budget, first 30 days (DIY)**: Apple $99 · LLC $90 · EIN $0 · FBN
$70–160 · trademark $700 · domain $15–60 · email $0–96 · Firebase ~$0–25/mo
· store $0–39/mo · samples $50–80 · print $60–135 · ads $0 · content $0 →
**~$1,100–1,400** (franchise tax $800 lands month 4). With an attorney
~$2,400–3,700. Order of spend: Apple → LLC → domain → trademark → print.

## The 90-day proof window (investor-audit milestones)

Clock starts on TestFlight. First-party measurement only
(`Tools/metrics_report.py`, weekly, same day).
- Week 0: pay the $99, upload, invite 10 testers.
- Weeks 1–2: fix what the first 25 strangers hit; App Store submission.
- Weeks 1–12: coach pilot (`docs/archive/COACH-PILOT.md`, 10–25 paying coaches).
- Bars: D30 ≥ 10–12 %, organic k > 0, activation (first log) ≥ 40 %.
- Week 12: coach wedge proven → raise or bootstrap on revenue; disproven
  → consumer bootstrap, no raise.
