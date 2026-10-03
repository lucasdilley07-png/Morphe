import SwiftUI
import AVFoundation
import Vision

// MARK: - Form Check
//
// On-device ONLY. Vision runs on the raw camera buffer; nothing — least of all
// video — ever leaves the phone. The camera coach frames the athlete, draws
// their skeleton, learns their build, counts reps, and reads what a single
// phone camera can honestly read: joint angles, range, tempo, symmetry, and
// alignment. It never diagnoses. The honesty bar is highest here because a
// wrong cue under a loaded bar is an injury.
//
// Architecture (2026-10-02 rebuild):
//   FormMovementPattern / FormPatternSpec — the movement library: for every
//     camera-trackable pattern, the joints that define it, which way a rep
//     travels, the thresholds that count it, and the posture it is framed in.
//   RepDetector — a PURE state machine over joint angles (unit-tested with
//     synthetic motion), hysteresis + minimum duration + false-start rejection.
//   BodyCalibrator — learns the athlete's build (torso, leg, shoulder width,
//     standing hip height, front vs side view) from still frames, so framing
//     and every proportion-based check are relative to THEM, not to pixels.
//   FormAnalyzer — PURE per-pattern form checks → ranked cues + a rep grade.
//   FormCheckSession — the camera + Vision pipeline that feeds the above.
//
// The iOS Simulator has no camera, so `configure()` resolves to `.unavailable`
// there and the screen shows a device-required state. The live pipeline must be
// verified on a physical iPhone.

typealias PoseJoints = [VNHumanBodyPoseObservation.JointName: CGPoint]

/// One pose observation in view space: normalized (0...1), top-left origin,
/// mirrored to match the front-camera preview, with the frame's timestamp.
struct PoseFrame {
    var joints: PoseJoints
    var time: Double
}

// MARK: Movement library

/// The camera-trackable movement patterns. Every library exercise resolves
/// to one of these (see `infer`); `untracked` is the honest answer for what
/// a single front camera cannot read (carries, sprints, stretches, dance).
enum FormMovementPattern: String, CaseIterable, Codable {
    case squat, hinge, lunge, bridge, push, press, pull, curl, armExtension, raise, jump, hold, untracked

    var spec: FormPatternSpec { FormPatternSpec.table[self]! }

    /// Resolves an exercise to its pattern from the library's own movement
    /// pattern string first, then the name, then the muscle group. Order
    /// matters: "Jump Squat" is a jump, "Bulgarian Split Squat" is a lunge,
    /// "Nordic Hamstring Curl" is not a curl.
    static func infer(exerciseName: String, libraryPattern: String? = nil, muscleGroup: MuscleGroup) -> FormMovementPattern {
        let n = exerciseName.lowercased()
        let p = (libraryPattern ?? "").lowercased()
        func has(_ words: String...) -> Bool { words.contains { n.contains($0) || p.contains($0) } }

        // Holds and isometrics first — they are named after the posture.
        if has("plank", "hold", "wall sit", "hollow", "chair pose", "warrior", "cobra", "superman",
               "handstand", "isometric", "pilates hundred", "dead bug", "bird dog") { return .hold }
        // What a single front camera cannot read: locomotion, carries,
        // machines, stretches, striking, ground flow. Timed, honestly.
        if has("stretch", "mobility", "pose", "treadmill", "rowing machine", "bike", "carry",
               "sprint", "flying", "hill", "drill", "crawl", "shuffle", "carioca", "ladder", "shuttle", "boxing",
               "heavy bag", "jab", "punch", "slam", "throw", "toss", "sled", "step touch", "grapevine",
               "dance", "get-up", "halo", "escape", "front kick", "side kick", "downward dog", "cat-cow",
               "roll-up", "circle", "swimming", "teaser", "spine twist", "leg pull", "shrug", "flutter",
               "nordic", "hamstring curl", "leg extension", "leg curl", "calf", "pullover", "arm swing",
               // Straight-arm and fixed-elbow work: the elbow angle never moves, so
               // there is nothing honest to count. Rotations and reaches likewise.
               "pull-apart", "pull apart", "straight-arm", "scapular", "fly", "crossover", "knee raise",
               "leg raise", "rotation", "needle", "wave", "reach", "slip", "boxer", "pallof", "wall ball") { return .untracked }
        // Explosive and rhythmic lower-body work counts jumps, not depth.
        if has("jump", "hop", "bound", "bibasis", "double under", "skater", "burpee", "tuck", "pogo", "sprawl") { return .jump }
        // Supine hip extension: the hip OPENS at the top.
        if has("bridge", "hip thrust") { return .bridge }
        // Single-leg knee-dominant work.
        if has("lunge", "split squat", "split-squat", "step-up", "step up", "step-down", "step down",
               "single-leg squat", "pistol", "bulgarian", "split stance") { return .lunge }
        if has("squat", "leg press", "thruster") { return .squat }
        if has("deadlift", "rdl", "hinge", "swing", "good morning", "back extension", "clean", "snatch", "scoop") { return .hinge }
        // Arms: curls before pulls ("Hammer Curl" contains no "pull"), and
        // never a hamstring/nordic "curl", which is a knee movement.
        if has("curl"), !has("hamstring", "nordic", "leg curl") { return .curl }
        if has("pushdown", "skullcrusher", "skull crusher", "tricep extension", "triceps extension",
               "overhead extension", "cable extension", "kickback") { return .armExtension }
        if has("lateral raise", "front raise", "raise") { return .raise }
        if has("pull-up", "pull up", "pullup", "chin-up", "chin up", "pulldown", "row", "pull-apart",
               "pull apart", "face pull", "pull") { return .pull }
        // Push-ups and dips first ("Incline Push-Up" is a push-up), then
        // overhead and incline PRESSING, where the elbow OPENS at the top.
        if has("push-up", "push up", "pushup", "dip", "bench", "chest press", "chest pass") { return .push }
        if has("overhead press", "shoulder press", "arnold", "push press", "landmine press", "military",
               "seated dumbbell press", "incline") { return .press }
        if has("press") { return .press }

        switch muscleGroup {
        case .chest: return .push
        case .shoulders: return .press
        case .back: return .pull
        case .arms: return .curl
        case .legs: return .squat
        case .core, .conditioning: return .untracked
        }
    }
}

/// Everything the detector and analyzer need to know about one pattern.
struct FormPatternSpec {
    enum Posture { case standingFull, standingUpper, horizontal }

    typealias Triple = (VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)

    let pattern: FormMovementPattern
    /// Shown in the header: "SQUAT PATTERN".
    let label: String
    /// The joint whose angle is the rep: "knee", "hip", "elbow", "shoulder".
    let angleName: String
    /// Left and right versions of the primary angle (a–b–c, measured at b).
    let left: Triple
    let right: Triple
    /// Which way a rep travels. A closing pattern (squat) rests extended and
    /// turns at a small angle; an opening pattern (press) rests flexed and
    /// turns at a large angle.
    let restsExtended: Bool
    /// Arm the rep once the primary angle passes this…
    let turnAt: CGFloat
    /// …and bank it once the angle returns past this (hysteresis).
    let resetAt: CGFloat
    /// The excursion that reads as a full rep, and the one short of which a
    /// rep is called shallow.
    let fullRange: CGFloat
    let shallowRange: CGFloat
    let posture: Posture
    let setupHint: String
    /// Plain-English meaning of the number on the review screen.
    let rangeNote: String

    var countsReps: Bool { pattern != .hold && pattern != .untracked }
    /// Squats, lunges and landings can show the knees caving (front view only).
    var readsKnees: Bool { [.squat, .lunge, .jump].contains(pattern) }
    /// +1 when excursion means a LARGER angle, −1 when it means a smaller one.
    var direction: CGFloat { restsExtended ? -1 : 1 }

    /// True when `peak` reached full range for this pattern.
    func isFull(_ peak: CGFloat) -> Bool { direction * (peak - fullRange) >= 0 }
    /// True when `peak` stopped short of the shallow line.
    func isShallow(_ peak: CGFloat) -> Bool { direction * (peak - shallowRange) < 0 }
    /// Ranks two peaks: true when `a` is the fuller rep.
    func isFuller(_ a: CGFloat, than b: CGFloat) -> Bool { direction * (a - b) > 0 }

    static let table: [FormMovementPattern: FormPatternSpec] = {
        var t: [FormMovementPattern: FormPatternSpec] = [:]
        func add(_ s: FormPatternSpec) { t[s.pattern] = s }
        add(FormPatternSpec(
            pattern: .squat, label: "Squat pattern", angleName: "knee",
            left: (.leftHip, .leftKnee, .leftAnkle), right: (.rightHip, .rightKnee, .rightAnkle),
            restsExtended: true, turnAt: 115, resetAt: 150, fullRange: 100, shallowRange: 112,
            posture: .standingFull,
            setupHint: "Face the camera (knee tracking) or stand side-on (depth), whole body in frame, feet visible. Hold still a moment first.",
            rangeNote: "A smaller knee angle is a deeper squat — about 90–100° is parallel. Facing the camera, depth is read from how far your hips drop against your own leg length."))
        add(FormPatternSpec(
            pattern: .hinge, label: "Hinge pattern", angleName: "hip",
            left: (.leftShoulder, .leftHip, .leftKnee), right: (.rightShoulder, .rightHip, .rightKnee),
            restsExtended: true, turnAt: 130, resetAt: 160, fullRange: 105, shallowRange: 125,
            posture: .standingFull,
            setupHint: "Stand side-on to the camera, whole body in frame. Push the hips back.",
            rangeNote: "A smaller hip angle is a deeper hinge — about 90–105° is a full hinge."))
        add(FormPatternSpec(
            pattern: .lunge, label: "Lunge pattern", angleName: "front knee",
            left: (.leftHip, .leftKnee, .leftAnkle), right: (.rightHip, .rightKnee, .rightAnkle),
            restsExtended: true, turnAt: 115, resetAt: 150, fullRange: 100, shallowRange: 115,
            posture: .standingFull,
            setupHint: "Face the camera or stand side-on, whole body in frame. The working leg is read automatically.",
            rangeNote: "A smaller front-knee angle is a deeper lunge — about 90–100° is full depth."))
        add(FormPatternSpec(
            pattern: .bridge, label: "Bridge pattern", angleName: "hip",
            left: (.leftShoulder, .leftHip, .leftKnee), right: (.rightShoulder, .rightHip, .rightKnee),
            restsExtended: false, turnAt: 163, resetAt: 150, fullRange: 170, shallowRange: 162,
            posture: .horizontal,
            setupHint: "Lean the phone against something about 1.5 m to your side so it sees shoulders, hips and knees side-on.",
            rangeNote: "A larger hip angle is a fuller bridge — about 170–180° is a locked-out top."))
        add(FormPatternSpec(
            pattern: .push, label: "Push pattern", angleName: "elbow",
            left: (.leftShoulder, .leftElbow, .leftWrist), right: (.rightShoulder, .rightElbow, .rightWrist),
            restsExtended: true, turnAt: 110, resetAt: 150, fullRange: 95, shallowRange: 110,
            posture: .horizontal,
            setupHint: "Lean the phone against something about 1.5 m to your side so it sees your whole body side-on. Steady tempo.",
            rangeNote: "A smaller elbow angle is a deeper rep — about 90° is chest-to-floor range."))
        add(FormPatternSpec(
            pattern: .press, label: "Press pattern", angleName: "elbow",
            left: (.leftShoulder, .leftElbow, .leftWrist), right: (.rightShoulder, .rightElbow, .rightWrist),
            restsExtended: false, turnAt: 150, resetAt: 110, fullRange: 165, shallowRange: 155,
            posture: .standingUpper,
            setupHint: "Face the camera from the hips up, arms in frame at the top of the press.",
            rangeNote: "A larger elbow angle is a fuller lockout — about 165–180° is pressed out."))
        add(FormPatternSpec(
            pattern: .pull, label: "Pull pattern", angleName: "elbow",
            left: (.leftShoulder, .leftElbow, .leftWrist), right: (.rightShoulder, .rightElbow, .rightWrist),
            restsExtended: true, turnAt: 110, resetAt: 150, fullRange: 80, shallowRange: 100,
            posture: .standingUpper,
            setupHint: "Camera on your side or front, shoulders to hips in frame. Full hang or full reach between reps.",
            rangeNote: "A smaller elbow angle is a fuller pull — about 80° or less is a complete pull."))
        add(FormPatternSpec(
            pattern: .curl, label: "Curl pattern", angleName: "elbow",
            left: (.leftShoulder, .leftElbow, .leftWrist), right: (.rightShoulder, .rightElbow, .rightWrist),
            restsExtended: true, turnAt: 100, resetAt: 150, fullRange: 60, shallowRange: 85,
            posture: .standingUpper,
            setupHint: "Face the camera from the hips up. Elbows still, full stretch at the bottom.",
            rangeNote: "A smaller elbow angle is a fuller curl — about 60° or less is a full squeeze."))
        add(FormPatternSpec(
            pattern: .armExtension, label: "Extension pattern", angleName: "elbow",
            left: (.leftShoulder, .leftElbow, .leftWrist), right: (.rightShoulder, .rightElbow, .rightWrist),
            restsExtended: false, turnAt: 140, resetAt: 110, fullRange: 160, shallowRange: 150,
            posture: .standingUpper,
            setupHint: "Face the camera or stand side-on from the hips up. Lock out each rep.",
            rangeNote: "A larger elbow angle is a fuller lockout — about 160–180° is straight."))
        add(FormPatternSpec(
            pattern: .raise, label: "Raise pattern", angleName: "shoulder",
            left: (.leftHip, .leftShoulder, .leftWrist), right: (.rightHip, .rightShoulder, .rightWrist),
            restsExtended: false, turnAt: 60, resetAt: 35, fullRange: 80, shallowRange: 65,
            posture: .standingUpper,
            setupHint: "Face the camera from the hips up, arms fully in frame at the top.",
            rangeNote: "A larger shoulder angle is a higher raise — about 80–90° is shoulder height."))
        add(FormPatternSpec(
            pattern: .jump, label: "Jump pattern", angleName: "knee",
            left: (.leftHip, .leftKnee, .leftAnkle), right: (.rightHip, .rightKnee, .rightAnkle),
            restsExtended: true, turnAt: 150, resetAt: 165, fullRange: 120, shallowRange: 150,
            posture: .standingFull,
            setupHint: "Face the camera, whole body in frame with room above your head. Land soft.",
            rangeNote: "The knee angle at the bottom of each dip — a softer dip loads the jump and the landing."))
        add(FormPatternSpec(
            pattern: .hold, label: "Hold", angleName: "hip",
            left: (.leftShoulder, .leftHip, .leftAnkle), right: (.rightShoulder, .rightHip, .rightAnkle),
            restsExtended: true, turnAt: 0, resetAt: 0, fullRange: 0, shallowRange: 0,
            posture: .horizontal,
            setupHint: "Lean the phone against something so it sees your whole body, then get into position. Morphe times how long you hold still.",
            rangeNote: "Time held still in frame."))
        add(FormPatternSpec(
            pattern: .untracked, label: "Timed set", angleName: "",
            left: (.leftHip, .leftKnee, .leftAnkle), right: (.rightHip, .rightKnee, .rightAnkle),
            restsExtended: true, turnAt: 0, resetAt: 0, fullRange: 0, shallowRange: 0,
            posture: .standingFull,
            setupHint: "The camera can't read this movement yet — it will time the set and show your skeleton.",
            rangeNote: ""))
        return t
    }()
}

