import { test } from "node:test";
import assert from "node:assert/strict";
import {
  ageFromProfileJSON,
  costMicroUSD,
  worstCaseMicroUSD,
  MAX_TOTAL_CHARS,
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
  // Each web search is $0.01, outside tokens.
  assert.equal(costMicroUSD({ server_tool_use: { web_search_requests: 3 } }), 30_000);
});

test("the worst case bounds one request at well under a dollar", () => {
  const huge = sanitizeBody({ system: "x".repeat(60_000), messages: [{ role: "user", content: "y".repeat(20_000) }], max_tokens: 8000, tools: [{ type: "web_search_20260209", name: "web_search", max_uses: 5 }] });
  const worst = worstCaseMicroUSD(huge);
  assert.ok(worst < 300_000, `worst case ${worst} µUSD should stay under $0.30`);
  assert.throws(
    () => sanitizeBody({ system: "x".repeat(60_000), messages: Array.from({ length: 10 }, (_, i) => ({ role: i % 2 ? "assistant" : "user", content: "z".repeat(15_000) })) }),
    RelayRequestError,
    `over ${MAX_TOTAL_CHARS} characters is refused`,
  );
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
      { role: "assistant", content: [{ type: "server_tool_use", id: "s1", name: "web_search", input: { query: "x" }, cache_control: { type: "ephemeral", ttl: "1h" } }] },
    ],
  });
  assert.equal(body.messages.length, 2);
  const passed = (body.messages[1].content as Array<Record<string, unknown>>)[0];
  assert.equal(passed.cache_control, undefined, "client cache_control is stripped");
  // A user turn can't carry server-tool results, and HEIC isn't an API image type.
  assert.throws(() => sanitizeBody({ messages: [{ role: "user", content: [{ type: "web_search_tool_result", tool_use_id: "s1", content: [] }] }] }), RelayRequestError);
  assert.throws(() => sanitizeBody({ messages: [{ role: "user", content: [{ type: "image", source: { type: "base64", media_type: "image/heic", data: "abc" } }] }] }), RelayRequestError);
});
