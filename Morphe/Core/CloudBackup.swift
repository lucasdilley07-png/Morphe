import Foundation
import FirebaseFirestore

// MARK: - Cloud backup (profile + workout logs)
//
// Mirrors the two on-device persistence snapshots (LocalProfileSnapshot and the
// workout-log array) up to Firestore under the signed-in user, and pulls them
// back on sign-in so a reinstall or a second device restores the account.
//
// It intentionally reuses the SAME JSONEncoder/Decoder settings as the file
// persistence and the SAME tolerant per-element log decode. A backup is stored
// as one JSON string per document — that keeps byte-for-byte parity with the
// local files and the WorkoutLog tolerant decoder (a single bad field can never
// nuke the whole history), at the cost of the console showing a JSON blob
// rather than nested fields.
//
// Firestore layout (covered by the users/{uid}/{document=**} security rule):
//   users/{uid}/state/profile  { schemaVersion, json, updatedAt }
//   users/{uid}/state/logs     { schemaVersion, count, json, updatedAt }

struct CloudSnapshot {
    var profile: LocalProfileSnapshot?
    var logs: [WorkoutLog]?
}

/// Abstraction so the store can be built without Firebase (tests/previews use
/// the no-op). The real app injects `FirebaseCloudBackup`.
protocol CloudBackingUp: AnyObject {
    /// Point the backup at a user (nil on sign-out). Writes before this is set
    /// are dropped, so demo/pre-sign-in state never lands in the cloud.
    func setUser(_ uid: String?)
    func pushProfile(_ snapshot: LocalProfileSnapshot)
    func pushLogs(_ logs: [WorkoutLog])
    func pull() async -> CloudSnapshot
}

/// Default backup that does nothing — keeps the store fully functional offline
/// and keeps the 140 tests from needing Firebase.
final class NoOpCloudBackup: CloudBackingUp {
    func setUser(_ uid: String?) {}
    func pushProfile(_ snapshot: LocalProfileSnapshot) {}
    func pushLogs(_ logs: [WorkoutLog]) {}
    func pull() async -> CloudSnapshot { CloudSnapshot() }
}

final class FirebaseCloudBackup: CloudBackingUp {
    private var uid: String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var db: Firestore { Firestore.firestore() }

    init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func setUser(_ uid: String?) {
        self.uid = uid
    }

    private func stateDoc(_ name: String) -> DocumentReference? {
        guard let uid else { return nil }
        return db.collection("users").document(uid).collection("state").document(name)
    }

    func pushProfile(_ snapshot: LocalProfileSnapshot) {
        guard let doc = stateDoc("profile"),
              let data = try? encoder.encode(snapshot),
              let json = String(data: data, encoding: .utf8) else { return }
        // No completion handler: Firestore queues the write in its offline cache
        // and syncs it when the network is available.
        doc.setData([
            "schemaVersion": 1,
            "json": json,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func pushLogs(_ logs: [WorkoutLog]) {
        guard let doc = stateDoc("logs"),
              let data = try? encoder.encode(logs),
              let json = String(data: data, encoding: .utf8) else { return }
        doc.setData([
            "schemaVersion": 1,
            "count": logs.count,
            "json": json,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func pull() async -> CloudSnapshot {
        guard uid != nil else { return CloudSnapshot() }
        var result = CloudSnapshot()

        if let doc = stateDoc("profile"),
           let snap = try? await doc.getDocument(),
           let json = snap.data()?["json"] as? String,
           let data = json.data(using: .utf8),
           let profile = try? decoder.decode(LocalProfileSnapshot.self, from: data) {
            result.profile = profile
        }

        if let doc = stateDoc("logs"),
           let snap = try? await doc.getDocument(),
           let json = snap.data()?["json"] as? String,
           let data = json.data(using: .utf8),
           // Same tolerant per-element decode as the file store: one bad log
           // drops that entry, never the whole array.
           let elements = try? decoder.decode([FailableElement<WorkoutLog>].self, from: data) {
            result.logs = elements.compactMap(\.value)
        }

        return result
    }
}
