// Morphe AI online (Lucas 2026-10-14): the relay that lets members use
// Morphe AI without pasting their own Anthropic key.
//
// What it does, in order, for every request:
//   1. Verifies the Firebase ID token (a signed-in Morphe account), and the
//      App Check token when REQUIRE_APP_CHECK is on.
//   2. Reads the member's backed-up profile and refuses anyone under 18 or
//      with no age on file (Anthropic's rules for products minors use).
//   3. Counts the request against the member's daily allowance, allows one
//      request in flight per member, and holds the request's WORST-CASE
//      cost against the month's dollar budget — one Firestore transaction,
//      BEFORE Claude is called. The real cost replaces the hold afterward.
//      Anthropic's own spend cap on the key is the backstop.
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
  worstCaseMicroUSD,
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
  if (res.headersSent) return;
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

/** A request still marked in flight after this long is treated as dead
 *  (the function's own timeout is shorter). */
const IN_FLIGHT_STALE_MS = 6 * 60 * 1000;

interface Reservation {
  uid: string;
  day: string;
  month: string;
  /** Worst-case cost held against the month until the real cost lands. */
  heldMicroUSD: number;
}

/** Reserves one request in a single transaction: the month's budget must
 *  cover this request's WORST-CASE cost (held now, settled later), the
 *  member must be under the day's allowance, and have nothing else in
 *  flight. A burst of parallel requests can't slip past the budget. */
