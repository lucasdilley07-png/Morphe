// Pure helpers for the Morphe AI relay — no Firebase, no network, so
// they can be unit-tested with `node --test`.

/** What the relay charges for, per million tokens, in US dollars (Claude
 *  Sonnet 5.5, Anthropic first-party rates, checked 2026-10-14). Cache
 *  writes cost 1.25× input; cache reads 0.1× input. */
export const PRICE_PER_MILLION = {
  input: 2.0,
  output: 10.0,
  cacheWrite: 2.5,
  cacheRead: 0.2,
};
/** Web search is billed per search, outside token usage ($10 per 1,000). */
export const WEB_SEARCH_MICRO_USD = 10_000;

export const MODEL = "claude-sonnet-5-5";
export const MAX_SYSTEM_CHARS = 60_000;
export const MAX_MESSAGES = 40;
export const MAX_TEXT_CHARS = 20_000;
export const MAX_IMAGE_BASE64_CHARS = 7_000_000; // ~5 MB JPEG
export const MAX_OUTPUT_TOKENS = 8_000;
/** Everything the client sends (system + every block), in characters —
 *  roughly 40k tokens, so one request costs at most ~$0.20 in input. An
 *  image counts at a flat 2,000 characters (~1,600 tokens at 1024 px). */
export const MAX_TOTAL_CHARS = 150_000;
const IMAGE_CHARS = 2_000;
const MAX_PASSTHROUGH_BLOCK_CHARS = 50_000;
export const MAX_WEB_SEARCH_USES = 5;

export interface Usage {
  input_tokens?: number | null;
  output_tokens?: number | null;
  cache_creation_input_tokens?: number | null;
  cache_read_input_tokens?: number | null;
  server_tool_use?: { web_search_requests?: number | null } | null;
}

/** Cost of one response in micro-dollars (1e-6 USD), rounded up. */
export function costMicroUSD(usage: Usage | undefined | null): number {
  if (!usage) return 0;
  const n = (v: number | null | undefined) => (typeof v === "number" && v > 0 ? v : 0);
  const dollars =
    (n(usage.input_tokens) * PRICE_PER_MILLION.input +
      n(usage.output_tokens) * PRICE_PER_MILLION.output +
      n(usage.cache_creation_input_tokens) * PRICE_PER_MILLION.cacheWrite +
      n(usage.cache_read_input_tokens) * PRICE_PER_MILLION.cacheRead) /
    1_000_000;
  return Math.ceil(dollars * 1_000_000) + n(usage.server_tool_use?.web_search_requests) * WEB_SEARCH_MICRO_USD;
}

/** The most one request can cost, reserved against the month's budget
 *  BEFORE Claude is called (input at the cache-write price, every output
 *  token, every allowed search); the real cost replaces it afterward. */
export function worstCaseMicroUSD(body: SanitizedBody): number {
  const inputTokens = Math.ceil(body.totalChars / 3);
  const dollars =
    (inputTokens * PRICE_PER_MILLION.cacheWrite + body.maxTokens * PRICE_PER_MILLION.output) / 1_000_000;
  return Math.ceil(dollars * 1_000_000) + (body.webSearchUses ?? 0) * WEB_SEARCH_MICRO_USD;
}

/** "2026-10-14" in UTC — the relay's day for the per-user limit. */
export function dayKey(date: Date = new Date()): string {
  return date.toISOString().slice(0, 10);
}

/** "2026-10" in UTC — the relay's month for the budget. */
export function monthKey(date: Date = new Date()): string {
  return date.toISOString().slice(0, 7);
}

/** The age stored in the user's backed-up profile (LocalProfileSnapshot
 *  JSON under users/{uid}/state/profile). 0 when unknown. */
export function ageFromProfileJSON(json: unknown): number {
  if (typeof json !== "string" || json.length === 0) return 0;
  try {
    const parsed = JSON.parse(json);
    const age = parsed?.age;
    return typeof age === "number" && Number.isFinite(age) ? Math.floor(age) : 0;
  } catch {
    return 0;
  }
}

export class RelayRequestError extends Error {
  constructor(public status: number, public type: string, message: string) {
    super(message);
  }
}

