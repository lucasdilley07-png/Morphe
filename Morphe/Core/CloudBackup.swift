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

// MARK: - Verification (manual review → server-granted badge)
//
// The client can only ASK: it writes a request (selfie + note) to
// verificationRequests/{uid} and reads back two server-owned facts — the
// request's status and users/{uid}.verified. The badge flag itself is granted
// exclusively from the Firebase console (rules: keepsVerifiedHonest), so no
// client, bot, or jailbreak can mint a checkmark.

enum VerificationRequestStatus: String {
    case none          // never asked
    case pending       // submitted, awaiting review
    case declined      // reviewed and not granted (may resubmit)
}

protocol VerificationSyncing: AnyObject {
    /// Submits (or resubmits) the user's verification request.
    func submitRequest(uid: String, name: String, username: String, role: String,
                       note: String, selfieJPEG: Data) async -> Bool
    /// (verified badge granted?, current request status)
    func fetchStatus(uid: String) async -> (verified: Bool, request: VerificationRequestStatus)?
}

final class NoOpVerificationService: VerificationSyncing {
    func submitRequest(uid: String, name: String, username: String, role: String,
                       note: String, selfieJPEG: Data) async -> Bool { false }
    func fetchStatus(uid: String) async -> (verified: Bool, request: VerificationRequestStatus)? { nil }
}

final class FirebaseVerificationService: VerificationSyncing {
    private var db: Firestore { Firestore.firestore() }

    func submitRequest(uid: String, name: String, username: String, role: String,
                       note: String, selfieJPEG: Data) async -> Bool {
        do {
            try await db.collection("verificationRequests").document(uid).setData([
                "uid": uid,
                "name": name,
                "username": username,
                "role": role,
                "note": note,
                "selfieJPEG": selfieJPEG.base64EncodedString(),
                "status": VerificationRequestStatus.pending.rawValue,
                "createdAt": FieldValue.serverTimestamp()
            ])
            return true
        } catch {
            return false
        }
    }

    func fetchStatus(uid: String) async -> (verified: Bool, request: VerificationRequestStatus)? {
        guard let userSnap = try? await db.collection("users").document(uid).getDocument() else { return nil }
        let verified = (userSnap.data()?["verified"] as? Bool) ?? false
        var requestStatus = VerificationRequestStatus.none
        if let reqSnap = try? await db.collection("verificationRequests").document(uid).getDocument(),
           reqSnap.exists,
           let raw = reqSnap.data()?["status"] as? String {
            requestStatus = VerificationRequestStatus(rawValue: raw) ?? .pending
        }
        return (verified, requestStatus)
    }
}

// MARK: - Coach-managed client handoff
//
// A coach creates a client profile before that person has a Morphe account,
// logs workouts against it, and shares an invite code. When the client signs
// up and enters the code during onboarding, the profile is atomically claimed
// and the coach-logged history imports into their brand-new account.
//
// Firestore layout (managedClients rules in BACKEND/firestore.rules):
//   managedClients/{code}  { coachUid, coachName, athleteID, name, email,
//                            sport, notes, status, claimedByUid, claimedByName,
//                            logsJSON, logCount, createdAt, updatedAt }
//
// Logs ride in the parent doc as ONE JSON string (`logsJSON`) — the same
// snapshot pattern as CloudBackup above, and it makes the claim a single
// get + a single guarded update, no subcollection rules. Possession of the
// code is the authorization, exactly like party join codes.

enum ManagedClientClaimError: Error, Equatable {
    case notFound
    case alreadyClaimed
    case network

    var message: String {
        switch self {
        case .notFound: return "No client profile matches that code. Double-check it with your coach."
        case .alreadyClaimed: return "That invite code has already been used."
        case .network: return "Couldn't reach Morphe — check your connection and try again."
        }
    }
}

