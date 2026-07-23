import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firebase-backed auth
//
// Implements the same `AuthService` protocol as `LocalAuthService`, so nothing
// in the store or UI changes — only the provider swapped in `MorpheApp`.
//
// Firebase Auth owns email/password + the uid. It does NOT store the app's own
// fields (role, display name), so those live in a Firestore `users/{uid}`
// document written at sign-up and read back at sign-in. That same document is
// the anchor the cloud-backup layer will hang profile + logs off next.
//
// `currentUser` must be synchronous (the store reads it during init), so the
// last signed-in `AppUser` is cached on disk. Firebase persists its own auth
// session across launches; when that session exists we return the cached user.

final class FirebaseAuthService: AuthService {
    private let cache: SignedInUserCache
    private(set) var currentUser: AppUser?

    private var db: Firestore { Firestore.firestore() }
    private var usersCollection: CollectionReference { db.collection("users") }

    init() {
        cache = SignedInUserCache()
        // Only trust the cache when Firebase still holds a live session for the
        // same uid — otherwise a stale cache could "sign in" a signed-out user.
        if let firebaseUser = Auth.auth().currentUser,
           let cached = cache.load(), cached.id == firebaseUser.uid {
            currentUser = cached
        } else {
            currentUser = nil
        }
    }

    func signUp(email: String, password: String, role: UserRole, displayName: String) async throws -> AppUser {
        try Self.validate(email: email, password: password)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let result = try await Auth.auth().createUser(withEmail: normalizedEmail, password: password)
            let uid = result.user.uid

            // Mirror the display name onto the Firebase user, too (handy in the
            // console and for any provider that reads it).
            if !name.isEmpty {
                let change = result.user.createProfileChangeRequest()
                change.displayName = name
                try? await change.commitChanges()
            }

            let user = AppUser(
                id: uid,
                email: normalizedEmail,
                role: role,
                displayName: name,
                createdAt: Date()
            )
            try await usersCollection.document(uid).setData(Self.document(from: user))
            cache.save(user)
            currentUser = user
            return user
        } catch let error as AuthError {
            throw error
        } catch {
            throw Self.mapError(error)
        }
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        try Self.validate(email: email, password: password)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            let result = try await Auth.auth().signIn(withEmail: normalizedEmail, password: password)
            let uid = result.user.uid

            // Pull the app-specific fields from the user's doc. If it's missing
            // (e.g. an account made directly in the console), fall back to sane
            // defaults built from the Firebase user and heal the doc.
            let snapshot = try? await usersCollection.document(uid).getDocument()
            let user: AppUser
            if let data = snapshot?.data(), let decoded = Self.user(from: data, uid: uid, email: normalizedEmail) {
                user = decoded
            } else {
                let healed = AppUser(
                    id: uid,
                    email: result.user.email ?? normalizedEmail,
                    role: .athlete,
                    displayName: result.user.displayName ?? "",
                    createdAt: Date()
                )
                try? await usersCollection.document(uid).setData(Self.document(from: healed), merge: true)
                user = healed
            }

            cache.save(user)
            currentUser = user
            return user
        } catch let error as AuthError {
            throw error
        } catch {
            throw Self.mapError(error)
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        cache.clear()
        currentUser = nil
    }

    func sendPasswordReset(email: String) async throws {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        do {
            try await Auth.auth().sendPasswordReset(withEmail: normalized)
        } catch {
            throw Self.mapError(error)
        }
    }

    // MARK: - Firestore <-> AppUser mapping

    private static func document(from user: AppUser) -> [String: Any] {
        [
            "email": user.email,
            "role": user.role.rawValue,
            "displayName": user.displayName,
            "createdAt": Timestamp(date: user.createdAt)
        ]
    }

    private static func user(from data: [String: Any], uid: String, email: String) -> AppUser? {
        let roleRaw = data["role"] as? String ?? UserRole.athlete.rawValue
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return AppUser(
            id: uid,
            email: data["email"] as? String ?? email,
            role: UserRole(rawValue: roleRaw) ?? .athlete,
            displayName: data["displayName"] as? String ?? "",
            createdAt: createdAt
        )
    }

    // MARK: - Error mapping

    private static func mapError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .emailInUse
        case AuthErrorCode.weakPassword.rawValue:
            return .weakPassword
        case AuthErrorCode.invalidEmail.rawValue:
            return .invalidEmail
        case AuthErrorCode.userNotFound.rawValue:
            return .userNotFound
        case AuthErrorCode.wrongPassword.rawValue, AuthErrorCode.invalidCredential.rawValue:
            // With email-enumeration protection on, Firebase returns
            // invalidCredential for both wrong password and unknown user.
            return .wrongPassword
        case AuthErrorCode.networkError.rawValue:
            return .unknown("Network error — check your connection and try again.")
        default:
            return .unknown(nsError.localizedDescription)
        }
    }
}

/// Tiny on-disk cache of the last signed-in `AppUser`, so `currentUser` can
/// answer synchronously at launch. Holds no password — Firebase owns the
/// credential/session; this only remembers who is signed in.
private final class SignedInUserCache {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directoryName: String = "MorpheStore", fileName: String = "firebase-account.json") {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent(fileName)
    }

    func load() -> AppUser? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(AppUser.self, from: data)
    }

    func save(_ user: AppUser) {
        guard let data = try? encoder.encode(user) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
