# Full usability audit — findings & dispositions (2026-07-29)

Four-track maximally-critical audit (new-user comprehension, social
surface, core training loop, cross-cutting). 68 findings + 5
hand-verified cross-cutting items. ~40 fixed in the same pass (commit
noted in git); the rest are dispositioned below.

## FIXED — functional (the ones that corrupted data or state)

- Typed console weight raced the Log Set button → committed per keystroke.
- Pull-to-refresh deleted paginated pages + scroll position → merges.
- LOAD OLDER could stall forever on a fully-filtered page → raw cursor.
- Presence rail + Duo Streak shrank to the 20-post page → dedicated 24h
  presence query (union; duo streak documented as undercount-only).
- Inbox never live-updated (unread frozen till relaunch) → refresh on
  pane switch; read-stamp now rides every listener delivery.
- Deep link to coach thread landed on the list after first back-out →
  store-level pending-thread id.
- Rest timer dead after mid-session relaunch → resumes from the shared
  wall-clock anchor.
- Minimum Win was a one-way door until midnight → Full Plan exit button.
- Quick-prompt declines were invisible (sheet only opened for
  conversational replies) → sheet opens first, navigation closes it
  same-transaction.
- "log bench 3x10" could mis-log against the active exercise → guides
  instead of guessing.
- Custom accent preview lagged while another palette active → always
  re-applies.

## FIXED — honesty

- Story "Reply…" posted a PUBLIC comment → labeled "Comment publicly…".
- Self bubble wore the "unseen" ring for your own posts → never does.
- Board bubble masqueraded as a person's story → named "Board".
- "Trend moving in the right direction" claimed unconditionally →
  gated on the real streak.
- Silent superset hop read as a bug → toast names the partner; first
  link explains the mechanic.
- Finish ≠ saved trap → "Finish & Review" + unmissable gold "Not saved
  yet" banner until logged.
- Strength charts silently excluded warm-ups → captions say so.
- Form Check oversell → "framing + rep counting, not a form diagnosis"
  pill shown BEFORE the first rep.
- Plan-by card implied adaptive AI coaching → "starting plan" wording.

## FIXED — comprehension

- Tab bar was six unlabeled glyphs (BLOCKER) → mono micro-labels.
- Morphe Score never explained → tappable pill + alert with the actual
  formula and tier legend; empty-state copy explains meaning not just
  timing.
- Onboarding: welcome promise matched to reality; username prefilled
  (suggested handle, fully editable); coach-code step marked OPTIONAL;
  30/60/90 goal boxes marked optional with worked examples; CRM jargon
  removed; injury step marked optional with a data-handling note.
- Terms: onboarding toggle now links to the FULL terms (read-only
  TermsGateView) and its consent satisfies the gate — no more double
  agreement wall; label no longer references a nonexistent separate
  "Privacy Policy" (the Your Data section covers current practice).
- Check-in scales anchored (drained↔charged etc.).
- RPE help renames itself in RIR mode + per-value anchors (6–10).
- AI pill keeps its label for 3 opens (was: de-labeled after 1).
- "Stage Today" → "Train Today" (3 sites). Discover: filters that
  zero-out show an explicit empty state + Clear; equipment filter no
  longer vanishes between categories.
- Feed: LOAD OLDER looks like a button; filtered lens explains why
  paging is off; ring legend line under the rail; chat-streak chip
  explains itself on tap; log history rows show EDIT, not an ellipsis;
  Log Old names its 14-day cap; board+challenges refresh with the pull.
- Streak Protection options explained (nothing is spent or lost).
- Tier unlocks announce themselves ("Today unlocked new cards…").
- Network camera button labeled FORM.

## DEFERRED (deliberate, with reasons)

- Cutting onboarding to ~4 steps: product surgery — trims shipped
  instead (optional labels, prefill, honest promise). Lucas's call.
- TabView page-swipe vs edge-swipe-back: on-device gesture verify.
- Console in-flight draft persistence across app kill: invasive in the
  6k-line view; local file save on log keeps loss to one dial-in.
- Reaction counts within the 5-min staleness window: accepted; pull
  refreshes page counts.
- Byline "whose streak" phrasing; CHATS/FOR YOU subtitles; header "+"
  coach-marks; per-tag legend for W/SS beyond first-link toast: minor
  polish queue.
- Cross-cutting track stalled mid-run; its five priority items were
  hand-verified and fixed (D1–D5). Full consistency sweep (back
  patterns, destructive confirms, caps style) still worth a pass.
- App Store still needs a HOSTED privacy policy URL (Lucas: required
  at submission; in-app Your Data section is not a substitute).
