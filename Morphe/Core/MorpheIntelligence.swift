import Foundation
import UIKit
import Security

// MARK: - Morphe Intelligence (rebuild wave, Lucas 2026-08-27)
//
// The optional Claude-powered brain behind chat and voice. The rules
// doors stay primary — instant, offline, free — and this layer answers
// ONLY when no door matched AND the user has a way to reach Claude:
// either Morphe AI online (Lucas 2026-10-14: Morphe's own relay, signed-in
// members 18 and older, a daily allowance, on Morphe's key) or their own
// Anthropic API key pasted in Settings. Neither, no network call, no
// behavior change: the built-in replies keep running exactly as before.
//
// Swift has no official Anthropic SDK, so this is the raw Messages API
// over URLSession. The relay speaks the same API (same body, same
// streaming events) behind a Firebase ID token, so one request builder
// serves both; the relay picks the model (Claude Sonnet 5.5) and a
// personal key runs claude-opus-5-5. Effort low so spoken answers come
// back fast. A safety refusal (stop_reason "refusal") is surfaced
// honestly, never papered over.

enum MorpheIntelligence {

    // MARK: Key storage (Keychain — an API key never sits in UserDefaults)

    private static let service = "com.morpheapp.Morphe"
    private static let account = "anthropic-api-key"
    /// In-memory cache so `isEnabled` checks don't hit the Keychain on
    /// every voice command. `loadKey()` fills it once per launch.
    private static var cachedKey: String??

    static var apiKey: String? {
        if let cached = cachedKey { return cached }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        let key = (status == errSecSuccess)
            ? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
            : nil
        // Only cache the negative on a definitive miss (audit 17, P3):
        // a transient Keychain error must not read as "no key" all launch.
        if status == errSecSuccess || status == errSecItemNotFound {
            cachedKey = .some(key)
        }
        return key
    }

    // MARK: Morphe AI online (the relay)

    /// Which door a request goes through. A personal key always wins:
    /// it bills the user, not Morphe, and runs the bigger model.
    enum Credential: Equatable {
        case personalKey(String)
        /// The account's ID token, plus the App Check token when the app can
        /// mint one (the relay requires it once App Check is enforced).
        case relay(token: String, appCheck: String?)
    }

    /// The relay (BACKEND/functions). Same body as the Messages API,
    /// `Authorization: Bearer <Firebase ID token>` instead of a key.
    static let relayURL = URL(string: "https://us-central1-morphe-3c5c2.cloudfunctions.net/morpheAI")!

    /// Set by the store: a fresh Firebase ID token for the signed-in
    /// account, nil when signed out or unreachable.
    @MainActor static var relayTokenProvider: (() async -> String?)?
    /// Set by the app at launch (after Firebase is configured): an App
    /// Check token, nil when none can be minted. Tests leave it nil.
    @MainActor static var appCheckTokenProvider: (() async -> String?)?
    /// Set by the store: the member turned Morphe AI online on, is signed
    /// in, and is 18 or older. Checked on every request, never cached.
    /// MainActor-typed (audit 2026-10-14, P0): the store state it reads
    /// lives on the main actor — asserting that from a pool thread trapped.
    @MainActor static var relayEligibility: (@MainActor () -> Bool)?

    @MainActor static var relayAllowed: Bool { relayEligibility?() ?? false }

    /// True when Claude can be reached one way or the other.
    @MainActor static var isEnabled: Bool { apiKey?.isEmpty == false || relayAllowed }

    /// Why `credential()` came back empty, so the line shown is the true one.
    enum NoCredential: Error { case notEligible, tokenUnavailable }

    /// The door for the next request. Throws `.tokenUnavailable` when the
    /// member is eligible but no ID token could be fetched (offline with an
    /// expired token) — that is a network problem, not a signed-out one.
    @MainActor static func credentialOrReason() async -> Result<Credential, NoCredential> {
        if let key = apiKey, !key.isEmpty { return .success(.personalKey(key)) }
        guard relayAllowed else { return .failure(.notEligible) }
        guard let token = await relayTokenProvider?(), !token.isEmpty else { return .failure(.tokenUnavailable) }
        let appCheck = await appCheckTokenProvider?()
        return .success(.relay(token: token, appCheck: appCheck))
    }

    /// The door for the next request, or nil (built-in answers only).
    @MainActor static func credential() async -> Credential? {
        try? await credentialOrReason().get()
    }

