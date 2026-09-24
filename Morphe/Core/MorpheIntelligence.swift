import Foundation
import Security

// MARK: - Morphe Intelligence (rebuild wave, Lucas 2026-08-27)
//
// The optional Claude-powered brain behind chat and voice. The rules
// doors stay primary — instant, offline, free — and this layer answers
// ONLY when no door matched AND the user has pasted their own Anthropic
// API key in Settings. No key, no network call, no behavior change:
// the canned coaching replies keep running exactly as before.
//
// Swift has no official Anthropic SDK, so this is the raw Messages API
// over URLSession: POST /v1/messages with model claude-opus-5, adaptive
// thinking left at its default, effort low so spoken answers come back
// fast. A safety refusal (stop_reason "refusal") is surfaced honestly,
// never papered over.

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
    }

    // MARK: Conversation shape

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

        var errorDescription: String? {
            switch self {
            case .badKey: return "That API key was rejected — check it in Settings."
            case .rateLimited: return "Anthropic is rate-limiting your key right now — try again in a minute."
            case .overloaded: return "Claude is overloaded right now — try again shortly."
            case .network: return "I couldn't reach Claude — check your connection."
            case .declined: return "Claude declined to answer that one."
            case .malformed: return "Claude sent something I couldn't read."
            case .badRequest: return "Something went wrong on my end — try rephrasing that."
            case .ranLong: return "That one ran long — try asking it more simply."
            }
        }
    }

    /// Error-absorbing wrapper for the store: every failure becomes an
    /// honest, speakable line instead of a thrown error.
    static func safeReply(system: String, turns: [Turn], apiKey: String,
                          timeout: TimeInterval = 30) async -> String {
        do {
            return try await reply(system: system, turns: turns, apiKey: apiKey, timeout: timeout)
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
    static func streamReply(system: String, turns: [Turn], apiKey: String,
                            timeout: TimeInterval = 30,
                            onDelta: @MainActor @escaping (String) -> Void) async throws -> String {
        var request = try makeRequest(system: system, turns: turns, apiKey: apiKey,
                                      timeout: timeout, stream: true)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw IntelligenceError.network }
        // Same status taxonomy as the non-streaming path (audit 23, P1:
        // a 429 told the user to "rephrase").
        switch http.statusCode {
        case 200: break
        case 401, 403: throw IntelligenceError.badKey
        case 429: throw IntelligenceError.rateLimited
        case 500...: throw IntelligenceError.overloaded
        default: throw IntelligenceError.badRequest
        }
        var full = ""
        var stopReason: String?
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = line.dropFirst(6)
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
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

    /// Shared request builder for both paths.
    private static func makeRequest(system: String, turns: [Turn], apiKey: String,
                                    timeout: TimeInterval, stream: Bool) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        var messages: [[String: Any]] = []
        for turn in turns.drop(while: { !$0.isUser }) {
            messages.append(["role": turn.isUser ? "user" : "assistant",
                             "content": turn.text])
        }
        guard messages.first?["role"] as? String == "user" else { throw IntelligenceError.malformed }
        var body: [String: Any] = [
            "model": "claude-opus-5",
            "max_tokens": 4000,
            "system": system,
            "output_config": ["effort": "low"],
            "messages": messages
        ]
        if stream { body["stream"] = true }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// One non-streaming Messages API request. Replies are deliberately
    /// short (voice-first: the system prompt caps spoken length) — the
    /// VOICE path uses this; chat streams via streamReply.
    static func reply(system: String, turns: [Turn], apiKey: String,
                      timeout: TimeInterval = 30) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // The Messages API requires the first message to be a user turn;
        // consecutive same-role messages are legal and combined.
        var messages: [[String: Any]] = []
        for turn in turns.drop(while: { !$0.isUser }) {
            messages.append(["role": turn.isUser ? "user" : "assistant",
                             "content": turn.text])
        }
        guard messages.first?["role"] as? String == "user" else { throw IntelligenceError.malformed }

        // max_tokens caps thinking + visible text TOGETHER on this model
        // (audit 17, P1): 700 let adaptive thinking eat the whole budget
        // and the truncated reply surfaced as a false "couldn't read"
        // error. The brevity contract lives in the system prompt, not the
        // token cap.
        let body: [String: Any] = [
            "model": "claude-opus-5",
            "max_tokens": 4000,
            "system": system,
            // Thinking off (luxury audit): adaptive thinking shared the
            // token budget with the visible text, so a long think could
            // return an EMPTY reply as "ranLong" — the least premium
            // outcome. The prompt already enforces brevity.
            "output_config": ["effort": "low"],
            "messages": messages
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw IntelligenceError.network
        }
        guard let http = response as? HTTPURLResponse else { throw IntelligenceError.network }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw IntelligenceError.badKey
        case 429: throw IntelligenceError.rateLimited
        case 500...: throw IntelligenceError.overloaded
        default: throw IntelligenceError.badRequest
        }

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