// MARK: Body calibration (the athlete's own dimensions)

/// How the athlete is standing relative to the camera. Some checks only
/// make sense from one angle: knee tracking needs the front, hinge depth
/// and hip line read best from the side.
enum FormViewAngle: String, Codable { case front, side }

/// The athlete's build, read from still frames: every proportional check
/// (framing, knee spread, elbow drift, airtime) is measured against these
/// instead of against raw pixels, so distance from the camera and the
/// athlete's height stop skewing the numbers.
struct BodyCalibration: Equatable {
    var torsoLength: CGFloat        // neck → root, normalized frame units
    var shoulderWidth: CGFloat
    var legLength: CGFloat?         // hip → ankle (standing patterns)
    var standingHipY: CGFloat?      // hip height at rest (jump airtime)
    var viewAngle: FormViewAngle

    /// A side-on athlete shows shoulders close together relative to the torso.
    static func viewAngle(shoulderWidth: CGFloat, torsoLength: CGFloat) -> FormViewAngle {
        torsoLength > 0 && shoulderWidth / torsoLength < 0.42 ? .side : .front
    }
}

/// Accumulates still, well-framed frames until the build is stable, then
/// hands back a calibration. Re-calibrates if the athlete leaves and returns.
struct BodyCalibrator {
    static let framesNeeded = 15
    private var samples: [(torso: CGFloat, shoulders: CGFloat, leg: CGFloat?, hipY: CGFloat?)] = []
    private var lastHip: CGPoint?
    private(set) var calibration: BodyCalibration?

    var progress: Double { calibration == nil ? Double(samples.count) / Double(Self.framesNeeded) : 1 }

    mutating func reset() { samples = []; lastHip = nil; calibration = nil }

    /// Feed one framed pose. Movement (hip speed above a sliver of the frame
    /// per frame) resets the still-frame run — the build is read at rest.
    mutating func ingest(_ joints: PoseJoints, posture: FormPatternSpec.Posture) {
        guard calibration == nil else { return }
        guard let neck = joints[.neck], let root = joints[.root] else { return }
        // Side-on, the far shoulder often drops out: one shoulder and the
        // neck still give a width (twice the half-span).
        let shoulderSpan: CGFloat
        switch (joints[.leftShoulder], joints[.rightShoulder]) {
        case let (l?, r?): shoulderSpan = abs(l.x - r.x)
        case let (l?, nil): shoulderSpan = abs(l.x - neck.x) * 2
        case let (nil, r?): shoulderSpan = abs(r.x - neck.x) * 2
        default: return
        }
        let hip = root
        if let last = lastHip, hypot(hip.x - last.x, hip.y - last.y) > 0.012 {
            samples.removeAll()
        }
        lastHip = hip
        let torso = hypot(neck.x - root.x, neck.y - root.y)
        let shoulders = shoulderSpan
        var leg: CGFloat?
        var hipY: CGFloat?
        if posture == .standingFull {
            // Standing patterns need the legs to be read; otherwise wait.
            guard let hipJ = joints[.leftHip] ?? joints[.rightHip],
                  let ankle = joints[.leftAnkle] ?? joints[.rightAnkle] else { return }
            leg = hypot(hipJ.x - ankle.x, hipJ.y - ankle.y)
            hipY = root.y
        }
        guard torso > 0.02 else { return }
        samples.append((torso, shoulders, leg, hipY))
        if samples.count >= Self.framesNeeded {
            let n = CGFloat(samples.count)
            let torsoAvg = samples.map(\.torso).reduce(0, +) / n
            let shouldersAvg = samples.map(\.shoulders).reduce(0, +) / n
            let legs = samples.compactMap(\.leg)
            let hips = samples.compactMap(\.hipY)
            calibration = BodyCalibration(
                torsoLength: torsoAvg,
                shoulderWidth: shouldersAvg,
                legLength: legs.isEmpty ? nil : legs.reduce(0, +) / CGFloat(legs.count),
                standingHipY: hips.isEmpty ? nil : hips.reduce(0, +) / CGFloat(hips.count),
                viewAngle: BodyCalibration.viewAngle(shoulderWidth: shouldersAvg, torsoLength: torsoAvg))
        }
    }
}

// MARK: Pose geometry (pure helpers shared by the detector and analyzer)

enum PoseMath {
    /// Interior angle (degrees) at joint `b` formed by a–b–c.
    static func angle(_ joints: PoseJoints, _ a: VNHumanBodyPoseObservation.JointName,
                      _ b: VNHumanBodyPoseObservation.JointName,
                      _ c: VNHumanBodyPoseObservation.JointName) -> CGFloat? {
        guard let pa = joints[a], let pb = joints[b], let pc = joints[c] else { return nil }
        return angle(pa, pb, pc)
    }

    static func angle(_ pa: CGPoint, _ pb: CGPoint, _ pc: CGPoint) -> CGFloat? {
        let v1 = CGVector(dx: pa.x - pb.x, dy: pa.y - pb.y)
        let v2 = CGVector(dx: pc.x - pb.x, dy: pc.y - pb.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag = hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy)
        guard mag > 0 else { return nil }
        return acos(max(-1, min(1, dot / mag))) * 180 / .pi
    }