    @discardableResult
    static func setAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return false }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecSuccess { cachedKey = .some(trimmed) }
        return status == errSecSuccess
    }

    static func clearAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        cachedKey = .some(nil)
    }

    // MARK: Conversation shape

    /// The system prompt in two parts (reverse-engineering audit
    /// 2026-10-14): `stable` is identical across a member's turns and
    /// across voice and chat (identity, rules, persona, profile), so it is
    /// sent as its own block with a cache breakpoint; `live` holds what
    /// changes per turn (session state, today's numbers, the format rule).
    struct SystemPrompt: Equatable {
        var stable: String
        var live: String
        init(_ single: String) { stable = single; live = "" }
        init(stable: String, live: String) { self.stable = stable; self.live = live }
        var joined: String { live.isEmpty ? stable : stable + " " + live }
        /// Messages-API `system` blocks: the breakpoint on the stable one.
        var blocks: [[String: Any]] {
            var out: [[String: Any]] = [["type": "text", "text": stable, "cache_control": ["type": "ephemeral"]]]
            if !live.isEmpty { out.append(["type": "text", "text": live]) }
            return out
        }
    }

    struct Turn {
        let isUser: Bool
        let text: String
    }

    enum IntelligenceError: LocalizedError {
        case badKey
        case rateLimited
        case overloaded
        case network
        case declined
        case malformed
        case badRequest
        case ranLong
        // Morphe AI online (the relay's own refusals, each actionable).
        case signInNeeded
        case ageRestricted
        case dailyLimit
        case budget
        case busy

        var errorDescription: String? {
            switch self {
            case .signInNeeded: return "Sign in again to use Morphe AI online."
            case .ageRestricted: return "Morphe AI online is for members 18 and older. If you just added your age in Profile → Your Details, give it a moment and ask again."
            case .busy: return "Morphe AI is still answering your last question — one at a time."
            case .dailyLimit: return "You've used today's online answers — the built-in brain still works, and it resets at midnight UTC."
            case .budget: return "Morphe's AI budget for this month is used up — the built-in answers still work until it resets."
            case .badKey: return "That API key was rejected — check it in Profile → Morphe Intelligence."
            case .rateLimited: return "Claude is rate-limiting right now — try again in a minute."
            case .overloaded: return "Claude is overloaded right now — try again shortly."
            case .network: return "I couldn't reach Claude — check your connection."
            case .declined: return "Claude declined to answer that one."
            case .malformed: return "Claude sent something I couldn't read."
            case .badRequest: return "Something went wrong on my end — try rephrasing that."
            case .ranLong: return "That one ran long — try asking it more simply."
            }
        }
    }

    /// True for the honest failure lines the app shows in place of an
    /// answer (fix wave 2026-10-13). They stay visible in the thread but are
    /// never sent back to Claude as if Claude had said them.
    static func isFailureNote(_ text: String) -> Bool {
        let notes: [IntelligenceError] = [.badKey, .rateLimited, .overloaded, .network, .declined, .malformed, .badRequest, .ranLong,
                                          .signInNeeded, .ageRestricted, .dailyLimit, .budget, .busy]
        if notes.contains(where: { $0.errorDescription == text }) { return true }
        return text.hasPrefix("I couldn't reach Claude.") || text.hasPrefix("I hit a snag reaching Claude")
    }

    /// Error-absorbing wrapper for the store: every failure becomes an
    /// honest, speakable line instead of a thrown error.
    static func safeReply(system: SystemPrompt, turns: [Turn], credential: Credential,
                          timeout: TimeInterval = 30) async -> String {
        do {
            return try await reply(system: system, turns: turns, credential: credential, timeout: timeout)
        } catch {
            return (error as? IntelligenceError)?.errorDescription
                ?? "I hit a snag reaching Claude \u{2014} try again in a moment."
        }
    }

    // MARK: The call

    /// Streaming chat reply (luxury audit 2026-09): first tokens land in
    /// ~600ms instead of the full-generation wait. Deltas arrive on the
    /// MainActor; the final full text returns (or throws — callers wrap
    /// with the same error copy as safeReply). Voice still uses safeReply:
    /// a spoken answer needs the complete utterance anyway.
    static func streamReply(system: SystemPrompt, turns: [Turn], credential: Credential,
                            timeout: TimeInterval = 30,
                            onDelta: @MainActor @escaping (String) -> Void) async throws -> String {
        let request = try makeRequest(system: system, turns: turns, credential: credential,
                                      timeout: timeout, stream: true)
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            throw IntelligenceError.network
        }
        guard let http = response as? HTTPURLResponse else { throw IntelligenceError.network }
        // Same status taxonomy as the non-streaming path (audit 23, P1:
        // a 429 told the user to "rephrase"); the relay's own refusals
        // (age, daily allowance, budget) carry a type in the body.
        if http.statusCode != 200 {
            var body = Data()
            for try await byte in bytes { body.append(byte); if body.count > 4096 { break } }
            throw error(status: http.statusCode, body: body)
        }
        var full = ""
        var stopReason: String?
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = line.dropFirst(6)
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            // A mid-stream error event (fix wave 2026-10-13) used to read
            // as a silent stop; it throws the same honest error as HTTP.
            if json["type"] as? String == "error" {
                let kind = (json["error"] as? [String: Any])?["type"] as? String ?? ""
                switch kind {
                case "overloaded_error", "api_error": throw IntelligenceError.overloaded
                case "rate_limit_error": throw IntelligenceError.rateLimited
                case "authentication_error", "permission_error": throw IntelligenceError.badKey
                default: throw IntelligenceError.overloaded
                }
            }
            if json["type"] as? String == "content_block_delta",
               let delta = json["delta"] as? [String: Any],
               delta["type"] as? String == "text_delta",
               let text = delta["text"] as? String {
                full += text
                let snapshot = full
                await onDelta(snapshot)
            }
            // stop_reason arrives in message_delta (audit 23, P1): a
            // refusal with HTTP 200 must read as declined — including a
            // MID-stream refusal, which must not pass off a truncated
            // partial as a finished answer.
            if json["type"] as? String == "message_delta",
               let delta = json["delta"] as? [String: Any],
               let reason = delta["stop_reason"] as? String {
                stopReason = reason
            }
        }
        if stopReason == "refusal" { throw IntelligenceError.declined }
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IntelligenceError.ranLong }
        return trimmed
    }

    /// The empty POST for either door: Anthropic with the key, or the
    /// relay with the account's token. Internal so the tests can see
    /// where a request goes.
    static func baseRequest(credential: Credential, timeout: TimeInterval) -> URLRequest {
        var request: URLRequest
        switch credential {
        case .personalKey(let key):
            request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .relay(let token, let appCheck):
            request = URLRequest(url: relayURL)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let appCheck { request.setValue(appCheck, forHTTPHeaderField: "X-Firebase-AppCheck") }
        }
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        return request
    }

    /// Maps a non-200 to the honest line. The relay names its refusals
    /// (`error.type`): sign_in, age, daily_limit, budget.
    static func error(status: Int, body: Data?) -> IntelligenceError {
        let type = body
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            .flatMap { ($0["error"] as? [String: Any])?["type"] as? String }
        switch (status, type ?? "") {
        case (401, "sign_in"), (401, "app_check"): return .signInNeeded
        case (403, "age"): return .ageRestricted
        case (429, "daily_limit"): return .dailyLimit
        case (429, "budget"): return .budget
        case (429, "busy"): return .busy
        case (429, "rate_limit_error"), (503, _): return .overloaded
        case (401, _), (403, _): return .badKey
        case (429, _): return .rateLimited
        case (500..., _): return .overloaded
        default: return .badRequest
        }
    }

    /// Shared request builder for both paths.
    static func makeRequest(system: SystemPrompt, turns: [Turn], credential: Credential,
                            timeout: TimeInterval, stream: Bool) throws -> URLRequest {
        var request = baseRequest(credential: credential, timeout: timeout)
        var messages: [[String: Any]] = []
        for turn in turns.drop(while: { !$0.isUser }) {
            messages.append(["role": turn.isUser ? "user" : "assistant",
                             "content": turn.text])
        }
        guard messages.first?["role"] as? String == "user" else { throw IntelligenceError.malformed }
        // max_tokens caps thinking + visible text TOGETHER (audit 17, P1):
        // 700 let adaptive thinking eat the whole budget. The brevity
        // contract lives in the system prompt, not the token cap.
        var body: [String: Any] = [
            "max_tokens": 4000,
            "system": system.blocks,
            "output_config": ["effort": "low"],
            "messages": messages
        ]
        // The relay chooses its own model; a personal key runs Opus.
        if case .personalKey = credential { body["model"] = "claude-opus-5-5" }
        if stream { body["stream"] = true }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// One non-streaming Messages API request. Replies are deliberately
    /// short (voice-first: the system prompt caps spoken length) — the
    /// VOICE path uses this; chat streams via streamReply.
    static func reply(system: SystemPrompt, turns: [Turn], credential: Credential,
                      timeout: TimeInterval = 30) async throws -> String {
        let request = try makeRequest(system: system, turns: turns, credential: credential,
                                      timeout: timeout, stream: false)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw IntelligenceError.network
        }
        guard let http = response as? HTTPURLResponse else { throw IntelligenceError.network }
        if http.statusCode != 200 { throw error(status: http.statusCode, body: data) }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IntelligenceError.malformed
        }
        // Safety classifiers return HTTP 200 with stop_reason "refusal" —
        // check it BEFORE reading content (content can be empty).
        if json["stop_reason"] as? String == "refusal" {
            throw IntelligenceError.declined
        }
        guard let content = json["content"] as? [[String: Any]] else {
            throw IntelligenceError.malformed
        }
        let text = content
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if json["stop_reason"] as? String == "max_tokens", text.isEmpty {
            // The whole budget went to thinking — an honest "ran long"
            // beats blaming the response format (audit 17, P1).
            throw IntelligenceError.ranLong
        }
        guard !text.isEmpty else { throw IntelligenceError.malformed }
        return text
    }
}


