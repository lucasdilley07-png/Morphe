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
