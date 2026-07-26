import Foundation
import FirebaseFirestore

// MARK: - Username directory (global uniqueness)
//
// Every account owns exactly one @username, and every username belongs to
// exactly one account. The directory is a Firestore collection keyed by the
// lowercased name — existence IS the claim, and a transaction makes two
// people racing for the same name impossible:
//
//   usernames/{name}   { uid, claimedAt }
//
// Changing a username claims the new name and releases the old one in the
// same transaction, so the account never holds zero or two names.

enum UsernameClaimResult {
    case claimed
    /// Someone else owns it.
    case taken
    /// Network/backend failure — distinct from taken so the UI can say
    /// "try again" instead of "pick another name".
    case failed
}

enum UsernameRules {
    static let minLength = 3
    static let maxLength = 20

    /// Lowercased letters, digits, and underscore — the storable form.
    static func normalize(_ raw: String) -> String {
        String(
            raw.lowercased()
                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                .prefix(maxLength)
        )
    }

    /// Nil when valid; otherwise the reason to show the user.
    static func validationError(_ name: String) -> String? {
        if name.count < minLength { return "Usernames need at least \(minLength) characters." }
        if name.count > maxLength { return "Usernames max out at \(maxLength) characters." }
        if name.first == "_" || Int(String(name.first ?? "0")) != nil { return "Start with a letter." }
        return nil
    }
}

protocol UsernameDirectoryService: AnyObject {
    /// True when nobody (or this uid) owns the name.
    func isAvailable(_ username: String, for uid: String) async -> Bool
    /// Atomically claims `username` for `uid`, releasing `previous` (when
    /// given and owned by this uid) in the same transaction.
    func claim(_ username: String, for uid: String, releasing previous: String?) async -> UsernameClaimResult
    /// Prefix search over the directory for user discovery — (username, uid)
    /// pairs, name-ordered. Empty on failure or empty prefix.
    func search(prefix: String, limit: Int) async -> [(username: String, uid: String)]
    /// Releases a claim on account deletion so the name frees up. Rules
    /// enforce owner-only; a mismatched uid write is simply denied.
    func release(_ username: String, for uid: String) async
}

/// Offline default for tests/previews: everything is available and every
/// claim succeeds. Real uniqueness comes from `FirebaseUsernameDirectory`.
final class NoOpUsernameDirectory: UsernameDirectoryService {
    func isAvailable(_ username: String, for uid: String) async -> Bool { true }
    func claim(_ username: String, for uid: String, releasing previous: String?) async -> UsernameClaimResult { .claimed }
    func search(prefix: String, limit: Int) async -> [(username: String, uid: String)] { [] }
    func release(_ username: String, for uid: String) async {}
}

final class FirebaseUsernameDirectory: UsernameDirectoryService {
    private var db: Firestore { Firestore.firestore() }

    private func nameDoc(_ username: String) -> DocumentReference {
        db.collection("usernames").document(username)
    }

    func isAvailable(_ username: String, for uid: String) async -> Bool {
        guard let snap = try? await nameDoc(username).getDocument() else { return false }
        guard snap.exists else { return true }
        return (snap.data()?["uid"] as? String) == uid
    }

    func search(prefix: String, limit: Int) async -> [(username: String, uid: String)] {
        let clean = UsernameRules.normalize(prefix)
        guard !clean.isEmpty else { return [] }
        // Doc-id range scan: the doc id IS the lowercased username, so
        // [prefix, prefix + U+F8FF) is every name starting with it.
        guard let snapshot = try? await db.collection("usernames")
            .whereField(FieldPath.documentID(), isGreaterThanOrEqualTo: clean)
            .whereField(FieldPath.documentID(), isLessThan: clean + "\u{f8ff}")
            .limit(to: max(limit, 1))
            .getDocuments()
        else { return [] }
        return snapshot.documents.compactMap { document in
            guard let uid = document.data()["uid"] as? String else { return nil }
            return (username: document.documentID, uid: uid)
        }
    }

    func release(_ username: String, for uid: String) async {
        let clean = UsernameRules.normalize(username)
        guard !clean.isEmpty else { return }
        // Owner-only delete is enforced by the rules; a stale/mismatched
        // claim just fails quietly.
        try? await nameDoc(clean).delete()
    }

    func claim(_ username: String, for uid: String, releasing previous: String?) async -> UsernameClaimResult {
        do {
            let result = try await db.runTransaction { [weak self] transaction, errorPointer -> Any? in
                guard let self else { return "failed" }
                let newDoc = self.nameDoc(username)
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(newDoc)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return "failed"
                }
                if snapshot.exists, (snapshot.data()?["uid"] as? String) != uid {
                    return "taken"
                }
                transaction.setData([
                    "uid": uid,
                    "claimedAt": FieldValue.serverTimestamp()
                ], forDocument: newDoc)
                if let previous, previous != username, !previous.isEmpty {
                    transaction.deleteDocument(self.nameDoc(previous))
                }
                return "claimed"
            }
            switch result as? String {
            case "claimed": return .claimed
            case "taken": return .taken
            default: return .failed
            }
        } catch {
            return .failed
        }
    }
}
