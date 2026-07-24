import Foundation
import FirebaseFirestore

// MARK: - Train Together (workout parties)
//
// One concept, all modes: a "party" is a small Firestore document holding a
// workout snapshot plus a members subcollection. In-person and virtual differ
// only in how much live sync the UI shows — the data model is identical, so
// group/class mode later is the same plumbing with more members.
//
// Firestore layout (see the parties block in the security rules):
//   parties/{code}                  { mode, hostID, hostName, workoutName,
//                                     workoutJSON, createdAt }
//   parties/{code}/members/{uid}    { name, email, isHost, joinedAt, ready,
//                                     exerciseName, setsDone, finished,
//                                     summary, updatedAt }
//   parties/{code}/nudges/{auto}    { fromName, emoji, sentAt }
//
// Honest boundary: no video, no audio — a virtual session syncs progress and
// nudges; the FaceTime button hands off to Apple's app.

enum PartyMode: String {
    case inPerson = "inPerson"
    case virtualSession = "virtual"
    case group = "group"
}

/// Buddy sessions are always live; group classes open in a lobby and go
/// live when the host starts everyone at once.
enum PartyStatus: String {
    case lobby
    case live
}

/// One person in the party. Progress fields stay at their defaults until the
/// member publishes something (Phase 2 live sync / end-of-session summary).
struct PartyParticipant: Identifiable, Hashable {
    var id: String
    var name: String
    var email: String
    var isHost: Bool
    var isReady: Bool = false
    var exerciseName: String = ""
    var setsDone: Int = 0
    /// Whole-session set count — the group leaderboard's ranking key.
    var totalSetsDone: Int = 0
    var isFinished: Bool = false
    /// One-line totals ("5 exercises · 14 sets · 32 min"), written at log time.
    var summary: String = ""
}

struct PartyNudge: Identifiable, Hashable {
    var id: String
    var fromID: String
    var fromName: String
    var emoji: String
}

struct WorkoutParty: Hashable {
    /// Six-character join code; doubles as the Firestore document id.
    var id: String
    var mode: PartyMode
    var hostID: String
    var hostName: String
    var workoutName: String
    var status: PartyStatus = .live
    /// Advertised class time (informational — the host still starts it).
    var startsAt: Date?
    var participants: [PartyParticipant] = []
}

/// The reduced, Codable form of a workout that travels inside the party doc —
/// enough for a buddy's phone to run the exact same session.
struct PartyWorkoutSnapshot: Codable {
    struct Exercise: Codable {
        var id: String
        var exerciseLibraryID: String
        var name: String
        var muscleGroup: String
        var sets: String
        var reps: String
        var formCue: String
        var intensityLabel: String
        var restSeconds: Int?
    }

    var name: String
    var goal: String
    var durationMinutes: Int
    var sport: String
    var exercises: [Exercise]

    init(template: WorkoutTemplate) {
        name = template.name
        goal = template.goal
        durationMinutes = template.durationMinutes
        sport = template.sport.rawValue
        exercises = template.exercises.map {
            Exercise(
                id: $0.id,
                exerciseLibraryID: $0.exerciseLibraryID,
                name: $0.name,
                muscleGroup: $0.muscleGroup.rawValue,
                sets: $0.sets,
                reps: $0.reps,
                formCue: $0.formCue,
                intensityLabel: $0.intensityLabel,
                restSeconds: $0.restSeconds
            )
        }
    }

    /// Rebuilds a runnable template on the joining phone. A fresh UUID keeps
    /// it out of the way of the buddy's own library content.
    func makeTemplate() -> WorkoutTemplate {
        WorkoutTemplate(
            name: name,
            type: "Buddy Session",
            sport: SportFocus(rawValue: sport) ?? .generalFitness,
            goal: goal,
            difficulty: .moderate,
            durationMinutes: durationMinutes,
            equipment: "",
            exercises: exercises.map {
                WorkoutExercise(
                    id: $0.id,
                    exerciseLibraryID: $0.exerciseLibraryID,
                    name: $0.name,
                    muscleGroup: MuscleGroup(rawValue: $0.muscleGroup) ?? .conditioning,
                    sets: $0.sets,
                    reps: $0.reps,
                    difficulty: .moderate,
                    formCue: $0.formCue,
                    intensityLabel: $0.intensityLabel,
                    restSeconds: $0.restSeconds
                )
            },
            notes: "Shared by your training partner.",
            coachNote: ""
        )
    }
}