    /// The pattern's primary angle for a frame. Both sides when both are
    /// visible and agree (their mean). When they disagree: arm patterns and
    /// the lunge take the side further into the movement (one-arm rows,
    /// alternating curls, the working leg); the two-leg patterns trust the
    /// less-moved side, since a wild reading there is an occluded limb.
    /// Facing the camera, knee-dominant depth is read from the hip drop
    /// against the athlete's own leg length instead of the foreshortened
    /// 2D knee angle (see `frontViewKneeAngle`).
    static func primaryAngle(_ joints: PoseJoints, spec: FormPatternSpec, calibration: BodyCalibration? = nil) -> CGFloat? {
        if [.squat, .lunge, .jump].contains(spec.pattern), let cal = calibration, cal.viewAngle == .front,
           let estimate = frontViewKneeAngle(joints, calibration: cal) {
            return estimate
        }
        let l = angle(joints, spec.left.0, spec.left.1, spec.left.2)
        let r = angle(joints, spec.right.0, spec.right.1, spec.right.2)
        switch (l, r) {
        case let (l?, r?):
            let unilateral = [.lunge, .push, .press, .pull, .curl, .armExtension, .raise].contains(spec.pattern)
            if abs(l - r) > 35 {
                return unilateral ? (spec.isFuller(l, than: r) ? l : r) : (spec.isFuller(l, than: r) ? r : l)
            }
            return (l + r) / 2
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    /// Knee angle estimated from the hip drop, for a front-facing athlete.
    /// With thigh and shin folding symmetrically, hip height above the feet
    /// is legLength × cos(a) and the knee angle is 180° − 2a — so a hip
    /// that has dropped 29% of the leg reads as a 90° (parallel) squat. It
    /// uses the athlete's own standing hip height and leg length, which is
    /// what makes it distance- and height-independent.
    static func frontViewKneeAngle(_ joints: PoseJoints, calibration: BodyCalibration) -> CGFloat? {
        guard let standing = calibration.standingHipY, let leg = calibration.legLength, leg > 0.05,
              let hip = joints[.root] ?? midpoint(joints[.leftHip], joints[.rightHip]) else { return nil }
        let drop = max(0, hip.y - standing)
        let ratio = max(0, min(1, 1 - drop / leg))
        let a = acos(ratio)
        return 180 - 2 * a * 180 / .pi
    }

    /// Left and right primary angles when BOTH are visible (asymmetry).
    static func sideAngles(_ joints: PoseJoints, spec: FormPatternSpec) -> (left: CGFloat, right: CGFloat)? {
        guard let l = angle(joints, spec.left.0, spec.left.1, spec.left.2),
              let r = angle(joints, spec.right.0, spec.right.1, spec.right.2) else { return nil }
        return (l, r)
    }

    static func midpoint(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? {
        switch (a, b) {
        case let (a?, b?): return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    /// Torso lean from vertical, in degrees (0 = upright), from the
    /// shoulder midpoint over the hip midpoint. Image y grows downward.
    static func torsoLean(_ joints: PoseJoints) -> CGFloat? {
        guard let shoulders = midpoint(joints[.leftShoulder], joints[.rightShoulder]),
              let hips = midpoint(joints[.leftHip], joints[.rightHip]) else { return nil }
        let dx = shoulders.x - hips.x, dy = hips.y - shoulders.y
        guard hypot(dx, dy) > 0.01 else { return nil }
        return abs(atan2(dx, dy)) * 180 / .pi
    }

    /// Torso lean estimated from foreshortening when the athlete faces the
    /// camera: a torso that projects shorter than its standing length has
    /// tipped toward or away from the lens by acos(projected ÷ full).
    static func frontViewTorsoLean(_ joints: PoseJoints, calibration: BodyCalibration) -> CGFloat? {
        guard calibration.torsoLength > 0.02, let neck = joints[.neck], let root = joints[.root] else { return nil }
        let projected = hypot(neck.x - root.x, neck.y - root.y)
        let ratio = max(0, min(1, projected / calibration.torsoLength))
        return acos(ratio) * 180 / .pi
    }

    /// Knee-spread ÷ ankle-spread — the knee-valgus proxy (front view only).
    static func kneeSpreadRatio(_ j: PoseJoints) -> CGFloat? {
        guard let lk = j[.leftKnee], let rk = j[.rightKnee],
              let la = j[.leftAnkle], let ra = j[.rightAnkle] else { return nil }
        let knee = abs(lk.x - rk.x), ankle = abs(la.x - ra.x)
        guard ankle > 0.02 else { return nil }
        return knee / ankle
    }

    /// How far the shoulder–hip–ankle line bends, in degrees (0 = straight
    /// plank). Falls back to the knee when the ankle is out of frame.
    static func hipLineDeviation(_ j: PoseJoints) -> CGFloat? {
        guard let shoulder = midpoint(j[.leftShoulder], j[.rightShoulder]),
              let hip = midpoint(j[.leftHip], j[.rightHip]),
              let foot = midpoint(j[.leftAnkle], j[.rightAnkle]) ?? midpoint(j[.leftKnee], j[.rightKnee]),
              let a = angle(shoulder, hip, foot) else { return nil }
        return 180 - a
    }

    /// Horizontal wrist offset from the shoulder, in torso lengths (press
    /// stack: 0 = wrist straight over the shoulder).
    static func wristOffset(_ j: PoseJoints, torso: CGFloat) -> CGFloat? {
        guard torso > 0 else { return nil }
        var offsets: [CGFloat] = []
        if let s = j[.leftShoulder], let w = j[.leftWrist] { offsets.append(abs(w.x - s.x) / torso) }
        if let s = j[.rightShoulder], let w = j[.rightWrist] { offsets.append(abs(w.x - s.x) / torso) }
        guard !offsets.isEmpty else { return nil }
        return offsets.reduce(0, +) / CGFloat(offsets.count)
    }

    /// Elbow travel relative to the shoulder between two frames, in torso
    /// lengths (curl drift: elbows swinging forward).
    static func elbowDrift(from start: PoseJoints, to peak: PoseJoints, torso: CGFloat) -> CGFloat? {
        guard torso > 0 else { return nil }
        var drifts: [CGFloat] = []
        for (s, e) in [(VNHumanBodyPoseObservation.JointName.leftShoulder, VNHumanBodyPoseObservation.JointName.leftElbow),
                       (.rightShoulder, .rightElbow)] {
            guard let s0 = start[s], let e0 = start[e], let s1 = peak[s], let e1 = peak[e] else { continue }
            let before = CGPoint(x: e0.x - s0.x, y: e0.y - s0.y)
            let after = CGPoint(x: e1.x - s1.x, y: e1.y - s1.y)
            drifts.append(hypot(after.x - before.x, after.y - before.y) / torso)
        }
        guard !drifts.isEmpty else { return nil }
        return drifts.reduce(0, +) / CGFloat(drifts.count)
    }
}

// MARK: Rep metrics

/// What the camera measured for one rep. Only the primary angle and the
/// tempo are always present; everything else is nil whenever the joints it
/// needs were not confidently visible — the analyzer never guesses.
struct FormRepMetrics: Equatable {
    var pattern: FormMovementPattern
    /// The turning point of the primary angle (smallest for a closing
    /// pattern, largest for an opening one).
    var peakAngle: CGFloat
    /// The primary angle where the rep started (lockout quality).
    var restAngle: CGFloat
    /// Seconds into the turning point, and back out.
    var descentSeconds: Double
    var ascentSeconds: Double
    /// |left − right| primary angle at the peak, when both sides were seen.
    var asymmetry: CGFloat?
    /// Knee-spread ÷ ankle-spread at the bottom (front view, knee patterns).
    var valgusRatio: CGFloat?
    /// Torso lean from vertical at the peak, degrees.
    var torsoLean: CGFloat?
    /// Change in torso lean from rest to peak, degrees (momentum/swing).
    var torsoSwing: CGFloat?
    /// Shoulder–hip–foot line bend at the peak, degrees (push/hold).
    var hipLineDeviation: CGFloat?
    /// Wrist offset from the shoulder at the peak, in torso lengths (press).
    var wristOffset: CGFloat?
    /// Elbow travel from rest to peak, in torso lengths (curl/extension).
    var elbowDrift: CGFloat?
    /// A second angle the pattern cares about at the peak: the KNEE for a
    /// hinge (a hinge that bends the knees hard became a squat).
    var secondaryAngle: CGFloat?
    /// Jumps: seconds the hips were above standing height.
    var airtimeSeconds: Double?
    /// Jumps: knee angle on the first frame back on the ground.
    var landingKneeAngle: CGFloat?

    init(pattern: FormMovementPattern, peakAngle: CGFloat, restAngle: CGFloat = 175,
         descentSeconds: Double, ascentSeconds: Double,
         asymmetry: CGFloat? = nil, valgusRatio: CGFloat? = nil, torsoLean: CGFloat? = nil,
         torsoSwing: CGFloat? = nil, hipLineDeviation: CGFloat? = nil, wristOffset: CGFloat? = nil,
         elbowDrift: CGFloat? = nil, secondaryAngle: CGFloat? = nil, airtimeSeconds: Double? = nil, landingKneeAngle: CGFloat? = nil) {
        self.pattern = pattern; self.peakAngle = peakAngle; self.restAngle = restAngle
        self.descentSeconds = descentSeconds; self.ascentSeconds = ascentSeconds
        self.asymmetry = asymmetry; self.valgusRatio = valgusRatio; self.torsoLean = torsoLean
        self.torsoSwing = torsoSwing; self.hipLineDeviation = hipLineDeviation; self.wristOffset = wristOffset
        self.elbowDrift = elbowDrift; self.secondaryAngle = secondaryAngle
        self.airtimeSeconds = airtimeSeconds; self.landingKneeAngle = landingKneeAngle
    }
}

// MARK: Rep detector (pure state machine)

/// Counts reps from the primary angle with hysteresis, a minimum duration,
/// false-start rejection, and median smoothing — and captures the rep's
/// metrics from the frames at rest and at the turning point. Pure: feed it
/// frames, get reps back; unit-tested with synthetic motion.
struct RepDetector {
    let spec: FormPatternSpec
    var calibration: BodyCalibration?

    /// A rep shorter than this is jitter, not a movement.
    static let minimumRepSeconds = 0.45
    /// Median window on the primary angle — kills single-frame spikes.
    static let smoothingWindow = 5

    private enum Phase { case rest, moving, armed }
    private var phase: Phase = .rest
    private var recent: [CGFloat] = []
    private var startTime: Double?
    private var startFrame: PoseFrame?
    private var startAngle: CGFloat = 0
    /// The most-at-rest angle seen since the last rep (the lockout).
    private var restExtreme: CGFloat?
    private var peakAngle: CGFloat = 0
    private var peakTime: Double = 0
    private var peakFrame: PoseFrame?
    // Jumps are counted on the LANDING, not on knee hysteresis: the knee
    // straightens in flight and would bank mid-air. Bookkeeping below.
    private var airStart: Double?
    private var wasAirborne = false
    private var dipMin: CGFloat = 180          // deepest knee since the last landing
    private var dipStart: Double?              // when the loading dip began
    private var pendingLanding: (time: Double, airtime: Double, dip: CGFloat, descent: Double, kneeMin: CGFloat, frames: Int)?
    /// Flights shorter than this are a bounce in the pose, not a jump.
    static let minimumAirtime = 0.12

    init(spec: FormPatternSpec, calibration: BodyCalibration? = nil) {
        self.spec = spec
        self.calibration = calibration
    }

    /// The smoothed primary angle of the last frame, for the live readout.
    private(set) var currentAngle: CGFloat?

    mutating func reset() {
        phase = .rest; recent = []; startTime = nil; startFrame = nil
        peakFrame = nil; currentAngle = nil; restExtreme = nil
        airStart = nil; wasAirborne = false; dipMin = 180; dipStart = nil; pendingLanding = nil
    }

    /// Feed one frame. Returns the rep's metrics the moment a rep completes.
    mutating func ingest(_ frame: PoseFrame) -> FormRepMetrics? {
        guard spec.countsReps, let raw = PoseMath.primaryAngle(frame.joints, spec: spec, calibration: calibration) else { return nil }
        recent.append(raw)
        if recent.count > Self.smoothingWindow { recent.removeFirst() }
        let angle = recent.sorted()[recent.count / 2]
        currentAngle = angle
        let d = spec.direction
        let t = frame.time

        if spec.pattern == .jump { return ingestJump(angle: angle, frame: frame) }

        switch phase {
        case .rest:
            if restExtreme == nil || d * (angle - restExtreme!) < 0 { restExtreme = angle }
            // Leaving rest: the angle has crossed the reset line into the movement.
            if d * (angle - spec.resetAt) > 0 {
                phase = .moving
                startTime = t; startFrame = frame
                startAngle = restExtreme ?? angle
                restExtreme = nil
                peakAngle = angle; peakTime = t; peakFrame = frame
            }
        case .moving:
            if d * (angle - peakAngle) > 0 { peakAngle = angle; peakTime = t; peakFrame = frame }
            if d * (angle - spec.turnAt) >= 0 {
                phase = .armed
            } else if d * (angle - spec.resetAt) <= 0 {
                // Came back without reaching the turn: a false start, not a rep.
                phase = .rest
            }
        case .armed:
            if d * (angle - peakAngle) > 0 { peakAngle = angle; peakTime = t; peakFrame = frame }
            if d * (angle - spec.resetAt) <= 0 {
                defer { phase = .rest }
                guard let startTime, let startFrame, let peakFrame,
                      t - startTime >= Self.minimumRepSeconds else { return nil }
                return makeMetrics(start: startFrame, peak: peakFrame, startAngle: startAngle,
                                   peakAngle: peakAngle, peakTime: peakTime, startTime: startTime, endTime: t)
            }
        }
        return nil
    }

    /// Jumps: a rep is a flight. Airborne = the hips rise clearly above the
    /// calibrated standing height (a slice of the athlete's own leg length,
    /// so it scales with distance); the rep banks a few frames after
    /// landing so the landing knee angle can be read. The loading dip before
    /// takeoff is the rep's "peak" angle. Needs the build to be read first.
    private mutating func ingestJump(angle: CGFloat, frame: PoseFrame) -> FormRepMetrics? {
        let t = frame.time
        // Track the loading dip since the last landing.
        if angle < 165, dipStart == nil, !wasAirborne { dipStart = t }
        if !wasAirborne { dipMin = min(dipMin, angle) }

        // A landing waits ten frames so the absorb-dip is in the number.
        if var pending = pendingLanding {
            pending.frames += 1
            pending.kneeMin = min(pending.kneeMin, angle)
            pendingLanding = pending
            if pending.frames >= 10 {
                pendingLanding = nil
                dipMin = 180; dipStart = nil
                return FormRepMetrics(
                    pattern: .jump, peakAngle: pending.dip, restAngle: 175,
                    descentSeconds: pending.descent, ascentSeconds: pending.airtime,
                    airtimeSeconds: pending.airtime, landingKneeAngle: pending.kneeMin)
            }
        }

        guard let hip = frame.joints[.root] ?? PoseMath.midpoint(frame.joints[.leftHip], frame.joints[.rightHip]),
              let standing = calibration?.standingHipY else { return nil }
        let lift = (calibration?.legLength ?? 0.4) * 0.12
        let airborne = hip.y < standing - lift
        if airborne, !wasAirborne {
            airStart = t
            // A takeoff while a landing is still pending (quick bounce): bank
            // the pending one now with what it has.
            if let pending = pendingLanding {
                pendingLanding = nil
                dipMin = 180; dipStart = nil
                wasAirborne = true
                return FormRepMetrics(
                    pattern: .jump, peakAngle: pending.dip, restAngle: 175,
                    descentSeconds: pending.descent, ascentSeconds: pending.airtime,
                    airtimeSeconds: pending.airtime, landingKneeAngle: pending.kneeMin)
            }
        }
        if !airborne, wasAirborne, let airStart {
            let airtime = t - airStart
            if airtime >= Self.minimumAirtime {
                pendingLanding = (time: t, airtime: airtime, dip: dipMin,
                                  descent: max(0, airStart - (dipStart ?? airStart)), kneeMin: angle, frames: 0)
            }
            self.airStart = nil
        }
        wasAirborne = airborne
        return nil
    }

    private func makeMetrics(start: PoseFrame, peak: PoseFrame, startAngle: CGFloat, peakAngle: CGFloat,
                             peakTime: Double, startTime: Double, endTime: Double) -> FormRepMetrics {
        let torso = calibration?.torsoLength ?? 0
        let frontView = calibration?.viewAngle == .front
        _ = frontView
        var m = FormRepMetrics(
            pattern: spec.pattern, peakAngle: peakAngle, restAngle: startAngle,
            descentSeconds: max(0, peakTime - startTime), ascentSeconds: max(0, endTime - peakTime))
        if let sides = PoseMath.sideAngles(peak.joints, spec: spec), spec.pattern != .lunge {
            m.asymmetry = abs(sides.left - sides.right)
        }
        // Knee tracking is a FRONT-view read of a two-leg stance only: a
        // split stance or a side view makes the spread ratio pure noise, and
        // "knees caved" is the cue that leads the review — it must be real.
        if spec.readsKnees, spec.pattern != .lunge, frontView, let cal = calibration,
           let la = peak.joints[.leftAnkle], let ra = peak.joints[.rightAnkle],
           abs(la.x - ra.x) >= cal.shoulderWidth * 0.4 {
            m.valgusRatio = PoseMath.kneeSpreadRatio(peak.joints)
        }
        // Lean is a side-view read; facing the camera it is estimated from
        // the torso's foreshortening against the calibrated length.
        func lean(_ joints: PoseJoints) -> CGFloat? {
            if frontView, let cal = calibration { return PoseMath.frontViewTorsoLean(joints, calibration: cal) }
            return calibration?.viewAngle == .side ? PoseMath.torsoLean(joints) : nil
        }
        switch spec.pattern {
        case .squat, .hinge, .lunge:
            m.torsoLean = lean(peak.joints)
        case .press:
            // A back-lean of 15° is inside the foreshortening noise from the
            // front; only a side view can call it.
            if calibration?.viewAngle == .side { m.torsoLean = PoseMath.torsoLean(peak.joints) }
        case .curl, .pull, .raise:
            if calibration?.viewAngle == .side,
               let a = PoseMath.torsoLean(start.joints), let b = PoseMath.torsoLean(peak.joints) {
                m.torsoSwing = abs(b - a)
            }
        default: break
        }
        if spec.pattern == .push {
            m.hipLineDeviation = PoseMath.hipLineDeviation(peak.joints)
        }
        // From the front the wrist offset is just grip width; forward drift
        // of a press is a side-view read.
        if spec.pattern == .press, torso > 0, calibration?.viewAngle == .side {
            m.wristOffset = PoseMath.wristOffset(peak.joints, torso: torso)
        }
        if spec.pattern == .curl || spec.pattern == .armExtension, torso > 0 {
            m.elbowDrift = PoseMath.elbowDrift(from: start.joints, to: peak.joints, torso: torso)
        }
        if spec.pattern == .hinge {
            let squatSpec = FormMovementPattern.squat.spec
            m.secondaryAngle = PoseMath.primaryAngle(peak.joints, spec: squatSpec)
        }
        return m
    }
}

// MARK: Framing state (the distance box)

enum FramingState: Equatable {
    case noPerson
    case tooClose   // red — filling too much of the frame
    case tooFar     // yellow — almost there, come closer
    case feetCut    // yellow — standing patterns need the feet in frame
    case good       // green — framed for tracking

    var label: String {
        switch self {
        case .noPerson: return "STEP INTO FRAME"
        case .tooClose: return "STEP BACK"
        case .tooFar:   return "MOVE CLOSER"
        case .feetCut:  return "STEP BACK — SHOW YOUR FEET"
        case .good:     return "FRAMED — HOLD THERE"
        }
    }

    /// Literal traffic-light semantics per the feature spec. This is a
    /// functional signal, so it steps outside the brand palette on purpose
    /// (red and green carry meaning a monochrome box couldn't).
    var color: Color {
        switch self {
        case .noPerson: return Color.white.opacity(0.35)
        case .tooClose: return Color(red: 0.92, green: 0.26, blue: 0.28)
        case .tooFar, .feetCut: return Color(red: 0.98, green: 0.78, blue: 0.22)
        case .good:     return Color(red: 0.30, green: 0.85, blue: 0.45)
        }
    }

    var isTrackable: Bool { self == .good }

    /// Pure framing judgment per posture.
    static func judge(_ joints: PoseJoints, posture: FormPatternSpec.Posture, spec: FormPatternSpec) -> FramingState {
        guard joints.count >= 5 else { return .noPerson }
        let xs = joints.values.map(\.x), ys = joints.values.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return .noPerson }
        let height = maxY - minY, width = maxX - minX
        switch posture {
        case .standingFull:
            if height > 0.95 { return .tooClose }
            let hasFeet = joints[.leftAnkle] != nil || joints[.rightAnkle] != nil
            let hasHips = joints[.leftHip] != nil || joints[.rightHip] != nil
            let hasShoulders = joints[.leftShoulder] != nil || joints[.rightShoulder] != nil
            // The upper body is in but the feet are not: the fix is to step
            // back, and that is a different instruction from "move closer".
            if hasHips, hasShoulders, !hasFeet { return .feetCut }
            if height < 0.5 { return .tooFar }
            return hasFeet ? .good : .tooFar
        case .standingUpper:
            let shoulders: CGFloat
            switch (joints[.leftShoulder], joints[.rightShoulder], joints[.neck]) {
            case let (l?, r?, _): shoulders = abs(l.x - r.x)
            case let (l?, nil, n?): shoulders = abs(l.x - n.x) * 2
            case let (nil, r?, n?): shoulders = abs(r.x - n.x) * 2
            default: return .tooFar
            }
            if shoulders > 0.6 || height > 0.98 { return .tooClose }
            let armSeen = (joints[.leftElbow] != nil && joints[.leftWrist] != nil)
                || (joints[.rightElbow] != nil && joints[.rightWrist] != nil)
            // Side-on, the shoulders overlap; judge by torso height instead.
            let torsoSeen = joints[.neck] != nil && (joints[.leftHip] != nil || joints[.rightHip] != nil)
            if !armSeen || !torsoSeen { return .tooFar }
            return (shoulders > 0.12 || height > 0.35) ? .good : .tooFar
        case .horizontal:
            if max(width, height) > 0.97 { return .tooClose }
            if max(width, height) < 0.35 { return .tooFar }
            return PoseMath.primaryAngle(joints, spec: spec) != nil ? .good : .tooFar
        }
    }
}

// MARK: Form analysis (pure, per pattern)
//
// Cues are observations + suggestions, never diagnoses. Each pattern leads
// with its safety-relevant read (knees, back, hips), then range, then tempo
// and control. A cue fires only on a consistent signal across the set, and
// only on metrics the camera actually measured.

struct FormCue: Equatable {
    enum Category: String { case knees, back, hips, range, tempo, control, symmetry, lockout, landing }
    enum Tone { case good, suggestion }
    var category: Category
    var tone: Tone
    var message: String
}

/// A single rep's overall grade — the per-rep pop-up rating.
enum FormRepGrade: String {
    case poor = "Poor"
    case good = "Good"
    case great = "Great"
    case excellent = "Excellent"

    var color: Color {
        switch self {
        case .poor:      return Color(red: 0.92, green: 0.26, blue: 0.28)
        case .good:      return Color(red: 0.98, green: 0.78, blue: 0.22)
        case .great:     return Color(red: 0.45, green: 0.85, blue: 0.48)
        case .excellent: return Color(red: 0.24, green: 0.95, blue: 0.55)
        }
    }
}

struct FormSetSummary: Equatable {
    var pattern: FormMovementPattern
    var reps: Int
    /// Mean and best turning-point angle (best = fullest range for the pattern).
    var avgPeakAngle: CGFloat
    var bestPeakAngle: CGFloat
    var cues: [FormCue]
    /// Holds: seconds held still in frame.
    var holdSeconds: Double = 0
}

enum FormAnalyzer {
    // Honest heuristics from coaching practice, not medical limits.
    static let valgusRatio: CGFloat = 0.85        // knee spread ÷ ankle spread below this ≈ caving
    static let fastDescent: Double = 0.6          // faster than this ≈ dropping into the rep
    static let squatLean: CGFloat = 50            // torso past this from vertical at the bottom
    static let lungeLean: CGFloat = 35
    static let pressLean: CGFloat = 15
    static let hingeKneeBend: CGFloat = 115       // knee closing past this in a hinge ≈ squatting it
    static let hipSag: CGFloat = 15               // plank line bend past this ≈ hips sagging/piking
    static let swing: CGFloat = 12                // torso swing past this in arm work ≈ momentum
    static let asymmetry: CGFloat = 15            // left/right angle gap past this ≈ favoring a side
    static let elbowDrift: CGFloat = 0.18         // elbows traveling past this (torso lengths) ≈ swinging
    static let wristOffset: CGFloat = 0.22        // wrist this far from over the shoulder ≈ pressing forward
    static let stiffLanding: CGFloat = 150        // landing knee angle above this ≈ landing stiff
    static let lockoutShortfall: CGFloat = 12     // rest angle this far short of straight ≈ not finishing

    /// The share of measured reps a signal must cover before a cue fires.
    private static func majority(_ count: Int, of total: Int, minimum: Int = 3) -> Bool {
        total >= minimum && Double(count) / Double(total) > 0.5
    }

    static func analyze(_ metrics: [FormRepMetrics], pattern: FormMovementPattern, holdSeconds: Double = 0) -> FormSetSummary {
        let spec = pattern.spec
        guard !metrics.isEmpty else {
            return FormSetSummary(pattern: pattern, reps: 0, avgPeakAngle: 0, bestPeakAngle: 0, cues: [], holdSeconds: holdSeconds)
        }
        let n = metrics.count
        let peaks = metrics.map(\.peakAngle)
        let avg = peaks.reduce(0, +) / CGFloat(n)
        let best = peaks.reduce(peaks[0]) { spec.isFuller($1, than: $0) ? $1 : $0 }
        var cues: [FormCue] = []
        func reps(_ k: Int) -> String { "\(k) of \(n) rep\(n == 1 ? "" : "s")" }

        // 1. Safety-relevant reads lead.
        if spec.readsKnees {
            let values = metrics.compactMap(\.valgusRatio)
            let caved = values.filter { $0 < valgusRatio }.count
            if majority(caved, of: values.count) {
                cues.append(FormCue(category: .knees, tone: .suggestion,
                    message: pattern == .jump
                        ? "Knees drifted inward on \(caved) landing\(caved == 1 ? "" : "s") — land with the knees over the feet."
                        : "Push your knees out — they drifted inward on \(reps(caved)), often as you tire."))
            }
        }
        switch pattern {
        case .squat, .lunge:
            let leans = metrics.compactMap(\.torsoLean)
            let limit = pattern == .squat ? squatLean : lungeLean
            let folded = leans.filter { $0 > limit }.count
            if majority(folded, of: leans.count) {
                cues.append(FormCue(category: .back, tone: .suggestion,
                    message: "Your chest dropped forward on \(reps(folded)) — brace and keep the chest up through the bottom."))
            }
        case .hinge:
            // The hinge reads the hip; a knee closing hard means the hips
            // stopped going back and the rep turned into a squat.
            let knees = metrics.compactMap(\.secondaryAngle)
            let bent = knees.filter { $0 < hingeKneeBend }.count
            if majority(bent, of: knees.count) {
                cues.append(FormCue(category: .back, tone: .suggestion,
                    message: "Your knees bent a lot on \(reps(bent)) — push the hips back first and keep the shins near vertical."))
            }
        case .press:
            let leans = metrics.compactMap(\.torsoLean)
            let leaned = leans.filter { $0 > pressLean }.count
            if majority(leaned, of: leans.count) {
                cues.append(FormCue(category: .back, tone: .suggestion,
                    message: "You leaned back to finish \(reps(leaned)) — ribs down, squeeze the glutes, press straight up."))
            }
        case .push:
            let lines = metrics.compactMap(\.hipLineDeviation)
            let bent = lines.filter { $0 > hipSag }.count
            if majority(bent, of: lines.count) {
                cues.append(FormCue(category: .hips, tone: .suggestion,
                    message: "Your hips left the line on \(reps(bent)) — squeeze the glutes so shoulders, hips and heels stay straight."))
            }
        default: break
        }

        // 2. Range of motion.
        let shallow = peaks.filter { spec.isShallow($0) }.count
        if Double(shallow) / Double(n) > 0.4 {
            cues.append(FormCue(category: .range, tone: .suggestion, message: shallowMessage(pattern, shallow: reps(shallow))))
        } else {
            cues.append(FormCue(category: .range, tone: .good, message: fullRangeMessage(pattern)))
        }

        // 3. Tempo, control, symmetry, lockout, landings.
        // A descent under a tenth of a second is a rep that STARTED at the
        // bottom (a negative, a step-up), not a drop — it is left out.
        let descents = metrics.map(\.descentSeconds).filter { $0 >= 0.1 }
        let avgDescent = descents.isEmpty ? 0 : descents.reduce(0, +) / Double(descents.count)
        if [.squat, .lunge, .hinge, .push, .pull, .curl].contains(pattern), descents.count >= 2, avgDescent < fastDescent {
            cues.append(FormCue(category: .tempo, tone: .suggestion,
                message: pattern == .pull || pattern == .curl
                    ? "Control the lowering — you're letting go fast; take about two seconds back down."
                    : "Control the way down — you're dropping fast; aim for about two seconds."))
        }
        if [.curl, .pull, .raise].contains(pattern) {
            let swings = metrics.compactMap(\.torsoSwing)
            let swung = swings.filter { $0 > swing }.count
            if majority(swung, of: swings.count) {
                cues.append(FormCue(category: .control, tone: .suggestion,
                    message: "You swung your torso into \(reps(swung)) — plant your feet and let the muscle move the weight."))
            }
        }
        if pattern == .curl || pattern == .armExtension {
            let drifts = metrics.compactMap(\.elbowDrift)
            let drifted = drifts.filter { $0 > elbowDrift }.count
            if majority(drifted, of: drifts.count) {
                cues.append(FormCue(category: .control, tone: .suggestion,
                    message: "Your elbows traveled on \(reps(drifted)) — pin them to your sides and move only the forearm."))
            }
        }
        if pattern == .press {
            let offsets = metrics.compactMap(\.wristOffset)
            let forward = offsets.filter { $0 > wristOffset }.count
            if majority(forward, of: offsets.count) {
                cues.append(FormCue(category: .control, tone: .suggestion,
                    message: "The bar finished in front of you on \(reps(forward)) — press up so the wrists stack over the shoulders."))
            }
        }
        if [.squat, .push, .press, .pull, .curl, .raise, .armExtension].contains(pattern) {
            let gaps = metrics.compactMap(\.asymmetry)
            let uneven = gaps.filter { $0 > asymmetry }.count
            if majority(uneven, of: gaps.count) {
                cues.append(FormCue(category: .symmetry, tone: .suggestion,
                    message: "One side worked harder on \(reps(uneven)) — slow down and match both sides."))
            }
        }
        if spec.restsExtended, [.squat, .push, .hinge].contains(pattern) {
            // A 2D elbow at a clean push-up top reads 165–172°; the knee and
            // hip read closer to straight.
            let floor: CGFloat = pattern == .push ? 160 : 180 - lockoutShortfall
            let short = metrics.filter { $0.restAngle < floor }.count
            if majority(short, of: n) {
                cues.append(FormCue(category: .lockout, tone: .suggestion,
                    message: pattern == .push ? "Finish each rep — lock the elbows out at the top."
                                              : "Stand all the way up between reps — finish tall before the next one."))
            }
        }
        if pattern == .jump {
            let landings = metrics.compactMap(\.landingKneeAngle)
            let stiff = landings.filter { $0 > stiffLanding }.count
            if majority(stiff, of: landings.count) {
                cues.append(FormCue(category: .landing, tone: .suggestion,
                    message: "You landed stiff on \(stiff) jump\(stiff == 1 ? "" : "s") — bend the knees to absorb it quietly."))
            } else if landings.count >= 3 {
                cues.append(FormCue(category: .landing, tone: .good, message: "Soft landings — you're absorbing each jump through the knees."))
            }
        }

        // At most three cues so it reads as coaching, not a wall of text.
        return FormSetSummary(pattern: pattern, reps: n, avgPeakAngle: avg, bestPeakAngle: best,
                              cues: Array(cues.prefix(3)), holdSeconds: holdSeconds)
    }

    private static func shallowMessage(_ pattern: FormMovementPattern, shallow: String) -> String {
        switch pattern {
        case .squat: return "Try sitting a little lower — \(shallow) stopped above parallel."
        case .lunge: return "Sink a little deeper — \(shallow) stopped short; aim the back knee toward the floor."
        case .hinge: return "Push the hips further back — \(shallow) stopped short of a full hinge."
        case .bridge: return "Drive the hips higher — \(shallow) stopped short of a full bridge."
        case .push: return "Go a little lower — \(shallow) were shallow; bring the chest toward the floor."
        case .press: return "Finish the press — \(shallow) stopped short of lockout overhead."
        case .pull: return "Pull all the way in — \(shallow) stopped short; drive the elbows back."
        case .curl: return "Squeeze to the top — \(shallow) stopped short of a full curl."
        case .armExtension: return "Lock the elbows out — \(shallow) stopped short of straight."
        case .raise: return "Raise to shoulder height — \(shallow) stopped low."
        case .jump: return "Load the jump — \(shallow) barely dipped before takeoff."
        case .hold, .untracked: return ""
        }
    }

    private static func fullRangeMessage(_ pattern: FormMovementPattern) -> String {
        switch pattern {
        case .squat: return "Good depth — you're getting to about parallel."
        case .lunge: return "Good depth — the front knee is reaching a full bend."
        case .hinge: return "Full hinge — the hips are getting all the way back."
        case .bridge: return "Full bridge — the hips are reaching lockout at the top."
        case .push: return "Good range — you're getting nice and low."
        case .press: return "Full lockout — every press finished overhead."
        case .pull: return "Full pulls — the elbows are coming all the way through."
        case .curl: return "Full curls — a complete squeeze at the top."
        case .armExtension: return "Clean lockouts — the elbows straightened on every rep."
        case .raise: return "Good height — the arms are reaching shoulder level."
        case .jump: return "Good loading — a real dip before every takeoff."
        case .hold, .untracked: return ""
        }
    }

    /// Overall grade for one rep from range + the pattern's safety read + tempo.
    static func grade(_ m: FormRepMetrics) -> FormRepGrade {
        let spec = m.pattern.spec
        var score = 0
        // Range: full earns two, in between one, short loses one.
        if spec.isFull(m.peakAngle) { score += 2 }
        else if !spec.isShallow(m.peakAngle) { score += 1 }
        else { score -= 1 }
        // The pattern's safety read.
        switch m.pattern {
        case .squat, .lunge, .jump:
            if let v = m.valgusRatio { score += v >= 0.9 ? 1 : (v < valgusRatio ? -1 : 0) }
            if let lean = m.torsoLean, lean > (m.pattern == .squat ? squatLean : lungeLean) { score -= 1 }
            if m.pattern == .jump, let k = m.landingKneeAngle, k > stiffLanding { score -= 1 }
        case .push:
            if let bend = m.hipLineDeviation { score += bend <= 8 ? 1 : (bend > hipSag ? -1 : 0) }
        case .press:
            if let lean = m.torsoLean, lean > pressLean { score -= 1 }
            if let off = m.wristOffset, off > wristOffset { score -= 1 }
        case .curl, .pull, .raise:
            if let sw = m.torsoSwing { score += sw <= 5 ? 1 : (sw > swing ? -1 : 0) }
        case .armExtension:
            if let drift = m.elbowDrift, drift > elbowDrift { score -= 1 }
        case .hinge:
            if let knee = m.secondaryAngle, knee < hingeKneeBend { score -= 1 }
        default: break
        }
        // Tempo — controlled earns, dropping loses (for the lowering patterns).
        if [.squat, .lunge, .hinge, .push, .pull, .curl].contains(m.pattern) {
            if m.descentSeconds >= 0.8 { score += 1 }
            else if m.descentSeconds >= 0.1, m.descentSeconds < 0.4 { score -= 1 }
        }
        switch score {
        case 3...: return .excellent
        case 2:    return .great
        case 1:    return .good
        default:   return .poor
        }
    }

    /// One-line feedback for the rep that just finished (shown live) — the
    /// worst thing the camera saw, or "clean".
    static func liveCue(for m: FormRepMetrics, repNumber: Int) -> String {
        let spec = m.pattern.spec
        let prefix = "Rep \(repNumber) · "
        if spec.readsKnees, let v = m.valgusRatio, v < valgusRatio { return prefix + "knees caved in" }
        if m.pattern == .push, let bend = m.hipLineDeviation, bend > hipSag { return prefix + "hips off the line" }
        if m.pattern == .press, let lean = m.torsoLean, lean > pressLean { return prefix + "leaned back" }
        if [.squat, .lunge].contains(m.pattern), let lean = m.torsoLean, lean > (m.pattern == .squat ? squatLean : lungeLean) {
            return prefix + "chest dropped"
        }
        if [.curl, .pull, .raise].contains(m.pattern), let sw = m.torsoSwing, sw > swing { return prefix + "swung it" }
        if m.pattern == .hinge, let knee = m.secondaryAngle, knee < hingeKneeBend { return prefix + "knees bent — hips back" }
        if m.pattern == .jump, let k = m.landingKneeAngle, k > stiffLanding { return prefix + "stiff landing" }
        if spec.isShallow(m.peakAngle) {
            switch m.pattern {
            case .squat: return prefix + "a little above parallel"
            case .press, .armExtension: return prefix + "short of lockout"
            case .raise: return prefix + "a little low"
            default: return prefix + "a little shallow"
            }
        }
        return prefix + "clean"
    }
}

// MARK: Persisted form-check history (isolated from the workout-log store)

struct FormCheckResult: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Double                 // timeIntervalSince1970
    var exercise: String
    /// FormMovementPattern raw value; results saved before patterns existed
    /// decode as "squat".
    var pattern: String
    var reps: Int
    /// The primary angle's mean and best turning point. (Field names kept
    /// from the squat-only era so older files still decode.)
    var avgMinKneeAngle: Double
    var bestMinKneeAngle: Double
    var holdSeconds: Double
    var cues: [String]

    init(id: UUID = UUID(), date: Double, exercise: String, pattern: FormMovementPattern = .squat, reps: Int,
         avgMinKneeAngle: Double, bestMinKneeAngle: Double, holdSeconds: Double = 0, cues: [String]) {
        self.id = id; self.date = date; self.exercise = exercise; self.pattern = pattern.rawValue; self.reps = reps
        self.avgMinKneeAngle = avgMinKneeAngle; self.bestMinKneeAngle = bestMinKneeAngle
        self.holdSeconds = holdSeconds; self.cues = cues
    }

    // Tolerant decode — one bad field can't nil the whole history.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = ((try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? nil) ?? UUID()
        date = ((try? c.decodeIfPresent(Double.self, forKey: .date)) ?? nil) ?? 0
        exercise = ((try? c.decodeIfPresent(String.self, forKey: .exercise)) ?? nil) ?? "Squat"
        pattern = ((try? c.decodeIfPresent(String.self, forKey: .pattern)) ?? nil) ?? FormMovementPattern.squat.rawValue
        reps = ((try? c.decodeIfPresent(Int.self, forKey: .reps)) ?? nil) ?? 0
        avgMinKneeAngle = ((try? c.decodeIfPresent(Double.self, forKey: .avgMinKneeAngle)) ?? nil) ?? 0
        bestMinKneeAngle = ((try? c.decodeIfPresent(Double.self, forKey: .bestMinKneeAngle)) ?? nil) ?? 0
        holdSeconds = ((try? c.decodeIfPresent(Double.self, forKey: .holdSeconds)) ?? nil) ?? 0
        cues = ((try? c.decodeIfPresent([String].self, forKey: .cues)) ?? nil) ?? []
    }
}

/// Standalone, versioned, tolerant persistence — deliberately NOT wired into
/// the god-object store or the workout-log/streak/XP paths.
final class FormCheckFilePersistence {
    private struct Wrapper: Codable { var schemaVersion: Int; var results: [FormCheckResult] }
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directoryName: String = "MorpheStore") {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("form-check-history.json")
    }

    func load() -> [FormCheckResult] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        if let w = try? decoder.decode(Wrapper.self, from: data) { return w.results }
        return []   // unreadable → empty, never a crash
    }

