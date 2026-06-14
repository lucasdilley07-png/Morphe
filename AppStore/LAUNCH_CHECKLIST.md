# Morphe — Launch checklist

What's ready in this repo, and the exact steps that need your Apple/GitHub accounts.

## ✅ Done (in the repo)
- `AppStore/metadata.md` — app name, subtitle, keywords, description, what's-new, and the App Privacy answer ("Data Not Collected").
- `AppStore/screenshots/` — 4 screenshots at 1320×2868 (the App Store 6.9" iPhone size): Today, Train, Progress, Learn.
- `PRIVACY_POLICY.md` and `docs/index.html` — the privacy policy (markdown + a ready-to-host web page).
- The app compiles cleanly in **Release** configuration (verified), so it's archive-ready.
- `PrivacyInfo.xcprivacy` privacy manifest is bundled; a 1024px app icon (no alpha) is set.

## 1. Host the privacy policy → get a URL  (needs your GitHub, ~5 min)
App Store Connect requires a public Privacy Policy URL.
1. First edit `docs/index.html` (and `PRIVACY_POLICY.md`) and replace the placeholders:
   `[Developer / legal name]`, `[contact email]`, `[your state/country]`.
2. Create a GitHub repo and push this project.
3. Repo → **Settings → Pages** → Source: **Deploy from a branch**, Branch: `main`, Folder: `/docs` → Save.
4. After a minute your URL is `https://<your-username>.github.io/<repo>/` — use it as the Privacy Policy URL.
   (Any static host or even a public Notion page works too.)

## 2. Apple Developer + signing  (needs your Apple ID, one-time)
1. Enroll in the **Apple Developer Program** ($99/yr) if you haven't.
2. In **Xcode → Settings → Accounts**, add your Apple ID. _(This machine currently has no account signed in — that's why the CLI archive step is blocked.)_
3. Open `Morphe.xcodeproj`, select the **Morphe** target → **Signing & Capabilities** → check **Automatically manage signing** and pick your Team (the project is preset to team `8P47H3XRN3` — change it to yours if different).

## 3. Create the app in App Store Connect  (needs your account)
1. appstoreconnect.apple.com → **My Apps → +** → New App.
2. Platform iOS · Name **Morphe** · Primary language English · Bundle ID **com.lucas.Morphe** · SKU `morphe-001`.
3. Fill the listing from `AppStore/metadata.md`; set Privacy Policy URL from step 1; App Privacy → **Data Not Collected**.

## 4. Archive & upload  (in Xcode, after steps 2–3)
1. Xcode → toolbar device target → **Any iOS Device (arm64)**.
2. **Product → Archive**.
3. In the Organizer that opens → **Distribute App → App Store Connect → Upload**.
   - CLI equivalent (once signed in): `xcodebuild -project Morphe.xcodeproj -scheme Morphe -configuration Release -archivePath build/Morphe.xcarchive archive` then export/upload.

## 5. TestFlight  (the goal)
1. App Store Connect → your app → **TestFlight**. The uploaded build appears after processing (~10–30 min).
2. Fill **Test Information** (Beta App Description + your feedback email).
3. **Internal Testing** → add yourself/testers (up to 100 internal, no review needed) → they install via the TestFlight app.
4. For **external** testers (up to 10,000), submit the build for a quick Beta App Review first.

## 6. Public release (later)
Add the 4 screenshots, finalize the description, set age rating 4+ and category Health & Fitness, then **Submit for Review**.

---

## Known follow-ups worth fixing before public release (not blockers for TestFlight)
- The **Train → "Good for Today"** card shows **"Source: Lucas"** and a **"With Buddy"** option — leftover demo/multi-user leaks that should be cleaned for a solo v1.
- Replace the placeholder **app icon** (a plain "M") with real branding.
- A full **accessibility** pass (only core nav is labeled so far).
