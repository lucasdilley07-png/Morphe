# Universal Links — the $99 flip

Everything is staged; the paid Apple Developer Program is the only gate.
When the account exists, this is the whole flip:

## Already done (this repo)

- **App-side parsing** — `handleIncomingURL` accepts
  `https://<any-host>/invite/<handle>` exactly like `morphe://invite/…`
  (host-agnostic on purpose: iOS only delivers hosts the AASA matched, so
  the handler survives a domain move). Ships dormant until the entitlement
  exists.
- **Landing page** — `docs/invite.html` (+ `docs/404.html` path shim for
  GitHub Pages): shows who invited you, "Open in Morphe" via the custom
  scheme, App Store button placeholder, install steps. Brand-styled.
- **AASA file** — `docs/.well-known/apple-app-site-association`
  (`8P47H3XRN3.com.morpheapp.Morphe`, paths `/invite/*`).

## The flip (after the $99 account)

1. **Team id check** — the paid account may mint a NEW team id. If it does,
   update the `appID` prefix in the AASA file and re-host.
2. **Host the site** — GitHub Pages from `docs/` (same motion as the
   privacy policy in LAUNCH_CHECKLIST step 1). Custom domain strongly
   preferred (e.g. `morphe.app`): AASA must be served from
   `https://<domain>/.well-known/apple-app-site-association`, content-type
   `application/json`, no redirect. GitHub Pages serves `.well-known` fine.
3. **Entitlement** — add Associated Domains to the Morphe target:
   `applinks:<domain>` (needs the paid account; free teams reject it).
   Update `Morphe/Morphe.entitlements` + provisioning (
   `-allowProvisioningUpdates` handles it).
4. **Update the share caption** — `MorpheStore.shareCardCaption` and
   `networkInviteMessage` currently say `morphe://invite/<handle>`; switch
   to `https://<domain>/invite/<handle>` so the SAME link works for
   installed (opens app) and not-installed (lands on the page).
5. **App Store button** — put the real listing URL into `docs/invite.html`
   (`#store` link, remove `hidden`).
6. **Verify** — `curl -i https://<domain>/.well-known/apple-app-site-association`,
   then on-device: tap an `/invite/<handle>` link from Notes with the app
   installed (should open the app and save the referral) and without
   (should land on the page).

## Why this matters

The referral loop currently dead-ends for anyone WITHOUT the app: a
`morphe://` link does nothing in their browser. After the flip, one link
serves both sides — that closes the biggest hole in the growth loop
(docs/BRAND-AUDIT-2026-07.md, gap #3).