    func append(_ result: FormCheckResult) {
        var all = load()
        all.insert(result, at: 0)
        if let data = try? encoder.encode(Wrapper(schemaVersion: 2, results: all)) {
            try? data.write(to: url, options: [.atomic])
        }
    }

    /// Best turning-point angle on record for a pattern — fullest range in
    /// the pattern's own direction, never compared across patterns.
    func bestPeakAngle(for pattern: FormMovementPattern) -> Double? {
        let spec = pattern.spec
        let peaks = load().filter { $0.pattern == pattern.rawValue && $0.reps > 0 }.map(\.bestMinKneeAngle).filter { $0 > 0 }
        guard let first = peaks.first else { return nil }
        return peaks.reduce(first) { spec.isFuller(CGFloat($1), than: CGFloat($0)) ? $1 : $0 }
    }

    /// Longest hold on record for a hold-type exercise.
    func bestHold(for exercise: String) -> Double? {
        load().filter { $0.exercise == exercise }.map(\.holdSeconds).filter { $0 > 0 }.max()
    }

    func clear() { try? FileManager.default.removeItem(at: url) }
}

// MARK: Camera + Vision session

@Observable
final class FormCheckSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    enum Availability { case unknown, authorized, denied, unavailable }

    /// Where the build-reading stands — shown as a pill so the athlete knows
    /// to hold still for a moment before the first rep.
    enum CalibrationState: Equatable {
        case waiting            // not framed yet
        case reading(Double)    // 0…1 progress through the still frames
        case ready(FormViewAngle)
    }

    // Observed UI state (always mutated on the main actor).
    private(set) var availability: Availability = .unknown
    private(set) var isRunning = false
    private(set) var framing: FramingState = .noPerson
    private(set) var calibrationState: CalibrationState = .waiting
    private(set) var repCount = 0
    /// Live smoothed primary angle, for the on-screen readout.
    private(set) var liveAngle: CGFloat?
    /// Detected joints in view space: normalized (0...1), top-left origin,
    /// already mirrored to match the front-camera preview.
    private(set) var joints: PoseJoints = [:]
    /// Holds: seconds held still in frame. Timed sets: seconds since start.
    private(set) var elapsedSeconds: Double = 0

    let exerciseName: String
    let pattern: FormMovementPattern
    var spec: FormPatternSpec { pattern.spec }

    let session: AVCaptureSession = {
        let session = AVCaptureSession()
        // Video-only capture (audio audit P1-6): never let the capture
        // session auto-configure the app audio session — Form Check has
        // no mic input, so it has no business touching audio at all.
        session.automaticallyConfiguresApplicationAudioSession = false
        return session
    }()

    private let sessionQueue = DispatchQueue(label: "com.morpheapp.formcheck.session")
    private let videoQueue = DispatchQueue(label: "com.morpheapp.formcheck.video")
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private var isConfigured = false

    // Per-rep feedback.
    private(set) var repMetrics: [FormRepMetrics] = []
    private(set) var liveCue: String?
    private(set) var lastRepGrade: FormRepGrade?

    // Form Clips: a movie output rides the same session. The clip lives in
    // the temp directory and leaves through the SYSTEM share sheet — it
    // never touches Morphe's backend, so no Storage bucket and no
    // moderation surface exist to build (that's full S3, gated on Blaze).
    private let movieOutput = AVCaptureMovieFileOutput()
    private(set) var isRecording = false
    private(set) var recordingSeconds = 0
    private(set) var finishedClipURL: URL?
    private var recordingTimer: Timer?
    /// Clips cap at 30s — form clips, not vlogs.
    private static let clipSecondsCap = 30

    // The pipeline (video queue only).
    private var detector: RepDetector
    private var calibrator = BodyCalibrator()
    private var smoothed: PoseJoints = [:]
    private var lastFrameTime: Double?
    private var framesWithoutPerson = 0
    private var holdAccumulated: Double = 0
    private var startedAt: Double?
    private let history = FormCheckFilePersistence()

    /// Per-joint exponential smoothing: enough to stop the skeleton
    /// shimmering, not enough to lag a real movement.
    private static let smoothing: CGFloat = 0.55
    /// Pose confidence floor — low-certainty joints stay out of the math;
    /// they were the biggest source of wrong depth and knee readings.
    private static let confidenceFloor: Float = 0.5

    init(exerciseName: String, pattern: FormMovementPattern) {
        self.exerciseName = exerciseName
        self.pattern = pattern
        self.detector = RepDetector(spec: pattern.spec)
        super.init()
    }

    // MARK: Lifecycle

    func configure() {
        guard !isConfigured else { start(); return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            buildSessionAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.buildSessionAndStart() }
                    else { self?.availability = .denied }
                }
            }
        default:
            availability = .denied
        }
    }

    private func buildSessionAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input)
            else {
                DispatchQueue.main.async { self.availability = .unavailable }
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            self.session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.videoQueue)
            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
            }
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90  // portrait
            }
            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
                if let clipConnection = self.movieOutput.connection(with: .video) {
                    if clipConnection.isVideoRotationAngleSupported(90) {
                        clipConnection.videoRotationAngle = 90
                    }
                    // Mirror to match what the athlete sees in the preview.
                    if clipConnection.isVideoMirroringSupported {
                        clipConnection.isVideoMirrored = true
                    }
                }
            }
            self.session.commitConfiguration()
            self.isConfigured = true

            self.session.startRunning()
            DispatchQueue.main.async {
                self.availability = .authorized
                self.isRunning = true
            }
        }
    }

    func start() {
        guard isConfigured, !session.isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.isRunning = true }
        }
    }

    // MARK: Form Clips (record + hand off to the system share sheet)

    func toggleClipRecording() {
        isRecording ? stopClipRecording() : startClipRecording()
    }

    private func startClipRecording() {
        guard availability == .authorized, !isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("morphe-form-clip-\(Int(Date.now.timeIntervalSince1970)).mov")
        try? FileManager.default.removeItem(at: url)
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        recordingSeconds = 0
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.isRecording else { return }
                self.recordingSeconds += 1
                if self.recordingSeconds >= Self.clipSecondsCap {
                    self.stopClipRecording()
                }
            }
        }
    }

    func stopClipRecording() {
        guard isRecording else { return }
        // isRecording flips in the delegate — when the file is actually real.
        movieOutput.stopRecording()
    }

    func clearFinishedClip() {
        if let url = finishedClipURL {
            try? FileManager.default.removeItem(at: url)
        }
        finishedClipURL = nil
    }

    func stop() {
        sessionQueue.async { [weak self] in
            if self?.session.isRunning == true { self?.session.stopRunning() }
            DispatchQueue.main.async { self?.isRunning = false }
        }
    }

    /// Bumped on every reset; a rep dispatched from a frame processed just
    /// before the reset carries the old value and is dropped on arrival.
    @ObservationIgnored private var resetGeneration = 0

    func resetReps() {
        repCount = 0
        repMetrics = []
        liveCue = nil
        lastRepGrade = nil
        elapsedSeconds = 0
        resetGeneration += 1
        videoQueue.async { [weak self] in
            guard let self else { return }
            self.detector.reset()
            self.holdAccumulated = 0
            self.startedAt = nil
        }
    }

    /// Ends the set, analyzes it, persists the result, and returns the summary
    /// plus the all-time best for the review screen.
    func finishSet() -> (summary: FormSetSummary, bestEver: Double?) {
        stop()
        let summary = FormAnalyzer.analyze(repMetrics, pattern: pattern, holdSeconds: elapsedSeconds)
        if summary.reps > 0 || (pattern == .hold && summary.holdSeconds >= 5) {
            history.append(FormCheckResult(
                date: Date().timeIntervalSince1970,
                exercise: exerciseName,
                pattern: pattern,
                reps: summary.reps,
                avgMinKneeAngle: Double(summary.avgPeakAngle),
                bestMinKneeAngle: Double(summary.bestPeakAngle),
                holdSeconds: summary.holdSeconds,
                cues: summary.cues.map(\.message)))
        }
        let best: Double? = pattern == .hold ? history.bestHold(for: exerciseName) : history.bestPeakAngle(for: pattern)
        return (summary, best)
    }

    // MARK: Frame processing (video queue)

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let frameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        if startedAt == nil { startedAt = frameTime }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([poseRequest])

        // Several people in frame: follow the one the camera reads best
        // (most confident joints), not whoever Vision listed first.
        let observation = (poseRequest.results ?? []).max { a, b in
            let ca = (try? a.recognizedPoints(.all))?.values.filter { $0.confidence > Self.confidenceFloor }.count ?? 0
            let cb = (try? b.recognizedPoints(.all))?.values.filter { $0.confidence > Self.confidenceFloor }.count ?? 0
            return ca < cb
        }
        guard let observation, let points = try? observation.recognizedPoints(.all) else {
            lostPerson(at: frameTime)
            return
        }

        // Vision: normalized, bottom-left origin. Convert to top-left and
        // mirror X so the overlay lines up with the mirrored front preview.
        var raw: PoseJoints = [:]
        for (name, point) in points where point.confidence > Self.confidenceFloor {
            raw[name] = CGPoint(x: 1 - point.location.x, y: 1 - point.location.y)
        }
        guard raw.count >= 5 else { lostPerson(at: frameTime); return }
        framesWithoutPerson = 0

        // Exponential smoothing per joint; a joint that just reappeared
        // snaps to its new position rather than sliding in from stale data.
        var next: PoseJoints = [:]
        for (name, p) in raw {
            if let prev = smoothed[name] {
                let a = Self.smoothing
                next[name] = CGPoint(x: prev.x + (p.x - prev.x) * a, y: prev.y + (p.y - prev.y) * a)
            } else {
                next[name] = p
            }
        }
        smoothed = next

        let framing = FramingState.judge(next, posture: spec.posture, spec: spec)

        // The build is read from still, framed frames; once known it feeds
        // every proportional check in the detector.
        if framing.isTrackable {
            calibrator.ingest(next, posture: spec.posture)
            if detector.calibration == nil, let cal = calibrator.calibration {
                detector.calibration = cal
            }
        }
        let calState: CalibrationState = {
            if let cal = calibrator.calibration { return .ready(cal.viewAngle) }
            return framing.isTrackable ? .reading(calibrator.progress) : .waiting
        }()

        let frame = PoseFrame(joints: next, time: frameTime)
        let newRep = detector.ingest(frame)
        let angle = detector.currentAngle
        let generation = resetGeneration

        // Holds accumulate still time; timed sets just run.
        var elapsed: Double?
        if pattern == .hold {
            if let last = lastFrameTime, framing.isTrackable, Self.isStill(next, previous: smoothedBeforeHold) {
                holdAccumulated += max(0, min(0.2, frameTime - last))
            }
            elapsed = holdAccumulated
        } else if pattern == .untracked, let startedAt {
            elapsed = frameTime - startedAt
        }
        smoothedBeforeHold = next
        lastFrameTime = frameTime

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.joints = next
            self.framing = framing
            self.calibrationState = calState
            self.liveAngle = angle
            if let elapsed { self.elapsedSeconds = elapsed }
            if let metrics = newRep, generation == self.resetGeneration {
                self.repMetrics.append(metrics)
                self.repCount += 1
                self.lastRepGrade = FormAnalyzer.grade(metrics)
                self.liveCue = FormAnalyzer.liveCue(for: metrics, repNumber: self.repCount)
                Haptics.impact(.light)
            }
        }
    }

    private var smoothedBeforeHold: PoseJoints = [:]

    /// Still enough to count as holding: the tracked joints barely moved.
    private static func isStill(_ now: PoseJoints, previous: PoseJoints) -> Bool {
        var total: CGFloat = 0, n = 0
        for (name, p) in now {
            guard let q = previous[name] else { continue }
            total += hypot(p.x - q.x, p.y - q.y); n += 1
        }
        return n > 0 && total / CGFloat(n) < 0.006
    }

    private func lostPerson(at time: Double) {
        framesWithoutPerson += 1
        lastFrameTime = time
        // Stale joints must not slide back in when the person reappears.
        smoothed = [:]
        // A third of a second gone mid-rep: that rep is abandoned, never
        // banked on the first frame back.
        if framesWithoutPerson == 10 { detector.reset() }
        // A real absence resets the build so the next person (or a changed
        // camera distance) is re-read.
        if framesWithoutPerson > 45 {
            calibrator.reset()
            detector.calibration = nil
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.joints = [:]
            self.framing = .noPerson
            if self.framesWithoutPerson > 45 { self.calibrationState = .waiting }
        }
    }
}