/// Neural voice (Tier 2 of Siri-level, 2026-09-23): Morphe's spoken
/// replies rendered by ElevenLabs Flash instead of the on-device
/// synthesizer. The key lives in the Keychain exactly like the Claude
/// key; no key = the on-device voice, unchanged. HONESTY: with a key,
/// the TEXT of Morphe's answers leaves the phone to make the audio —
/// the settings copy says so. Workout data does not leave.
enum MorpheNeuralVoice {

    private static let service = "com.morpheapp.Morphe"
    private static let account = "elevenlabs-api-key"
    private static var cachedKey: String??

    static var apiKey: String? {
        if let cached = cachedKey { return cached }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        let key = (status == errSecSuccess)
            ? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
            : nil
        if status == errSecSuccess || status == errSecItemNotFound {
            cachedKey = .some(key)
        }
        return key
    }

    static var isEnabled: Bool { apiKey?.isEmpty == false }

    @discardableResult
    static func setAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return false }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecSuccess { cachedKey = .some(trimmed) }
        return status == errSecSuccess
    }

    static func clearAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        cachedKey = .some(nil)
        Task { @MainActor in resolvedVoiceCache = [:] }
    }

    // MARK: Voice resolution — name-matched, never hardcoded ids

    /// Preferred premade-voice NAMES per Morphe voice style, best first.
    /// Matched against the account's live voice list at runtime, so no
    /// voice id is baked in to rot.
    nonisolated static func preferredNames(for styleID: String) -> [String] {
        // Replacement names first (ElevenLabs retires its legacy Default
        // voices 2026-12-31; audit 24 verified the successors), legacy
        // names after for pre-2026 accounts.
        switch styleID {
        case "british-female": return ["Alicia", "Florence", "Alice", "Lily"]
        case "american": return ["Sawyer", "Caleb", "Eddie", "Wyatt", "Brian", "Chris", "Eric", "Bill"]
        case "australian": return ["Baxter", "Charlie"]
        default: return ["Finley", "Eldrin", "Daniel", "George"]
        }
    }

    /// Pure pick for tests: first preferred name present wins
    /// (case-insensitive). NO first-voice fallback (audit 24, P1): a
    /// random cloned voice from the account is worse than the honest
    /// on-device fallback.
    nonisolated static func pickVoiceID(from voices: [(id: String, name: String)],
                                        for styleID: String) -> String? {
        for wanted in preferredNames(for: styleID) {
            if let hit = voices.first(where: { $0.name.caseInsensitiveCompare(wanted) == .orderedSame }) {
                return hit.id
            }
        }
        return nil
    }

    /// nil value = resolution FAILED this session (audit 24, P1: a bad
    /// key re-ran the /v1/voices round trip before every sentence).
    /// MainActor-isolated: the dictionary was racing concurrent fetch and
    /// prefetch writes (audit 24, P1).
    @MainActor private static var resolvedVoiceCache: [String: String?] = [:]

    /// Resolves (and caches per launch, failures included) the voice id
    /// for a style.
    static func voiceID(for styleID: String, apiKey: String) async -> String? {
        if let cached = await MainActor.run(body: { resolvedVoiceCache[styleID] }) {
            return cached
        }
        let picked = await fetchVoiceID(for: styleID, apiKey: apiKey)
        await MainActor.run { resolvedVoiceCache[styleID] = .some(picked) }
        return picked
    }

    private static func fetchVoiceID(for styleID: String, apiKey: String) async -> String? {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/voices") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["voices"] as? [[String: Any]] else { return nil }
        let voices: [(id: String, name: String)] = list.compactMap { entry in
            guard let id = entry["voice_id"] as? String,
                  let name = entry["name"] as? String else { return nil }
            return (id, name)
        }
        return pickVoiceID(from: voices, for: styleID)
    }

    /// One sentence → MP3 via the Flash model (lowest latency).
    static func synthesize(_ text: String, voiceID: String, apiKey: String) async throws -> Data {
        // Compact output (audit 24, P2): spoken coaching lines don't need
        // 128kbps — 32kbps mp3 fetches faster and plays identically here.
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)?output_format=mp3_22050_32") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 6
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "model_id": "eleven_flash_v2_5",
            "voice_settings": ["stability": 0.5, "similarity_boost": 0.75]
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

// MARK: - Food check (Lucas 2026-10-10)

/// Where a checked food's facts come from, in order of honesty:
///  1. Open Food Facts — a public, volunteer-built product database read
///     by barcode (ingredients, additives, NOVA group, Nutri-Score,
///     origins, labels, nutrition per 100 g). No key, no personal data:
///     the barcode is the whole request.
///  2. Claude with the user's OWN key — reads the photo and/or the
///     database facts, searches the web for the brand's supply chain,
///     and returns a strict JSON report with the URLs it actually read.
///     The photo leaves the phone only on this path, and only when the
///     user tapped Check.
/// Everything the report says carries a confidence and a source. When a
/// fact isn't found the field says "unknown" — never a guess dressed up
/// as a finding.
enum FoodCheckService {

    struct OpenFoodFactsProduct {
        var barcode: String
        var name: String
        var brand: String
        var ingredientsText: String
        var additiveTags: [String]
        var nova: Int?
        var nutriScore: String?
        var origins: String
        var manufacturingPlaces: String
        var countries: [String]
        var labels: [String]
        var analysis: [String]
        var allergens: [String]
        var kcal100: Double?
        var protein100: Double?
        var carbs100: Double?
        var fat100: Double?
        var sugar100: Double?
        var fiber100: Double?
        var salt100: Double?
        var url: String { "https://world.openfoodfacts.org/product/\(barcode)" }
    }

    private static let fields = "product_name,brands,ingredients_text,additives_tags,nova_group,nutriscore_grade,nutriments,origins,manufacturing_places,labels_tags,countries_tags,ingredients_analysis_tags,allergens_tags"

    enum LookupResult {
        case found(OpenFoodFactsProduct)
        case notFound
        case unreachable
    }

