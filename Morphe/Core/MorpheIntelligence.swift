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

    /// One non-streaming Messages API request. Replies are deliberately
    /// short (voice-first: the system prompt caps spoken length), so a
    /// single response body beats streaming complexity here.
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