extension FormCheckSession: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            self.finishedClipURL = error == nil ? outputFileURL : nil
        }
    }
}

// MARK: - Camera preview (AVCaptureVideoPreviewLayer)

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.configuredSession = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.configuredSession = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        var configuredSession: AVCaptureSession? {
            didSet { attachSession() }
        }

        // RotationCoordinator is Apple's fix for exactly our bug: it knows the
        // camera's true portrait angle per device and publishes changes via
        // KVO. A hand-set 90 could be silently undone when the session's
        // commitConfiguration recreated the preview connection AFTER the layer
        // attached — with no later layout pass, the default (sideways) stuck.
        private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
        private var rotationObservation: NSKeyValueObservation?
        private var startObserver: NSObjectProtocol?

        deinit {
            if let startObserver {
                NotificationCenter.default.removeObserver(startObserver)
            }
        }

        // Assigning the session to the preview layer BEFORE the view is in the
        // window hierarchy can leave the preview connection inactive — a black
        // screen even though the session is running. Re-attaching once the view
        // has a window (and on every session change) is the reliable fix.
        override func didMoveToWindow() {
            super.didMoveToWindow()
            attachSession()
        }

        // Re-assert on layout too — belt and suspenders alongside the
        // coordinator and the did-start-running observer.
        override func layoutSubviews() {
            super.layoutSubviews()
            applyPortraitRotation()
        }

        private func attachSession() {
            guard window != nil, let session = configuredSession else { return }
            if videoPreviewLayer.session !== session {
                videoPreviewLayer.session = session
            }
            videoPreviewLayer.videoGravity = .resizeAspectFill

            // The session (re)creates its preview connection when configuration
            // commits, which wipes any angle set earlier. It always starts
            // running right after committing, so re-applying on this
            // notification closes the ordering hole for good.
            if startObserver == nil {
                startObserver = NotificationCenter.default.addObserver(
                    forName: .AVCaptureSessionDidStartRunning,
                    object: session,
                    queue: .main
                ) { [weak self] _ in
                    self?.applyPortraitRotation(retry: true)
                }
            }
            applyPortraitRotation(retry: true)
        }

        /// Pin the preview to portrait via the device's RotationCoordinator;
        /// the front-camera preview layer stays mirrored (selfie) by default,
        /// matching the pose overlay's coords.
        private func applyPortraitRotation(retry: Bool = false) {
            guard let connection = videoPreviewLayer.connection else {
                if retry {
                    // Connection not formed yet — try again shortly.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.applyPortraitRotation(retry: true)
                    }
                }
                return
            }

            if rotationCoordinator == nil,
               let device = (configuredSession?.inputs.first as? AVCaptureDeviceInput)?.device {
                let coordinator = AVCaptureDevice.RotationCoordinator(
                    device: device,
                    previewLayer: videoPreviewLayer
                )
                rotationCoordinator = coordinator
                rotationObservation = coordinator.observe(
                    \.videoRotationAngleForHorizonLevelPreview,
                    options: [.new]
                ) { [weak self] _, _ in
                    DispatchQueue.main.async { self?.applyPortraitRotation() }
                }
            }

            // Coordinator angle when available; 90 as the portrait fallback
            // until the session's input exists.
            let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview ?? 90
            if connection.isVideoRotationAngleSupported(angle), connection.videoRotationAngle != angle {
                connection.videoRotationAngle = angle
            }
        }
    }
}

