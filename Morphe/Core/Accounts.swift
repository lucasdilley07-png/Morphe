import Foundation

// MARK: - Accounts & auth seam
//
// This is the backend-agnostic foundation for the v2 multi-user platform. The
// app talks to an `AuthService`; today a `LocalAuthService` backs it so the auth
// flow compiles and runs on-device. When the Firebase project exists, a
// `FirebaseAuthService` implements the same protocol and the local one becomes a
// fallback/offline cache — no UI or store changes required.

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case athlete
    case coach

    var id: String { rawValue }
    var title: String { self == .coach ? "Coach" : "Athlete" }
    var appRole: AppRole { self == .coach ? .coach : .client }
}

/// The authenticated account. `id` becomes the Firebase Auth uid once connected.
struct AppUser: Codable, Equatable, Identifiable {
    var id: String
    var email: String
    var role: UserRole
    var displayName: String
    var createdAt: Date
}

enum AuthError: Error, LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case emailInUse
    case userNotFound
    case wrongPassword
    case notConfigured
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return "Enter a valid email address."
        case .weakPassword: return "Use a password of at least 6 characters."
        case .emailInUse: return "An account already exists for that email."
        case .userNotFound: return "No account found for that email."
        case .wrongPassword: return "That password doesn't match."
        case .notConfigured: return "Sign-in isn't connected yet."
        case .unknown(let message): return message
        }
    }
}

/// Abstraction over the auth provider. Implemented locally now, by Firebase later.
protocol AuthService: AnyObject {
    var currentUser: AppUser? { get }
    func signUp(email: String, password: String, role: UserRole, displayName: String) async throws -> AppUser
    func signIn(email: String, password: String) async throws -> AppUser
    func signOut()
    /// Emails the user a password-reset link. Only a real backend can do this;
    /// the local service throws `.notConfigured`.
    func sendPasswordReset(email: String) async throws
}

extension AuthService {
    static func validate(email: String, password: String) throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains("."), trimmed.count >= 5 else {
            throw AuthError.invalidEmail
        }
        guard password.count >= 6 else { throw AuthError.weakPassword }
    }
}

/// On-device account store used until Firebase is connected. Models a single
/// device account; the real backend replaces password handling entirely, so this
/// deliberately does NOT persist passwords — it just remembers who is signed in.
final class LocalAuthService: AuthService {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private(set) var currentUser: AppUser?

    init(directoryName: String = "MorpheStore", fileName: String = "account.json") {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent(fileName)
        self.currentUser = load()
    }

    func signUp(email: String, password: String, role: UserRole, displayName: String) async throws -> AppUser {
        try Self.validate(email: email, password: password)
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let existing = load(), existing.email == normalized {
            throw AuthError.emailInUse
        }
        let user = AppUser(
            id: UUID().uuidString,
            email: normalized,
            role: role,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )
        save(user)
        currentUser = user
        return user
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        try Self.validate(email: email, password: password)
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let user = load(), user.email == normalized else {
            throw AuthError.userNotFound
        }
        currentUser = user
        return user
    }

    func signOut() {
        currentUser = nil
    }

    /// The device account never had a real password to reset — be honest
    /// about it instead of pretending an email went out.
    func sendPasswordReset(email: String) async throws {
        throw AuthError.notConfigured
    }

    /// Removes the stored device account entirely (used by tests).
    func reset() {
        currentUser = nil
        try? FileManager.default.removeItem(at: url)
    }

    private func load() -> AppUser? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(AppUser.self, from: data)
    }

    private func save(_ user: AppUser) {
        guard let data = try? encoder.encode(user) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