/// Abstraction so tests/previews run without Firebase; the real app injects
/// `FirebaseManagedClientService`.
protocol ManagedClientSyncing: AnyObject {
    /// Create or update a managed client (including its logs snapshot).
    func push(_ client: ManagedClient)
    /// All managed clients created by this coach, or nil when offline/unavailable.
    func fetchMine(coachUid: String) async -> [ManagedClient]?
    /// Atomically claim an unclaimed profile for the signed-in athlete.
    func claim(code: String, athleteUid: String, athleteName: String) async -> Result<ManagedClient, ManagedClientClaimError>
    /// Remove an (unclaimed) managed client.
    func delete(code: String)
}

final class NoOpManagedClientService: ManagedClientSyncing {
    func push(_ client: ManagedClient) {}
    func fetchMine(coachUid: String) async -> [ManagedClient]? { nil }
    func claim(code: String, athleteUid: String, athleteName: String) async -> Result<ManagedClient, ManagedClientClaimError> {
        .failure(.network)
    }
    func delete(code: String) {}
}

final class FirebaseManagedClientService: ManagedClientSyncing {
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

    private func doc(_ code: String) -> DocumentReference {
        db.collection("managedClients").document(code)
    }

    func push(_ client: ManagedClient) {
        let logsJSON = (try? encoder.encode(client.logs))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        // Fire-and-forget like the party/backup writes: Firestore queues it
        // offline and syncs when the network returns.
        doc(client.id).setData([
            "schemaVersion": 1,
            "coachUid": client.coachUid,
            "coachName": client.coachName,
            "athleteID": client.athleteID.uuidString,
            "name": client.name,
            "email": client.email,
            "sport": client.sport.rawValue,
            "notes": client.notes,
            "status": client.status.rawValue,
            "claimedByName": client.claimedByName,
            "logsJSON": logsJSON,
            "logCount": client.logs.count,
            "createdAt": Timestamp(date: client.createdAt),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func fetchMine(coachUid: String) async -> [ManagedClient]? {
        guard let snapshot = try? await db.collection("managedClients")
            .whereField("coachUid", isEqualTo: coachUid)
            .getDocuments()
        else { return nil }
        return snapshot.documents
            .compactMap { client(from: $0.documentID, data: $0.data()) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func claim(code: String, athleteUid: String, athleteName: String) async -> Result<ManagedClient, ManagedClientClaimError> {
        let reference = doc(code)
        guard let snap = try? await reference.getDocument() else { return .failure(.network) }
        guard snap.exists, let data = snap.data(),
              var client = client(from: code, data: data) else { return .failure(.notFound) }
        guard client.status == .unclaimed else { return .failure(.alreadyClaimed) }

        do {
            // The rules only allow this transition (unclaimed → claimed, by the
            // claimer, everything else unchanged), so a second device racing
            // this claim loses at the rules layer, not just here.
            try await reference.updateData([
                "status": ManagedClientStatus.claimed.rawValue,
                "claimedByUid": athleteUid,
                "claimedByName": athleteName,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            return .failure(.network)
        }

        client.status = .claimed
        client.claimedByName = athleteName
        return .success(client)
    }

    func delete(code: String) {
        doc(code).delete()
    }

    /// Tolerant hand-decode, same per-field-defaults style as the party
    /// service — one malformed field never hides a whole client.
    private func client(from id: String, data: [String: Any]) -> ManagedClient? {
        guard let coachUid = data["coachUid"] as? String,
              let name = data["name"] as? String else { return nil }
        var logs: [WorkoutLog] = []
        if let json = data["logsJSON"] as? String,
           let bytes = json.data(using: .utf8),
           let elements = try? decoder.decode([FailableElement<WorkoutLog>].self, from: bytes) {
            logs = elements.compactMap(\.value)
        }
        return ManagedClient(
            id: id,
            athleteID: (data["athleteID"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(),
            coachUid: coachUid,
            coachName: data["coachName"] as? String ?? "",
            name: name,
            email: data["email"] as? String ?? "",
            sport: (data["sport"] as? String).flatMap(SportFocus.init(rawValue:)) ?? .generalFitness,
            notes: data["notes"] as? String ?? "",
            status: (data["status"] as? String).flatMap(ManagedClientStatus.init(rawValue:)) ?? .unclaimed,
            claimedByName: data["claimedByName"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
            logs: logs
        )
    }
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
