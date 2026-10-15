// Morphe AI online (Lucas 2026-10-14): the relay that lets members use
// Morphe AI without pasting their own Anthropic key.
//
// What it does, in order, for every request:
//   1. Verifies the Firebase ID token (a signed-in Morphe account), and the
//      App Check token when REQUIRE_APP_CHECK is on.
//   2. Reads the member's backed-up profile and refuses anyone under 18 or
//      with no age on file (Anthropic's rules for products minors use).
//   3. Counts the request against the member's daily allowance and the
//      month's dollar budget, in one Firestore transaction, BEFORE Claude
//      is called. Both limits are the relay's; Anthropic's own spend cap on
//      the key is the backstop.
//   4. Forwards a bounded request to Claude Sonnet 5.5 and streams the
//      answer back in Anthropic's own event format, so the app reads it
//      exactly like a direct call.
//   5. Charges the real cost (from the response's usage) to the month.
//
// Nothing about the conversation is stored here: the usage docs hold
// counts and dollars only.

import { onRequest } from "firebase-functions/v2/https";
import { defineSecret, defineInt, defineString } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getAppCheck } from "firebase-admin/app-check";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import Anthropic from "@anthropic-ai/sdk";
import type { Request, Response } from "express";
import {
  MODEL,
  RelayRequestError,
  ageFromProfileJSON,
  costMicroUSD,
  dayKey,
  monthKey,
  sanitizeBody,
  type Usage,
} from "./guard.js";

initializeApp();

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
/** Requests per member per UTC day. */
const DAILY_LIMIT = defineInt("MORPHE_AI_DAILY_LIMIT", { default: 30 });
/** The relay stops for the month at this estimated spend (USD). Keep it
 *  under the hard cap set on the Anthropic key ($50). */
const MONTHLY_BUDGET_USD = defineInt("MORPHE_AI_MONTHLY_BUDGET_USD", { default: 45 });
const MINIMUM_AGE = defineInt("MORPHE_AI_MINIMUM_AGE", { default: 18 });
/** "true" once App Check is enforced (needs the paid Apple account). */
const REQUIRE_APP_CHECK = defineString("MORPHE_AI_REQUIRE_APP_CHECK", { default: "false" });

const db = () => getFirestore();

function fail(res: Response, status: number, type: string, message: string) {
  res.status(status).json({ error: { type, message } });
}

async function verifyCaller(req: Request): Promise<string> {
  const header = req.get("authorization") ?? "";
  const match = /^Bearer (.+)$/.exec(header);
  if (!match) throw new RelayRequestError(401, "sign_in", "Sign in to use Morphe AI online.");
  let uid: string;
  try {
    uid = (await getAuth().verifyIdToken(match[1])).uid;
  } catch {
    throw new RelayRequestError(401, "sign_in", "Sign in again to use Morphe AI online.");
  }
  if (REQUIRE_APP_CHECK.value() === "true") {
    const token = req.get("x-firebase-appcheck");
    if (!token) throw new RelayRequestError(401, "app_check", "This request did not come from the Morphe app.");
    try {
      await getAppCheck().verifyToken(token);
    } catch {
      throw new RelayRequestError(401, "app_check", "This request did not come from the Morphe app.");
    }
  }
  return uid;
}

async function verifyAge(uid: string) {
  const snap = await db().doc(`users/${uid}/state/profile`).get();
  const age = ageFromProfileJSON(snap.data()?.json);
  if (age < MINIMUM_AGE.value()) {
    throw new RelayRequestError(
      403,
      "age",
      age === 0
        ? "Add your age in Profile → Your Details to use Morphe AI online (18 and older)."
        : "Morphe AI online is for members 18 and older.",
    );
  }
}

/** Reserves one request: bumps the member's day count and the month's
 *  request count, refusing when either limit is reached. */