// MARK: - Skeleton + framing overlay

private struct PoseOverlay: View {
    let joints: PoseJoints
    let framing: FramingState
    let spec: FormPatternSpec

    // Bones to connect, as joint-name pairs.
    private static let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    /// The joints the pattern is read from draw brighter and larger, so the
    /// athlete sees exactly what the camera is measuring.
    private var primaryJoints: Set<VNHumanBodyPoseObservation.JointName> {
        guard spec.countsReps else { return [] }
        return [spec.left.0, spec.left.1, spec.left.2, spec.right.0, spec.right.1, spec.right.2]
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let primary = primaryJoints
            ZStack {
                // Distance framing box.
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .inset(by: 4)
                    .stroke(framing.color, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .padding(.horizontal, w * 0.10)
                    .padding(.vertical, h * 0.06)

                // Bones.
                Path { path in
                    for (a, b) in Self.bones {
                        guard let pa = joints[a], let pb = joints[b] else { continue }
                        path.move(to: CGPoint(x: pa.x * w, y: pa.y * h))
                        path.addLine(to: CGPoint(x: pb.x * w, y: pb.y * h))
                    }
                }
                .stroke(framing.color.opacity(0.9), lineWidth: 3)

                // Joints.
                ForEach(Array(joints.keys), id: \.self) { name in
                    if let p = joints[name] {
                        let isPrimary = primary.contains(name)
                        Circle()
                            .fill(isPrimary ? Color.white : framing.color)
                            .frame(width: isPrimary ? 12 : 8, height: isPrimary ? 12 : 8)
                            .overlay(Circle().stroke(framing.color, lineWidth: isPrimary ? 2 : 0))
                            .position(x: p.x * w, y: p.y * h)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.linear(duration: 0.08), value: framing)
    }
}

// MARK: - Screen

struct FormCheckView: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var session: FormCheckSession
    @State private var summaryPayload: SummaryPayload?
    @State private var flashGrade: FormRepGrade?
    @State private var flashToken = 0

    /// Called with the rep count when the user submits the set, so the live
    /// workout can log the camera-counted reps.
    var onFinish: (Int) -> Void = { _ in }

    private struct SummaryPayload: Identifiable {
        let id = UUID()
        let summary: FormSetSummary
        let bestEver: Double?
        let exerciseName: String
        let metrics: [FormRepMetrics]
    }

    init(exerciseName: String = "Squat", pattern: FormMovementPattern = .squat,
         onFinish: @escaping (Int) -> Void = { _ in }) {
        _session = State(initialValue: FormCheckSession(exerciseName: exerciseName, pattern: pattern))
        self.onFinish = onFinish
    }

    private var spec: FormPatternSpec { session.spec }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch session.availability {
            case .authorized:
                liveView
            case .denied:
                messageState(
                    title: "Camera access needed",
                    detail: "Form Check needs the camera to see your movement. Enable it in Settings → Morphe → Camera. Video never leaves your phone."
                )
            case .unavailable:
                messageState(
                    title: "Needs a real device",
                    detail: "Form Check uses the front camera, which the Simulator doesn't have. Run Morphe on an iPhone to try it."
                )
            case .unknown:
                ProgressView().tint(.white)
            }
        }
        .task { session.configure() }
        .onDisappear {
            session.stopClipRecording()
            session.stop()
        }
        // The finished clip hands straight to the system share sheet —
        // Photos, Messages, IG, wherever. Dismissing cleans the temp file.
        .sheet(isPresented: Binding(
            get: { session.finishedClipURL != nil },
            set: { if !$0 { session.clearFinishedClip() } }
        )) {
            if let url = session.finishedClipURL {
                DataExportShareSheet(url: url) {
                    store.noteFormClipCaptured()
                    session.clearFinishedClip()
                }
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(item: $summaryPayload) { payload in
            FormSummarySheet(
                summary: payload.summary,
                bestEver: payload.bestEver,
                exerciseName: payload.exerciseName,
                metrics: payload.metrics
            ) {
                let reps = payload.summary.reps
                summaryPayload = nil
                onFinish(reps)
                dismiss()
            }
        }
    }

    private var liveView: some View {
        ZStack {
            CameraPreview(session: session.session).ignoresSafeArea()
            PoseOverlay(joints: session.joints, framing: session.framing, spec: spec).ignoresSafeArea()

            VStack {
                header

                // Expectations set BEFORE the first rep, not in a footnote:
                // this frames, counts, and reads angles — it does not
                // diagnose form.
                Text(spec.countsReps
                     ? "Reads joint angles, range and tempo. A training aid, not a form diagnosis."
                     : (spec.pattern == .hold ? "Times how long you hold still. A training aid, not a form diagnosis."
                                              : "The camera can't read this movement yet — timing the set."))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.45)))

                // Per-rep grade pop-up at the top — clear of the framing pill
                // and rep counter at the bottom.
                if let flashGrade {
                    Text(flashGrade.rawValue.uppercased())
                        .scaledFont(size: 34, weight: .heavy, design: .monospaced)
                        .tracking(3)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .fill(flashGrade.color.opacity(0.92))
                        )
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .padding(.top, 10)
                }

                Spacer()
                footer
            }
            .padding(20)
        }
        .onChange(of: session.repCount) { _, _ in
            guard let grade = session.lastRepGrade else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { flashGrade = grade }
            flashToken += 1
            let token = flashToken
            Task {
                try? await Task.sleep(for: .seconds(1.1))
                if token == flashToken {
                    withAnimation(.easeOut(duration: 0.3)) { flashGrade = nil }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("FORM CHECK · \(spec.label.uppercased())")
                    .font(MorpheTheme.microLabel(10)).tracking(1.6)
                    .foregroundStyle(MorpheTheme.brandBlueText)
                Text(session.exerciseName.uppercased())
                    .scaledFont(size: 22, weight: .bold, design: .monospaced).tracking(2)
                    .foregroundStyle(.white)
                Text(spec.setupHint)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: MorpheTheme.radius).fill(.black.opacity(0.5)))
            }
            .accessibilityLabel("Close Form Check")
        }
    }

    /// The build-reading pill: hold still a beat, then the camera knows you.
    private var calibrationLabel: String? {
        switch session.calibrationState {
        case .waiting: return nil
        case .reading(let p): return "READING YOUR BUILD · \(Int(p * 100))%"
        case .ready(let view): return "LOCKED · \(view == .front ? "FRONT" : "SIDE") VIEW"
        }
    }

    private var counterValue: String {
        switch spec.pattern {
        case .hold, .untracked:
            let s = Int(session.elapsedSeconds)
            return String(format: "%d:%02d", s / 60, s % 60)
        default:
            return "\(session.repCount)"
        }
    }

    private var counterLabel: String {
        switch spec.pattern {
        case .hold: return "HELD"
        case .untracked: return "TIMED"
        default: return "REPS"
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            // Framing status pill, and the build-reading pill beside it.
            HStack(spacing: 8) {
                Text(session.framing.label)
                    .font(MorpheTheme.microLabel(12)).tracking(1.6)
                    .foregroundStyle(MorpheTheme.onFill(session.framing.color))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: MorpheTheme.radius).fill(session.framing.color))
                if spec.countsReps, let calibrationLabel {
                    Text(calibrationLabel)
                        .font(MorpheTheme.microLabel(10)).tracking(1.4)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: MorpheTheme.radius).fill(Color.black.opacity(0.55)))
                }
            }

            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(counterValue)
                        .scaledFont(size: 56, weight: .bold, design: .monospaced)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                    Text(counterLabel)
                        .font(MorpheTheme.microLabel(12)).tracking(2)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    // The live primary angle — the number the rep is read from.
                    if spec.countsReps, let angle = session.liveAngle {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(angle))°")
                                .scaledFont(size: 22, weight: .semibold, design: .monospaced)
                                .foregroundStyle(.white)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text(spec.angleName.uppercased())
                                .font(MorpheTheme.microLabel(9)).tracking(1.4)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }

                if let cue = session.liveCue, spec.countsReps {
                    Text(cue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button("Reset") { session.resetReps() }
                        .buttonStyle(SecondaryCTAButtonStyle())

                    // Form Clips: record ≤30s with the overlay running,
                    // then share through the SYSTEM sheet — the clip never
                    // touches Morphe's backend.
                    Button {
                        session.toggleClipRecording()
                        Haptics.impact(session.isRecording ? .light : .medium)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(session.isRecording ? MorpheTheme.danger : .white)
                                .frame(width: 8, height: 8)
                            Text(session.isRecording ? "0:\(String(format: "%02d", session.recordingSeconds))" : "Clip")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .accessibilityLabel(session.isRecording
                        ? "Stop recording, \(session.recordingSeconds) seconds"
                        : "Record a form clip")

                    Button("Finish") {
                        let result = session.finishSet()
                        summaryPayload = SummaryPayload(
                            summary: result.summary,
                            bestEver: result.bestEver,
                            exerciseName: session.exerciseName,
                            metrics: session.repMetrics
                        )
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.brandBlue))
                    .accessibilityLabel("Finish set and review")
                    .disabled(spec.countsReps ? session.repCount == 0 : session.elapsedSeconds < 1)
                    .opacity((spec.countsReps ? session.repCount == 0 : session.elapsedSeconds < 1) ? 0.5 : 1)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: MorpheTheme.radius).fill(.black.opacity(0.55)))

            Text("Morphe reads what the front camera can see — joint angles, range, tempo and alignment. It can't see the load, your spine, or pain. A training aid, not a physical therapist.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private func messageState(title: String, detail: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 40)).foregroundStyle(MorpheTheme.brandBlueText)
            Text(title).font(.title3.weight(.bold)).foregroundStyle(.white)
            Text(detail)
                .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.brandBlue))
                .padding(.top, 8)
        }
        .padding(28)
    }
}