type Block = Record<string, unknown>;

const ALLOWED_BLOCK_TYPES = new Set([
  "text",
  "image",
  "server_tool_use",
  "web_search_tool_result",
  "thinking",
  "redacted_thinking",
]);

function sanitizeBlock(block: unknown, index: number, role: "user" | "assistant"): Block {
  if (!block || typeof block !== "object") {
    throw new RelayRequestError(400, "bad_request", `content[${index}] must be an object`);
  }
  const b = block as Block;
  const type = b.type;
  if (typeof type !== "string" || !ALLOWED_BLOCK_TYPES.has(type)) {
    throw new RelayRequestError(400, "bad_request", `content[${index}] has an unsupported type`);
  }
  if (type === "text") {
    const text = b.text;
    if (typeof text !== "string" || text.length > MAX_TEXT_CHARS) {
      throw new RelayRequestError(400, "bad_request", `content[${index}] text is missing or too long`);
    }
    return { type, text };
  }
  if (type === "image") {
    const source = b.source as Block | undefined;
    const data = source?.data;
    const media = source?.media_type;
    if (
      !source ||
      source.type !== "base64" ||
      typeof data !== "string" ||
      data.length > MAX_IMAGE_BASE64_CHARS ||
      typeof media !== "string" ||
      !["image/jpeg", "image/png", "image/gif", "image/webp"].includes(media)
    ) {
      throw new RelayRequestError(400, "bad_request", `content[${index}] image must be a base64 JPEG/PNG/GIF/WebP under 5 MB`);
    }
    return { type, source: { type: "base64", media_type: media, data } };
  }
  // Server-tool continuation blocks (pause_turn) and thinking blocks are
  // echoed back as Anthropic produced them — assistant turns only, bounded,
  // and rebuilt from known keys so nothing like cache_control rides along.
  if (role !== "assistant") {
    throw new RelayRequestError(400, "bad_request", `content[${index}] of type ${type} belongs to an assistant turn`);
  }
  if (JSON.stringify(b).length > MAX_PASSTHROUGH_BLOCK_CHARS) {
    throw new RelayRequestError(400, "bad_request", `content[${index}] is too large`);
  }
  const keys: Record<string, string[]> = {
    server_tool_use: ["type", "id", "name", "input"],
    web_search_tool_result: ["type", "tool_use_id", "content"],
    thinking: ["type", "thinking", "signature"],
    redacted_thinking: ["type", "data"],
  };
  const clean: Block = {};
  for (const key of keys[type] ?? ["type"]) {
    if (key in b) clean[key] = b[key];
  }
  return clean;
}

function blockChars(block: Block): number {
  if (block.type === "image") return IMAGE_CHARS;
  if (block.type === "text") return (block.text as string).length;
  return JSON.stringify(block).length;
}

export interface SanitizedBody {
  /** System + every message, in characters (images at a flat rate). */
  totalChars: number;
  /** One to three text blocks; the relay caches the first one. */
  system: Array<{ type: "text"; text: string }>;
  messages: Array<{ role: "user" | "assistant"; content: string | Block[] }>;
  maxTokens: number;
  stream: boolean;
  effort: "low" | "medium";
  webSearchUses: number | null;
  /** A JSON schema for structured output, when the client sent one. */
  format: { type: "json_schema"; schema: Record<string, unknown> } | null;
}

/** Keeps only what the relay forwards, bounded. The model, pricing, caching
 *  and fallbacks are the relay's decisions, never the client's. */