/// Live progress one member publishes while training (Phase 2 sync).
struct PartyProgressUpdate {
    var exerciseName: String
    var setsDone: Int
    var totalSetsDone: Int
    var isReady: Bool
    var isFinished: Bool
}

/// Abstraction so the store runs without Firebase (tests use a mock, previews
/// the no-op). The real app injects `FirebasePartyService`.
protocol WorkoutPartying: AnyObject {
    func createParty(_ party: WorkoutParty, host: PartyParticipant, workout: PartyWorkoutSnapshot) async -> Bool
    func fetchParty(code: String) async -> (party: WorkoutParty, workout: PartyWorkoutSnapshot)?
    func join(partyID: String, participant: PartyParticipant) async -> Bool
    func leave(partyID: String, participantID: String) async
    /// Host-only (enforced by the security rules): flips a lobby live.
    func updateStatus(partyID: String, status: PartyStatus)
    func publishProgress(partyID: String, participantID: String, progress: PartyProgressUpdate)
    func publishSummary(partyID: String, participantID: String, summary: String)
    func sendNudge(partyID: String, from participant: PartyParticipant, emoji: String)
    /// Streams status + member + nudge changes until `stopListening()`.
    func listen(partyID: String,
                onStatus: @escaping (PartyStatus) -> Void,
                onMembers: @escaping ([PartyParticipant]) -> Void,
                onNudge: @escaping (PartyNudge) -> Void)
    func stopListening()
}

/// Default that does nothing — keeps the store fully functional offline and
/// keeps the test suite off the network.
final class NoOpPartyService: WorkoutPartying {
    func createParty(_ party: WorkoutParty, host: PartyParticipant, workout: PartyWorkoutSnapshot) async -> Bool { false }
    func fetchParty(code: String) async -> (party: WorkoutParty, workout: PartyWorkoutSnapshot)? { nil }
    func join(partyID: String, participant: PartyParticipant) async -> Bool { false }
    func leave(partyID: String, participantID: String) async {}
    func updateStatus(partyID: String, status: PartyStatus) {}
    func publishProgress(partyID: String, participantID: String, progress: PartyProgressUpdate) {}
    func publishSummary(partyID: String, participantID: String, summary: String) {}
    func sendNudge(partyID: String, from participant: PartyParticipant, emoji: String) {}
    func listen(partyID: String,
                onStatus: @escaping (PartyStatus) -> Void,
                onMembers: @escaping ([PartyParticipant]) -> Void,
                onNudge: @escaping (PartyNudge) -> Void) {}
    func stopListening() {}
}

final class FirebasePartyService: WorkoutPartying {
    private var db: Firestore { Firestore.firestore() }
    private var partyListener: ListenerRegistration?
    private var memberListener: ListenerRegistration?
    private var nudgeListener: ListenerRegistration?
    /// Nudges that existed before we started listening (or that we already
    /// surfaced) — only genuinely new ones reach the UI.
    private var seenNudgeIDs = Set<String>()

    private func partyDoc(_ code: String) -> DocumentReference {
        db.collection("parties").document(code)
    }

    func createParty(_ party: WorkoutParty, host: PartyParticipant, workout: PartyWorkoutSnapshot) async -> Bool {
        guard let workoutData = try? JSONEncoder().encode(workout),
              let workoutJSON = String(data: workoutData, encoding: .utf8) else { return false }
        do {
            var data: [String: Any] = [
                "mode": party.mode.rawValue,
                "hostID": party.hostID,
                "hostName": party.hostName,
                "workoutName": party.workoutName,
                "workoutJSON": workoutJSON,
                "status": party.status.rawValue,
                "createdAt": FieldValue.serverTimestamp()
            ]
            if let startsAt = party.startsAt {
                data["startsAt"] = Timestamp(date: startsAt)
            }
            try await partyDoc(party.id).setData(data)
            return await join(partyID: party.id, participant: host)
        } catch {
            return false
        }
    }

    func updateStatus(partyID: String, status: PartyStatus) {
        partyDoc(partyID).setData(["status": status.rawValue], merge: true)
    }