// MARK: - Set review (post-set summary + honest cues)

private struct FormSummarySheet: View {
    let summary: FormSetSummary
    let bestEver: Double?
    var exerciseName: String = "Squat"
    var metrics: [FormRepMetrics] = []
    let onClose: () -> Void

    private var spec: FormPatternSpec { summary.pattern.spec }
    private var bestLabel: String { spec.restsExtended ? "Deepest" : "Fullest" }

    #if DEBUG
    @State private var aiText: String?
    @State private var aiError: String?
    @State private var aiLoading = false
    @State private var keyDraft = ""
    @State private var hasKey = (DevAIKey.value?.isEmpty == false)
    #endif

    private func clock(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitleView(title: "Set Review", subtitle: "What the front camera measured this set.")

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            if spec.countsReps {
                                HStack(spacing: 8) {
                                    MetricPill(label: "Reps", value: "\(summary.reps)")
                                    MetricPill(label: "Avg \(spec.angleName)", value: summary.reps > 0 ? "\(Int(summary.avgPeakAngle))°" : "—")
                                    MetricPill(label: bestLabel, value: summary.reps > 0 ? "\(Int(summary.bestPeakAngle))°" : "—")
                                }
                                Text(spec.rangeNote)
                                    .font(.caption2)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            } else if summary.pattern == .hold {
                                HStack(spacing: 8) {
                                    MetricPill(label: "Held still", value: clock(summary.holdSeconds))
                                }
                                Text(spec.rangeNote)
                                    .font(.caption2)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            } else {
                                HStack(spacing: 8) {
                                    MetricPill(label: "Timed", value: clock(summary.holdSeconds))
                                }
                                Text("The camera can't read this movement yet, so nothing here is a form read.")
                                    .font(.caption2)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                        }
                    }