async function reserve(uid: string) {
  const day = dayKey();
  const month = monthKey();
  const userRef = db().doc(`aiUsage/${uid}`);
  const monthRef = db().doc(`aiUsage/_month_${month}`);
  const budgetMicro = MONTHLY_BUDGET_USD.value() * 1_000_000;
  await db().runTransaction(async (tx) => {
    const [userSnap, monthSnap] = await Promise.all([tx.get(userRef), tx.get(monthRef)]);
    const spent = (monthSnap.data()?.spentMicroUSD as number | undefined) ?? 0;
    if (spent >= budgetMicro) {
      throw new RelayRequestError(429, "budget", "Morphe's AI budget for this month is used up — the built-in answers still work, and it resets next month.");
    }
    const sameDay = userSnap.data()?.day === day;
    const count = sameDay ? ((userSnap.data()?.count as number | undefined) ?? 0) : 0;
    if (count >= DAILY_LIMIT.value()) {
      throw new RelayRequestError(429, "daily_limit", `You've used today's ${DAILY_LIMIT.value()} online answers — the built-in brain still works, and it resets at midnight UTC.`);
    }
    tx.set(userRef, { day, count: count + 1, updatedAt: FieldValue.serverTimestamp() });
    tx.set(monthRef, { requests: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  });
}

async function charge(usage: Usage | undefined | null) {
  const micro = costMicroUSD(usage);
  if (micro <= 0) return;
  await db()
    .doc(`aiUsage/_month_${monthKey()}`)
    .set({ spentMicroUSD: FieldValue.increment(micro), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
}

export const morpheAI = onRequest(
  {
    region: "us-central1",
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 120,
    memory: "512MiB",
    concurrency: 20,
    maxInstances: 10,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      fail(res, 405, "method", "POST only");
      return;
    }
    let uid = "";
    try {
      uid = await verifyCaller(req);
      await verifyAge(uid);
      const body = sanitizeBody(req.body);
      await reserve(uid);

      const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
      const params = {
        model: MODEL,
        max_tokens: body.maxTokens,
        system: body.system,
        messages: body.messages as Anthropic.Beta.BetaMessageParam[],
        output_config: { effort: body.effort },
        // The system prompt is the stable prefix: cached across a member's
        // turns, so every follow-up pays a tenth for it.
        cache_control: { type: "ephemeral" as const },
        // A policy decline is retried server-side on Anthropic's
        // recommended model for that category instead of reaching the
        // member as a refusal.
        fallbacks: "default" as const,
        betas: ["server-side-fallback-2026-07-01"],
        ...(body.webSearchUses
          ? { tools: [{ type: "web_search_20260209" as const, name: "web_search" as const, max_uses: body.webSearchUses }] }
          : {}),
      };

      if (body.stream) {
        res.status(200);
        res.setHeader("content-type", "text/event-stream; charset=utf-8");
        res.setHeader("cache-control", "no-cache");
        res.setHeader("x-accel-buffering", "no");
        res.flushHeaders();
        const usage: Usage = {};
        try {
          const stream = await client.beta.messages.create({ ...params, stream: true });
          for await (const event of stream) {
            if (event.type === "message_start") {
              const u = event.message.usage;
              usage.input_tokens = u.input_tokens;
              usage.cache_creation_input_tokens = u.cache_creation_input_tokens;
              usage.cache_read_input_tokens = u.cache_read_input_tokens;
            } else if (event.type === "message_delta") {
              usage.output_tokens = event.usage.output_tokens;
            }
            res.write(`event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`);
          }
        } catch (error) {
          // The same honest shape the Messages API uses for a mid-stream
          // error; the app already reads it.
          const type = error instanceof Anthropic.RateLimitError ? "rate_limit_error"
            : error instanceof Anthropic.APIError && (error.status ?? 0) >= 500 ? "overloaded_error"
            : "api_error";
          res.write(`event: error\ndata: ${JSON.stringify({ type: "error", error: { type, message: "Morphe AI online hit a snag." } })}\n\n`);
          logger.error("stream failed", { uid, error: String(error) });
        } finally {
          res.end();
          await charge(usage);
        }
        return;
      }

      const message = await client.beta.messages.create(params);
      await charge(message.usage);
      res.status(200).json(message);
    } catch (error) {
      if (error instanceof RelayRequestError) {
        fail(res, error.status, error.type, error.message);
        return;
      }
      if (error instanceof Anthropic.RateLimitError) {
        fail(res, 429, "rate_limit_error", "Morphe AI online is busy — try again in a minute.");
        return;
      }
      if (error instanceof Anthropic.AuthenticationError || error instanceof Anthropic.PermissionDeniedError) {
        logger.error("relay key rejected", { error: String(error) });
        fail(res, 503, "relay_key", "Morphe AI online is not available right now.");
        return;
      }
      if (error instanceof Anthropic.APIError) {
        logger.error("anthropic error", { uid, status: error.status, error: String(error) });
        fail(res, (error.status ?? 0) >= 500 ? 503 : 502, "api_error", "Morphe AI online hit a snag — try again shortly.");
        return;
      }
      logger.error("relay failed", { uid, error: String(error) });
      fail(res, 500, "api_error", "Morphe AI online hit a snag — try again shortly.");
    }
  },
);