export function sanitizeBody(raw: unknown): SanitizedBody {
  if (!raw || typeof raw !== "object") {
    throw new RelayRequestError(400, "bad_request", "body must be a JSON object");
  }
  const body = raw as Record<string, unknown>;

  // The system prompt arrives as a string or as up to three text blocks
  // (stable prefix first). Only the text survives: the relay sets the
  // cache breakpoint itself, never the client.
  const rawSystem = body.system;
  let system: Array<{ type: "text"; text: string }> = [];
  if (typeof rawSystem === "string") {
    if (rawSystem.length > 0) system = [{ type: "text", text: rawSystem }];
  } else if (Array.isArray(rawSystem)) {
    if (rawSystem.length > 3) throw new RelayRequestError(400, "bad_request", "too many system blocks");
    system = rawSystem.map((b, i) => {
      const text = (b as Record<string, unknown> | null)?.text;
      if ((b as Record<string, unknown> | null)?.type !== "text" || typeof text !== "string") {
        throw new RelayRequestError(400, "bad_request", `system[${i}] must be a text block`);
      }
      return { type: "text" as const, text };
    });
  } else if (rawSystem !== undefined) {
    throw new RelayRequestError(400, "bad_request", "system must be a string or an array of text blocks");
  }
  const systemChars = system.reduce((sum, b) => sum + b.text.length, 0);
  if (systemChars > MAX_SYSTEM_CHARS) {
    throw new RelayRequestError(400, "bad_request", "system prompt too long");
  }

  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    throw new RelayRequestError(400, "bad_request", "messages must be a non-empty array");
  }
  if (body.messages.length > MAX_MESSAGES) {
    throw new RelayRequestError(400, "bad_request", "too many messages");
  }
  const messages = body.messages.map((m, i): SanitizedBody["messages"][number] => {
    const msg = (m ?? {}) as Record<string, unknown>;
    const role = msg.role;
    if (role !== "user" && role !== "assistant") {
      throw new RelayRequestError(400, "bad_request", `messages[${i}].role must be user or assistant`);
    }
    const content = msg.content;
    if (typeof content === "string") {
      if (content.length > MAX_TEXT_CHARS) {
        throw new RelayRequestError(400, "bad_request", `messages[${i}] is too long`);
      }
      return { role, content };
    }
    if (Array.isArray(content)) {
      if (content.length > 40) {
        throw new RelayRequestError(400, "bad_request", `messages[${i}] has too many blocks`);
      }
      return { role, content: content.map((block, j) => sanitizeBlock(block, j, role)) };
    }
    throw new RelayRequestError(400, "bad_request", `messages[${i}].content must be a string or an array`);
  });
  if (messages[0].role !== "user") {
    throw new RelayRequestError(400, "bad_request", "the first message must be from the user");
  }
  let totalChars = systemChars;
  for (const m of messages) {
    totalChars += typeof m.content === "string" ? m.content.length : m.content.reduce((sum, b) => sum + blockChars(b), 0);
  }
  if (totalChars > MAX_TOTAL_CHARS) {
    throw new RelayRequestError(400, "bad_request", "this conversation is too long for Morphe AI online — start a new chat");
  }

  const requested = typeof body.max_tokens === "number" ? body.max_tokens : 4000;
  const maxTokens = Math.max(256, Math.min(MAX_OUTPUT_TOKENS, Math.floor(requested)));

  const config = (body.output_config ?? {}) as Record<string, unknown>;
  const effort = config.effort === "medium" ? "medium" : "low";
  // Structured outputs (GA): the schema itself is forwarded, bounded.
  let format: SanitizedBody["format"] = null;
  const rawFormat = config.format as Record<string, unknown> | undefined;
  if (rawFormat) {
    const schema = rawFormat.schema;
    if (rawFormat.type !== "json_schema" || !schema || typeof schema !== "object" || JSON.stringify(schema).length > 12_000) {
      throw new RelayRequestError(400, "bad_request", "output_config.format must be a json_schema under 12k characters");
    }
    format = { type: "json_schema", schema: schema as Record<string, unknown> };
  }

  let webSearchUses: number | null = null;
  if (Array.isArray(body.tools)) {
    for (const tool of body.tools) {
      const t = (tool ?? {}) as Record<string, unknown>;
      if (t.name === "web_search" && typeof t.type === "string" && t.type.startsWith("web_search")) {
        const uses = typeof t.max_uses === "number" ? t.max_uses : MAX_WEB_SEARCH_USES;
        webSearchUses = Math.max(1, Math.min(MAX_WEB_SEARCH_USES, Math.floor(uses)));
      } else {
        throw new RelayRequestError(400, "bad_request", "only the web_search tool is available through Morphe AI online");
      }
    }
  }

  return { totalChars, system, messages, maxTokens, stream: body.stream === true, effort, webSearchUses, format };
}