    /// A scanned payload as a lookup code: ASCII digits only, 8–14 of
    /// them, and a zero-suppressed UPC-E expanded to the UPC-A the
    /// database keys on. QR/Code-128 payloads that aren't a bare number
    /// are refused (audit 2026-10-10: a URL with a date in it looked up a
    /// random product).
    static func lookupCode(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        let code = trimmed.count == 8 && (trimmed.first == "0" || trimmed.first == "1") ? expandUPCE(trimmed) : trimmed
        guard code.count >= 8, code.count <= 14 else { return nil }
        return code
    }

    /// UPC-E → UPC-A, the standard expansion by the sixth digit.
    static func expandUPCE(_ upce: String) -> String {
        let d = Array(upce)
        guard d.count == 8 else { return upce }
        let ns = String(d[0]); let m = d[1...6].map(String.init); let check = String(d[7])
        let body: String
        switch m[5] {
        case "0", "1", "2": body = m[0] + m[1] + m[5] + "0000" + m[2] + m[3] + m[4]
        case "3": body = m[0] + m[1] + m[2] + "00000" + m[3] + m[4]
        case "4": body = m[0] + m[1] + m[2] + m[3] + "00000" + m[4]
        default: body = m[0] + m[1] + m[2] + m[3] + m[4] + "0000" + m[5]
        }
        return ns + body + check
    }

    static func lookup(barcode raw: String) async -> LookupResult {
        guard let code = lookupCode(from: raw),
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=\(fields)")
        else { return .notFound }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Morphe iOS (https://lucasdilley07-png.github.io/Morphe/)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return .unreachable }
        if http.statusCode == 404 { return .notFound }
        guard http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .unreachable }
        let status = (json["status"] as? Int) ?? Int((json["status"] as? String) ?? "") ?? 0
        guard status == 1, let product = json["product"] as? [String: Any] else { return .notFound }
        return .found(parse(product, code: code))
    }

