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
// Firestore layout (owner-only state/* rule in BACKEND/firestore.rules):
//   users/{uid}/state/profile        { schemaVersion, json, updatedAt }
//   users/{uid}/state/logs           { schemaVersion, count, json, updatedAt }
//   users/{uid}/state/weightHistory  { schemaVersion, count, json, updatedAt }
//   users/{uid}/state/extras         { schemaVersion, count, json, updatedAt }
//     (json = {name: base64 plist} — training prefs, competition,
//      recovery/nutrition series, program state + completions)

struct CloudSnapshot {
    var profile: LocalProfileSnapshot?
    var logs: [WorkoutLog]?
    var weightHistory: [MorpheAppStore.BodyWeightHistoryEntry]?
    /// The per-profile UserDefaults blobs (training prefs, competition,
    /// recovery/nutrition series, program state + completions), keyed by
    /// logical name, values base64 property-list data. Backed up raw so
    /// the same tolerant decoders that read them locally read the restore.
    var extras: [String: String]?
}

/// Abstraction so the store can be built without Firebase (tests/previews use
/// the no-op). The real app injects `FirebaseCloudBackup`.
protocol CloudBackingUp: AnyObject {
    /// Point the backup at a user (nil on sign-out). Writes before this is set
    /// are dropped, so demo/pre-sign-in state never lands in the cloud.
    func setUser(_ uid: String?)
    func pushProfile(_ snapshot: LocalProfileSnapshot)
    /// True when the history doc landed. False = the backup is BEHIND —
    /// callers surface it; fire-and-forget silently stranded users whose
    /// uploads failed (audit finding).
    @discardableResult
    func pushLogs(_ logs: [WorkoutLog]) async -> Bool
    func pushWeightHistory(_ entries: [MorpheAppStore.BodyWeightHistoryEntry])
    /// The per-profile blob bag (see CloudSnapshot.extras) — merged by
    /// name server-side-of-write, so a device missing a blob can't erase it.
    func pushExtras(_ blobs: [String: String])
    func pull() async -> CloudSnapshot
    /// Account deletion: removes every state/* backup doc for the current
    /// user (best-effort, while the auth session is still valid).
    func eraseUser() async
}

/// Default backup that does nothing — keeps the store fully functional offline
/// and keeps the 140 tests from needing Firebase.
final class NoOpCloudBackup: CloudBackingUp {
    func setUser(_ uid: String?) {}
    func pushProfile(_ snapshot: LocalProfileSnapshot) {}
    // "Nothing to back up to" is not "behind" — inert reports success.
    func pushLogs(_ logs: [WorkoutLog]) async -> Bool { true }
    func pushWeightHistory(_ entries: [MorpheAppStore.BodyWeightHistoryEntry]) {}
    func pushExtras(_ blobs: [String: String]) {}
    func pull() async -> CloudSnapshot { CloudSnapshot() }
    func eraseUser() async {}
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
    /// Athlete side: publishes the consented progress summary the named
    /// coach may read (users/{athleteUid}/coachShare/summary).
    func pushCoachShare(_ summary: CoachShareSummary, athleteUid: String)
    /// Athlete side: revokes consent by deleting the summary doc.
    func clearCoachShare(athleteUid: String)
    /// Coach side: the claimed client's shared summary — nil when the
    /// athlete isn't sharing (or offline).
    func fetchCoachShare(athleteUid: String) async -> CoachShareSummary?
}

final class NoOpManagedClientService: ManagedClientSyncing {
    func push(_ client: ManagedClient) {}
    func pushCoachShare(_ summary: CoachShareSummary, athleteUid: String) {}
    func clearCoachShare(athleteUid: String) {}
    func fetchCoachShare(athleteUid: String) async -> CoachShareSummary? { nil }
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

    private func coachShareDoc(_ athleteUid: String) -> DocumentReference {
        db.collection("users").document(athleteUid).collection("coachShare").document("summary")
    }

