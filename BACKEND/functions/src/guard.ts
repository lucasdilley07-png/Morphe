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

export const MODEL = "claude-sonnet-5-5";
export const MAX_SYSTEM_CHARS = 60_000;
export const MAX_MESSAGES = 40;
export const MAX_TEXT_CHARS = 20_000;
export const MAX_IMAGE_BASE64_CHARS = 7_000_000; // ~5 MB JPEG
export const MAX_OUTPUT_TOKENS = 8_000;
export const MAX_WEB_SEARCH_USES = 5;

export interface Usage {
  input_tokens?: number | null;
  output_tokens?: number | null;
  cache_creation_input_tokens?: number | null;
  cache_read_input_tokens?: number | null;
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
  return Math.ceil(dollars * 1_000_000);
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

function sanitizeBlock(block: unknown, index: number): Block {
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
      !["image/jpeg", "image/png", "image/webp", "image/heic"].includes(media)
    ) {
      throw new RelayRequestError(400, "bad_request", `content[${index}] image must be a base64 JPEG/PNG/WebP under 5 MB`);
    }
    return { type, source: { type: "base64", media_type: media, data } };
  }
  // Server-tool continuation blocks (pause_turn) and thinking blocks are
  // echoed back exactly as Anthropic produced them.
  return b;
}

export interface SanitizedBody {
  system: string;
  messages: Array<{ role: "user" | "assistant"; content: string | Block[] }>;
  maxTokens: number;
  stream: boolean;
  effort: "low" | "medium";
  webSearchUses: number | null;
}

/** Keeps only what the relay forwards, bounded. The model, pricing, caching
 *  and fallbacks are the relay's decisions, never the client's. */
export function sanitizeBody(raw: unknown): SanitizedBody {
  if (!raw || typeof raw !== "object") {
    throw new RelayRequestError(400, "bad_request", "body must be a JSON object");
  }
  const body = raw as Record<string, unknown>;

  const system = typeof body.system === "string" ? body.system : "";
  if (system.length > MAX_SYSTEM_CHARS) {
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
      return { role, content: content.map(sanitizeBlock) };
    }
    throw new RelayRequestError(400, "bad_request", `messages[${i}].content must be a string or an array`);
  });
  if (messages[0].role !== "user") {
    throw new RelayRequestError(400, "bad_request", "the first message must be from the user");
  }

  const requested = typeof body.max_tokens === "number" ? body.max_tokens : 4000;
  const maxTokens = Math.max(256, Math.min(MAX_OUTPUT_TOKENS, Math.floor(requested)));

  const config = (body.output_config ?? {}) as Record<string, unknown>;
  const effort = config.effort === "medium" ? "medium" : "low";

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

  return { system, messages, maxTokens, stream: body.stream === true, effort, webSearchUses };
}