    private static func parse(_ product: [String: Any], code: String) -> OpenFoodFactsProduct {
        let nutriments = product["nutriments"] as? [String: Any] ?? [:]
        func number(_ key: String) -> Double? {
            if let d = nutriments[key] as? Double { return d }
            if let i = nutriments[key] as? Int { return Double(i) }
            if let s = nutriments[key] as? String { return Double(s) }
            return nil
        }
        func tags(_ key: String) -> [String] {
            (product[key] as? [String] ?? []).map { $0.replacingOccurrences(of: "en:", with: "") }
        }
        let novaValue: Int? = (product["nova_group"] as? Int) ?? Int((product["nova_group"] as? String) ?? "")
        return OpenFoodFactsProduct(
            barcode: code,
            name: (product["product_name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            brand: (product["brands"] as? String ?? "").components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "",
            ingredientsText: (product["ingredients_text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            additiveTags: tags("additives_tags"),
            nova: novaValue,
            nutriScore: (product["nutriscore_grade"] as? String).flatMap { ["a", "b", "c", "d", "e"].contains($0) ? $0.uppercased() : nil },
            origins: product["origins"] as? String ?? "",
            manufacturingPlaces: product["manufacturing_places"] as? String ?? "",
            countries: tags("countries_tags"),
            labels: tags("labels_tags"),
            analysis: tags("ingredients_analysis_tags"),
            allergens: tags("allergens_tags"),
            kcal100: number("energy-kcal_100g"),
            protein100: number("proteins_100g"),
            carbs100: number("carbohydrates_100g"),
            fat100: number("fat_100g"),
            sugar100: number("sugars_100g"),
            fiber100: number("fiber_100g"),
            salt100: number("salt_100g"))
    }

    // MARK: Deterministic report from the database alone

    /// Pure culinary ingredients — a one-ingredient jar of these is NOVA
    /// group 2, not "real food".
    private static let culinaryWords = ["sugar", "oil", "salt", "syrup", "flour", "starch", "honey", "butter", "lard", "vinegar", "cream", "molasses"]

    /// Processing when the database has no NOVA group: only what the
    /// ingredient list can honestly support.
    static func inferProcessing(ingredients: String, additives: Int) -> (FoodProcessingClass, String) {
        let markers = ultraProcessingMarkers(in: ingredients)
        if !markers.isEmpty {
            return (.ultraProcessed, "No NOVA group on file; the ingredient list carries ultra-processing markers: \(markers.joined(separator: ", ")).")
        }
        if additives > 0 {
            return (.processed, "No NOVA group on file; \(additives) additive\(additives == 1 ? "" : "s") listed.")
        }
        let parts = ingredients.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: ",;.")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if parts.isEmpty { return (.unknown, "No NOVA group and no ingredient list on file.") }
        if parts.count == 1 {
            if culinaryWords.contains(where: { parts[0].contains($0) }) {
                return (.kitchenIngredient, "One ingredient, and it's a cooking ingredient (NOVA group 2).")
            }
            return (.wholeFood, "One ingredient, no additives.")
        }
        return (.unknown, "No NOVA group on file and \(parts.count) ingredients — not enough to classify without guessing.")
    }

    static func record(from p: OpenFoodFactsProduct, usedPhoto: Bool = false) -> FoodCheckRecord {
        var r = FoodCheckRecord()
        r.method = usedPhoto ? .photoAndBarcode : .barcode
        r.usedPhoto = usedPhoto
        r.name = p.name.isEmpty ? "Product \(p.barcode)" : p.name
        r.brand = p.brand
        r.barcode = p.barcode
        r.ingredients = p.ingredientsText
        r.additives = p.additiveTags.map { additive(forTag: $0) }
        r.nutriScore = p.nutriScore

        // Processing: the database's NOVA group when it has one, else only
        // what the ingredient list can honestly support.
        if let nova = p.nova {
            r.processing = FoodProcessingClass(nova: nova)
            r.processingReason = "NOVA group \(nova), from Open Food Facts."
        } else {
            (r.processing, r.processingReason) = inferProcessing(ingredients: p.ingredientsText, additives: r.additives.count)
        }

        // Origin: the label's own words, else only where it's sold.
        let originBits = [p.origins, p.manufacturingPlaces].filter { !$0.isEmpty }
        if !originBits.isEmpty {
            r.origin = originBits.joined(separator: " · ")
            r.originConfidence = .high
        } else if !p.countries.isEmpty {
            r.origin = "Not stated on the label. Sold in \(p.countries.map(pretty).prefix(3).joined(separator: ", "))."
            r.originConfidence = .low
        } else {
            r.origin = "Not on file."
            r.originConfidence = .unknown
        }

        // Health: Nutri-Score plus the per-100 g thresholds (UK FSA:
        // sugar >22.5 g, fat >17.5 g, salt >1.5 g per 100 g is "high").
        var flags: [String] = []
        if let s = p.sugar100, s > 22.5 { flags.append("high sugar (\(Int(s.rounded())) g/100 g)") }
        if let f = p.fat100, f > 17.5 { flags.append("high fat (\(Int(f.rounded())) g/100 g)") }
        if let salt = p.salt100, salt > 1.5 { flags.append("high salt (\(salt.formatted(.number.precision(.fractionLength(1)))) g/100 g)") }
        var good: [String] = []
        if let pr = p.protein100, pr >= 12 { good.append("protein-dense (\(Int(pr.rounded())) g/100 g)") }
        if let fb = p.fiber100, fb >= 6 { good.append("high fibre (\(Int(fb.rounded())) g/100 g)") }
        var health = p.nutriScore.map { "Nutri-Score \($0)." } ?? "No Nutri-Score on file."
        if !flags.isEmpty { health += " " + flags.joined(separator: ", ").prefix(1).uppercased() + flags.joined(separator: ", ").dropFirst() + "." }
        if !good.isEmpty { health += " " + good.joined(separator: ", ").prefix(1).uppercased() + good.joined(separator: ", ").dropFirst() + "." }
        if !p.allergens.isEmpty { health += " Allergens: \(p.allergens.map(pretty).joined(separator: ", "))." }
        r.healthRead = health

        // GMO: a label settles it; otherwise the crop logic, stated as such.
        let labels = p.labels.joined(separator: " ")
        if labels.contains("organic") || labels.contains("non-gmo") || labels.contains("no-gmo") {
            r.gmoLikelihood = .low
            r.gmoRead = "Labelled \(labels.contains("organic") ? "organic" : "non-GMO") — GM ingredients are not permitted under that label."
        } else {
            let crops = gmCrops(in: p.ingredientsText)
            let northAmerica = p.countries.contains { $0.contains("united-states") || $0.contains("canada") }
            if !crops.isEmpty && northAmerica {
                r.gmoLikelihood = .high
                r.gmoRead = "Contains \(crops.joined(separator: ", ")) and is sold in North America, where most of those crops are genetically modified unless labelled organic or Non-GMO Project. Not confirmed for this product."
            } else if !crops.isEmpty {
                r.gmoLikelihood = .medium
                r.gmoRead = "Contains \(crops.joined(separator: ", ")) — crops that are often GM depending on the country of origin. No label either way."
            } else {
                r.gmoLikelihood = .unknown
                r.gmoRead = p.ingredientsText.isEmpty ? "No ingredient list on file." : "No common GM crops in the ingredient list and no label either way."
            }
        }

        r.calories = p.kcal100.map { Int($0.rounded()) }
        r.protein = p.protein100.map { Int($0.rounded()) }
        r.carbs = p.carbs100.map { Int($0.rounded()) }
        r.fat = p.fat100.map { Int($0.rounded()) }
        r.sugar = p.sugar100.map { Int($0.rounded()) }
        r.fiber = p.fiber100.map { Int($0.rounded()) }
        r.sodiumMg = p.salt100.map { Int(($0 * 400).rounded()) }
        r.servingNote = "Per 100 g, from the label as recorded on Open Food Facts."
        r.sources = [FoodSourceLink(title: "Open Food Facts — \(r.name)", url: p.url)]
        r.verdict = "\(r.processing.title)." + (p.nutriScore.map { " Nutri-Score \($0)." } ?? "") + (flags.isEmpty ? "" : " " + flags.joined(separator: ", ").prefix(1).uppercased() + flags.joined(separator: ", ").dropFirst() + ".")
        return r
    }

    private static func pretty(_ tag: String) -> String {
        tag.replacingOccurrences(of: "-", with: " ").capitalized
    }

    private static let ultraMarkers = ["high fructose", "corn syrup", "glucose syrup", "glucose-fructose", "hydrogenated", "interesterified",
                                       "maltodextrin", "dextrose", "invert sugar", "flavouring", "flavoring", "natural flavour", "natural flavor",
                                       "artificial flavour", "artificial flavor", "emulsifier", "stabiliser", "stabilizer", "thickener",
                                       "colour", "color (", "protein isolate", "isolate", "hydrolysed", "hydrolyzed", "sweetener",
                                       "aspartame", "sucralose", "acesulfame", "carrageenan", "modified starch", "monosodium glutamate", "msg"]

    static func ultraProcessingMarkers(in ingredients: String) -> [String] {
        let lower = ingredients.lowercased()
        return ultraMarkers.filter { lower.contains($0) }.map { $0.replacingOccurrences(of: " (", with: "") }
    }

    private static let gmCropWords: [(word: String, crop: String)] = [
        ("corn", "corn"), ("maize", "corn"), ("soy", "soy"), ("soja", "soy"), ("canola", "canola"), ("rapeseed", "canola"),
        ("sugar beet", "sugar beet"), ("beet sugar", "sugar beet"), ("cottonseed", "cottonseed"), ("papaya", "papaya")
    ]

    static func gmCrops(in ingredients: String) -> [String] {
        // "May contain traces of soy" is an allergen note, not an
        // ingredient (audit 2026-10-10) — stop reading there.
        var lower = ingredients.lowercased()
        for stop in ["may contain", "traces of", "produced in a facility"] {
            if let range = lower.range(of: stop) { lower = String(lower[..<range.lowerBound]) }
        }
        var found: [String] = []
        for pair in gmCropWords where lower.contains(pair.word) && !found.contains(pair.crop) { found.append(pair.crop) }
        return found
    }

    // MARK: Additives — the common E-numbers in plain words

    private static let additiveTable: [String: (name: String, note: String, concern: FoodAdditiveConcern)] = [
        "e100": ("Curcumin", "Turmeric colour.", .none), "e101": ("Riboflavin", "Vitamin B2 as colour.", .none),
        "e102": ("Tartrazine", "Synthetic yellow; carries an EU hyperactivity warning for children.", .moderate),
        "e104": ("Quinoline yellow", "Synthetic yellow; EU hyperactivity warning.", .moderate),
        "e110": ("Sunset yellow", "Synthetic orange; EU hyperactivity warning.", .moderate),
        "e120": ("Cochineal", "Red from insects; rare allergen.", .low),
        "e122": ("Carmoisine", "Synthetic red; EU hyperactivity warning.", .moderate),
        "e124": ("Ponceau 4R", "Synthetic red; EU hyperactivity warning.", .moderate),
        "e129": ("Allura red", "Synthetic red; EU hyperactivity warning.", .moderate),
        "e133": ("Brilliant blue", "Synthetic blue.", .low), "e150a": ("Plain caramel", "Burnt-sugar colour.", .none),
        "e150c": ("Ammonia caramel", "Caramel colour; can carry 4-MEI.", .moderate), "e150d": ("Sulphite ammonia caramel", "Cola colour; can carry 4-MEI.", .moderate),
        "e160a": ("Carotenes", "Carrot-type colour.", .none), "e160c": ("Paprika extract", "Colour.", .none), "e162": ("Beet red", "Colour.", .none),
        "e171": ("Titanium dioxide", "Whitener; banned as a food additive in the EU since 2022.", .high),
        "e200": ("Sorbic acid", "Preservative.", .low), "e202": ("Potassium sorbate", "Preservative.", .low),
        "e211": ("Sodium benzoate", "Preservative; forms traces of benzene with vitamin C.", .moderate),
        "e220": ("Sulphur dioxide", "Preservative; sulphite allergen.", .moderate), "e223": ("Sodium metabisulphite", "Sulphite preservative.", .moderate),
        "e224": ("Potassium metabisulphite", "Sulphite preservative.", .moderate),
        "e250": ("Sodium nitrite", "Cured-meat preservative; forms nitrosamines when cooked hot.", .high),
        "e251": ("Sodium nitrate", "Cured-meat preservative.", .high), "e252": ("Potassium nitrate", "Cured-meat preservative.", .high),
        "e260": ("Acetic acid", "Vinegar.", .none), "e270": ("Lactic acid", "Acidity regulator.", .none), "e296": ("Malic acid", "Fruit acid.", .none),
        "e300": ("Ascorbic acid", "Vitamin C.", .none), "e306": ("Tocopherols", "Vitamin E.", .none), "e322": ("Lecithins", "Emulsifier from soy or sunflower.", .none),
        "e325": ("Sodium lactate", "Acidity regulator.", .none), "e330": ("Citric acid", "Acidity regulator.", .none), "e331": ("Sodium citrates", "Acidity regulator.", .none),
        "e338": ("Phosphoric acid", "Cola acid; a phosphate.", .moderate), "e339": ("Sodium phosphates", "Phosphate.", .moderate), "e340": ("Potassium phosphates", "Phosphate.", .moderate),
        "e341": ("Calcium phosphates", "Phosphate.", .moderate), "e407": ("Carrageenan", "Seaweed thickener; gut-irritation debate.", .moderate),
        "e410": ("Locust bean gum", "Thickener.", .none), "e412": ("Guar gum", "Thickener.", .none), "e414": ("Gum arabic", "Thickener.", .none),
        "e415": ("Xanthan gum", "Thickener.", .none), "e420": ("Sorbitol", "Sugar alcohol; laxative in quantity.", .low), "e421": ("Mannitol", "Sugar alcohol.", .low),
        "e422": ("Glycerol", "Humectant.", .none), "e440": ("Pectin", "Fruit thickener.", .none),
        "e450": ("Diphosphates", "Phosphate.", .moderate), "e451": ("Triphosphates", "Phosphate.", .moderate), "e452": ("Polyphosphates", "Phosphate.", .moderate),
        "e460": ("Cellulose", "Bulking agent.", .low), "e461": ("Methyl cellulose", "Thickener.", .low), "e464": ("Hypromellose", "Thickener.", .low), "e466": ("CMC", "Thickener.", .low),
        "e471": ("Mono- and diglycerides", "Emulsifier from fats.", .low), "e472e": ("DATEM", "Bread emulsifier.", .low), "e473": ("Sucrose esters", "Emulsifier.", .low),
        "e481": ("Sodium stearoyl lactylate", "Emulsifier.", .low), "e500": ("Sodium bicarbonate", "Baking soda.", .none), "e501": ("Potassium carbonates", "Raising agent.", .none),
        "e503": ("Ammonium carbonates", "Raising agent.", .none), "e508": ("Potassium chloride", "Salt substitute.", .none), "e509": ("Calcium chloride", "Firming agent.", .none),
        "e551": ("Silicon dioxide", "Anti-caking.", .low), "e570": ("Fatty acids", "Anti-caking.", .none), "e621": ("Monosodium glutamate", "Flavour enhancer.", .low),
        "e627": ("Disodium guanylate", "Flavour enhancer.", .low), "e631": ("Disodium inosinate", "Flavour enhancer.", .low), "e635": ("Ribonucleotides", "Flavour enhancer.", .low),
        "e900": ("Dimethylpolysiloxane", "Anti-foam.", .low), "e950": ("Acesulfame K", "Artificial sweetener.", .moderate), "e951": ("Aspartame", "Artificial sweetener.", .moderate),
        "e952": ("Cyclamate", "Artificial sweetener; not permitted in the US.", .moderate), "e954": ("Saccharin", "Artificial sweetener.", .moderate),
        "e955": ("Sucralose", "Artificial sweetener.", .moderate), "e960": ("Steviol glycosides", "Stevia sweetener.", .none), "e965": ("Maltitol", "Sugar alcohol.", .low),
        "e967": ("Xylitol", "Sugar alcohol; toxic to dogs.", .low), "e968": ("Erythritol", "Sugar alcohol.", .low), "e1400": ("Dextrin", "Modified starch.", .low),
        "e1404": ("Oxidised starch", "Modified starch.", .low), "e1412": ("Distarch phosphate", "Modified starch.", .low), "e1414": ("Acetylated distarch phosphate", "Modified starch.", .low),
        "e1422": ("Acetylated distarch adipate", "Modified starch.", .low), "e1442": ("Hydroxypropyl distarch phosphate", "Modified starch.", .low), "e1510": ("Ethanol", "Carrier.", .none)
    ]

    /// "e322i", "e500ii", "e160ai" are the database's sub-variants of
    /// E322, E500, E160a — same substance family, same note.
    static func additiveTableKey(_ code: String) -> String {
        let key = code.lowercased().replacingOccurrences(of: "en:", with: "").replacingOccurrences(of: " ", with: "")
        if additiveTable[key] != nil { return key }
        for suffix in ["iv", "iii", "ii", "i"] where key.hasSuffix(suffix) {
            let base = String(key.dropLast(suffix.count))
            if additiveTable[base] != nil { return base }
        }
        return key
    }

    static func additive(forTag tag: String) -> FoodAdditive {
        let code = tag.lowercased().replacingOccurrences(of: "en:", with: "")
        if let hit = additiveTable[additiveTableKey(code)] {
            return FoodAdditive(code: code.uppercased(), name: hit.name, note: hit.note, concern: hit.concern)
        }
        // A code we don't carry a note for — say so, never guess.
        return FoodAdditive(code: code.uppercased(), name: "Additive \(code.uppercased())", note: "Not in Morphe's table — look it up before trusting it.", concern: .unknown)
    }

    // MARK: Claude: photo + facts + the web, as strict JSON

    static func jpeg(from image: UIImage, maxSide: CGFloat = 1024) -> Data? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        // Scale 1 (reverse-engineering audit 2026-10-14): the default
        // renderer used the 3× screen scale, so a "1024 px" photo left the
        // phone at ~3072 px and cost three times the vision tokens.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.72)
    }

    private static let reportSystem = """
    You are Morphe's food checker: disciplined, direct, honest to the last digit. You read a photo of a food, meal or package and/or product facts from Open Food Facts, you search the web for the brand's production and supply chain, and you report. Rules: never invent a fact; when something is not found, write "unknown" and say why; cite only pages you actually read; nutrition for a plate is an estimate and must say so; say "likely" and "possible" only with the reason; no medical claims; plain words, no hype. GMO: a GM ingredient is likely only when a GM crop (corn, soy, canola, sugar beet, cottonseed, papaya) is present AND the product is sold where that crop is mostly GM and no organic/non-GMO label exists. Processing uses the NOVA groups: 1 whole or minimally processed, 2 kitchen ingredient, 3 processed, 4 ultra-processed.
    Reply with ONE JSON object and nothing else, no code fences:
    {"name":"","brand":"","processing":"wholeFood|kitchenIngredient|processed|ultraProcessed|unknown","processingReason":"","origin":"where it comes from: country/region, grower or factory if known, how it reached the shelf","originConfidence":"high|medium|low|unknown","healthRead":"2-4 sentences on how healthy it is and why","nutriScore":"A-E or null","additives":[{"code":"E322 or name","name":"","note":"","concern":"none|low|moderate|high|unknown"}],"gmoRead":"","gmoLikelihood":"high|medium|low|unknown","ingredients":"as read, or unknown","calories":null,"protein":null,"carbs":null,"fat":null,"sugar":null,"fiber":null,"sodiumMg":null,"servingNote":"what the numbers are for and whether estimated","sources":[{"title":"","url":""}],"verdict":"one laconic line"}
    Numbers are integers; use null for any you cannot support.
    """

    static func analyze(imageJPEG: Data?, product: OpenFoodFactsProduct?, barcode: String? = nil,
                        credential: MorpheIntelligence.Credential) async throws -> FoodCheckRecord {
        var content: [[String: Any]] = []
        if let imageJPEG {
            content.append(["type": "image", "source": ["type": "base64", "media_type": "image/jpeg",
                                                         "data": imageJPEG.base64EncodedString()]])
        }
        var ask = "Check this food. "
        if let p = product {
            let facts: [String: Any] = [
                "barcode": p.barcode, "name": p.name, "brand": p.brand, "ingredients": p.ingredientsText,
                "additives": p.additiveTags, "nova": p.nova as Any, "nutriScore": p.nutriScore as Any,
                "origins": p.origins, "manufacturingPlaces": p.manufacturingPlaces, "countriesSold": p.countries,
                "labels": p.labels, "allergens": p.allergens,
                "per100g": ["kcal": p.kcal100 as Any, "protein": p.protein100 as Any, "carbs": p.carbs100 as Any,
                            "fat": p.fat100 as Any, "sugar": p.sugar100 as Any, "fiber": p.fiber100 as Any, "salt": p.salt100 as Any],
                "source": p.url
            ]
            if let data = try? JSONSerialization.data(withJSONObject: facts), let text = String(data: data, encoding: .utf8) {
                ask += "Open Food Facts has these facts for its barcode (treat as the label, cite the source URL): \(text). "
            }
        }
        if product == nil, let barcode {
            ask += "The scanned barcode is \(barcode) and it is not in Open Food Facts; identify the product by searching the web for that number, and if nothing identifies it set name to \"unknown\" and every field to unknown. "
        }
        ask += imageJPEG != nil
            ? "Identify what is in the photo. Search the web for the brand or food's origin, production and supply chain, and for any additive or GMO facts you state."
            : "Search the web for the brand's origin, production and supply chain, and for any additive or GMO facts you state."
        content.append(["type": "text", "text": ask])

        var request = MorpheIntelligence.baseRequest(credential: credential, timeout: 90)
        // The server tool can pause a long search loop (stop_reason
        // pause_turn): resend with the assistant's content appended, up to
        // three times. max_tokens caps thinking + text together, so
        // thinking stays low and the cap generous (audit 2026-10-10).
        var messages: [[String: Any]] = [["role": "user", "content": content]]
        var blocks: [[String: Any]] = []
        var searched = false
        var visited = Set<String>()
        for _ in 0..<4 {
            var body: [String: Any] = [
                "max_tokens": 8000,
                "system": reportSystem,
                "output_config": ["effort": "low"],
                // The dynamic-filtering search (web_search_20260209) is the
                // current tool on Opus 5.5 and Sonnet 5.5.
                "tools": [["type": "web_search_20260209", "name": "web_search", "max_uses": 5]],
                "messages": messages
            ]
            if case .personalKey = credential { body["model"] = "claude-opus-5-5" }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let data: Data
            let response: URLResponse
            do { (data, response) = try await URLSession.shared.data(for: request) } catch { throw MorpheIntelligence.IntelligenceError.network }
            guard let http = response as? HTTPURLResponse else { throw MorpheIntelligence.IntelligenceError.network }
            if http.statusCode != 200 { throw MorpheIntelligence.error(status: http.statusCode, body: data) }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw MorpheIntelligence.IntelligenceError.malformed }
            let stop = json["stop_reason"] as? String
            if stop == "refusal" { throw MorpheIntelligence.IntelligenceError.declined }
            guard let turn = json["content"] as? [[String: Any]] else { throw MorpheIntelligence.IntelligenceError.malformed }
            blocks += turn
            if turn.contains(where: { $0["type"] as? String == "server_tool_use" }) { searched = true }
            // The pages actually read: tool results and citations.
            for block in turn {
                if block["type"] as? String == "web_search_tool_result", let results = block["content"] as? [[String: Any]] {
                    for hit in results { if let url = hit["url"] as? String { visited.insert(url) } }
                }
                if let citations = block["citations"] as? [[String: Any]] {
                    for citation in citations { if let url = citation["url"] as? String { visited.insert(url) } }
                }
            }
            if stop == "pause_turn" {
                messages.append(["role": "assistant", "content": turn])
                continue
            }
            if stop == "max_tokens" { throw MorpheIntelligence.IntelligenceError.ranLong }
            break
        }
        let text = blocks.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
        guard let object = extractJSONObject(from: text) else { throw MorpheIntelligence.IntelligenceError.malformed }
        var record = record(fromReport: object)
        // A source Claude names but never read is not a source (audit
        // 2026-10-10): keep only pages the search actually returned.
        if !visited.isEmpty {
            let visitedHosts = Set(visited.compactMap { URL(string: $0)?.host })
            record.sources = record.sources.filter { visited.contains($0.url) || (URL(string: $0.url)?.host).map(visitedHosts.contains) == true }
        }
        record.method = imageJPEG != nil ? (product != nil ? .photoAndBarcode : .photo) : .barcode
        record.usedPhoto = imageJPEG != nil
        record.usedWebSearch = searched
        record.barcode = product?.barcode
        if let p = product {
            // The database is the label; Claude fills what it can't.
            if record.name.isEmpty { record.name = p.name }
            if record.brand.isEmpty { record.brand = p.brand }
            if record.ingredients.isEmpty || record.ingredients.lowercased() == "unknown" { record.ingredients = p.ingredientsText }
            if record.nutriScore == nil { record.nutriScore = p.nutriScore }
            if record.additives.isEmpty { record.additives = p.additiveTags.map { additive(forTag: $0) } }
            if !record.sources.contains(where: { $0.url == p.url }) {
                record.sources.insert(FoodSourceLink(title: "Open Food Facts — \(p.name)", url: p.url), at: 0)
            }
        }
        return record
    }

    /// The report object inside prose: try each "{" until one parses.
    static func extractJSONObject(from text: String) -> [String: Any]? {
        guard let end = text.lastIndex(of: "}") else { return nil }
        var searchFrom = text.startIndex
        while let start = text[searchFrom...].firstIndex(of: "{"), start < end {
            let slice = String(text[start...end])
            if let object = (try? JSONSerialization.jsonObject(with: Data(slice.utf8))) as? [String: Any], object["name"] != nil || object["verdict"] != nil {
                return object
            }
            searchFrom = text.index(after: start)
        }
        return nil
    }

    static func record(fromReport o: [String: Any]) -> FoodCheckRecord {
        func str(_ k: String) -> String { ((o[k] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        func int(_ k: String) -> Int? {
            if let i = o[k] as? Int { return i }
            if let d = o[k] as? Double { return Int(d.rounded()) }
            return nil
        }
        var r = FoodCheckRecord()
        r.name = str("name"); r.brand = str("brand")
        r.processing = FoodProcessingClass(rawValue: str("processing")) ?? .unknown
        r.processingReason = str("processingReason")
        r.origin = str("origin"); r.originConfidence = FoodConfidence(rawValue: str("originConfidence")) ?? .unknown
        r.healthRead = str("healthRead")
        let score = str("nutriScore").uppercased()
        r.nutriScore = ["A", "B", "C", "D", "E"].contains(score) ? score : nil
        r.additives = (o["additives"] as? [[String: Any]] ?? []).compactMap { a in
            let code = (a["code"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let name = (a["name"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            guard !code.isEmpty || !name.isEmpty else { return nil }
            let key = additiveTableKey(code)
            if let known = additiveTable[key] {
                return FoodAdditive(code: code.uppercased(), name: known.name, note: known.note, concern: known.concern)
            }
            return FoodAdditive(code: code.isEmpty ? name : code, name: name.isEmpty ? code : name,
                                note: a["note"] as? String ?? "", concern: FoodAdditiveConcern(rawValue: a["concern"] as? String ?? "") ?? .unknown)
        }
        r.gmoRead = str("gmoRead"); r.gmoLikelihood = FoodConfidence(rawValue: str("gmoLikelihood")) ?? .unknown
        r.ingredients = str("ingredients")
        r.calories = int("calories"); r.protein = int("protein"); r.carbs = int("carbs"); r.fat = int("fat")
        r.sugar = int("sugar"); r.fiber = int("fiber"); r.sodiumMg = int("sodiumMg")
        r.servingNote = str("servingNote")
        r.sources = (o["sources"] as? [[String: Any]] ?? []).compactMap { s in
            guard let url = s["url"] as? String, url.hasPrefix("http") else { return nil }
            return FoodSourceLink(title: (s["title"] as? String ?? url), url: url)
        }
        r.verdict = str("verdict")
        return r
    }
}


// MARK: - Food library (fuel rebuild 2026-10-10)

/// The bundled USDA SR Legacy set: 1,195 common whole foods, per 100 g,
/// public domain. Loaded once, searched in memory — instant and offline,
/// and the verified-source choice the accuracy benchmarks reward.
enum FoodLibrary {
    private static var cache: [FoodLibraryItem]?

    static var all: [FoodLibraryItem] {
        if let cache { return cache }
        guard let url = Bundle.main.url(forResource: "FoodLibrary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let foods = json["foods"],
              let foodData = try? JSONSerialization.data(withJSONObject: foods),
              let items = try? JSONDecoder().decode([FoodLibraryItem].self, from: foodData) else {
            cache = []
            return []
        }
        cache = items
        return items
    }

    /// Ranked: every query word must match; names that START with the
    /// query win, then shorter (plainer) names.
    static func search(_ query: String, limit: Int = 25) -> [FoodLibraryItem] {
        let words = query.lowercased().split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        let scored: [(FoodLibraryItem, Int)] = all.compactMap { item in
            let name = item.name.lowercased()
            guard words.allSatisfy({ name.contains($0) }) else { return nil }
            var score = 0
            if name.hasPrefix(words[0]) { score += 100 }
            if let first = name.split(separator: ",").first, words.allSatisfy({ first.contains($0) }) { score += 40 }
            score -= min(name.count, 60)
            return (item, score)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }
}

extension FoodCheckService {
    /// Packaged products by name from Open Food Facts text search — the
    /// same public database the barcode check reads. Per 100 g, with the
    /// listed serving when the product states one in grams.
    enum ProductSearchResult {
        case hits([FoodSearchResult])
        case unreachable
    }

    static func searchProducts(_ query: String, limit: Int = 15) async -> ProductSearchResult {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~ ")
        guard q.count >= 2,
              let encoded = q.addingPercentEncoding(withAllowedCharacters: allowed)?.replacingOccurrences(of: " ", with: "+"),
              let url = URL(string: "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encoded)&search_simple=1&action=process&json=1&page_size=\(limit)&fields=code,product_name,brands,nutriments,serving_size")
        else { return .hits([]) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Morphe iOS (https://lucasdilley07-png.github.io/Morphe/)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let products = json["products"] as? [[String: Any]] else { return .unreachable }
        return .hits(products.compactMap { p in
            let name = (p["product_name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let n = p["nutriments"] as? [String: Any] ?? [:]
            func number(_ key: String) -> Double? {
                if let d = n[key] as? Double { return d }
                if let i = n[key] as? Int { return Double(i) }
                if let s = n[key] as? String { return Double(s) }
                return nil
            }
            // Many entries carry kJ only (audit 2026-10-10): 1 kcal = 4.184 kJ.
            guard !name.isEmpty, let kcal = number("energy-kcal_100g") ?? number("energy_100g").map({ $0 / 4.184 }) else { return nil }
            let serving = servingGrams(from: p["serving_size"] as? String)
            return FoodSearchResult(
                name: name,
                brand: (p["brands"] as? String ?? "").components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "",
                source: "Open Food Facts",
                kcal100: kcal, protein100: number("proteins_100g") ?? 0,
                carbs100: number("carbohydrates_100g") ?? 0, fat100: number("fat_100g") ?? 0,
                servingGrams: serving, servingLabel: serving.map { "Listed serving · \($0) g" },
                barcode: p["code"] as? String)
        })
    }

    /// "1 portion (100 g)", "200 g", "30g", "1 cup (240 ml)" → grams/ml.
    static func servingGrams(from text: String?) -> Int? {
        guard let text else { return nil }
        let pattern = #"(\d+(?:[.,]\d+)?)\s*(g|ml)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text),
              let value = Double(text[range].replacingOccurrences(of: ",", with: ".")) else { return nil }
        let grams = Int(value.rounded())
        return grams > 0 && grams <= 2_000 ? grams : nil
    }
}