async function reserve(uid: string, heldMicroUSD: number): Promise<Reservation> {
  const day = dayKey();
  const month = monthKey();
  const userRef = db().doc(`aiUsage/${uid}`);
  const monthRef = db().doc(`aiUsage/_month_${month}`);
  const budgetMicro = MONTHLY_BUDGET_USD.value() * 1_000_000;
  await db().runTransaction(async (tx) => {
    const [userSnap, monthSnap] = await Promise.all([tx.get(userRef), tx.get(monthRef)]);
    const spent = (monthSnap.data()?.spentMicroUSD as number | undefined) ?? 0;
    if (spent + heldMicroUSD > budgetMicro) {
      throw new RelayRequestError(429, "budget", "Morphe's AI budget for this month is used up — the built-in answers still work, and it resets next month.");
    }
    const user = userSnap.data() ?? {};
    const sameDay = user.day === day;
    const count = sameDay ? ((user.count as number | undefined) ?? 0) : 0;
    if (count >= DAILY_LIMIT.value()) {
      throw new RelayRequestError(429, "daily_limit", `You've used today's ${DAILY_LIMIT.value()} online answers — the built-in brain still works, and it resets at midnight UTC.`);
    }
    const since = (user.inFlightSince as number | undefined) ?? 0;
    if (since && Date.now() - since < IN_FLIGHT_STALE_MS) {
      throw new RelayRequestError(429, "busy", "Morphe AI is still answering your last question — one at a time.");
    }
    tx.set(userRef, { day, count: count + 1, inFlightSince: Date.now(), updatedAt: FieldValue.serverTimestamp() });
    tx.set(monthRef, { spentMicroUSD: FieldValue.increment(heldMicroUSD), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  });
  return { uid, day, month, heldMicroUSD };
}

/** Replaces the held worst case with the real cost, frees the member's
 *  slot, and — when Anthropic itself failed before answering — gives the
 *  day's request back. Never throws: the answer already went out. */
async function settle(r: Reservation, usage: Usage | undefined | null, refundRequest: boolean) {
  try {
    const actual = costMicroUSD(usage);
    await db()
      .doc(`aiUsage/_month_${r.month}`)
      .set({
        spentMicroUSD: FieldValue.increment(actual - r.heldMicroUSD),
        requests: FieldValue.increment(refundRequest ? 0 : 1),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    const userRef = db().doc(`aiUsage/${r.uid}`);
    await db().runTransaction(async (tx) => {
      const user = (await tx.get(userRef)).data() ?? {};
      const update: Record<string, unknown> = { inFlightSince: 0, updatedAt: FieldValue.serverTimestamp() };
      if (refundRequest && user.day === r.day) {
        update.count = Math.max(0, ((user.count as number | undefined) ?? 1) - 1);
      }
      tx.set(userRef, update, { merge: true });
    });
  } catch (error) {
    logger.error("settle failed", { uid: r.uid, error: String(error) });
  }
}

/** Anthropic's own failures (rate limits, overload, outages) are not the
 *  member's — their daily request is refunded. A 400 is not refunded. */
function isUpstreamFailure(error: unknown): boolean {
  if (error instanceof Anthropic.APIConnectionError) return true;
  if (error instanceof Anthropic.RateLimitError) return true;
  return error instanceof Anthropic.APIError && (error.status ?? 0) >= 500;
}

function mergeUsage(into: Usage, from: Partial<Usage> | null | undefined) {
  if (!from) return;
  // message_delta carries CUMULATIVE usage (it grows with each search
  // iteration and replaces the start numbers on a fallback).
  if (typeof from.input_tokens === "number") into.input_tokens = from.input_tokens;
  if (typeof from.output_tokens === "number") into.output_tokens = from.output_tokens;
  if (typeof from.cache_creation_input_tokens === "number") into.cache_creation_input_tokens = from.cache_creation_input_tokens;
  if (typeof from.cache_read_input_tokens === "number") into.cache_read_input_tokens = from.cache_read_input_tokens;
  if (from.server_tool_use && typeof from.server_tool_use.web_search_requests === "number") {
    into.server_tool_use = { web_search_requests: from.server_tool_use.web_search_requests };
  }
}

export const morpheAI = onRequest(
  {
    region: "us-central1",
    secrets: [ANTHROPIC_API_KEY],
    // An 8,000-token answer with five searches can run past two minutes.
    timeoutSeconds: 300,
    memory: "512MiB",
    // Tight until App Check is enforced: a script can't fan out wide.
    concurrency: 10,
    maxInstances: 2,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      fail(res, 405, "method", "POST only");
      return;
    }
    let uid = "";
    let reservation: Reservation | null = null;
    try {
      uid = await verifyCaller(req);
      await verifyAge(uid);
      const body = sanitizeBody(req.body);
      reservation = await reserve(uid, worstCaseMicroUSD(body));

      const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
      const params = {
        model: MODEL,
        max_tokens: body.maxTokens,
        // The system prompt is the stable prefix: one explicit breakpoint
        // on it, so a member's follow-ups within five minutes read it at a
        // tenth of the price.
        system: (body.system.length ? body.system : [{ type: "text" as const, text: "You are Morphe." }])
          .map((block, i) => (i === 0 ? { ...block, cache_control: { type: "ephemeral" as const } } : block)),
        messages: body.messages as Anthropic.Beta.BetaMessageParam[],
        output_config: { effort: body.effort, ...(body.format ? { format: body.format } : {}) },
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
        let started = false;
        let refund = false;
        const stream = await client.beta.messages.create({ ...params, stream: true }).catch((error) => {
          refund = isUpstreamFailure(error);
          throw error;
        });
        // The member left (closed the chat, lost signal): stop generating
        // instead of paying for an answer nobody reads.
        req.on("close", () => stream.controller.abort());
        try {
          for await (const event of stream) {
            if (event.type === "message_start") {
              started = true;
              mergeUsage(usage, event.message.usage);
            } else if (event.type === "message_delta") {
              mergeUsage(usage, event.usage);
            }
            res.write(`event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`);
          }
        } catch (error) {
          refund = !started && isUpstreamFailure(error);
          if (!res.writableEnded && !req.destroyed) {
            // The same honest shape the Messages API uses for a mid-stream
            // error; the app already reads it.
            const type = error instanceof Anthropic.RateLimitError ? "rate_limit_error"
              : error instanceof Anthropic.APIError && (error.status ?? 0) >= 500 ? "overloaded_error"
              : "api_error";
            res.write(`event: error\ndata: ${JSON.stringify({ type: "error", error: { type, message: "Morphe AI online hit a snag." } })}\n\n`);
          }
          logger.error(error instanceof Anthropic.AuthenticationError ? "relay key rejected" : "stream failed", { uid, error: String(error) });
        } finally {
          if (!res.writableEnded) res.end();
          await settle(reservation, usage, refund);
          reservation = null;
        }
        return;
      }

      const message = await client.beta.messages.create(params);
      res.status(200).json(message);
      await settle(reservation, message.usage as Usage, false);
      reservation = null;
    } catch (error) {
      if (reservation) {
        await settle(reservation, null, isUpstreamFailure(error));
        reservation = null;
      }
      if (res.headersSent) {
        if (!res.writableEnded) res.end();
        return;
      }
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