    func pushCoachShare(_ summary: CoachShareSummary, athleteUid: String) {
        guard let data = try? encoder.encode(summary),
              let json = String(data: data, encoding: .utf8) else { return }
        // coachUid rides top-level too — it's the field the read rule checks.
        coachShareDoc(athleteUid).setData([
            "schemaVersion": 1,
            "coachUid": summary.coachUid,
            "json": json,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func clearCoachShare(athleteUid: String) {
        coachShareDoc(athleteUid).delete()
    }

    func fetchCoachShare(athleteUid: String) async -> CoachShareSummary? {
        guard let snap = try? await coachShareDoc(athleteUid).getDocument(),
              let json = snap.data()?["json"] as? String,
              let data = json.data(using: .utf8),
              let summary = try? decoder.decode(CoachShareSummary.self, from: data)
        else { return nil }
        return summary
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
        client.claimedByUid = athleteUid
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
            claimedByUid: data["claimedByUid"] as? String ?? "",
            claimedByName: data["claimedByName"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
            logs: logs
        )
    }
}

// MARK: - Real 1:1 messaging (coach ↔ claimed client)
//
// The only real link in Morphe today is a coach and the athlete who CLAIMED
// one of their managed-client codes — messaging is a 1:1 thread between
// exactly that pair. Thread ids are deterministic ("{coachUid}_{athleteUid}",
// the connections scheme), so both sides address the same doc with no lookup.
// Messages are immutable once sent; the thread doc carries a bounded preview
// (lastMessage ≤ 300 chars) so inboxes list without reading subcollections.
//
// Firestore layout (threads rules in BACKEND/firestore.rules):
//   threads/{coachUid_athleteUid}          { coachUid, athleteUid, coachName,
//                                            athleteName, lastMessage,
//                                            lastSender, updatedAt }
//   threads/{threadId}/messages/{msgId}    { senderUid, text, sentAt }

/// Abstraction so tests/previews run without Firebase; the real app resolves
/// `FirebaseMessagingService` (inferred alongside the party service).
protocol MessagingSyncing: AnyObject {
    /// Creates the deterministic thread doc if it doesn't exist yet.
    /// Returns the thread id, or nil when offline/unavailable.
    func ensureThread(coachUid: String, athleteUid: String,
                      coachName: String, athleteName: String) async -> String?
    /// Appends one immutable message and rolls the thread preview forward.
    func send(threadId: String, senderUid: String, text: String) async -> Bool
    /// Every thread this uid participates in (either role), or nil when
    /// offline/unavailable. Two participant-scoped queries, merged.
    func fetchThreads(for uid: String) async -> [MessageThreadSummary]?
    /// Streams the thread's messages (chronological) until `stopListening()`.
    /// Same internal-handle pattern as the party service.
    func listenMessages(threadId: String, onChange: @escaping ([ChatMessage]) -> Void)
    func stopListening()
    /// One-shot fallback when a live listener isn't wanted (newest `limit`,
    /// returned chronological), or nil when offline/unavailable.
    func fetchMessages(threadId: String, limit: Int) async -> [ChatMessage]?
}

final class NoOpMessagingService: MessagingSyncing {
    func ensureThread(coachUid: String, athleteUid: String,
                      coachName: String, athleteName: String) async -> String? { nil }
    func send(threadId: String, senderUid: String, text: String) async -> Bool { false }
    func fetchThreads(for uid: String) async -> [MessageThreadSummary]? { nil }
    func listenMessages(threadId: String, onChange: @escaping ([ChatMessage]) -> Void) {}
    func stopListening() {}
    func fetchMessages(threadId: String, limit: Int) async -> [ChatMessage]? { nil }
}

final class FirebaseMessagingService: MessagingSyncing {
    private var db: Firestore { Firestore.firestore() }
    private var messageListener: ListenerRegistration?

    /// Preview cap — mirrored in the rules (lastMessage.size() <= 300).
    static let previewLimit = 300

    private func threadDoc(_ id: String) -> DocumentReference {
        db.collection("threads").document(id)
    }

    func ensureThread(coachUid: String, athleteUid: String,
                      coachName: String, athleteName: String) async -> String? {
        let threadId = "\(coachUid)_\(athleteUid)"
        let reference = threadDoc(threadId)
        guard let snap = try? await reference.getDocument() else { return nil }
        if snap.exists { return threadId }
        do {
            // Exactly the create shape the rules allow — names freeze here.
            try await reference.setData([
                "coachUid": coachUid,
                "athleteUid": athleteUid,
                "coachName": coachName,
                "athleteName": athleteName,
                "lastMessage": "",
                "lastSender": "",
                "updatedAt": FieldValue.serverTimestamp()
            ])
            return threadId
        } catch {
            return nil
        }
    }

    func send(threadId: String, senderUid: String, text: String) async -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        // One atomic batch: the immutable message + the preview roll-forward,
        // so an inbox can never show a preview whose message doesn't exist.
        let batch = db.batch()
        let message = threadDoc(threadId).collection("messages").document()
        batch.setData([
            "senderUid": senderUid,
            "text": String(clean.prefix(2000)),
            "sentAt": FieldValue.serverTimestamp()
        ], forDocument: message)
        batch.updateData([
            "lastMessage": String(clean.prefix(Self.previewLimit)),
            "lastSender": senderUid,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: threadDoc(threadId))
        do {
            try await batch.commit()
            return true
        } catch {
            return false
        }
    }

    func fetchThreads(for uid: String) async -> [MessageThreadSummary]? {
        // The rules only allow participant-scoped lists, so both roles need
        // their own query; a user is never both sides of one thread.
        guard let asCoach = try? await db.collection("threads")
                .whereField("coachUid", isEqualTo: uid).getDocuments(),
              let asAthlete = try? await db.collection("threads")
                .whereField("athleteUid", isEqualTo: uid).getDocuments()
        else { return nil }
        var seen = Set<String>()
        var threads: [MessageThreadSummary] = []
        for document in asCoach.documents + asAthlete.documents {
            guard seen.insert(document.documentID).inserted,
                  let thread = Self.thread(from: document.documentID, data: document.data())
            else { continue }
            threads.append(thread)
        }
        return threads.sorted { $0.updatedAt > $1.updatedAt }
    }

    func listenMessages(threadId: String, onChange: @escaping ([ChatMessage]) -> Void) {
        stopListening()
        // Bounded window (1000-user audit): the listener's INITIAL snapshot
        // bills a read per doc, and opening a chat is the app's most
        // repeated gesture — 30 keeps it cheap; older history stays in the
        // cloud until a pager wants it.
        messageListener = threadDoc(threadId).collection("messages")
            .order(by: "sentAt")
            .limit(toLast: 30)
            .addSnapshotListener { snap, _ in
                guard let snap else { return }
                onChange(snap.documents.compactMap(Self.message(from:)))
            }
    }

    func stopListening() {
        messageListener?.remove()
        messageListener = nil
    }

    func fetchMessages(threadId: String, limit: Int) async -> [ChatMessage]? {
        guard let snap = try? await threadDoc(threadId).collection("messages")
            .order(by: "sentAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        else { return nil }
        return snap.documents.compactMap(Self.message(from:)).reversed()
    }

    /// Tolerant hand-decode, same per-field-defaults style as the other
    /// services — one malformed field never hides a whole thread.
    private static func thread(from id: String, data: [String: Any]) -> MessageThreadSummary? {
        guard let coachUid = data["coachUid"] as? String,
              let athleteUid = data["athleteUid"] as? String else { return nil }
        return MessageThreadSummary(
            id: id,
            coachUid: coachUid,
            athleteUid: athleteUid,
            coachName: data["coachName"] as? String ?? "Coach",
            athleteName: data["athleteName"] as? String ?? "Athlete",
            lastMessage: data["lastMessage"] as? String ?? "",
            lastSender: data["lastSender"] as? String ?? "",
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? .now
        )
    }

    private static func message(from document: QueryDocumentSnapshot) -> ChatMessage? {
        let data = document.data()
        guard let senderUid = data["senderUid"] as? String,
              let text = data["text"] as? String else { return nil }
        return ChatMessage(
            id: document.documentID,
            senderUid: senderUid,
            text: text,
            // A just-sent message's serverTimestamp is still pending locally —
            // .now keeps it ordered at the bottom instead of dropped.
            sentAt: (data["sentAt"] as? Timestamp)?.dateValue() ?? .now
        )
    }
}

// MARK: - Real community feed (posts, reactions, saves)
//
// The For You surface, backed by real Firestore documents. Posts are
// immutable once published (rules: update == false); a "reaction" is one
// doc per user under the post (doc id = reactor uid), so counts are honest —
// counted, never self-reported. Saved posts live under the owner
// (users/{uid}/savedPosts/{postId}) so bookmarks stay private.
//
// Firestore layout (posts rules in BACKEND/firestore.rules):
//   posts/{postId}                  { authorUid, authorName, verified, text,
//                                     workoutName?, repostOfId?,
//                                     repostOfAuthor?, durationMinutes?,
//                                     setCount?, exerciseCount?, prNames?,
//                                     createdAt }
//   posts/{postId}/reactions/{uid}  { value: true, type?, createdAt }
//   posts/{postId}/comments/{id}    { authorUid, authorName, text, createdAt }
//   users/{uid}/savedPosts/{postId} { savedAt }
//   users/{uid}/following/{target}  { createdAt }

extension String {
    /// Trims to at most `max` UTF-8 bytes without splitting a character.
    /// Swift's `prefix(n)` counts grapheme clusters while the rules' `size()`
    /// counts smaller units — an emoji-heavy "300-character" string can blow
    /// the rule bound and get the whole write denied. Byte-capping is
    /// over-strict but always passes.
    func wireClamped(_ max: Int) -> String {
        var clamped = String(prefix(max))
        while clamped.utf8.count > max, !clamped.isEmpty {
            clamped.removeLast()
        }
        return clamped
    }
}

/// Abstraction so tests/previews run without Firebase; the real app resolves
/// `FirebaseFeedService` (inferred alongside the party service).
protocol FeedSyncing: AnyObject {
    /// Publishes one post exactly as given (id = doc id). False on failure.
    func publish(post: FeedPost) async -> Bool
    /// Newest posts first, or nil when offline/unavailable. `before`
    /// pages older content (createdAt strictly earlier than the cursor).
    func fetchRecent(limit: Int, before: Date?) async -> [FeedPost]?
    /// Posts newer than `date` (presence window) — independent of the
    /// paginated feed so "Trained Today" can't shrink with page size.
    func fetchSince(date: Date, limit: Int) async -> [FeedPost]?
    /// Writes this uid's single reaction doc with `type` ("heart"/"fire"/
    /// "power"/"clap"), or removes it when type is nil. Still one doc per
    /// uid, so counts stay honest whatever the type.
    func react(postId: String, uid: String, type: String?)
    /// Real reaction counts via server-side count() aggregation. Posts whose
    /// count couldn't be fetched are simply absent from the result.
    func fetchReactionCounts(postIds: [String]) async -> [String: Int]
    /// This uid's own reaction per post (postId → type) for the given posts —
    /// hydrates the filled-heart state across relaunches. Nil when offline.
    func fetchMyReactions(uid: String, postIds: [String]) async -> [String: String]?
    /// Oldest-first comments for one post, or nil when offline/unavailable.
    func fetchComments(postId: String, limit: Int) async -> [PostComment]?
    /// Publishes one comment exactly as given (id = doc id). False on failure.
    func addComment(_ comment: PostComment) async -> Bool
    /// Removes one comment (rules enforce author-only).
    func deleteComment(postId: String, commentId: String)
    /// Adds (on) or removes (off) a bookmark under the owner.
    func savePost(uid: String, postId: String, on: Bool)
    /// Every post id this user saved, or nil when offline/unavailable.
    func fetchSavedPostIds(uid: String) async -> Set<String>?
    /// Adds (on) or removes (off) one follow edge under the owner.
    func setFollow(uid: String, targetUid: String, on: Bool)
    /// Every uid this user follows, or nil when offline/unavailable.
    func fetchFollowing(uid: String) async -> Set<String>?
    /// Files one abuse report into reports/ (create-only from clients; the
    /// Morphe team reviews via Tools/review_reports.py). False on failure.
    func submitReport(reporterUid: String, kind: String, targetId: String,
                      targetUid: String, reason: String, excerpt: String) async -> Bool
    /// Adds (on) or removes (off) one block edge under the owner, with the
    /// display name at block time (so the manage list can show WHO).
    func setBlocked(uid: String, targetUid: String, name: String, on: Bool)
    /// Every uid this user blocked (uid -> name), or nil when unavailable.
    func fetchBlocked(uid: String) async -> [String: String]?
    /// Removes one post (rules enforce author-only).
    func delete(postId: String)
}

final class NoOpFeedService: FeedSyncing {
    func publish(post: FeedPost) async -> Bool { false }
    func fetchRecent(limit: Int, before: Date?) async -> [FeedPost]? { nil }
    func fetchSince(date: Date, limit: Int) async -> [FeedPost]? { nil }
    func react(postId: String, uid: String, type: String?) {}
    func fetchReactionCounts(postIds: [String]) async -> [String: Int] { [:] }
    func fetchMyReactions(uid: String, postIds: [String]) async -> [String: String]? { nil }
    func fetchComments(postId: String, limit: Int) async -> [PostComment]? { nil }
    func addComment(_ comment: PostComment) async -> Bool { false }
    func deleteComment(postId: String, commentId: String) {}
    func savePost(uid: String, postId: String, on: Bool) {}
    func fetchSavedPostIds(uid: String) async -> Set<String>? { nil }
    func setFollow(uid: String, targetUid: String, on: Bool) {}
    func fetchFollowing(uid: String) async -> Set<String>? { nil }
    func submitReport(reporterUid: String, kind: String, targetId: String,
                      targetUid: String, reason: String, excerpt: String) async -> Bool { false }
    func setBlocked(uid: String, targetUid: String, name: String, on: Bool) {}
    func fetchBlocked(uid: String) async -> [String: String]? { nil }
    func delete(postId: String) {}
}

final class FirebaseFeedService: FeedSyncing {
    private var db: Firestore { Firestore.firestore() }

    private var posts: CollectionReference { db.collection("posts") }

    private func savedPosts(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("savedPosts")
    }

    func publish(post: FeedPost) async -> Bool {
        // Exactly the create shape the rules allow: optional fields are
        // omitted (not written empty) so keys().hasOnly stays meaningful.
        var data: [String: Any] = [
            "authorUid": post.authorUid,
            "authorName": post.authorName,
            "verified": post.verified,
            "text": post.text.wireClamped(1000),
            "createdAt": FieldValue.serverTimestamp()
        ]
        if !post.workoutName.isEmpty {
            data["workoutName"] = post.workoutName.wireClamped(80)
        }
        if !post.repostOfId.isEmpty {
            data["repostOfId"] = post.repostOfId
            data["repostOfAuthor"] = String(post.repostOfAuthor.prefix(60))
        }
        // Structured session stats (auto-share). Written only when present so
        // plain text posts keep the minimal shape.
        if let minutes = post.durationMinutes { data["durationMinutes"] = minutes }
        if let sets = post.setCount { data["setCount"] = sets }
        if let exercises = post.exerciseCount { data["exerciseCount"] = exercises }
        if !post.prNames.isEmpty { data["prNames"] = Array(post.prNames.prefix(3)) }
        if !post.authorAccent.isEmpty { data["authorAccent"] = String(post.authorAccent.prefix(24)) }
        if !post.authorHeadline.isEmpty { data["authorHeadline"] = String(post.authorHeadline.prefix(80)) }
        // Mirror of the rules cap (90k chars). Clamping here would corrupt
        // the JPEG — an over-budget image is the encoder's bug to fix, so
        // it's dropped whole rather than truncated into garbage.
        if !post.imageB64.isEmpty, post.imageB64.count <= 90_000 {
            data["imageB64"] = post.imageB64
        }
        do {
            try await posts.document(post.id).setData(data)
            return true
        } catch {
            return false
        }
    }

    func fetchSince(date: Date, limit: Int) async -> [FeedPost]? {
        // Same-field range + order — no composite index needed.
        guard let snapshot = try? await posts
            .order(by: "createdAt", descending: true)
            .whereField("createdAt", isGreaterThan: Timestamp(date: date))
            .limit(to: limit)
            .getDocuments()
        else { return nil }
        return snapshot.documents.compactMap { Self.post(from: $0.documentID, data: $0.data()) }
    }

    func fetchRecent(limit: Int, before: Date?) async -> [FeedPost]? {
        var query: Query = posts.order(by: "createdAt", descending: true)
        if let before {
            // Same field as the ordering — no composite index needed.
            query = query.whereField("createdAt", isLessThan: Timestamp(date: before))
        }
        guard let snapshot = try? await query
            .limit(to: limit)
            .getDocuments()
        else { return nil }
        return snapshot.documents.compactMap { Self.post(from: $0.documentID, data: $0.data()) }
    }

    func react(postId: String, uid: String, type: String?) {
        // Fire-and-forget like the other services: Firestore queues the write
        // offline and syncs when the network returns.
        let doc = posts.document(postId).collection("reactions").document(uid)
        if let type {
            doc.setData(["value": true, "type": type, "createdAt": FieldValue.serverTimestamp()])
        } else {
            doc.delete()
        }
    }

    private func comments(_ postId: String) -> CollectionReference {
        posts.document(postId).collection("comments")
    }

    func fetchComments(postId: String, limit: Int) async -> [PostComment]? {
        guard let snapshot = try? await comments(postId)
            .order(by: "createdAt", descending: false)
            .limit(to: limit)
            .getDocuments()
        else { return nil }
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let authorUid = data["authorUid"] as? String,
                  let text = data["text"] as? String else { return nil }
            return PostComment(
                id: document.documentID,
                postId: postId,
                authorUid: authorUid,
                authorName: data["authorName"] as? String ?? "Athlete",
                text: text,
                // Pending serverTimestamp on a just-sent comment: .now keeps
                // it ordered at the bottom instead of dropped.
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now
            )
        }
    }

    func addComment(_ comment: PostComment) async -> Bool {
        let data: [String: Any] = [
            "authorUid": comment.authorUid,
            "authorName": comment.authorName,
            "text": comment.text.wireClamped(300),
            "createdAt": FieldValue.serverTimestamp()
        ]
        do {
            try await comments(comment.postId).document(comment.id).setData(data)
            return true
        } catch {
            return false
        }
    }

    func deleteComment(postId: String, commentId: String) {
        comments(postId).document(commentId).delete()
    }

    private func following(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("following")
    }

    func setFollow(uid: String, targetUid: String, on: Bool) {
        let doc = following(uid).document(targetUid)
        if on {
            doc.setData(["createdAt": FieldValue.serverTimestamp()])
        } else {
            doc.delete()
        }
    }

    func fetchFollowing(uid: String) async -> Set<String>? {
        guard let snapshot = try? await following(uid).getDocuments() else { return nil }
        return Set(snapshot.documents.map(\.documentID))
    }

    func submitReport(reporterUid: String, kind: String, targetId: String,
                      targetUid: String, reason: String, excerpt: String) async -> Bool {
        let data: [String: Any] = [
            "reporterUid": reporterUid,
            "kind": kind,
            "targetId": targetId,
            "targetUid": targetUid,
            "reason": reason,
            "excerpt": excerpt.wireClamped(300),
            "status": "open",
            "createdAt": FieldValue.serverTimestamp()
        ]
        do {
            try await db.collection("reports").document(UUID().uuidString).setData(data)
            return true
        } catch {
            return false
        }
    }

    private func blocked(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("blocked")
    }

    func setBlocked(uid: String, targetUid: String, name: String, on: Bool) {
        let doc = blocked(uid).document(targetUid)
        if on {
            doc.setData(["name": String(name.prefix(60)), "createdAt": FieldValue.serverTimestamp()])
        } else {
            doc.delete()
        }
    }

    func fetchBlocked(uid: String) async -> [String: String]? {
        guard let snapshot = try? await blocked(uid).getDocuments() else { return nil }
        var result: [String: String] = [:]
        for document in snapshot.documents {
            result[document.documentID] = document.data()["name"] as? String ?? "Athlete"
        }
        return result
    }

    func fetchReactionCounts(postIds: [String]) async -> [String: Int] {
        // Server-side count() aggregation (firebase-ios-sdk 10+): one cheap
        // aggregate per post instead of reading every reaction doc.
        var counts: [String: Int] = [:]
        for postId in postIds {
            let query = posts.document(postId).collection("reactions").count
            guard let snap = try? await query.getAggregation(source: .server) else { continue }
            counts[postId] = Int(truncating: snap.count)
        }
        return counts
    }

    func fetchMyReactions(uid: String, postIds: [String]) async -> [String: String]? {
        // One direct doc-get per visible post (max 50), run concurrently —
        // each is the single reactions/{uid} doc, cached offline by Firestore.
        await withTaskGroup(of: (String, String)?.self) { group in
            for postId in postIds {
                let doc = posts.document(postId).collection("reactions").document(uid)
                group.addTask {
                    guard let snap = try? await doc.getDocument(), snap.exists else { return nil }
                    return (postId, snap.data()?["type"] as? String ?? "heart")
                }
            }
            var result: [String: String] = [:]
            for await hit in group {
                if let (postId, type) = hit {
                    result[postId] = type
                }
            }
            return result
        }
    }

    func savePost(uid: String, postId: String, on: Bool) {
        let doc = savedPosts(uid).document(postId)
        if on {
            doc.setData(["savedAt": FieldValue.serverTimestamp()])
        } else {
            doc.delete()
        }
    }

    func fetchSavedPostIds(uid: String) async -> Set<String>? {
        guard let snapshot = try? await savedPosts(uid).getDocuments() else { return nil }
        return Set(snapshot.documents.map(\.documentID))
    }

    func delete(postId: String) {
        posts.document(postId).delete()
    }

    /// Tolerant hand-decode, same per-field-defaults style as the other
    /// services — one malformed field never hides a whole post.
    private static func post(from id: String, data: [String: Any]) -> FeedPost? {
        guard let authorUid = data["authorUid"] as? String,
              let text = data["text"] as? String else { return nil }
        return FeedPost(
            id: id,
            authorUid: authorUid,
            authorName: data["authorName"] as? String ?? "Athlete",
            verified: data["verified"] as? Bool ?? false,
            text: text,
            workoutName: data["workoutName"] as? String ?? "",
            repostOfId: data["repostOfId"] as? String ?? "",
            repostOfAuthor: data["repostOfAuthor"] as? String ?? "",
            // A just-published post's serverTimestamp is still pending in the
            // local cache — .now keeps it at the top instead of dropped.
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
            durationMinutes: data["durationMinutes"] as? Int,
            setCount: data["setCount"] as? Int,
            exerciseCount: data["exerciseCount"] as? Int,
            prNames: data["prNames"] as? [String] ?? [],
            authorAccent: data["authorAccent"] as? String ?? "",
            authorHeadline: data["authorHeadline"] as? String ?? "",
            imageB64: data["imageB64"] as? String ?? ""
        )
    }
}

// MARK: - First-party telemetry (privacy-respecting measurement)
//
// The app's OWN measurement — no third-party SDK, no device fingerprint,
// no ad identifiers, disclosed in the privacy policy. One tiny doc per
// event ({ uid, name, day, createdAt }), write-only from clients (rules
// forbid reads), aggregated only by the founder via the service account
// (Tools/metrics_report.py). This is how retention/activation/loop
// attribution get measured WITHOUT breaking the no-trackers promise.
//
// Firestore layout: telemetry/{autoId} { uid, name, day, createdAt }

protocol TelemetrySyncing: AnyObject {
    /// Fire-and-forget event write. `day` is the local calendar day key.
    func record(uid: String, name: String, day: String)
    /// Account deletion: removes every event this uid ever recorded — the
    /// policy's "deleted with your account" promise, kept client-side.
    func eraseAll(uid: String) async
}

final class NoOpTelemetryService: TelemetrySyncing {
    func record(uid: String, name: String, day: String) {}
    func eraseAll(uid: String) async {}
}

final class FirebaseTelemetryService: TelemetrySyncing {
    private var db: Firestore { Firestore.firestore() }

    func record(uid: String, name: String, day: String) {
        db.collection("telemetry").addDocument(data: [
            "uid": uid,
            "name": String(name.prefix(40)),
            "day": String(day.prefix(10)),
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func eraseAll(uid: String) async {
        // Batched: query own events (rules allow reading exactly these),
        // delete, repeat until empty. Best-effort like the other erases.
        while true {
            guard let snapshot = try? await db.collection("telemetry")
                .whereField("uid", isEqualTo: uid)
                .limit(to: 200)
                .getDocuments(),
                  !snapshot.documents.isEmpty else { return }
            for document in snapshot.documents {
                try? await document.reference.delete()
            }
            if snapshot.documents.count < 200 { return }
        }
    }
}

// MARK: - Referral receipts (who joined through your invite)
//
// One doc per athlete who joined through a user's invite link:
// users/{recruiterUid}/referrals/{referredUid} { createdAt }. The REFERRED
// user writes their own receipt at consume time (rules pin the doc id to
// their auth uid — a receipt nobody else can mint for them, in a ledger
// only the recruiter can read). The count this yields is as honest as the
// auth layer: forging it costs one real account per fake referral.

protocol ReferralSyncing: AnyObject {
    /// The referred user's receipt in the recruiter's ledger — create-once,
    /// fire-and-forget (a duplicate create is denied by rules and ignored).
    func recordReferral(recruiterUid: String, referredUid: String)
    /// Recruiter-side: size of their own ledger. Nil on failure (offline),
    /// so a cached count is never overwritten with a fake zero.
    func referralCount(uid: String) async -> Int?
    /// Account erasure: the referred user deletes the receipts they wrote.
    /// Paths are remembered client-side (recruiter uids), because rules
    /// give the referred user delete on exactly those docs.
    func eraseReceipts(referredUid: String, recruiterUids: [String]) async
}

final class NoOpReferralService: ReferralSyncing {
    func recordReferral(recruiterUid: String, referredUid: String) {}
    func referralCount(uid: String) async -> Int? { nil }
    func eraseReceipts(referredUid: String, recruiterUids: [String]) async {}
}

final class FirebaseReferralService: ReferralSyncing {
    private var db: Firestore { Firestore.firestore() }

    private func receiptDoc(recruiterUid: String, referredUid: String) -> DocumentReference {
        db.collection("users").document(recruiterUid)
            .collection("referrals").document(referredUid)
    }

    func recordReferral(recruiterUid: String, referredUid: String) {
        receiptDoc(recruiterUid: recruiterUid, referredUid: referredUid)
            .setData(["createdAt": FieldValue.serverTimestamp()])
    }

    func referralCount(uid: String) async -> Int? {
        guard let snapshot = try? await db.collection("users").document(uid)
            .collection("referrals").getDocuments() else { return nil }
        return snapshot.documents.count
    }

    func eraseReceipts(referredUid: String, recruiterUids: [String]) async {
        for recruiterUid in recruiterUids {
            try? await receiptDoc(recruiterUid: recruiterUid, referredUid: referredUid).delete()
        }
    }
}

// MARK: - Appointments (personal schedule, per-doc sync)
//
// Each appointment is its OWN document — users/{uid}/appointments/{id} —
// unlike the profile/logs snapshots above, because a schedule appends
// forever: one blob would mean re-uploading the whole history to add one
// entry, and a single corrupt write could nuke it. Per-doc also gets
// Firestore's offline cache per appointment for free, which is why the
// store keeps no file persistence for these.
//
// Firestore layout (owner-only rules in BACKEND/firestore.rules):
//   users/{uid}/appointments/{id}  { title, notes, date, durationMinutes,
//                                    kind, withName, createdByRole, status,
//                                    updatedAt }

/// Abstraction so tests/previews run without Firebase; the real app injects
/// `FirebaseAppointmentService`.
protocol AppointmentSyncing: AnyObject {
    /// Create or update one appointment doc.
    func push(_ appointment: Appointment, uid: String)
    /// Remove one appointment doc.
    func delete(id: String, uid: String)
    /// All of this user's appointments, or nil when offline/unavailable.
    func fetchAll(uid: String) async -> [Appointment]?
}

final class NoOpAppointmentService: AppointmentSyncing {
    func push(_ appointment: Appointment, uid: String) {}
    func delete(id: String, uid: String) {}
    func fetchAll(uid: String) async -> [Appointment]? { nil }
}

final class FirebaseAppointmentService: AppointmentSyncing {
    private var db: Firestore { Firestore.firestore() }

    private func collection(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("appointments")
    }

    func push(_ appointment: Appointment, uid: String) {
        // Fire-and-forget like the other services: Firestore queues the write
        // offline and syncs when the network returns.
        collection(uid).document(appointment.id).setData([
            "schemaVersion": 1,
            "title": appointment.title,
            "notes": appointment.notes,
            "date": Timestamp(date: appointment.date),
            "durationMinutes": appointment.durationMinutes,
            "kind": appointment.kind.rawValue,
            "withName": appointment.withName,
            "withUid": appointment.withUid ?? "",
            "createdByRole": appointment.createdByRole,
            "status": appointment.status,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func delete(id: String, uid: String) {
        collection(uid).document(id).delete()
    }

    func fetchAll(uid: String) async -> [Appointment]? {
        guard let snapshot = try? await collection(uid).getDocuments() else { return nil }
        return snapshot.documents
            .compactMap { appointment(from: $0.documentID, data: $0.data()) }
            .sorted { $0.date < $1.date }
    }

    /// Tolerant hand-decode, same per-field-defaults style as the managed
    /// client service — one malformed field never hides a whole appointment.
    private func appointment(from id: String, data: [String: Any]) -> Appointment? {
        guard let title = data["title"] as? String,
              let date = (data["date"] as? Timestamp)?.dateValue() else { return nil }
        return Appointment(
            id: id,
            title: title,
            notes: data["notes"] as? String ?? "",
            date: date,
            durationMinutes: data["durationMinutes"] as? Int ?? 60,
            kind: (data["kind"] as? String).flatMap(AppointmentKind.init(rawValue:)) ?? .custom,
            withName: data["withName"] as? String ?? "",
            withUid: (data["withUid"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            createdByRole: data["createdByRole"] as? String ?? "",
            status: data["status"] as? String ?? Appointment.statusScheduled
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

    func pushLogs(_ logs: [WorkoutLog]) async -> Bool {
        guard let doc = stateDoc("logs"),
              let data = try? encoder.encode(logs),
              let json = String(data: data, encoding: .utf8) else { return false }
        do {
            try await doc.setData([
                "schemaVersion": 1,
                "count": logs.count,
                "json": json,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            return true
        } catch {
            return false
        }
    }

    func pushWeightHistory(_ entries: [MorpheAppStore.BodyWeightHistoryEntry]) {
        guard let doc = stateDoc("weightHistory") else { return }
        // MERGE, never blind-overwrite: if a fresh install's restore silently
        // failed (offline pull), the local series is 1 entry while the cloud
        // holds the real trend — a whole-blob write here would destroy the
        // exact data this doc exists to protect. Union by date instead.
        let encoder = self.encoder
        let decoder = self.decoder
        Task {
            var merged = entries
            if let snap = try? await doc.getDocument(),
               let json = snap.data()?["json"] as? String,
               let data = json.data(using: .utf8),
               let cloud = try? decoder.decode([MorpheAppStore.BodyWeightHistoryEntry].self, from: data) {
                var byDate: [Date: MorpheAppStore.BodyWeightHistoryEntry] = [:]
                for entry in cloud { byDate[entry.date] = entry }
                for entry in entries { byDate[entry.date] = entry }   // local wins on same-date edits
                merged = byDate.values.sorted { $0.date < $1.date }
                if merged.count > 200 {
                    merged.removeFirst(merged.count - 200)
                }
            }
            guard let data = try? encoder.encode(merged),
                  let json = String(data: data, encoding: .utf8) else { return }
            // Best-effort like every backup write — a failed push retries on
            // the next reading via Firestore's offline queue.
            try? await doc.setData([
                "schemaVersion": 1,
                "count": merged.count,
                "json": json,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }
    }

    func pushExtras(_ blobs: [String: String]) {
        guard let doc = stateDoc("extras"), !blobs.isEmpty else { return }
        // MERGE by blob name, same reasoning as pushWeightHistory: a fresh
        // device that only has (say) training prefs so far must not erase
        // the cloud's program state. Local wins per name; absent names keep
        // their cloud value.
        let encoder = self.encoder
        let decoder = self.decoder
        Task {
            var merged = blobs
            if let snap = try? await doc.getDocument(),
               let json = snap.data()?["json"] as? String,
               let data = json.data(using: .utf8),
               let cloud = try? decoder.decode([String: String].self, from: data) {
                merged = cloud.merging(blobs) { _, local in local }
            }
            guard let data = try? encoder.encode(merged),
                  let json = String(data: data, encoding: .utf8) else { return }
            try? await doc.setData([
                "schemaVersion": 1,
                "count": merged.count,
                "json": json,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }
    }

    func eraseUser() async {
        for name in ["profile", "logs", "weightHistory", "extras"] {
            if let doc = stateDoc(name) {
                try? await doc.delete()
            }
        }
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

        if let doc = stateDoc("weightHistory"),
           let snap = try? await doc.getDocument(),
           let json = snap.data()?["json"] as? String,
           let data = json.data(using: .utf8),
           let entries = try? decoder.decode([MorpheAppStore.BodyWeightHistoryEntry].self, from: data) {
            result.weightHistory = entries
        }

        if let doc = stateDoc("extras"),
           let snap = try? await doc.getDocument(),
           let json = snap.data()?["json"] as? String,
           let data = json.data(using: .utf8),
           let blobs = try? decoder.decode([String: String].self, from: data) {
            result.extras = blobs
        }

        return result
    }
}