                    if summary.cues.isEmpty {
                        GlassCard {
                            Text(summary.reps == 0 && spec.countsReps
                                 ? "No full reps were counted. Get your whole body in the green frame, hold still a moment so Morphe reads your build, then move through a full range."
                                 : (spec.countsReps ? "Nothing to flag — those reps looked clean."
                                                    : (summary.pattern == .hold ? "Hold recorded." : "Timed — nothing logged.")))
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(Array(summary.cues.enumerated()), id: \.offset) { _, cue in
                            GlassCard {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: cue.tone == .good ? "checkmark.circle.fill" : "arrow.up.forward.circle.fill")
                                        .foregroundStyle(cue.tone == .good ? Color(red: 0.30, green: 0.85, blue: 0.45) : MorpheTheme.accentText)
                                    Text(cue.message)
                                        .font(.subheadline)
                                        .foregroundStyle(MorpheTheme.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    #if DEBUG
                    if spec.countsReps { aiReviewSection }
                    #endif

                    if let best = bestEver, best > 0 {
                        Text(summary.pattern == .hold
                             ? "Your longest \(exerciseName.lowercased()) on record: \(clock(best))."
                             : "Your \(bestLabel.lowercased()) \(spec.label.lowercased().replacingOccurrences(of: " pattern", with: "")) rep on record: \(Int(best))° \(spec.angleName) angle.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Text("These are what the camera could see — a helpful signal, not a medical assessment. If something hurts, stop.")
                        .font(.caption2)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onClose() }.foregroundStyle(MorpheTheme.textPrimary)
                }
            }
        }
    }

    #if DEBUG
    @ViewBuilder private var aiReviewSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("AI COACH · DEV")
                    .font(MorpheTheme.microLabel(10)).tracking(1.4)
                    .foregroundStyle(MorpheTheme.accentText)

                if !hasKey {
                    Text("Paste an Anthropic API key to try AI coaching on this set. Dev builds only — stored on this device, never shipped.")
                        .font(.caption).foregroundStyle(MorpheTheme.textSecondary)
                    SecureField("sk-ant-...", text: $keyDraft)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Save key") {
                        DevAIKey.value = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        hasKey = (DevAIKey.value?.isEmpty == false)
                        keyDraft = ""
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                } else if let aiText {
                    Text(aiText)
                        .font(.subheadline).foregroundStyle(MorpheTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Re-run") { Task { await runAIReview() } }
                        .buttonStyle(SecondaryCTAButtonStyle())
                } else {
                    if let aiError {
                        Text(aiError)
                            .font(.caption).foregroundStyle(Color(red: 0.92, green: 0.40, blue: 0.40))
                    }
                    Button(aiLoading ? "Reviewing…" : "Get Coaching") {
                        Task { await runAIReview() }
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .disabled(aiLoading || summary.reps == 0)
                }
            }
        }
    }

    @MainActor private func runAIReview() async {
        aiLoading = true
        aiError = nil
        defer { aiLoading = false }
        do {
            aiText = try await FormAIReviewer().review(
                exerciseName: exerciseName, pattern: summary.pattern, metrics: metrics)
        } catch {
            aiError = (error as? FormAIReviewer.APIError)?.message ?? error.localizedDescription
        }
    }
    #endif
}

#if DEBUG
// MARK: - Dev-only Claude form review
//
// GATED TO DEBUG BUILDS ONLY — never compiled into a release/TestFlight/App
// Store build, so the app can never ship an API key or call Anthropic
// directly. This is a temporary way to feel the AI coaching before the
// Firebase Cloud Function proxy exists (the proxy is where the key lives for
// real). The key is entered at runtime and stored on-device.

enum DevAIKey {
    private static let storageKey = "morphe.dev.anthropicKey"
    static var value: String? {
        get { UserDefaults.standard.string(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }
}

struct FormAIReviewer {
    struct APIError: Error { let message: String }

    /// Sends the MEASURED rep data (angles/tempo — never video) to Claude and
    /// returns a short coaching note. Raw HTTPS: Swift has no official
    /// Anthropic SDK.
    func review(exerciseName: String, pattern: FormMovementPattern, metrics: [FormRepMetrics]) async throws -> String {
        guard let apiKey = DevAIKey.value, !apiKey.isEmpty else {
            throw APIError(message: "No API key set.")
        }
        guard !metrics.isEmpty else {
            throw APIError(message: "No reps to review.")
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "claude-opus-4-8",
            "max_tokens": 320,
            "system": Self.system,
            "messages": [["role": "user", "content": Self.prompt(exerciseName: exerciseName, pattern: pattern, metrics: metrics)]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError(message: "No response from the API.") }
        guard http.statusCode == 200 else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0?["error"] as? [String: Any])?["message"] as? String }
            throw APIError(message: "API \(http.statusCode): \(detail ?? "request failed")")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw APIError(message: "Couldn't read the response.")
        }
        let text = content.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "No coaching came back — try again." : text
    }

    private static let system = """
    You are an experienced, encouraging strength coach reviewing ONE set an athlete just finished. It was measured by a phone's front camera — you have joint angles per rep, not video. Give 2–4 short sentences of specific coaching grounded ONLY in the numbers provided (range of motion, tempo, consistency across reps, symmetry, and the pattern's alignment read). Never diagnose injuries or pain. If the set looks clean, say so and give one thing to keep doing. Plain conversational language, no bullet lists, no preamble.
    """

    private static func prompt(exerciseName: String, pattern: FormMovementPattern, metrics: [FormRepMetrics]) -> String {
        let spec = pattern.spec
        var lines: [String] = [
            "Exercise: \(exerciseName)",
            "Pattern: \(spec.label) — the primary angle is the \(spec.angleName); \(spec.rangeNote)",
            "Reps counted: \(metrics.count)"
        ]
        for (i, m) in metrics.enumerated() {
            var parts = ["peak \(Int(m.peakAngle))°", "rest \(Int(m.restAngle))°",
                         "down \(String(format: "%.1f", m.descentSeconds))s", "up \(String(format: "%.1f", m.ascentSeconds))s"]
            if let v = m.valgusRatio { parts.append("knee/ankle spread \(String(format: "%.2f", v))") }
            if let l = m.torsoLean { parts.append("torso lean \(Int(l))°") }
            if let s = m.torsoSwing { parts.append("torso swing \(Int(s))°") }
            if let h = m.hipLineDeviation { parts.append("hip line bend \(Int(h))°") }
            if let a = m.asymmetry { parts.append("left/right gap \(Int(a))°") }
            if let k = m.secondaryAngle { parts.append("knee at bottom \(Int(k))°") }
            if let air = m.airtimeSeconds { parts.append("airtime \(String(format: "%.2f", air))s") }
            if let land = m.landingKneeAngle { parts.append("landing knee \(Int(land))°") }
            lines.append("Rep \(i + 1): " + parts.joined(separator: ", "))
        }
        lines.append("")
        lines.append("Reference: knee/ankle spread below ~0.85 suggests the knees caving inward (a single front camera reads this loosely). Torso lean is degrees from vertical. Hip line bend is how far the shoulder–hip–foot line deviates from straight.")
        return lines.joined(separator: "\n")
    }
}
#endif
