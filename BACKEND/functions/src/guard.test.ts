import { test } from "node:test";
import assert from "node:assert/strict";
import {
  ageFromProfileJSON,
  costMicroUSD,
  dayKey,
  monthKey,
  sanitizeBody,
  RelayRequestError,
  MAX_OUTPUT_TOKENS,
} from "./guard.js";

test("cost follows Sonnet 5.5 rates", () => {
  // 1M input + 1M output = $12.00
  assert.equal(costMicroUSD({ input_tokens: 1_000_000, output_tokens: 1_000_000 }), 12_000_000);
  // 3,000 in + 300 out ≈ $0.009
  assert.equal(costMicroUSD({ input_tokens: 3000, output_tokens: 300 }), 9000);
  assert.equal(costMicroUSD(undefined), 0);
  assert.equal(costMicroUSD({ input_tokens: -5 }), 0);
});

test("day and month keys are UTC", () => {
  const d = new Date("2026-10-14T23:59:00Z");
  assert.equal(dayKey(d), "2026-10-14");
  assert.equal(monthKey(d), "2026-10");
});

test("age reads the profile snapshot, 0 when unknown", () => {
  assert.equal(ageFromProfileJSON(JSON.stringify({ age: 24 })), 24);
  assert.equal(ageFromProfileJSON(JSON.stringify({ name: "x" })), 0);
  assert.equal(ageFromProfileJSON("not json"), 0);
  assert.equal(ageFromProfileJSON(undefined), 0);
});

test("sanitizeBody keeps the bounded fields and nothing else", () => {
  const body = sanitizeBody({
    model: "claude-fable-5-1", // the client never picks the model
    system: "You are Morphe.",
    messages: [{ role: "user", content: "hi" }],
    max_tokens: 999_999,
    stream: true,
    output_config: { effort: "max" },
    tools: [{ type: "web_search_20250305", name: "web_search", max_uses: 50 }],
  });
  assert.equal(body.maxTokens, MAX_OUTPUT_TOKENS);
  assert.equal(body.effort, "low");
  assert.equal(body.stream, true);
  assert.equal(body.webSearchUses, 5);
  assert.deepEqual(body.messages, [{ role: "user", content: "hi" }]);
});

test("sanitizeBody refuses what the relay does not forward", () => {
  assert.throws(() => sanitizeBody({ messages: [] }), RelayRequestError);
  assert.throws(() => sanitizeBody({ messages: [{ role: "assistant", content: "x" }] }), RelayRequestError);
  assert.throws(
    () => sanitizeBody({ messages: [{ role: "user", content: [{ type: "tool_result", content: "x" }] }] }),
    RelayRequestError,
  );
  assert.throws(
    () => sanitizeBody({ messages: [{ role: "user", content: "x" }], tools: [{ type: "bash_20250124", name: "bash" }] }),
    RelayRequestError,
  );
});

test("sanitizeBody passes images and server-tool continuations through", () => {
  const body = sanitizeBody({
    messages: [
      { role: "user", content: [{ type: "image", source: { type: "base64", media_type: "image/jpeg", data: "abc" } }, { type: "text", text: "what is this" }] },
      { role: "assistant", content: [{ type: "server_tool_use", id: "s1", name: "web_search", input: { query: "x" } }] },
    ],
  });
  assert.equal(body.messages.length, 2);
});