    func fetchParty(code: String) async -> (party: WorkoutParty, workout: PartyWorkoutSnapshot)? {
        guard let snap = try? await partyDoc(code).getDocument(),
              let data = snap.data(),
              let modeRaw = data["mode"] as? String,
              let mode = PartyMode(rawValue: modeRaw),
              let workoutJSON = data["workoutJSON"] as? String,
              let workoutData = workoutJSON.data(using: .utf8),
              let workout = try? JSONDecoder().decode(PartyWorkoutSnapshot.self, from: workoutData)
        else { return nil }

        var party = WorkoutParty(
            id: code,
            mode: mode,
            hostID: data["hostID"] as? String ?? "",
            hostName: data["hostName"] as? String ?? "",
            workoutName: data["workoutName"] as? String ?? workout.name,
            status: (data["status"] as? String).flatMap(PartyStatus.init(rawValue:)) ?? .live,
            startsAt: (data["startsAt"] as? Timestamp)?.dateValue()
        )
        if let members = try? await partyDoc(code).collection("members").getDocuments() {
            party.participants = members.documents.map { Self.participant(from: $0) }
        }
        return (party, workout)
    }

    func join(partyID: String, participant: PartyParticipant) async -> Bool {
        do {
            try await partyDoc(partyID).collection("members").document(participant.id).setData([
                "name": participant.name,
                "email": participant.email,
                "isHost": participant.isHost,
                "ready": false,
                "exerciseName": "",
                "setsDone": 0,
                "totalSetsDone": 0,
                "finished": false,
                "summary": "",
                "joinedAt": FieldValue.serverTimestamp()
            ])
            return true
        } catch {
            return false
        }
    }

    func leave(partyID: String, participantID: String) async {
        try? await partyDoc(partyID).collection("members").document(participantID).delete()
    }

