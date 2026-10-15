# Morphe AI online — the relay

One Cloud Function (`morpheAI`, 2nd gen, us-central1) that lets a signed-in
Morphe member use Morphe AI without their own Anthropic key. The app calls it
exactly like the Anthropic Messages API, with a Firebase ID token instead of
an API key; the function checks the account, the member's age (18+), the
member's daily allowance and the month's budget, then forwards a bounded
request to Claude Sonnet 5.5 and streams the answer back unchanged.

URL the app uses: `https://us-central1-morphe-3c5c2.cloudfunctions.net/morpheAI`
(`MorpheIntelligence.relayURL`).

## Limits (Firebase params, change without a code change)

| Param | Default | Meaning |
|---|---|---|
| `MORPHE_AI_DAILY_LIMIT` | 30 | requests per member per UTC day |
| `MORPHE_AI_MONTHLY_BUDGET_USD` | 45 | the relay stops for the month at this estimated spend |
| `MORPHE_AI_MINIMUM_AGE` | 18 | from the member's backed-up profile; no age on file = refused |
| `MORPHE_AI_REQUIRE_APP_CHECK` | false | set `true` once App Check is enforced (paid Apple account) |

Usage lives in Firestore `aiUsage/{uid}` (day + count) and
`aiUsage/_month_YYYY-MM` (requests + spentMicroUSD). Counts and dollars only —
no message content is stored. The rules deny every client read and write.

## Deploy (once Node 22 and the Firebase CLI are installed)

```bash
cd BACKEND/functions && npm install && npm test
```

```bash
cd BACKEND && firebase login
```

```bash
cd BACKEND && firebase functions:secrets:set ANTHROPIC_API_KEY
```

Paste the Morphe key from the Anthropic console (the one with the $50/month
spend limit). Then:

```bash
cd BACKEND && firebase deploy --only functions
```

The first deploy asks to enable Cloud Functions, Cloud Build, Artifact
Registry and Secret Manager on the project — say yes. It needs the Blaze
plan.

## Prove it

Signed-in request from a machine (ID token from the app's debug log or
`firebase auth:export`):

```bash
curl -N -X POST https://us-central1-morphe-3c5c2.cloudfunctions.net/morpheAI -H "authorization: Bearer $ID_TOKEN" -H "content-type: application/json" -d '{"system":"You are Morphe.","messages":[{"role":"user","content":"Say hi in four words."}],"stream":true}'
```

Expected: `event: message_start` … `event: message_stop`. A 401 without a
token, a 403 `age` for a profile under 18, a 429 `daily_limit` on the 31st
request of the day, a 429 `budget` once the month's estimate passes the
budget.

## Change the model or the price table

`src/guard.ts` — `MODEL` and `PRICE_PER_MILLION`. The price table is what
the budget counts with; keep it in step with Anthropic's pricing page when
the model changes.