    func publishProgress(partyID: String, participantID: String, progress: PartyProgressUpdate) {
        // Merge, no completion: Firestore queues offline and syncs when it can.
        partyDoc(partyID).collection("members").document(participantID).setData([
            "exerciseName": progress.exerciseName,
            "setsDone": progress.setsDone,
            "totalSetsDone": progress.totalSetsDone,
            "ready": progress.isReady,
            "finished": progress.isFinished,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func publishSummary(partyID: String, participantID: String, summary: String) {
        partyDoc(partyID).collection("members").document(participantID).setData([
            "summary": summary,
            "finished": true,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func sendNudge(partyID: String, from participant: PartyParticipant, emoji: String) {
        partyDoc(partyID).collection("nudges").addDocument(data: [
            "fromID": participant.id,
            "fromName": participant.name,
            "emoji": emoji,
            "sentAt": FieldValue.serverTimestamp()
        ])
    }

    func listen(partyID: String,
                onStatus: @escaping (PartyStatus) -> Void,
                onMembers: @escaping ([PartyParticipant]) -> Void,
                onNudge: @escaping (PartyNudge) -> Void) {
        stopListening()
        partyListener = partyDoc(partyID).addSnapshotListener { snap, _ in
            guard let raw = snap?.data()?["status"] as? String,
                  let status = PartyStatus(rawValue: raw) else { return }
            onStatus(status)
        }
        memberListener = partyDoc(partyID).collection("members").addSnapshotListener { snap, _ in
            guard let snap else { return }
            onMembers(snap.documents.map { Self.participant(from: $0) })
        }
        nudgeListener = partyDoc(partyID).collection("nudges").addSnapshotListener { [weak self] snap, _ in
            guard let self, let snap else { return }
            for change in snap.documentChanges where change.type == .added {
                let doc = change.document
                guard !self.seenNudgeIDs.contains(doc.documentID) else { continue }
                self.seenNudgeIDs.insert(doc.documentID)
                // The first snapshot replays history; only surface fresh sends.
                guard doc.data()["sentAt"] != nil || !snap.metadata.isFromCache else { continue }
                onNudge(PartyNudge(
                    id: doc.documentID,
                    fromID: doc.data()["fromID"] as? String ?? "",
                    fromName: doc.data()["fromName"] as? String ?? "Buddy",
                    emoji: doc.data()["emoji"] as? String ?? "🔥"
                ))
            }
        }
    }

    func stopListening() {
        partyListener?.remove()
        memberListener?.remove()
        nudgeListener?.remove()
        partyListener = nil
        memberListener = nil
        nudgeListener = nil
        seenNudgeIDs = []
    }

    private static func participant(from doc: QueryDocumentSnapshot) -> PartyParticipant {
        let data = doc.data()
        return PartyParticipant(
            id: doc.documentID,
            name: data["name"] as? String ?? "Buddy",
            email: data["email"] as? String ?? "",
            isHost: data["isHost"] as? Bool ?? false,
            isReady: data["ready"] as? Bool ?? false,
            exerciseName: data["exerciseName"] as? String ?? "",
            setsDone: data["setsDone"] as? Int ?? 0,
            totalSetsDone: data["totalSetsDone"] as? Int ?? 0,
            isFinished: data["finished"] as? Bool ?? false,
            summary: data["summary"] as? String ?? ""
        )
    }
}

// MARK: - Weekly leaderboard + challenges (opt-in competition)
//
// Firestore layout (leaderboards/challenges blocks in BACKEND/firestore.rules):
//   leaderboards/{weekKey}/entries/{uid}   { uid, name, verified, score,
//                                            workouts, updatedAt }
//   challenges/{code}                      { hostUid, hostName, title, metric,
//                                            startsAt, endsAt, createdAt }
//   challenges/{code}/members/{uid}        { name, verified, score, updatedAt }
//
// Honest boundaries: every row is a real signed-in account's own write (the
// rules pin each entry to its uid); scores derive from the user's own logged
// sets; `verified` can only mirror the server-granted badge. Nothing here is
// seeded, simulated, or ranked beyond what was actually fetched.

/// Monday-anchored ISO year-week key ("2026-W30") — the weekly board's
/// document id. Pure and injectable so tests can pin dates and zones.
enum LeaderboardWeek {
    static func key(for date: Date = .now, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .iso8601)   // ISO 8601 weeks start Monday
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", parts.yearForWeekOfYear ?? 0, parts.weekOfYear ?? 0)
    }

    /// The Monday-00:00 start of `date`'s ISO week — the window scores count.
    static func start(of date: Date = .now, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }
}

/// Abstraction so the store runs without Firebase (tests use a mock, previews
/// the no-op). The real app injects `FirebaseLeaderboardService`.
protocol LeaderboardSyncing: AnyObject {
    // Weekly board
    /// Upsert the user's own entry (fire-and-forget; Firestore queues offline).
    func postScore(weekKey: String, entry: WeeklyLeaderboardEntry)
    /// Top entries by score, or nil when offline/unavailable.
    func fetchTop(weekKey: String, limit: Int) async -> [WeeklyLeaderboardEntry]?
    /// One user's entry, nil when they haven't posted this week.
    func fetchEntry(weekKey: String, uid: String) async -> WeeklyLeaderboardEntry?

    // Challenges
    func createChallenge(_ challenge: ChallengeSummary, host: ChallengeMember) async -> Bool
    /// Joins by code; returns the challenge (with members) or nil when the
    /// code resolves to nothing / the write fails.
    func joinChallenge(code: String, member: ChallengeMember) async -> ChallengeSummary?
    /// The challenge plus its current members, nil when the code is unknown.
    func fetchChallenge(code: String) async -> ChallengeSummary?
    /// Upsert the user's own member score (fire-and-forget).
    func postChallengeScore(code: String, member: ChallengeMember)
}

/// Default that does nothing — keeps the store fully functional offline and
/// keeps the test suite off the network.
final class NoOpLeaderboardService: LeaderboardSyncing {
    func postScore(weekKey: String, entry: WeeklyLeaderboardEntry) {}
    func fetchTop(weekKey: String, limit: Int) async -> [WeeklyLeaderboardEntry]? { nil }
    func fetchEntry(weekKey: String, uid: String) async -> WeeklyLeaderboardEntry? { nil }
    func createChallenge(_ challenge: ChallengeSummary, host: ChallengeMember) async -> Bool { false }
    func joinChallenge(code: String, member: ChallengeMember) async -> ChallengeSummary? { nil }
    func fetchChallenge(code: String) async -> ChallengeSummary? { nil }
    func postChallengeScore(code: String, member: ChallengeMember) {}
}

final class FirebaseLeaderboardService: LeaderboardSyncing {
    private var db: Firestore { Firestore.firestore() }

    private func entries(_ weekKey: String) -> CollectionReference {
        db.collection("leaderboards").document(weekKey).collection("entries")
    }

    private func challengeDoc(_ code: String) -> DocumentReference {
        db.collection("challenges").document(code)
    }

    // MARK: Weekly board

    func postScore(weekKey: String, entry: WeeklyLeaderboardEntry) {
        // Merge, no completion: Firestore queues offline and syncs when it can.
        entries(weekKey).document(entry.uid).setData([
            "uid": entry.uid,
            "name": entry.name,
            "verified": entry.verified,
            "score": entry.score,
            "workouts": entry.workouts,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func fetchTop(weekKey: String, limit: Int) async -> [WeeklyLeaderboardEntry]? {
        guard let snapshot = try? await entries(weekKey)
            .order(by: "score", descending: true)
            .limit(to: limit)
            .getDocuments()
        else { return nil }
        return snapshot.documents.compactMap { Self.entry(from: $0.documentID, data: $0.data()) }
    }

    func fetchEntry(weekKey: String, uid: String) async -> WeeklyLeaderboardEntry? {
        guard let snap = try? await entries(weekKey).document(uid).getDocument(),
              snap.exists, let data = snap.data() else { return nil }
        return Self.entry(from: snap.documentID, data: data)
    }

    // MARK: Challenges

    func createChallenge(_ challenge: ChallengeSummary, host: ChallengeMember) async -> Bool {
        do {
            try await challengeDoc(challenge.code).setData([
                "hostUid": challenge.hostUid,
                "hostName": challenge.hostName,
                "title": challenge.title,
                "metric": challenge.metric.rawValue,
                "startsAt": Timestamp(date: challenge.startsAt),
                "endsAt": Timestamp(date: challenge.endsAt),
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch {
            return false
        }
        return await writeMember(code: challenge.code, member: host)
    }

    func joinChallenge(code: String, member: ChallengeMember) async -> ChallengeSummary? {
        guard let challenge = await fetchChallenge(code: code) else { return nil }
        guard await writeMember(code: code, member: member) else { return nil }
        var joined = challenge
        joined.members.removeAll { $0.uid == member.uid }
        joined.members.append(member)
        return joined
    }

    func fetchChallenge(code: String) async -> ChallengeSummary? {
        guard let snap = try? await challengeDoc(code).getDocument(),
              snap.exists, let data = snap.data(),
              var challenge = Self.challenge(from: snap.documentID, data: data)
        else { return nil }
        if let members = try? await challengeDoc(code).collection("members").getDocuments() {
            challenge.members = members.documents.compactMap {
                Self.member(from: $0.documentID, data: $0.data())
            }
        }
        return challenge
    }

    func postChallengeScore(code: String, member: ChallengeMember) {
        challengeDoc(code).collection("members").document(member.uid).setData([
            "name": member.name,
            "verified": member.verified,
            "score": member.score,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func writeMember(code: String, member: ChallengeMember) async -> Bool {
        do {
            try await challengeDoc(code).collection("members").document(member.uid).setData([
                "name": member.name,
                "verified": member.verified,
                "score": member.score,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            return true
        } catch {
            return false
        }
    }

    // MARK: Tolerant hand-decodes (same per-field-defaults style as the
    // party service — one malformed field never hides a whole row)

    private static func entry(from uid: String, data: [String: Any]) -> WeeklyLeaderboardEntry? {
        guard let name = data["name"] as? String else { return nil }
        return WeeklyLeaderboardEntry(
            uid: uid,
            name: name,
            verified: data["verified"] as? Bool ?? false,
            score: data["score"] as? Int ?? 0,
            workouts: data["workouts"] as? Int ?? 0,
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }

    private static func member(from uid: String, data: [String: Any]) -> ChallengeMember? {
        guard let name = data["name"] as? String else { return nil }
        return ChallengeMember(
            uid: uid,
            name: name,
            verified: data["verified"] as? Bool ?? false,
            score: data["score"] as? Int ?? 0,
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }

    private static func challenge(from code: String, data: [String: Any]) -> ChallengeSummary? {
        guard let hostUid = data["hostUid"] as? String,
              let title = data["title"] as? String,
              let startsAt = (data["startsAt"] as? Timestamp)?.dateValue(),
              let endsAt = (data["endsAt"] as? Timestamp)?.dateValue()
        else { return nil }
        return ChallengeSummary(
            code: code,
            hostUid: hostUid,
            hostName: data["hostName"] as? String ?? "",
            title: title,
            metric: (data["metric"] as? String).flatMap(ChallengeMetric.init(rawValue:)) ?? .sets,
            startsAt: startsAt,
            endsAt: endsAt
        )
    }
}
