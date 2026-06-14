import Foundation

enum MorpheDemoContent {
    static let brandOneLiner = "Morphe helps beginners build consistency through AI guidance, coach support, and small daily wins."
    static let slogans = [
        "Build momentum, not perfection.",
        "Your next win starts today.",
        "Fitness that adapts to you.",
        "Small wins. Real transformation."
    ]

    static let launchMessages = [
        "Reading your recovery...",
        "Checking your goals...",
        "Today's plan is ready."
    ]

    static let themePresets = ThemePreset.allCases
    static let accentPalettes = AccentPalette.allCases
    static let avatarStyles = AvatarStyle.allCases
    static let bannerPresets = BannerPreset.allCases
    static let coachMarcusID = UUID(uuidString: "99999999-9999-9999-9999-999999999999") ?? UUID()
    static let lucasAthleteID = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
    static let alexAthleteID = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()
    static let mayaAthleteID = UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID()
    static let chrisAthleteID = UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID()
    static let jordanAthleteID = UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID()

    private static func daysAgo(_ count: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -count, to: .now) ?? .now
    }

    static let exerciseDatabase: [ExerciseReference] = [
        ExerciseReference(
            id: "goblet-squat",
            name: "Goblet Squat",
            muscleGroup: .legs,
            movementPattern: "Squat",
            musclesWorked: "Legs and glutes",
            equipment: "Dumbbell or kettlebell",
            difficulty: .beginner,
            videoPlaceholder: "Front-view squat demo placeholder",
            instructions: [
                "Hold one dumbbell at chest height.",
                "Sit your hips down between your heels.",
                "Drive through the floor and stand tall."
            ],
            formCue: "Keep your chest tall and push the floor away.",
            commonMistakes: "Knees collapsing inward.",
            beginnerModification: "Use a bodyweight squat to a bench.",
            alternatives: ["Bodyweight Squat", "Glute Bridge"],
            whyThisMatters: "Squat patterns build leg strength, balance, and everyday movement confidence."
        ),
        ExerciseReference(
            id: "bodyweight-squat",
            name: "Bodyweight Squat",
            muscleGroup: .legs,
            movementPattern: "Squat",
            musclesWorked: "Legs and glutes",
            equipment: "None",
            difficulty: .beginner,
            videoPlaceholder: "Coach-led bodyweight squat demo placeholder",
            instructions: [
                "Stand tall with feet just outside hip width.",
                "Sit down and back with control.",
                "Stand up without rushing."
            ],
            formCue: "Own the range you can control.",
            commonMistakes: "Falling forward too fast.",
            beginnerModification: "Sit to a chair and stand back up.",
            alternatives: ["Goblet Squat", "Glute Bridge"],
            whyThisMatters: "Bodyweight squats teach control before load."
        ),
        ExerciseReference(
            id: "incline-push-up",
            name: "Incline Push-Up",
            muscleGroup: .chest,
            movementPattern: "Push",
            musclesWorked: "Chest, shoulders, triceps",
            equipment: "Bench or countertop",
            difficulty: .beginner,
            videoPlaceholder: "Incline push-up setup placeholder",
            instructions: [
                "Place hands on an elevated surface.",
                "Keep your body in one long line.",
                "Lower with control and press away."
            ],
            formCue: "Move your ribs and hips together.",
            commonMistakes: "Hips sagging toward the floor.",
            beginnerModification: "Use a higher surface.",
            alternatives: ["Dumbbell Bench Press", "Wall Push-Up"],
            whyThisMatters: "This builds upper-body strength without overwhelming new lifters."
        ),
        ExerciseReference(
            id: "dumbbell-bench-press",
            name: "Dumbbell Bench Press",
            muscleGroup: .chest,
            movementPattern: "Push",
            musclesWorked: "Chest, shoulders, triceps",
            equipment: "Bench and dumbbells",
            difficulty: .moderate,
            videoPlaceholder: "Bench press demo placeholder",
            instructions: [
                "Set your shoulder blades before you press.",
                "Lower the dumbbells beside your chest.",
                "Press up with a full exhale."
            ],
            formCue: "Keep your forearms stacked under the weights.",
            commonMistakes: "Pressing with flared elbows.",
            beginnerModification: "Use lighter dumbbells or a floor press.",
            alternatives: ["Incline Push-Up", "Push-Up"],
            whyThisMatters: "Pressing strength supports body composition and sport power."
        ),
        ExerciseReference(
            id: "dumbbell-row",
            name: "Dumbbell Row",
            muscleGroup: .back,
            movementPattern: "Pull",
            musclesWorked: "Lats, upper back, biceps",
            equipment: "Bench and dumbbell",
            difficulty: .beginner,
            videoPlaceholder: "Single-arm row demo placeholder",
            instructions: [
                "Brace one hand on a bench or chair.",
                "Pull the elbow toward your hip.",
                "Lower the weight slowly."
            ],
            formCue: "Lead with your elbow, not your shoulder.",
            commonMistakes: "Shrugging the shoulder at the top.",
            beginnerModification: "Use a lighter dumbbell and shorten the range.",
            alternatives: ["Lat Pulldown", "Band Row"],
            whyThisMatters: "Rows improve posture and pulling strength."
        ),
        ExerciseReference(
            id: "lat-pulldown",
            name: "Lat Pulldown",
            muscleGroup: .back,
            movementPattern: "Pull",
            musclesWorked: "Lats, upper back, biceps",
            equipment: "Cable machine",
            difficulty: .beginner,
            videoPlaceholder: "Lat pulldown demo placeholder",
            instructions: [
                "Sit tall and grip the bar just outside shoulder width.",
                "Pull the bar toward your upper chest.",
                "Return with control."
            ],
            formCue: "Drive elbows down toward your pockets.",
            commonMistakes: "Leaning too far back.",
            beginnerModification: "Use a lighter stack and pause at the top.",
            alternatives: ["Dumbbell Row", "Band Pulldown"],
            whyThisMatters: "Pulling strength supports posture, shoulders, and contact sports."
        ),
        ExerciseReference(
            id: "glute-bridge",
            name: "Glute Bridge",
            muscleGroup: .legs,
            movementPattern: "Hinge",
            musclesWorked: "Glutes, hamstrings, core",
            equipment: "None",
            difficulty: .beginner,
            videoPlaceholder: "Glute bridge floor demo placeholder",
            instructions: [
                "Lie on your back with knees bent.",
                "Press through your feet and lift your hips.",
                "Pause at the top before lowering."
            ],
            formCue: "Tuck the ribs down and squeeze the glutes.",
            commonMistakes: "Overarching the low back.",
            beginnerModification: "Reduce the range and hold for one breath.",
            alternatives: ["Bodyweight Squat", "Romanian Deadlift"],
            whyThisMatters: "Glute strength supports sprinting, jumping, and low-back comfort."
        ),
        ExerciseReference(
            id: "romanian-deadlift",
            name: "Romanian Deadlift",
            muscleGroup: .legs,
            movementPattern: "Hinge",
            musclesWorked: "Glutes, hamstrings, back",
            equipment: "Dumbbells or barbell",
            difficulty: .moderate,
            videoPlaceholder: "Hip hinge demo placeholder",
            instructions: [
                "Soften the knees and hinge from the hips.",
                "Keep the weights close to your thighs.",
                "Stand tall by driving your hips through."
            ],
            formCue: "Keep the chest long while the hips travel back.",
            commonMistakes: "Turning it into a squat.",
            beginnerModification: "Use light dumbbells and stop at knee height.",
            alternatives: ["Glute Bridge", "Kettlebell Deadlift"],
            whyThisMatters: "Hinge patterns build power for sprinting, lifting, and posture."
        ),
        ExerciseReference(
            id: "walking-lunge",
            name: "Walking Lunge",
            muscleGroup: .legs,
            movementPattern: "Split stance",
            musclesWorked: "Quads, glutes, balance",
            equipment: "Bodyweight or dumbbells",
            difficulty: .moderate,
            videoPlaceholder: "Walking lunge demo placeholder",
            instructions: [
                "Take a comfortable step forward.",
                "Lower with control until both knees bend.",
                "Push through the front foot and continue."
            ],
            formCue: "Think soft landing, tall torso.",
            commonMistakes: "Rushing and wobbling through each rep.",
            beginnerModification: "Use stationary split squats instead.",
            alternatives: ["Bodyweight Squat", "Goblet Squat"],
            whyThisMatters: "Lunges improve balance and one-leg control."
        ),
        ExerciseReference(
            id: "shoulder-press",
            name: "Shoulder Press",
            muscleGroup: .shoulders,
            movementPattern: "Push",
            musclesWorked: "Shoulders, triceps, upper core",
            equipment: "Dumbbells",
            difficulty: .moderate,
            videoPlaceholder: "Standing shoulder press demo placeholder",
            instructions: [
                "Start with dumbbells at shoulder height.",
                "Brace the core before you press.",
                "Press overhead without leaning back."
            ],
            formCue: "Ribs down, biceps by the ears.",
            commonMistakes: "Overarching the low back.",
            beginnerModification: "Use one arm at a time while seated.",
            alternatives: ["Landmine Press", "Incline Push-Up"],
            whyThisMatters: "Overhead strength helps with posture and upper-body resilience."
        ),
        ExerciseReference(
            id: "bicep-curl",
            name: "Bicep Curl",
            muscleGroup: .arms,
            movementPattern: "Accessory",
            musclesWorked: "Biceps, forearms",
            equipment: "Dumbbells",
            difficulty: .beginner,
            videoPlaceholder: "Curl demo placeholder",
            instructions: [
                "Stand tall with elbows close to the ribs.",
                "Curl the weights up without swinging.",
                "Lower slowly."
            ],
            formCue: "Let the elbow stay quiet while the forearm moves.",
            commonMistakes: "Rocking the torso to lift the weight.",
            beginnerModification: "Use alternating curls with lighter weight.",
            alternatives: ["Hammer Curl", "Band Curl"],
            whyThisMatters: "Accessory work helps arms feel stronger and more capable."
        ),
        ExerciseReference(
            id: "tricep-pushdown",
            name: "Tricep Pushdown",
            muscleGroup: .arms,
            movementPattern: "Accessory",
            musclesWorked: "Triceps, forearms",
            equipment: "Cable machine",
            difficulty: .beginner,
            videoPlaceholder: "Tricep pushdown demo placeholder",
            instructions: [
                "Set the elbows close to your sides.",
                "Press the handle down until the arms are straight.",
                "Return slowly without letting the shoulders drift."
            ],
            formCue: "Keep the elbows pinned and finish long.",
            commonMistakes: "Letting the shoulders roll forward.",
            beginnerModification: "Use a resistance band version.",
            alternatives: ["Bench Dip", "Overhead Extension"],
            whyThisMatters: "Triceps support pressing strength and elbow stability."
        ),
        ExerciseReference(
            id: "plank",
            name: "Plank",
            muscleGroup: .core,
            movementPattern: "Brace",
            musclesWorked: "Core, shoulders, glutes",
            equipment: "None",
            difficulty: .beginner,
            videoPlaceholder: "Forearm plank demo placeholder",
            instructions: [
                "Set elbows under the shoulders.",
                "Lift into a straight line from head to heels.",
                "Hold while breathing slowly."
            ],
            formCue: "Pull the floor toward your toes.",
            commonMistakes: "Dropping the hips toward the floor.",
            beginnerModification: "Elevate the hands or shorten the hold.",
            alternatives: ["Dead Bug", "Bear Hold"],
            whyThisMatters: "A stronger brace helps almost every other movement."
        ),
        ExerciseReference(
            id: "dead-bug",
            name: "Dead Bug",
            muscleGroup: .core,
            movementPattern: "Brace",
            musclesWorked: "Deep core, hips, coordination",
            equipment: "None",
            difficulty: .beginner,
            videoPlaceholder: "Dead bug demo placeholder",
            instructions: [
                "Lie on your back with arms and knees up.",
                "Lower the opposite arm and leg slowly.",
                "Return and switch sides."
            ],
            formCue: "Keep the low back heavy on the floor.",
            commonMistakes: "Arching the back to reach farther.",
            beginnerModification: "Move one limb at a time.",
            alternatives: ["Plank", "Heel Tap"],
            whyThisMatters: "Core control makes strength work safer and cleaner."
        ),
        ExerciseReference(
            id: "treadmill-walk",
            name: "Treadmill Walk",
            muscleGroup: .conditioning,
            movementPattern: "Conditioning",
            musclesWorked: "Cardio, calves, glutes",
            equipment: "Treadmill",
            difficulty: .recovery,
            videoPlaceholder: "Incline walk placeholder",
            instructions: [
                "Set an easy incline and steady pace.",
                "Keep the chest tall and shoulders relaxed.",
                "Breathe through the nose when possible."
            ],
            formCue: "Walk like you are late but not panicked.",
            commonMistakes: "Holding the rails the whole time.",
            beginnerModification: "Use a flat treadmill or outdoor walk.",
            alternatives: ["Outdoor Walk", "Bike"],
            whyThisMatters: "Recovery cardio protects consistency on low-energy days."
        ),
        ExerciseReference(
            id: "barbell-back-squat",
            name: "Barbell Back Squat",
            muscleGroup: .legs,
            movementPattern: "Squat",
            musclesWorked: "Quads, glutes, and lower back",
            equipment: "Barbell and rack",
            difficulty: .moderate,
            videoPlaceholder: "Back squat demo placeholder",
            instructions: [
                "Set the bar across your upper back, not your neck.",
                "Brace your core and sit your hips down and back.",
                "Drive through mid-foot to stand tall."
            ],
            formCue: "Spread the floor with your feet as you stand.",
            commonMistakes: "Heels lifting or knees caving in.",
            beginnerModification: "Use a goblet squat until depth feels easy.",
            alternatives: ["Goblet Squat", "Leg Press"],
            whyThisMatters: "The back squat is the most direct way to build total-body lower strength."
        ),
        ExerciseReference(
            id: "front-squat",
            name: "Front Squat",
            muscleGroup: .legs,
            movementPattern: "Squat",
            musclesWorked: "Quads, glutes, and upper back",
            equipment: "Barbell and rack",
            difficulty: .advanced,
            videoPlaceholder: "Front squat demo placeholder",
            instructions: [
                "Rest the bar on your front delts with elbows high.",
                "Sit straight down keeping your torso upright.",
                "Stand without letting the elbows drop."
            ],
            formCue: "Elbows up, chest proud the whole rep.",
            commonMistakes: "Elbows dropping and rounding forward.",
            beginnerModification: "Use a goblet squat to learn the upright torso.",
            alternatives: ["Goblet Squat", "Barbell Back Squat"],
            whyThisMatters: "Front squats build quad strength and a strong, upright posture."
        ),
        ExerciseReference(
            id: "leg-press",
            name: "Leg Press",
            muscleGroup: .legs,
            movementPattern: "Squat",
            musclesWorked: "Quads and glutes",
            equipment: "Leg press machine",
            difficulty: .beginner,
            videoPlaceholder: "Leg press demo placeholder",
            instructions: [
                "Set feet shoulder-width on the platform.",
                "Lower until your knees reach about 90 degrees.",
                "Press back without locking the knees hard."
            ],
            formCue: "Control the weight down, then push the platform away.",
            commonMistakes: "Letting the lower back round off the pad.",
            beginnerModification: "Use a lighter load and a smaller range.",
            alternatives: ["Goblet Squat", "Barbell Back Squat"],
            whyThisMatters: "The leg press lets beginners load the legs safely with back support."
        ),
        ExerciseReference(
            id: "bulgarian-split-squat",
            name: "Bulgarian Split Squat",
            muscleGroup: .legs,
            movementPattern: "Split stance",
            musclesWorked: "Quads, glutes, and hips",
            equipment: "Bench and optional dumbbells",
            difficulty: .moderate,
            videoPlaceholder: "Split squat demo placeholder",
            instructions: [
                "Rest your back foot on a bench behind you.",
                "Lower straight down on the front leg.",
                "Drive through the front heel to stand."
            ],
            formCue: "Stack your weight over the front heel.",
            commonMistakes: "Leaning so the back leg does the work.",
            beginnerModification: "Hold a rail and use bodyweight only.",
            alternatives: ["Walking Lunge", "Reverse Lunge"],
            whyThisMatters: "Single-leg work fixes side-to-side imbalances and protects the knees."
        ),
        ExerciseReference(
            id: "reverse-lunge",
            name: "Reverse Lunge",
            muscleGroup: .legs,
            movementPattern: "Split stance",
            musclesWorked: "Quads, glutes, and hamstrings",
            equipment: "None or dumbbells",
            difficulty: .beginner,
            videoPlaceholder: "Reverse lunge demo placeholder",
            instructions: [
                "Step one foot straight back.",
                "Lower the back knee toward the floor.",
                "Push through the front heel to return."
            ],
            formCue: "Step back softly and stay tall.",
            commonMistakes: "Short steps that crowd the knee.",
            beginnerModification: "Hold a wall or rail for balance.",
            alternatives: ["Walking Lunge", "Step-Up"],
            whyThisMatters: "Reverse lunges are an easier-on-the-knees way to train each leg."
        ),
        ExerciseReference(
            id: "step-up",
            name: "Step-Up",
            muscleGroup: .legs,
            movementPattern: "Split stance",
            musclesWorked: "Quads and glutes",
            equipment: "Box or bench",
            difficulty: .beginner,
            videoPlaceholder: "Step-up demo placeholder",
            instructions: [
                "Place one full foot on a sturdy box.",
                "Drive through that heel to stand on top.",
                "Lower with control, don't hop down."
            ],
            formCue: "Let the top leg do the work, not the push-off foot.",
            commonMistakes: "Bouncing off the back foot.",
            beginnerModification: "Use a lower step.",
            alternatives: ["Reverse Lunge", "Walking Lunge"],
            whyThisMatters: "Step-ups build single-leg power that carries into stairs and sport."
        ),
        ExerciseReference(
            id: "leg-extension",
            name: "Leg Extension",
            muscleGroup: .legs,
            movementPattern: "Accessory",
            musclesWorked: "Quadriceps",
            equipment: "Leg extension machine",
            difficulty: .beginner,
            videoPlaceholder: "Leg extension demo placeholder",
            instructions: [
                "Set the pad just above your ankles.",
                "Straighten your knees smoothly.",
                "Lower with control to the start."
            ],
            formCue: "Squeeze the quads at the top for a beat.",
            commonMistakes: "Swinging the weight up with momentum.",
            beginnerModification: "Use a light plate and slow tempo.",
            alternatives: ["Goblet Squat", "Leg Press"],
            whyThisMatters: "Isolating the quads helps knee stability and balanced leg shape."
        ),
        ExerciseReference(
            id: "hamstring-curl",
            name: "Hamstring Curl",
            muscleGroup: .legs,
            movementPattern: "Accessory",
            musclesWorked: "Hamstrings",
            equipment: "Leg curl machine",
            difficulty: .beginner,
            videoPlaceholder: "Hamstring curl demo placeholder",
            instructions: [
                "Set the pad just above your heels.",
                "Curl your heels toward your glutes.",
                "Lower slowly under control."
            ],
            formCue: "Pull with the back of the legs, not your back.",
            commonMistakes: "Hips lifting off the pad.",
            beginnerModification: "Use a lighter load and pause at the top.",
            alternatives: ["Romanian Deadlift", "Glute Bridge"],
            whyThisMatters: "Strong hamstrings balance the quads and protect the knees."
        ),
        ExerciseReference(
            id: "calf-raise",
            name: "Standing Calf Raise",
            muscleGroup: .legs,
            movementPattern: "Accessory",
            musclesWorked: "Calves",
            equipment: "None or dumbbells",
            difficulty: .beginner,
            videoPlaceholder: "Calf raise demo placeholder",
            instructions: [
                "Stand tall with the balls of your feet on an edge.",
                "Rise onto your toes as high as possible.",
                "Lower the heels below the step for a stretch."
            ],
            formCue: "Pause at the top, full range at the bottom.",
            commonMistakes: "Bouncing through tiny reps.",
            beginnerModification: "Do them flat on the floor.",
            alternatives: ["Jump Rope", "Treadmill Walk"],
            whyThisMatters: "Calf strength supports running, jumping, and ankle health."
        ),
        ExerciseReference(
            id: "conventional-deadlift",
            name: "Conventional Deadlift",
            muscleGroup: .back,
            movementPattern: "Hinge",
            musclesWorked: "Posterior chain, back, and grip",
            equipment: "Barbell",
            difficulty: .advanced,
            videoPlaceholder: "Deadlift demo placeholder",
            instructions: [
                "Set the bar over mid-foot and grip just outside the legs.",
                "Brace, take the slack out, and push the floor away.",
                "Stand tall, then return the bar along your legs."
            ],
            formCue: "Push the floor down rather than pulling the bar up.",
            commonMistakes: "Rounding the lower back or jerking the bar.",
            beginnerModification: "Start with a Romanian deadlift or trap-bar pull.",
            alternatives: ["Romanian Deadlift", "Glute Bridge"],
            whyThisMatters: "The deadlift trains the whole posterior chain and teaches a safe hinge."
        ),
        ExerciseReference(
            id: "pull-up",
            name: "Pull-Up",
            muscleGroup: .back,
            movementPattern: "Pull",
            musclesWorked: "Lats, upper back, and biceps",
            equipment: "Pull-up bar",
            difficulty: .advanced,
            videoPlaceholder: "Pull-up demo placeholder",
            instructions: [
                "Hang from the bar with palms facing away.",
                "Pull your chest toward the bar, leading with the elbows.",
                "Lower all the way down with control."
            ],
            formCue: "Drive the elbows down toward your ribs.",
            commonMistakes: "Kipping or cutting the range short.",
            beginnerModification: "Use a band or the lat pulldown machine.",
            alternatives: ["Lat Pulldown", "Inverted Row"],
            whyThisMatters: "Pull-ups build serious upper-back and arm strength with just a bar."
        ),
        ExerciseReference(
            id: "inverted-row",
            name: "Inverted Row",
            muscleGroup: .back,
            movementPattern: "Pull",
            musclesWorked: "Upper back, lats, and biceps",
            equipment: "Bar or rings",
            difficulty: .beginner,
            videoPlaceholder: "Inverted row demo placeholder",
            instructions: [
                "Set a bar at hip height and hang underneath it.",
                "Keep a straight line from head to heels.",
                "Pull your chest to the bar, then lower slowly."
            ],
            formCue: "Squeeze the shoulder blades together at the top.",
            commonMistakes: "Hips sagging or chin poking forward.",
            beginnerModification: "Raise the bar higher to make it easier.",
            alternatives: ["Dumbbell Row", "Lat Pulldown"],
            whyThisMatters: "Inverted rows are a scalable path toward your first pull-up."
        ),
        ExerciseReference(
            id: "bent-over-row",
            name: "Bent-Over Barbell Row",
            muscleGroup: .back,
            movementPattern: "Pull",
            musclesWorked: "Mid-back, lats, and biceps",
            equipment: "Barbell",
            difficulty: .moderate,
            videoPlaceholder: "Barbell row demo placeholder",
            instructions: [
                "Hinge forward with a flat back, bar hanging down.",
                "Pull the bar to your lower ribs.",
                "Lower under control without standing up."
            ],
            formCue: "Lead with the elbows, keep the torso still.",
            commonMistakes: "Standing up or using momentum.",
            beginnerModification: "Use a single-arm dumbbell row with bench support.",
            alternatives: ["Dumbbell Row", "Seated Cable Row"],
            whyThisMatters: "Heavy rows build the thick, strong mid-back that balances pressing."
        ),
        ExerciseReference(
            id: "seated-cable-row",
            name: "Seated Cable Row",
            muscleGroup: .back,
            movementPattern: "Pull",
            musclesWorked: "Mid-back, lats, and biceps",
            equipment: "Cable machine",
            difficulty: .beginner,
            videoPlaceholder: "Cable row demo placeholder",
            instructions: [
                "Sit tall with a slight knee bend.",
                "Pull the handle to your stomach, elbows close.",
                "Return forward with control and a tall chest."
            ],
            formCue: "Lead with the elbows and squeeze the back.",
            commonMistakes: "Rocking the torso for momentum.",
            beginnerModification: "Lighten the stack and slow the return.",
            alternatives: ["Dumbbell Row", "Lat Pulldown"],
            whyThisMatters: "Cable rows build the back safely with constant, smooth tension."
        ),
        ExerciseReference(
            id: "face-pull",
            name: "Face Pull",
            muscleGroup: .back,
            movementPattern: "Pull",
            musclesWorked: "Rear delts and upper back",
            equipment: "Cable and rope",
            difficulty: .beginner,
            videoPlaceholder: "Face pull demo placeholder",
            instructions: [
                "Set a rope at face height.",
                "Pull the rope to your forehead, splitting the ends.",
                "Return slowly with tall posture."
            ],
            formCue: "Aim to make a double-biceps pose at the end.",
            commonMistakes: "Using too much weight and shrugging.",
            beginnerModification: "Use a band anchored at head height.",
            alternatives: ["Rear Delt Fly", "Lateral Raise"],
            whyThisMatters: "Face pulls balance the shoulders and undo desk-posture rounding."
        ),
        ExerciseReference(
            id: "barbell-bench-press",
            name: "Barbell Bench Press",
            muscleGroup: .chest,
            movementPattern: "Push",
            musclesWorked: "Chest, shoulders, and triceps",
            equipment: "Barbell and bench",
            difficulty: .moderate,
            videoPlaceholder: "Bench press demo placeholder",
            instructions: [
                "Set your shoulder blades down and back on the bench.",
                "Lower the bar to mid-chest with control.",
                "Press up and slightly back over the shoulders."
            ],
            formCue: "Bend the bar and keep the elbows tucked slightly.",
            commonMistakes: "Bouncing the bar or flaring the elbows wide.",
            beginnerModification: "Use dumbbells or a machine press first.",
            alternatives: ["Dumbbell Bench Press", "Push-Up"],
            whyThisMatters: "The bench press is the benchmark lift for upper-body pushing strength."
        ),
        ExerciseReference(
            id: "push-up",
            name: "Push-Up",
            muscleGroup: .chest,
            movementPattern: "Push",
            musclesWorked: "Chest, shoulders, triceps, and core",
            equipment: "None",
            difficulty: .beginner,
            videoPlaceholder: "Push-up demo placeholder",
            instructions: [
                "Set hands just wider than your shoulders.",
                "Keep a straight line from head to heels.",
                "Lower your chest to the floor, then press up."
            ],
            formCue: "Squeeze your glutes so the hips don't sag.",
            commonMistakes: "Hips dropping or flaring the elbows out.",
            beginnerModification: "Do them with hands on a bench.",
            alternatives: ["Incline Push-Up", "Dumbbell Bench Press"],
            whyThisMatters: "Push-ups build pressing strength and core control anywhere."
        ),
        ExerciseReference(
            id: "dumbbell-chest-fly",
            name: "Dumbbell Chest Fly",
            muscleGroup: .chest,
            movementPattern: "Accessory",
            musclesWorked: "Chest and front delts",
            equipment: "Dumbbells and bench",
            difficulty: .moderate,
            videoPlaceholder: "Chest fly demo placeholder",
            instructions: [
                "Lie back holding dumbbells over your chest.",
                "Open your arms in a wide arc with a soft elbow.",
                "Hug the weights back together over the chest."
            ],
            formCue: "Think about hugging a big tree.",
            commonMistakes: "Bending the elbows into a press.",
            beginnerModification: "Use lighter dumbbells and a smaller arc.",
            alternatives: ["Dumbbell Bench Press", "Push-Up"],
            whyThisMatters: "Flys stretch and shape the chest through a wide range."
        ),
        ExerciseReference(
            id: "overhead-press",
            name: "Overhead Barbell Press",
            muscleGroup: .shoulders,
            movementPattern: "Push",
            musclesWorked: "Shoulders, triceps, and upper chest",
            equipment: "Barbell",
            difficulty: .moderate,
            videoPlaceholder: "Overhead press demo placeholder",
            instructions: [
                "Hold the bar at your collarbone, elbows under the bar.",
                "Brace your core and press straight overhead.",
                "Lower with control back to the shoulders."
            ],
            formCue: "Squeeze your glutes so you don't lean back.",
            commonMistakes: "Arching the lower back to press.",
            beginnerModification: "Use the seated dumbbell shoulder press.",
            alternatives: ["Shoulder Press", "Arnold Press"],
            whyThisMatters: "Pressing overhead builds strong, healthy shoulders and a braced core."
        ),
        ExerciseReference(
            id: "lateral-raise",
            name: "Lateral Raise",
            muscleGroup: .shoulders,
            movementPattern: "Accessory",
            musclesWorked: "Side delts",
            equipment: "Dumbbells",
            difficulty: .beginner,
            videoPlaceholder: "Lateral raise demo placeholder",
            instructions: [
                "Hold dumbbells at your sides with a soft elbow.",
                "Raise your arms out to shoulder height.",
                "Lower slowly under control."
            ],
            formCue: "Lead with the elbows, not the hands.",
            commonMistakes: "Swinging the weight up with the body.",
            beginnerModification: "Use very light dumbbells or water bottles.",
            alternatives: ["Front Raise", "Shoulder Press"],
            whyThisMatters: "Lateral raises build the rounded shoulder caps that widen your frame."
        ),
        ExerciseReference(
            id: "rear-delt-fly",
            name: "Rear Delt Fly",
            muscleGroup: .shoulders,
            movementPattern: "Accessory",
            musclesWorked: "Rear delts and upper back",
            equipment: "Dumbbells",
            difficulty: .beginner,
            videoPlaceholder: "Rear delt fly demo placeholder",
            instructions: [
                "Hinge forward with a flat back.",
                "Raise the dumbbells out to the sides.",
                "Squeeze the rear shoulders, then lower."
            ],
            formCue: "Pinch the shoulder blades at the top.",
            commonMistakes: "Turning it into a row with the lats.",
            beginnerModification: "Use light weights and pause at the top.",
            alternatives: ["Face Pull", "Lateral Raise"],
            whyThisMatters: "Rear delts balance the shoulders and improve posture."
        ),
        ExerciseReference(
            id: "arnold-press",
            name: "Arnold Press",
            muscleGroup: .shoulders,
            movementPattern: "Push",
            musclesWorked: "Shoulders and triceps",
            equipment: "Dumbbells",
            difficulty: .moderate,
            videoPlaceholder: "Arnold press demo placeholder",
            instructions: [
                "Start with dumbbells in front, palms toward you.",
                "Rotate and press overhead in one motion.",
                "Reverse the path back to the start."
            ],
            formCue: "Rotate smoothly, finish with palms forward.",
            commonMistakes: "Rushing the rotation and using the back.",
            beginnerModification: "Use a standard seated shoulder press.",
            alternatives: ["Shoulder Press", "Overhead Barbell Press"],
            whyThisMatters: "The rotation hits all three shoulder heads in one move."
        ),
        ExerciseReference(
            id: "hammer-curl",
            name: "Hammer Curl",
            muscleGroup: .arms,
            movementPattern: "Accessory",
            musclesWorked: "Biceps and forearms",
            equipment: "Dumbbells",
            difficulty: .beginner,
            videoPlaceholder: "Hammer curl demo placeholder",
            instructions: [
                "Hold dumbbells with palms facing each other.",
                "Curl up keeping the thumbs on top.",
                "Lower slowly under control."
            ],
            formCue: "Keep the elbows pinned to your sides.",
            commonMistakes: "Swinging the weights with the body.",
            beginnerModification: "Use lighter dumbbells and slow tempo.",
            alternatives: ["Bicep Curl", "Seated Cable Row"],
            whyThisMatters: "Hammer curls build the biceps and the forearm for stronger grip."
        ),
        ExerciseReference(
            id: "preacher-curl",
            name: "Preacher Curl",
            muscleGroup: .arms,
            movementPattern: "Accessory",
            musclesWorked: "Biceps",
            equipment: "Preacher bench and bar",
            difficulty: .moderate,
            videoPlaceholder: "Preacher curl demo placeholder",
            instructions: [
                "Rest your arms over the angled pad.",
                "Curl the bar up with control.",
                "Lower all the way without bouncing."
            ],
            formCue: "Keep the back of the arms on the pad.",
            commonMistakes: "Dropping the weight fast at the bottom.",
            beginnerModification: "Use a light bar or single dumbbell.",
            alternatives: ["Bicep Curl", "Hammer Curl"],
            whyThisMatters: "The pad removes momentum so the biceps do all the work."
        ),
        ExerciseReference(
            id: "skullcrusher",
            name: "Skullcrusher",
            muscleGroup: .arms,
            movementPattern: "Accessory",
            musclesWorked: "Triceps",
            equipment: "EZ bar or dumbbells",
            difficulty: .moderate,
            videoPlaceholder: "Skullcrusher demo placeholder",
            instructions: [
                "Lie back holding the bar over your chest.",
                "Bend the elbows to lower toward your forehead.",
                "Extend back up without moving the upper arms."
            ],
            formCue: "Keep the upper arms still and vertical.",
            commonMistakes: "Letting the elbows drift and flare.",
            beginnerModification: "Use the tricep pushdown instead.",
            alternatives: ["Tricep Pushdown", "Overhead Tricep Extension"],
            whyThisMatters: "Skullcrushers build the long head of the triceps for stronger pressing."
        ),
        ExerciseReference(
            id: "overhead-tricep-extension",
            name: "Overhead Tricep Extension",
            muscleGroup: .arms,
            movementPattern: "Accessory",
            musclesWorked: "Triceps",
            equipment: "Dumbbell or cable",
            difficulty: .beginner,
            videoPlaceholder: "Overhead extension demo placeholder",
            instructions: [
                "Hold one dumbbell overhead with both hands.",
                "Lower it behind your head by bending the elbows.",
                "Extend back up to the top."
            ],
            formCue: "Keep the elbows pointing forward and close.",
            commonMistakes: "Elbows flaring wide.",
            beginnerModification: "Use a lighter dumbbell and smaller range.",
            alternatives: ["Tricep Pushdown", "Skullcrusher"],
            whyThisMatters: "Overhead work stretches and strengthens the triceps fully."
        ),
        ExerciseReference(
            id: "dip",
            name: "Triceps Dip",
            muscleGroup: .arms,
            movementPattern: "Push",
            musclesWorked: "Triceps, chest, and shoulders",
            equipment: "Parallel bars or bench",
            difficulty: .moderate,
            videoPlaceholder: "Dip demo placeholder",
            instructions: [
                "Support yourself on parallel bars, arms straight.",
                "Lower until the elbows reach about 90 degrees.",
                "Press back up to the top."
            ],
            formCue: "Stay tall and lower with control.",
            commonMistakes: "Dropping too deep and stressing the shoulders.",
            beginnerModification: "Do bench dips with feet on the floor.",
            alternatives: ["Tricep Pushdown", "Push-Up"],
            whyThisMatters: "Dips build pressing strength and triceps size with bodyweight."
        ),
        ExerciseReference(
            id: "hanging-knee-raise",
            name: "Hanging Knee Raise",
            muscleGroup: .core,
            movementPattern: "Brace",
            musclesWorked: "Lower abs and hip flexors",
            equipment: "Pull-up bar",
            difficulty: .moderate,
            videoPlaceholder: "Hanging knee raise demo placeholder",
            instructions: [
                "Hang from a bar with a steady grip.",
                "Curl your knees up toward your chest.",
                "Lower slowly without swinging."
            ],
            formCue: "Curl the pelvis up, don't just lift the legs.",
            commonMistakes: "Swinging for momentum.",
            beginnerModification: "Do lying knee tucks on the floor.",
            alternatives: ["Dead Bug", "Plank"],
            whyThisMatters: "Hanging work trains the deep abs and a strong grip together."
        ),
        ExerciseReference(
            id: "russian-twist",
            name: "Russian Twist",
            muscleGroup: .core,
            movementPattern: "Brace",
            musclesWorked: "Obliques and abs",
            equipment: "None or a weight",
            difficulty: .beginner,
            videoPlaceholder: "Russian twist demo placeholder",
            instructions: [
                "Sit with knees bent and lean back slightly.",
                "Rotate your torso to tap each side.",
                "Keep the chest tall throughout."
            ],
            formCue: "Turn from the ribs, not just the arms.",
            commonMistakes: "Rounding the back and rushing.",
            beginnerModification: "Keep heels down and skip the weight.",
            alternatives: ["Bicycle Crunch", "Side Plank"],
            whyThisMatters: "Rotation strength protects the spine and powers sport movements."
        ),
        ExerciseReference(
            id: "side-plank",
            name: "Side Plank",
            muscleGroup: .core,
            movementPattern: "Brace",
            musclesWorked: "Obliques and deep core",
            equipment: "None",
            difficulty: .beginner,
            videoPlaceholder: "Side plank demo placeholder",
            instructions: [
                "Stack your feet and prop up on one forearm.",
                "Lift your hips into a straight line.",
                "Hold steady, then switch sides."
            ],
            formCue: "Push the floor away and stay long.",
            commonMistakes: "Hips sagging toward the floor.",
            beginnerModification: "Drop the bottom knee for support.",
            alternatives: ["Plank", "Dead Bug"],
            whyThisMatters: "Side planks build the obliques that stabilize your spine."
        ),
        ExerciseReference(
            id: "bicycle-crunch",
            name: "Bicycle Crunch",
            muscleGroup: .core,
            movementPattern: "Brace",
            musclesWorked: "Abs and obliques",
            equipment: "None",
            difficulty: .beginner,
            videoPlaceholder: "Bicycle crunch demo placeholder",
            instructions: [
                "Lie back with hands lightly behind your head.",
                "Bring one elbow toward the opposite knee.",
                "Switch sides in a slow pedaling motion."
            ],
            formCue: "Rotate the rib toward the knee, slowly.",
            commonMistakes: "Yanking the neck and rushing.",
            beginnerModification: "Slow the tempo and keep feet higher.",
            alternatives: ["Russian Twist", "Dead Bug"],
            whyThisMatters: "Bicycle crunches train the abs and obliques through full rotation."
        ),
        ExerciseReference(
            id: "mountain-climber",
            name: "Mountain Climber",
            muscleGroup: .core,
            movementPattern: "Conditioning",
            musclesWorked: "Core, shoulders, and hip flexors",
            equipment: "None",
            difficulty: .beginner,
            videoPlaceholder: "Mountain climber demo placeholder",
            instructions: [
                "Start in a strong push-up position.",
                "Drive one knee toward your chest.",
                "Switch legs quickly while keeping hips low."
            ],
            formCue: "Keep the hips level, like a moving plank.",
            commonMistakes: "Hips bouncing high with each rep.",
            beginnerModification: "Slow the pace or drive knees to a bench.",
            alternatives: ["Plank", "Jump Rope"],
            whyThisMatters: "Mountain climbers blend core control with a cardio bump."
        ),
        ExerciseReference(
            id: "jump-rope",
            name: "Jump Rope",
            muscleGroup: .conditioning,
            movementPattern: "Conditioning",
            musclesWorked: "Calves, shoulders, and heart",
            equipment: "Jump rope",
            difficulty: .beginner,
            videoPlaceholder: "Jump rope demo placeholder",
            instructions: [
                "Turn the rope with the wrists, not the arms.",
                "Stay on the balls of your feet with small hops.",
                "Find a steady, repeatable rhythm."
            ],
            formCue: "Small, quiet bounces close to the floor.",
            commonMistakes: "Jumping too high and swinging the arms.",
            beginnerModification: "Practice the bounce with no rope first.",
            alternatives: ["Jumping Jacks", "Treadmill Walk"],
            whyThisMatters: "Jump rope builds footwork, coordination, and conditioning fast."
        ),
        ExerciseReference(
            id: "kettlebell-swing",
            name: "Kettlebell Swing",
            muscleGroup: .conditioning,
            movementPattern: "Hinge",
            musclesWorked: "Glutes, hamstrings, and core",
            equipment: "Kettlebell",
            difficulty: .moderate,
            videoPlaceholder: "Kettlebell swing demo placeholder",
            instructions: [
                "Hinge at the hips and hike the bell back.",
                "Snap your hips forward to float the bell up.",
                "Let it fall and load the next hinge."
            ],
            formCue: "Power comes from the hips, not the arms.",
            commonMistakes: "Squatting instead of hinging.",
            beginnerModification: "Practice the hip hinge with no weight first.",
            alternatives: ["Romanian Deadlift", "Glute Bridge"],
            whyThisMatters: "Swings build explosive hips and conditioning at the same time."
        ),
        ExerciseReference(
            id: "rowing-machine",
            name: "Rowing Machine",
            muscleGroup: .conditioning,
            movementPattern: "Conditioning",
            musclesWorked: "Legs, back, and heart",
            equipment: "Rowing erg",
            difficulty: .beginner,
            videoPlaceholder: "Rowing machine demo placeholder",
            instructions: [
                "Drive with the legs first.",
                "Then lean back slightly and pull the handle to your ribs.",
                "Return arms, body, then legs in order."
            ],
            formCue: "Legs, body, arms — then reverse it.",
            commonMistakes: "Yanking with the arms before the legs drive.",
            beginnerModification: "Row at an easy pace and focus on order.",
            alternatives: ["Stationary Bike", "Treadmill Walk"],
            whyThisMatters: "Rowing is full-body cardio that is easy on the joints."
        ),
        ExerciseReference(
            id: "stationary-bike",
            name: "Stationary Bike",
            muscleGroup: .conditioning,
            movementPattern: "Conditioning",
            musclesWorked: "Legs and heart",
            equipment: "Stationary bike",
            difficulty: .recovery,
            videoPlaceholder: "Stationary bike demo placeholder",
            instructions: [
                "Set the seat so your knee has a slight bend at the bottom.",
                "Pedal at a smooth, steady cadence.",
                "Adjust resistance to keep effort easy."
            ],
            formCue: "Smooth circles, relaxed upper body.",
            commonMistakes: "Seat too low, knees aching.",
            beginnerModification: "Keep resistance light and time short.",
            alternatives: ["Treadmill Walk", "Rowing Machine"],
            whyThisMatters: "The bike is low-impact cardio that's great for recovery days."
        ),
        ExerciseReference(
            id: "burpee",
            name: "Burpee",
            muscleGroup: .conditioning,
            movementPattern: "Conditioning",
            musclesWorked: "Full body and heart",
            equipment: "None",
            difficulty: .advanced,
            videoPlaceholder: "Burpee demo placeholder",
            instructions: [
                "Drop your hands down and kick your feet back.",
                "Do a push-up or lower your chest.",
                "Jump your feet in and stand or hop up."
            ],
            formCue: "Move smoothly; sloppy reps cause aches.",
            commonMistakes: "Letting the hips sag in the plank.",
            beginnerModification: "Step back instead of jumping and skip the hop.",
            alternatives: ["Mountain Climber", "Jump Rope"],
            whyThisMatters: "Burpees deliver strength and cardio in one demanding move."
        )
    ]

    static let drillLibrary: [DrillReference] = [
        DrillReference(
            name: "Slip Rope Drill",
            sport: .boxing,
            skillCategory: "Defense",
            equipment: "Rope",
            difficulty: .moderate,
            instructions: ["Set a rope at shoulder height.", "Move under the rope after each punch.", "Keep the eyes level."],
            cues: "Bend at the knees, not the waist.",
            commonMistakes: "Dropping hands while slipping.",
            progression: "Add jab-cross after each slip.",
            regression: "Shadow the pattern without punches.",
            scoreMetric: "Rounds completed clean",
            whyThisMatters: "Head movement helps boxing defense without wasting energy."
        ),
        DrillReference(
            name: "Shadowboxing Rounds",
            sport: .boxing,
            skillCategory: "Skill work",
            equipment: "Timer",
            difficulty: .beginner,
            instructions: ["Set a round timer.", "Work on clean combinations and exits.", "Move with intent between exchanges."],
            cues: "Stay relaxed enough to think.",
            commonMistakes: "Throwing hard with no rhythm.",
            progression: "Add reactive defense calls.",
            regression: "Shorten the rounds.",
            scoreMetric: "Clean rounds completed",
            whyThisMatters: "Shadowboxing builds rhythm, technique, and fight conditioning."
        ),
        DrillReference(
            name: "Heavy Bag Intervals",
            sport: .boxing,
            skillCategory: "Conditioning",
            equipment: "Heavy bag",
            difficulty: .moderate,
            instructions: ["Work in rounds.", "Keep combinations short and sharp.", "Recover with breathing control between rounds."],
            cues: "Hit with intent, not panic.",
            commonMistakes: "Starting too hard and fading fast.",
            progression: "Add power finishers in the last 20 seconds.",
            regression: "Cut rounds to 60 seconds.",
            scoreMetric: "Rounds completed",
            whyThisMatters: "Bag intervals build boxing-specific conditioning."
        ),
        DrillReference(
            name: "Cone Dribble Weave",
            sport: .soccer,
            skillCategory: "Ball control",
            equipment: "Ball + cones",
            difficulty: .beginner,
            instructions: ["Set 5 cones in a line.", "Use small touches through the cones.", "Finish with a short acceleration."],
            cues: "Use small touches and keep your eyes up.",
            commonMistakes: "Pushing the ball too far ahead.",
            progression: "Use weaker foot only.",
            regression: "Walk the pattern first.",
            scoreMetric: "Time through cones",
            whyThisMatters: "Ball control quality helps match composure."
        ),
        DrillReference(
            name: "5-10-5 Agility Drill",
            sport: .soccer,
            skillCategory: "Agility",
            equipment: "Cones",
            difficulty: .moderate,
            instructions: ["Set three cones.", "Sprint 5 yards, turn, sprint 10, then finish 5."],
            cues: "Drop your hips before you cut.",
            commonMistakes: "Standing tall into the turn.",
            progression: "Add reactive direction starts.",
            regression: "Reduce total distance.",
            scoreMetric: "Best time",
            whyThisMatters: "Change-of-direction speed matters across field sports."
        ),
        DrillReference(
            name: "Defensive Slides",
            sport: .basketball,
            skillCategory: "Defense",
            equipment: "Court line",
            difficulty: .moderate,
            instructions: ["Start low.", "Slide cleanly without crossing your feet.", "Recover fast after the change of direction."],
            cues: "Stay low and keep your chest proud.",
            commonMistakes: "Standing up during the slide.",
            progression: "Add a reactive closeout.",
            regression: "Use shorter distances.",
            scoreMetric: "Reps in 30 seconds",
            whyThisMatters: "Lateral movement supports defense and change of pace."
        ),
        DrillReference(
            name: "Form Shooting",
            sport: .basketball,
            skillCategory: "Shooting",
            equipment: "Basketball",
            difficulty: .beginner,
            instructions: ["Start close to the rim.", "Use one-hand release focus.", "Hold the follow-through."],
            cues: "Own the finish of the shot.",
            commonMistakes: "Rushing the release.",
            progression: "Step back only when the form stays clean.",
            regression: "Use a wall or no-jump version.",
            scoreMetric: "Makes in a row",
            whyThisMatters: "Repetition with good mechanics builds game confidence."
        ),
        DrillReference(
            name: "Sprint Mechanics A-Skips",
            sport: .track,
            skillCategory: "Mechanics",
            equipment: "Track lane",
            difficulty: .beginner,
            instructions: ["Drive one knee up.", "Strike under the hips.", "Keep posture tall."],
            cues: "Push the ground away under you.",
            commonMistakes: "Reaching forward with the foot.",
            progression: "Blend into accelerations.",
            regression: "March first, then skip.",
            scoreMetric: "Quality score",
            whyThisMatters: "Better mechanics improve speed and reduce wasted motion."
        ),
        DrillReference(
            name: "Tempo Run",
            sport: .running,
            skillCategory: "Conditioning",
            equipment: "Track or road",
            difficulty: .moderate,
            instructions: ["Set a pace you can sustain.", "Breathe under control.", "Keep effort steady from start to finish."],
            cues: "Smooth is fast enough.",
            commonMistakes: "Starting too fast.",
            progression: "Extend the steady section.",
            regression: "Use run-walk intervals.",
            scoreMetric: "Time at tempo pace",
            whyThisMatters: "Tempo work raises work capacity for races and conditioning."
        ),
        DrillReference(
            name: "Mobility Flow",
            sport: .generalFitness,
            skillCategory: "Recovery",
            equipment: "Mat",
            difficulty: .recovery,
            instructions: ["Move through hips, thoracic spine, and ankles.", "Breathe slowly between positions."],
            cues: "Own the range you actually have today.",
            commonMistakes: "Rushing without breathing.",
            progression: "Add longer holds or deeper positions.",
            regression: "Shorten the flow to 5 minutes.",
            scoreMetric: "Minutes completed",
            whyThisMatters: "Mobility supports recovery and smoother movement."
        )
    ]

    static let dailyTasks: [TaskItem] = [
        TaskItem(title: "Drink 2 cups of water", difficulty: .easy, isCompleted: true, xp: 10),
        TaskItem(title: "Walk 10 minutes", difficulty: .easy, isCompleted: false, xp: 10),
        TaskItem(title: "Complete today's workout", difficulty: .steady, isCompleted: false, xp: 25),
        TaskItem(title: "Log your workout within 24 hours", difficulty: .steady, isCompleted: false, xp: 15),
        TaskItem(title: "Hit protein goal", difficulty: .stretch, isCompleted: false, xp: 20),
        TaskItem(title: "Write a short reflection", difficulty: .stretch, isCompleted: false, xp: 12)
    ]

    static let minimumWinTasks: [TaskItem] = [
        TaskItem(title: "Walk 5 minutes", difficulty: .easy, isCompleted: false, xp: 8),
        TaskItem(title: "Stretch hips and back", difficulty: .easy, isCompleted: false, xp: 8),
        TaskItem(title: "Drink water", difficulty: .easy, isCompleted: false, xp: 6),
        TaskItem(title: "Log mood", difficulty: .easy, isCompleted: false, xp: 6),
        TaskItem(title: "Watch one form tip", difficulty: .easy, isCompleted: false, xp: 6),
        TaskItem(title: "Do 10 bodyweight squats", difficulty: .steady, isCompleted: false, xp: 10)
    ]

    static let streakProtectionOptions = [
        "10-minute walk",
        "5-minute mobility",
        "Log reflection",
        "Recovery breathing"
    ]

    static let whyThisMatters: [WhyThisMatters] = [
        WhyThisMatters(title: "Protein", detail: "Protein helps your body recover and keeps you full."),
        WhyThisMatters(title: "Recovery", detail: "Recovery days help you train consistently without burning out."),
        WhyThisMatters(title: "Logging workouts", detail: "Logging helps Morphe adjust your next plan accurately."),
        WhyThisMatters(title: "Mobility", detail: "Mobility helps your body move better and reduces unnecessary strain.")
    ]

    static let lessons: [LessonCard] = [
        LessonCard(title: "Recovery Basics", subtitle: "Why your plan changes", detail: "Sleep, soreness, mood, pain, and previous session difficulty all help Morphe decide whether to push or protect the day."),
        LessonCard(title: "Protein First", subtitle: "Simple nutrition win", detail: "Start with protein, calories, water, and one or two repeatable meals instead of perfect macro tracking."),
        LessonCard(title: "Match Readiness", subtitle: "Sport-specific focus", detail: "Skill, freshness, and recovery matter more than random extra fatigue close to game day."),
        LessonCard(title: "The RPE Scale", subtitle: "Rate your effort 1–10", detail: "RPE means Rate of Perceived Exertion. A 6 feels easy with several reps left in the tank; a 9 means only one hard rep remained; a 10 is all-out. Most working sets should sit around RPE 7–8 — hard but clean."),
        LessonCard(title: "Reps In Reserve", subtitle: "Leave a little in the tank", detail: "RIR is how many more reps you could have done. Stopping with 1–3 reps in reserve builds strength while keeping your form sharp and your joints happy. Going to failure every set just slows recovery."),
        LessonCard(title: "Progressive Overload", subtitle: "How you actually grow", detail: "Muscles adapt when you ask a little more over time — slightly more weight, one more rep, or one more set. Small, steady increases beat random hard days. Track your sets so you know what 'a little more' looks like."),
        LessonCard(title: "Light, Moderate, Hard", subtitle: "Reading intensity", detail: "Light days (RPE 4–6) build skill and aid recovery. Moderate days (RPE 6–7) are your bread and butter. Hard days (RPE 8–9) push adaptation but cost more recovery, so you only earn a few each week."),
        LessonCard(title: "Push, Pull, Legs", subtitle: "Anatomy made simple", detail: "Most training splits into pushing muscles (chest, shoulders, triceps), pulling muscles (back and biceps), and legs (quads, hamstrings, glutes, calves). Balancing all three keeps your body strong and even."),
        LessonCard(title: "Your Core Is Deeper Than Abs", subtitle: "Anatomy made simple", detail: "Your core wraps all the way around — the front abs, the side obliques, and the deep muscles that brace your spine. Planks and anti-rotation work train the bracing job your core actually does in real life."),
        LessonCard(title: "Warm-Ups That Work", subtitle: "Move better, safer", detail: "A good warm-up raises your heart rate, then rehearses the day's movement with lighter sets. Five focused minutes beats a long stretch routine for getting ready to train safely."),
        LessonCard(title: "Soreness Is Not A Score", subtitle: "Recovery truth", detail: "Being sore doesn't mean a workout 'worked,' and not being sore doesn't mean it failed. Progress on your logged sets is the real signal. Sharp or joint pain is different — that's a stop sign, not soreness."),
        LessonCard(title: "Sleep Is Training", subtitle: "Recovery truth", detail: "Most of your adaptation happens during sleep. Seven to nine hours does more for strength and mood than any supplement. When sleep is short, Morphe will often dial the intensity back for you."),
        LessonCard(title: "Tempo And Time Under Tension", subtitle: "Control the rep", detail: "Lowering the weight for two to three seconds keeps tension on the muscle and protects your joints. Slower, controlled reps often beat heavier, sloppy ones for building muscle."),
        LessonCard(title: "Rest Periods Matter", subtitle: "How long to wait", detail: "For heavy strength work, rest two to three minutes so you can hit your reps. For lighter accessory work, one minute is plenty. Resting too little quietly turns a strength set into a cardio set."),
        LessonCard(title: "Deload When You Need It", subtitle: "Plan the easy week", detail: "Every few weeks, taking an easier week — less weight or fewer sets — lets your body catch up and come back stronger. Backing off on purpose is part of the plan, not a setback.")
    ]

    static let quizzes: [MiniQuiz] = [
        MiniQuiz(
            question: "What muscle group does a goblet squat mainly train?",
            options: ["Legs and glutes", "Chest", "Biceps", "Neck"],
            correctIndex: 0,
            explanation: "Goblet squats mainly train the legs and glutes while also teaching trunk control.",
            rewardXP: 12
        ),
        MiniQuiz(
            question: "What should you do if an exercise causes sharp pain?",
            options: ["Push harder", "Ignore it", "Stop and report it", "Add more weight"],
            correctIndex: 2,
            explanation: "Sharp pain is a signal to stop, report it, and pivot to a safer option.",
            rewardXP: 12
        ),
        MiniQuiz(
            question: "What helps most when recovery is low?",
            options: ["More random intensity", "A lighter session and extra sleep", "Skipping all food", "Longer rest between social media posts"],
            correctIndex: 1,
            explanation: "Low recovery usually responds best to a lighter session, better sleep, and simple consistency.",
            rewardXP: 10
        ),
        MiniQuiz(
            question: "What is the main point of a Plan B day?",
            options: ["Punish missed workouts", "Protect momentum with a smaller win", "Add extra cardio", "Test your willpower"],
            correctIndex: 1,
            explanation: "Plan B keeps the habit alive when energy, time, or motivation is low.",
            rewardXP: 10
        ),
        MiniQuiz(
            question: "Which choice best supports a strength session later today?",
            options: ["No water all day", "A protein-focused meal and hydration", "Skipping your warm-up", "Adding random sprints"],
            correctIndex: 1,
            explanation: "Protein and hydration support performance and recovery much better than trying to wing it.",
            rewardXP: 10
        ),
        MiniQuiz(
            question: "What does a recovery score help Morphe do?",
            options: ["Judge your effort", "Adjust the day's training load", "Replace your coach", "Count your social posts"],
            correctIndex: 1,
            explanation: "Recovery data is there to help Morphe protect the day, not shame the user.",
            rewardXP: 10
        ),
        MiniQuiz(
            question: "If a gym is crowded and your station is taken, what is the smartest move?",
            options: ["Wait angrily for 20 minutes", "Skip the workout", "Swap to an equivalent movement and keep going", "Double the weight"],
            correctIndex: 2,
            explanation: "A smooth swap keeps the session moving and protects momentum.",
            rewardXP: 10
        ),
        MiniQuiz(
            question: "Why do warm-ups matter before a workout?",
            options: ["They make the session longer", "They help you move better and ramp effort safely", "They replace strength work", "They are only for athletes"],
            correctIndex: 1,
            explanation: "Warm-ups prepare the joints, breathing, and nervous system so the session starts cleaner.",
            rewardXP: 10
        ),
        MiniQuiz(
            question: "On the RPE scale, what does an RPE of 8 mean?",
            options: ["You could do many more reps", "You had about 2 hard reps left", "You failed the rep", "You were resting"],
            correctIndex: 1,
            explanation: "RPE 8 means roughly 2 reps in reserve — hard but still clean. Most working sets live around RPE 7–8.",
            rewardXP: 12
        ),
        MiniQuiz(
            question: "What does 'Reps In Reserve' (RIR) describe?",
            options: ["How long you rest", "How many more reps you could have done", "How much you sweat", "Your heart rate"],
            correctIndex: 1,
            explanation: "RIR is how many reps you left in the tank. Stopping with 1–3 RIR builds strength while keeping form sharp.",
            rewardXP: 12
        ),
        MiniQuiz(
            question: "What is progressive overload?",
            options: ["Training to failure daily", "Gradually asking a little more over time", "Only lifting heavy", "Skipping rest days"],
            correctIndex: 1,
            explanation: "Muscles grow when you add a little — more weight, a rep, or a set — over time. Small, steady increases win.",
            rewardXP: 12
        ),
        MiniQuiz(
            question: "Which muscles are the main 'pulling' muscles?",
            options: ["Chest and triceps", "Back and biceps", "Quads and calves", "Abs and obliques"],
            correctIndex: 1,
            explanation: "Pulling movements like rows and pull-ups are driven by the back and biceps.",
            rewardXP: 10
        ),
        MiniQuiz(
            question: "You only slept five hours and feel drained. What's the smart call?",
            options: ["Push a hard max-effort day", "Train at a lighter intensity", "Skip warming up", "Double the workout"],
            correctIndex: 1,
            explanation: "Short sleep blunts recovery. Dialing the intensity back keeps momentum without digging a hole.",
            rewardXP: 12
        ),
        MiniQuiz(
            question: "How long should you rest between heavy strength sets?",
            options: ["No rest", "10–20 seconds", "About 2–3 minutes", "15 minutes"],
            correctIndex: 2,
            explanation: "Heavy sets need 2–3 minutes so you can actually hit your target reps with good form.",
            rewardXP: 10
        ),
        MiniQuiz(
            question: "Why slow down the lowering (eccentric) part of a rep?",
            options: ["To finish faster", "To keep tension on the muscle and protect joints", "To lift more weight", "It doesn't matter"],
            correctIndex: 1,
            explanation: "A controlled 2–3 second lower keeps tension on the muscle and is easier on your joints.",
            rewardXP: 10
        ),
        MiniQuiz(
            question: "What is the purpose of a deload week?",
            options: ["Quit training", "Let the body recover so it comes back stronger", "Max out every day", "Only do cardio"],
            correctIndex: 1,
            explanation: "An easier week every few weeks lets fatigue clear so you rebound stronger. It's planned, not a setback.",
            rewardXP: 12
        )
    ]

    static let goalTranslations: [GoalTranslation] = [
        GoalTranslation(goal: "Lose weight", weeklyActions: ["3 workouts per week", "7,000 steps per day", "Protein goal", "2 nutrition logs per day", "Weekly weigh-in", "1 recovery day"]),
        GoalTranslation(goal: "Gain muscle", weeklyActions: ["4 strength sessions", "Progressive overload on main lifts", "Daily protein goal", "2 mobility blocks", "Weekly progress check-in"]),
        GoalTranslation(goal: "Improve sport performance", weeklyActions: ["2 sport-specific sessions", "1 strength session", "1 mobility session", "Readiness check-ins"]),
        GoalTranslation(goal: "Build consistency", weeklyActions: ["3 short training sessions", "2 recovery check-ins", "1 simple nutrition habit", "Minimum Win backup plan"]),
        GoalTranslation(goal: "Improve conditioning", weeklyActions: ["2 conditioning sessions", "1 strength session", "1 recovery block", "Weekly effort review"]),
        GoalTranslation(goal: "Get stronger", weeklyActions: ["3 strength sessions", "Track one main lift", "Protein goal", "1 recovery day"]),
        GoalTranslation(goal: "Return after injury", weeklyActions: ["Pain-free movement check-in", "2 coached sessions", "Mobility every training day", "Coach review before big intensity jumps"]),
        GoalTranslation(goal: "Prepare for event/competition", weeklyActions: ["Event-specific training", "Readiness check-ins", "Taper planning", "Recovery priority"])
    ]

    static let roadmap: [RoadmapPhase] = [
        RoadmapPhase(title: "Assessment", focus: "Baseline movement, schedule, and confidence.", weeklyActions: ["Complete check-ins", "Try 2 simple sessions"], milestone: "Baseline captured", status: "Done"),
        RoadmapPhase(title: "Build Consistency", focus: "Repeat small wins until training feels normal.", weeklyActions: ["3 workouts", "7,000 steps", "2 nutrition logs"], milestone: "5-day streak", status: "Current"),
        RoadmapPhase(title: "Build Strength / Skill", focus: "Add stable progress to strength or sport work.", weeklyActions: ["1 progression each week", "1 form review"], milestone: "Repeatable form under fatigue", status: "Up Next"),
        RoadmapPhase(title: "Improve Conditioning", focus: "Raise work capacity without losing recovery.", weeklyActions: ["2 conditioning blocks", "1 recovery session"], milestone: "Higher work output", status: "Locked"),
        RoadmapPhase(title: "Performance / Transformation", focus: "Push targeted outcomes with cleaner planning.", weeklyActions: ["Sport metrics review", "Weekly coach feedback"], milestone: "Performance phase", status: "Locked"),
        RoadmapPhase(title: "Maintenance", focus: "Keep momentum while life gets busy.", weeklyActions: ["2 anchor sessions", "Minimum Win fallback"], milestone: "Lifestyle lock-in", status: "Locked")
    ]

    static let notifications: [SmartNotificationItem] = [
        SmartNotificationItem(type: "Workout reminder", title: "Workout log reminder", message: "You have 3 hours left to log yesterday's workout.", priority: .medium, action: "Open workout history"),
        SmartNotificationItem(type: "Streak protection", title: "Protect your streak", message: "You're one task away from protecting your streak.", priority: .high, action: "Open Minimum Win"),
        SmartNotificationItem(type: "Recovery suggestion", title: "Recovery adjusted your plan", message: "Your recovery is low. Morphe adjusted today's plan.", priority: .medium, action: "View adjusted session"),
        SmartNotificationItem(type: "Coach message", title: "Coach feedback is ready", message: "Your coach left feedback on your session.", priority: .low, action: "Open coach chat"),
        SmartNotificationItem(type: "Level motivation", title: "Small win counts", message: "Try your Minimum Win if today feels too busy.", priority: .low, action: "Open Plan B"),
        SmartNotificationItem(type: "Competition reminder", title: "Game day prep", message: "Game day is in 3 days. Recovery matters today.", priority: .medium, action: "Open event prep")
    ]

    static let patternInsights: [FrictionInsight] = [
        FrictionInsight(title: "Shorter sessions fit better", summary: "You complete 30-minute workouts more often than 45-minute workouts.", recommendation: "Morphe recommends shorter sessions this week."),
        FrictionInsight(title: "Core work keeps slipping", summary: "You often skip core work. Want to move core to the beginning of your workout?", recommendation: "Front-load one core block to improve follow-through."),
        FrictionInsight(title: "Evening sessions get skipped", summary: "You miss more workouts after 6 PM.", recommendation: "Try morning sessions or lunch walks on busy days.")
    ]

    static let personalRules: [PersonalRule] = [
        PersonalRule(title: "Prefers workouts under 45 minutes", detail: "Keep weekday sessions tight."),
        PersonalRule(title: "Avoids burpees", detail: "Use conditioning alternatives without unnecessary dread."),
        PersonalRule(title: "Trains at home on weekdays", detail: "Default to dumbbells and bodyweight Monday through Friday."),
        PersonalRule(title: "Knee pain history", detail: "Watch lunge depth and swap if needed."),
        PersonalRule(title: "Better consistency in the morning", detail: "Schedule effort work before 10 AM when possible."),
        PersonalRule(title: "Prefers dumbbells", detail: "Keep setup simple whenever possible."),
        PersonalRule(title: "Needs beginner-friendly explanations", detail: "Keep cues short, supportive, and clear."),
        PersonalRule(title: "Plays soccer on weekends", detail: "Lower Friday leg fatigue when soccer mode is active.")
    ]

    static let photoProgress = PhotoProgressSnapshot(
        frontLabel: "Front photo slot",
        sideLabel: "Side photo slot",
        backLabel: "Back photo slot",
        reminder: "Weekly reminder every Sunday evening",
        aiPreview: "AI scan preview placeholder: posture looks steadier and movement confidence is improving.",
        postureNote: "Posture notes placeholder: slight forward shoulder posture after long desk days.",
        compositionTrend: "Body composition trend placeholder: gradual consistency beat dramatic swings this month.",
        privacyNote: "Photos are private by default. AI scan is a demo preview and should not replace professional health advice."
    )

    static let nutrition = NutritionSnapshot(
        calorieGoal: 2200,
        caloriesConsumed: 1650,
        proteinGoal: 160,
        proteinConsumed: 105,
        waterGoal: 8,
        waterConsumed: 5,
        nutritionScore: 74,
        mode: .guided,
        meals: [
            MealLogEntry(mealType: "Breakfast", name: "Eggs + toast", calories: 420, protein: 28, logged: true),
            MealLogEntry(mealType: "Lunch", name: "Chicken bowl", calories: 650, protein: 48, logged: true),
            MealLogEntry(mealType: "Snack", name: "Greek yogurt", calories: 180, protein: 17, logged: true),
            MealLogEntry(mealType: "Dinner", name: "Not logged yet", calories: 0, protein: 0, logged: false)
        ],
        quickMeals: [
            QuickMeal(title: "Protein shake", calories: 240, protein: 30),
            QuickMeal(title: "Chicken wrap", calories: 390, protein: 32),
            QuickMeal(title: "Cottage cheese bowl", calories: 210, protein: 24)
        ],
        weeklyProteinTrend: [
            DayScore(day: "Mon", value: 122),
            DayScore(day: "Tue", value: 140),
            DayScore(day: "Wed", value: 118),
            DayScore(day: "Thu", value: 105),
            DayScore(day: "Fri", value: 132)
        ]
    )

    static let workoutTemplates: [WorkoutTemplate] = [
        WorkoutTemplate(
            name: "Beginner Full Body Strength",
            type: "Gym workout",
            sport: .strength,
            goal: "Build full-body strength with calm, repeatable reps.",
            difficulty: .beginner,
            durationMinutes: 38,
            equipment: "Dumbbells + bodyweight",
            exercises: [
                makeWorkoutExercise("goblet-squat", sets: "3 sets", reps: "10 reps"),
                makeWorkoutExercise("incline-push-up", sets: "3 sets", reps: "8 reps"),
                makeWorkoutExercise("dumbbell-row", sets: "3 sets", reps: "10 reps"),
                makeWorkoutExercise("glute-bridge", sets: "3 sets", reps: "12 reps"),
                makeWorkoutExercise("plank", sets: "3 sets", reps: "30 sec")
            ],
            notes: "Progressive overload starts with consistency. Show up, track it, improve next time.",
            coachNote: "Keep the pace steady and leave 2 reps in reserve."
        ),
        WorkoutTemplate(
            name: "Boxing Conditioning Builder",
            type: "Boxing session",
            sport: .boxing,
            goal: "Improve work capacity, footwork rhythm, and body composition.",
            difficulty: .moderate,
            durationMinutes: 42,
            equipment: "Jump rope, heavy bag, timer",
            exercises: [
                makeWorkoutExercise("jump-rope", sets: "1 round", reps: "5 min"),
                makeWorkoutExercise("plank", sets: "3 rounds", reps: "30 sec"),
                makeWorkoutExercise("dead-bug", sets: "2 rounds", reps: "8 / side")
            ],
            notes: "You do not need to train like a champion today. You just need to build the habits that create one.",
            coachNote: "Sharp rounds beat messy hard rounds."
        ),
        WorkoutTemplate(
            name: "Soccer Match Fitness",
            type: "Field session",
            sport: .soccer,
            goal: "Build match readiness one small win at a time.",
            difficulty: .moderate,
            durationMinutes: 40,
            equipment: "Ball + cones",
            exercises: [
                makeWorkoutExercise("bodyweight-squat", sets: "2 sets", reps: "10 reps"),
                makeWorkoutExercise("glute-bridge", sets: "2 sets", reps: "12 reps"),
                makeWorkoutExercise("treadmill-walk", sets: "1 block", reps: "10 min")
            ],
            notes: "Today's session builds match fitness one small win at a time.",
            coachNote: "Keep the freshness for the final third of the session."
        ),
        WorkoutTemplate(
            name: "15-Minute Quick Workout",
            type: "Quick session",
            sport: .generalFitness,
            goal: "Keep the habit alive when time is tight.",
            difficulty: .beginner,
            durationMinutes: 15,
            equipment: "Bodyweight + one dumbbell",
            exercises: [
                makeWorkoutExercise("bodyweight-squat", sets: "2 rounds", reps: "10 reps"),
                makeWorkoutExercise("incline-push-up", sets: "2 rounds", reps: "8 reps"),
                makeWorkoutExercise("plank", sets: "2 rounds", reps: "20 sec")
            ],
            notes: "Short still counts. Finish first, optimize later.",
            coachNote: "Great fallback on school, work, or travel days."
        ),
        WorkoutTemplate(
            name: "Low Energy Recovery Day",
            type: "Recovery session",
            sport: .generalFitness,
            goal: "Protect momentum without digging a deeper fatigue hole.",
            difficulty: .recovery,
            durationMinutes: 20,
            equipment: "Mat + easy walk",
            exercises: [
                makeWorkoutExercise("treadmill-walk", sets: "1 block", reps: "12 min"),
                makeWorkoutExercise("glute-bridge", sets: "2 sets", reps: "10 reps"),
                makeWorkoutExercise("dead-bug", sets: "2 sets", reps: "8 reps")
            ],
            notes: "Today does not need to be perfect. One lighter win still counts.",
            coachNote: "This is a recovery pivot, not a punishment."
        )
    ]

    static let savedWorkouts: [SavedWorkoutLibraryItem] = [
        SavedWorkoutLibraryItem(
            workoutTemplateID: workoutTemplates[1].id,
            workoutName: workoutTemplates[1].name,
            sport: .boxing,
            sourceName: "Coach Marcus",
            sourceRole: .coach,
            sourceContext: "Saved from coach plan",
            bestFor: .buddy,
            note: "Sharp rounds, clean pacing, and a repeatable conditioning anchor."
        ),
        SavedWorkoutLibraryItem(
            workoutTemplateID: workoutTemplates[3].id,
            workoutName: workoutTemplates[3].name,
            sport: .generalFitness,
            sourceName: "Lucas",
            sourceRole: .client,
            sourceContext: "Saved from athlete profile",
            bestFor: .fallback,
            note: "Best fallback when the day gets noisy but momentum still matters."
        )
    ]

    static let sportSessions: [SportSession] = [
        SportSession(
            name: "Boxing Session - Skill + Engine",
            sport: .boxing,
            type: .boxingSession,
            sections: [
                SessionSection(title: "Warm-up", detail: "Jump rope", duration: "5 min"),
                SessionSection(title: "Activation", detail: "Dynamic warm-up", duration: "5 min"),
                SessionSection(title: "Skill work", detail: "Shadowboxing", duration: "3 rounds"),
                SessionSection(title: "Main training", detail: "Heavy bag", duration: "4 rounds"),
                SessionSection(title: "Conditioning", detail: "Mitt work", duration: "4 rounds"),
                SessionSection(title: "Cooldown", detail: "Breathing + mobility", duration: "3 min")
            ],
            duration: 47,
            intensity: "Moderate-high",
            assignedTo: ["Lucas"]
        ),
        SportSession(
            name: "Soccer Session - Match Readiness",
            sport: .soccer,
            type: .fieldSession,
            sections: [
                SessionSection(title: "Warm-up", detail: "Dynamic warm-up", duration: "10 min"),
                SessionSection(title: "Skill work", detail: "Ball control", duration: "15 min"),
                SessionSection(title: "Main training", detail: "Sprint mechanics", duration: "10 min"),
                SessionSection(title: "Conditioning", detail: "Agility drills", duration: "15 min"),
                SessionSection(title: "Cooldown", detail: "Mobility", duration: "8 min")
            ],
            duration: 58,
            intensity: "Moderate",
            assignedTo: ["Maya"]
        ),
        SportSession(
            name: "Basketball Session - Jump + Engine",
            sport: .basketball,
            type: .courtSession,
            sections: [
                SessionSection(title: "Warm-up", detail: "Dynamic prep", duration: "8 min"),
                SessionSection(title: "Activation", detail: "Landing mechanics", duration: "6 min"),
                SessionSection(title: "Skill work", detail: "Form shooting", duration: "10 min"),
                SessionSection(title: "Main training", detail: "Jump series", duration: "18 min"),
                SessionSection(title: "Conditioning", detail: "Shuttle runs", duration: "10 min"),
                SessionSection(title: "Cooldown", detail: "Ankle + calf mobility", duration: "6 min")
            ],
            duration: 58,
            intensity: "High",
            assignedTo: ["Chris"]
        )
    ]

    static let healthTrend: [DayScore] = [
        DayScore(day: "Mon", value: 68),
        DayScore(day: "Tue", value: 70),
        DayScore(day: "Wed", value: 72),
        DayScore(day: "Thu", value: 76),
        DayScore(day: "Fri", value: 78),
        DayScore(day: "Sat", value: 76),
        DayScore(day: "Sun", value: 80)
    ]

    static let workoutConsistency: [WeeklyWorkoutCount] = [
        WeeklyWorkoutCount(week: "Week 1", workouts: 2),
        WeeklyWorkoutCount(week: "Week 2", workouts: 3),
        WeeklyWorkoutCount(week: "Week 3", workouts: 3),
        WeeklyWorkoutCount(week: "Week 4", workouts: 4)
    ]

    static let strengthTrend: [StrengthPoint] = [
        StrengthPoint(week: "Week 1", weight: 25),
        StrengthPoint(week: "Week 2", weight: 30),
        StrengthPoint(week: "Week 3", weight: 35),
        StrengthPoint(week: "Week 4", weight: 40)
    ]

    static let weightTrend: [WeightPoint] = [
        WeightPoint(label: "Start", value: 220),
        WeightPoint(label: "Wk 2", value: 219),
        WeightPoint(label: "Wk 3", value: 217),
        WeightPoint(label: "Current", value: 216)
    ]

    static let recentWins: [String] = [
        "You trained 4/5 days this week.",
        "Your consistency improved 18% this month.",
        "Your squat increased by 10 lbs.",
        "You protected your streak twice this month."
    ]

    static let recovery = RecoverySnapshot(
        score: 68,
        status: .takeItEasy,
        reason: "Low sleep and high soreness.",
        sleepHours: 6.1,
        energy: 6,
        soreness: 7,
        mood: 7,
        pain: false,
        previousSessionFeedback: .tooHard
    )

    static let defaultPlanAdjustment = PlanAdjustment(
        title: "Today's plan has been adjusted to protect momentum",
        body: "Today's session was adjusted because your recovery score is low and you reported soreness yesterday.",
        reasons: [.lowRecovery, .workoutTooHard],
        recommendation: "Keep the workload moderate, finish the basics, and let recovery catch up."
    )

    static let friendActivity: [FriendActivity] = [
        FriendActivity(title: "Jay completed a workout"),
        FriendActivity(title: "Maya hit a 7-day streak"),
        FriendActivity(title: "Chris completed a recovery walk")
    ]

    static let challenges: [Challenge] = [
        Challenge(title: "5-Day Consistency Challenge", detail: "Finish one training task for five straight days."),
        Challenge(title: "10K Steps Weekend Challenge", detail: "Use walks to keep recovery and momentum high."),
        Challenge(title: "Protein Goal Challenge", detail: "Hit your protein target three days in a row.")
    ]

    static let communityPosts: [ProgressPost] = [
        ProgressPost(
            author: "Coach Marcus",
            avatar: "🧠",
            role: .coach,
            headline: "Boxing and strength coach for beginners and athletes",
            rank: "Coach Leader",
            timeAgo: "45m",
            title: "How I keep athletes consistent on busy weeks",
            detail: "When confidence drops, I cut the plan in half before I cut the habit. Minimum Win beats guilt every time.",
            tags: ["Coaching", "Consistency", "Minimum Win"],
            reactions: 48,
            comments: 7,
            commentHighlights: [
                NetworkComment(author: "Lucas", avatar: "🥊", role: .client, headline: "Boxing athlete building consistency", rank: "Level 3 Builder", text: "This is exactly why I stayed on track this week.", likes: 6),
                NetworkComment(author: "Maya", avatar: "⚽", role: .client, headline: "Soccer athlete focused on match fitness", rank: "Strong Momentum", text: "Shorter sessions helped me stop skipping agility work.", likes: 4)
            ]
        ),
        ProgressPost(
            author: "Lucas",
            avatar: "🥊",
            role: .client,
            headline: "Boxing athlete improving conditioning and body composition",
            rank: "Level 3 Builder",
            timeAgo: "2h",
            title: "Protected the streak",
            detail: "Used Minimum Win Mode after work, finished the walk, and still logged the day. Small wins really do stack.",
            tags: ["Boxing", "Comeback", "Momentum"],
            reactions: 24,
            comments: 6,
            commentHighlights: [
                NetworkComment(author: "Coach Marcus", avatar: "🧠", role: .coach, headline: "Boxing and strength coach", rank: "Coach Leader", text: "This is the kind of discipline that changes the month, not just the day.", likes: 9)
            ]
        ),
        ProgressPost(
            author: "Maya",
            avatar: "⚽",
            role: .client,
            headline: "Soccer athlete chasing speed and match readiness",
            rank: "Strong",
            timeAgo: "5h",
            title: "Sprint PR",
            detail: "Best 10-yard split of the month today. The short acceleration work is finally clicking.",
            tags: ["Soccer", "Speed", "PR"],
            reactions: 31,
            comments: 9,
            commentHighlights: [
                NetworkComment(author: "Chris", avatar: "🏀", role: .client, headline: "Basketball athlete building bounce and conditioning", rank: "Building", text: "Love seeing the field athletes cook. Nice work.", likes: 3)
            ]
        ),
        ProgressPost(
            author: "Chris",
            avatar: "🏀",
            role: .client,
            headline: "Basketball athlete building vertical jump and conditioning",
            rank: "Building",
            timeAgo: "Yesterday",
            title: "Jump session done",
            detail: "Kept the landing mechanics cleaner this week and finished mobility instead of skipping it.",
            tags: ["Basketball", "Mobility", "Jump Prep"],
            reactions: 19,
            comments: 4,
            commentHighlights: []
        )
    ]

    static let trainingGroups: [TrainingGroupPreview] = [
        TrainingGroupPreview(title: "Boxing Class", detail: "Coach-led group for skill work, conditioning, and accountability.", memberCount: 24),
        TrainingGroupPreview(title: "Beginner Strength Group", detail: "New lifters building consistency together.", memberCount: 18),
        TrainingGroupPreview(title: "Weekend Match Fit", detail: "Soccer-focused accountability and recovery check-ins.", memberCount: 13)
    ]

    static let networkSuggestions: [NetworkConnectionSuggestion] = [
        NetworkConnectionSuggestion(name: "Coach Elena", avatar: "🥋", role: .coach, headline: "MMA coach sharing return-to-training progressions", rank: "Coach Mentor", mutualContext: "4 mutual groups"),
        NetworkConnectionSuggestion(name: "Jordan", avatar: "🏃", role: .client, headline: "Runner preparing for a 10K and sharing recovery habits", rank: "Strong", mutualContext: "Seen in Endurance Circle"),
        NetworkConnectionSuggestion(name: "Priya", avatar: "🏐", role: .client, headline: "Volleyball athlete focused on power and resilience", rank: "Momentum", mutualContext: "Commented on Maya's post")
    ]

    static let workoutPartners: [WorkoutPartner] = [
        WorkoutPartner(
            name: "Jay",
            sport: .boxing,
            linkedAthleteID: nil,
            vibe: "Direct and consistent",
            status: "Ready after 6 PM",
            streak: 6,
            favoriteSession: "Heavy bag conditioning"
        ),
        WorkoutPartner(
            name: "Maya",
            sport: .soccer,
            linkedAthleteID: mayaAthleteID,
            vibe: "Fast-paced and upbeat",
            status: "Available for short morning sessions",
            streak: 7,
            favoriteSession: "Agility + mobility combo"
        ),
        WorkoutPartner(
            name: "Chris",
            sport: .basketball,
            linkedAthleteID: chrisAthleteID,
            vibe: "Calm and competitive",
            status: "Good for gym sessions and quick check-ins",
            streak: 4,
            favoriteSession: "Lower body jump prep"
        )
    ]

    static let leaderboards: [LeaderboardEntry] = [
        LeaderboardEntry(category: "Most consistent", leader: "Lucas", detail: "5-day streak"),
        LeaderboardEntry(category: "Most improved", leader: "Maya", detail: "Sprint performance up 12%"),
        LeaderboardEntry(category: "Best comeback", leader: "Alex", detail: "Protected streak after a missed day"),
        LeaderboardEntry(category: "Most supportive teammate", leader: "Chris", detail: "Commented on 8 posts this week")
    ]

    static let profileShowcase = ProfileShowcase(
        displayName: "Lucas",
        username: "lucasfit",
        bio: "Boxing, better conditioning, and small wins that stack.",
        avatar: AvatarProfile(style: .fightReady, gear: "Boxing wraps", outfit: "Black kit", background: "Dim gym lights", badgeFrame: "Builder ring", levelGlow: "Electric blue"),
        banner: BannerProfile(preset: .boxing, title: "Build Momentum", subtitle: "Consistency Era"),
        theme: .morpheBlackBlue,
        accentPalette: .electricBlue,
        currentPhase: "Build Consistency",
        coachingTone: .direct,
        badges: [
            ProfileBadge(title: "First Workout", detail: "Completed the first logged session.", icon: "figure.walk"),
            ProfileBadge(title: "7-Day Streak", detail: "Seven straight days of momentum.", icon: "flame.fill"),
            ProfileBadge(title: "First Plan B Save", detail: "Protected the habit with a smaller win.", icon: "shield.fill"),
            ProfileBadge(title: "First Quiz Completed", detail: "Finished the first Morphe lesson quiz.", icon: "brain.head.profile")
        ],
        personalRecords: [
            PersonalRecord(title: "Goblet Squat", value: "40 lbs x 10", detail: "Up 10 lbs this month"),
            PersonalRecord(title: "Rounds completed", value: "8", detail: "Best boxing conditioning block"),
            PersonalRecord(title: "Plank", value: "1:34", detail: "Core stability is improving")
        ],
        milestones: [
            TransformationMilestone(title: "Assessment complete", date: "Apr 12", detail: "Started with low confidence and simple wins."),
            TransformationMilestone(title: "First full training week", date: "Apr 28", detail: "Logged every planned session."),
            TransformationMilestone(title: "Consistency era", date: "May 20", detail: "Protected the streak twice this month.")
        ],
        communityStats: [
            CommunityStat(label: "Supportive comments", value: "18"),
            CommunityStat(label: "Challenges joined", value: "4"),
            CommunityStat(label: "Posts shared", value: "3")
        ],
        featuredWorkouts: [
            FeaturedWorkout(title: "Boxing Conditioning Builder", subtitle: "Favorite session right now"),
            FeaturedWorkout(title: "15-Minute Quick Workout", subtitle: "Best fallback plan")
        ],
        featuredVideos: [
            FeaturedVideo(title: "Heavy Bag Round 3", subtitle: "Coach feedback clip"),
            FeaturedVideo(title: "Goblet Squat Form", subtitle: "First clean set at 40 lbs")
        ],
        aiPerformanceBio: "Lucas is building a strong identity around consistency-first boxing conditioning. He responds well to direct coaching, short wins, and plans that adapt when life gets noisy."
    )

    static let subscriptionPlans: [SubscriptionPlan] = [
        SubscriptionPlan(
            title: "Morphe Free",
            price: "$0",
            audience: "All users at launch",
            features: [
                "Basic workout tracking",
                "Basic and premium profile access",
                "Custom avatar and banner",
                "Theme colors and shareable profile card",
                "Basic AI coach messages",
                "Community, challenges, and leaderboards"
            ]
        ),
        SubscriptionPlan(
            title: "Morphe Premium",
            price: "$19/mo",
            audience: "Client upgrade preview",
            features: [
                "Personalized AI plans",
                "Advanced smart plan adjustment",
                "Advanced recovery insights",
                "Advanced workout analytics",
                "More AI coach access",
                "Advanced nutrition guidance"
            ]
        ),
        SubscriptionPlan(
            title: "Morphe Coach Pro",
            price: "$79/mo",
            audience: "Coach upgrade preview",
            features: [
                "Client management",
                "Program builder",
                "AI summaries",
                "Intervention queue",
                "Video review",
                "Sport-specific programming"
            ]
        )
    ]

    static let subscriptionStatus = SubscriptionStatus(
        currentPlan: "Morphe Free",
        isPremiumUnlocked: false,
        profileIsFree: true,
        note: "Premium Profile is completely free at launch. Personalization and shareable identity are growth features, not paywalled features."
    )

    static let unlockableItems: [UnlockableItem] = [
        UnlockableItem(title: "Builder glow", detail: "Unlocked after 250 XP"),
        UnlockableItem(title: "Consistency frame", detail: "Unlocked after protecting your streak 3 times"),
        UnlockableItem(title: "Comeback badge", detail: "Unlocked after a missed day followed by a rebound")
    ]

    static let clientCoachConversation: [ThreadMessage] = [
        ThreadMessage(sender: .coach, senderName: "Coach Marcus", text: "Good morning. Stay moderate today and tell me how the first round feels.", timestamp: "8:02 AM"),
        ThreadMessage(sender: .ai, senderName: "Morphe AI", text: "You completed 3 workouts this week. Today's goal is simple: finish your full-body workout and hit your protein target.", timestamp: "8:05 AM"),
        ThreadMessage(sender: .user, senderName: "Lucas", text: "If I feel tired after work, should I still train?", timestamp: "8:07 AM"),
        ThreadMessage(sender: .ai, senderName: "Morphe AI", text: "Yes, but make the goal smaller. Minimum Win counts when life is loud.", timestamp: "8:07 AM")
    ]

    static let athleteMessageThreads: [MessageThread] = [
        MessageThread(
            participant: "Coach Marcus",
            sport: .boxing,
            preview: "Stay moderate today and message me after round one.",
            isUnread: false,
            messages: [
                ThreadMessage(sender: .coach, senderName: "Coach Marcus", text: "Good morning. Stay moderate today and tell me how the first round feels.", timestamp: "8:02 AM"),
                ThreadMessage(sender: .user, senderName: "Lucas", text: "Got it. I’ll keep the first round clean and check in after.", timestamp: "8:08 AM")
            ]
        ),
        MessageThread(
            participant: "Morphe AI",
            sport: .generalFitness,
            preview: "I can help with plans, swaps, nutrition, and recovery.",
            isUnread: true,
            messages: [
                ThreadMessage(sender: .ai, senderName: "Morphe AI", text: "I’m here for workout swaps, recovery calls, food questions, and quick summaries when you need them.", timestamp: "Now")
            ]
        ),
        MessageThread(
            participant: "Jay",
            sport: .boxing,
            preview: "Want to sync heavy bag rounds tonight?",
            isUnread: true,
            messages: [
                ThreadMessage(sender: .client, senderName: "Jay", text: "Want to sync heavy bag rounds tonight?", timestamp: "12:11 PM"),
                ThreadMessage(sender: .user, senderName: "Lucas", text: "Yeah, let’s keep it technical for the first two rounds.", timestamp: "12:13 PM")
            ]
        ),
        MessageThread(
            participant: "Maya",
            sport: .soccer,
            preview: "Recovery day helped a lot before training.",
            isUnread: false,
            messages: [
                ThreadMessage(sender: .client, senderName: "Maya", text: "Recovery day helped a lot before training.", timestamp: "Yesterday"),
                ThreadMessage(sender: .user, senderName: "Lucas", text: "I need to copy that. My calves were cooked last week.", timestamp: "Yesterday")
            ]
        ),
        MessageThread(
            participant: "Chris",
            sport: .basketball,
            preview: "I just posted my jump day recap.",
            isUnread: false,
            messages: [
                ThreadMessage(sender: .client, senderName: "Chris", text: "I just posted my jump day recap.", timestamp: "Tue"),
                ThreadMessage(sender: .user, senderName: "Lucas", text: "Saw it. That shuttle finisher looked rough.", timestamp: "Tue")
            ]
        )
    ]

    static let clientProfile = ClientProfile(
        id: lucasAthleteID,
        name: "Lucas",
        gender: .male,
        welcomeMessage: "Build momentum, not perfection.",
        oneLiner: brandOneLiner,
        coachName: "Coach Marcus",
        coachStatus: "Online",
        coachPreview: "Good job this week. Let's keep the next workout at moderate intensity.",
        sportMode: .boxing,
        selectedSports: [.boxing, .strength],
        selectedTrainingStyles: [.conditioning, .strength],
        health: HealthScoreSummary(
            score: 76,
            headline: "Momentum",
            detail: "Your weekly Morphe Score is strong because consistency is improving, even though recovery still needs attention.",
            tier: .strong
        ),
        level: LevelProgress(
            currentTitle: "Level 3 - Builder",
            nextTitle: "Athlete Mode",
            currentXP: 220,
            targetXP: 300,
            streak: 5
        ),
        adherence: 82,
        networkRank: "Level 3 Builder",
        goal: "Improve conditioning and body composition",
        selectedGoals: ["Improve conditioning and body composition", "Build consistency"],
        physicalGoalTarget: "Lean out, sharpen conditioning, and feel more athletic in everyday training.",
        weightGoalTarget: "Reach 205 lbs while keeping boxing sharpness",
        goalDeadline: "By the end of summer",
        fitnessLevel: "Beginner-intermediate",
        limitations: "Knee can get cranky when lunges get sloppy.",
        equipment: "Home dumbbells, heavy bag, gym access twice a week",
        currentProgram: "Boxing Base Builder",
        planCreatedBy: "Morphe AI",
        aiTodayInsight: AIInsight(
            title: "AI Coach Message",
            summary: "You do not need to train like a champion today. You just need to build the habits that create one.",
            risk: .medium,
            recommendation: "Start moderate, protect your sleep tonight, and close the day with protein.",
            suggestedAction: "Start today's boxing session"
        ),
        aiProgressInsight: AIInsight(
            title: "Weekly AI Summary",
            summary: "You are getting more consistent. Your workout completion improved by 25% this month.",
            risk: .low,
            recommendation: "Shorter sessions and streak protection are working. Keep those systems in play.",
            suggestedAction: "Review your roadmap"
        ),
        aiNutritionInsight: AIInsight(
            title: "AI Nutrition Feedback",
            summary: "You are on track with calories, but protein is a little low. Try adding a lean protein source at dinner.",
            risk: .medium,
            recommendation: "Aim for 30-40 grams of protein at dinner.",
            suggestedAction: "Quick add a protein-forward meal"
        )
    )

    static let coachProfile = CoachProfile(
        id: coachMarcusID,
        name: "Coach Marcus",
        username: "coachmarcus",
        specialty: "Boxing / Strength / Weight Loss",
        headline: "Helping athletes and beginners train with more clarity, less chaos, and better compliance.",
        networkRank: "Coach Leader",
        sports: [.boxing, .strength, .weightLoss, .soccer, .basketball, .running],
        selectedTrainingStyles: [.conditioning, .strength, .mobility, .skillWork],
        selectedGoals: ["Build consistency", "Improve sport performance", "Get stronger"],
        activeClients: 18,
        groups: ["Boxing Class", "Beginner Strength"],
        playbooks: ["Beginner Boxing Foundation", "Fat Loss Starter", "Return-to-Training Protocol"]
    )

    static let coaches: [CoachProfile] = [coachProfile]

    static let coachClients: [CoachClient] = {
        return [
            CoachClient(
                id: lucasAthleteID,
                name: "Lucas",
                age: 29,
                sport: .boxing,
                position: "Amateur welterweight",
                goal: "Improve conditioning and body composition",
                fitnessLevel: "Beginner-intermediate",
                trainingAge: "11 months",
                injuryHistory: ["Old right ankle sprain"],
                limitations: ["Knee discomfort during deep lunges"],
                equipment: ["Dumbbells", "Heavy bag", "Jump rope"],
                weeklySchedule: ["Mon boxing", "Tue lift", "Thu boxing", "Sat conditioning"],
                competitionDate: "Sparring event in 21 days",
                recoveryScore: recovery,
                healthScore: 76,
                complianceScore: 82,
                readinessStatus: .takeItEasy,
                risk: .medium,
                statusText: "Building Momentum",
                currentProgram: "Boxing Base Builder",
                notes: ["Responds well to simple direct cues.", "Weekend schedule is less reliable."],
                aiSummary: "Lucas is consistent with boxing sessions but recovery is slightly low. Keep tomorrow moderate.",
                lastWorkout: "Yesterday",
                coachNotes: "Struggles with weekends. Keep sessions under 45 minutes during work-heavy weeks.",
                nutritionNotes: "Protein usually drops at dinner. Hydration is improving.",
                adherenceSummary: "Strong overall. Usually follows the plan, but often skips core or mobility.",
                timeline: [
                    ClientTimelineEvent(title: "Completed boxing session", detail: "Logged 42-minute boxing conditioning builder."),
                    ClientTimelineEvent(title: "Protected streak", detail: "Used Minimum Win Mode after a late workday."),
                    ClientTimelineEvent(title: "Coach message sent", detail: "Moderate intensity reminder before tomorrow.")
                ],
                healthTrend: healthTrend,
                weightTrend: weightTrend,
                tests: [
                    PerformanceTest(name: "Rounds completed", sport: .boxing, category: "Conditioning", result: "8", unit: "rounds", previousResult: "6", trend: "Up"),
                    PerformanceTest(name: "Footwork drill time", sport: .boxing, category: "Skill", result: "1:14", unit: "min", previousResult: "1:19", trend: "Up"),
                    PerformanceTest(name: "Reaction score", sport: .boxing, category: "Skill", result: "82", unit: "/100", previousResult: "77", trend: "Up")
                ],
                reportCard: AthleteReport(athleteID: lucasAthleteID, week: "May 19-25", compliance: "82%", readiness: "Moderate", performance: "Improving", mainWin: "Completed 3/4 sessions", mainIssue: "Low sleep", coachNotes: "Works best with direct cues and shorter sessions.", aiSummary: "Solid week. Reduce Friday intensity if recovery stays low.", nextFocus: "Recovery + protein consistency"),
                movementQuality: MovementQualityScore(score: 78, summary: "Good control overall. Improve knee tracking and trunk stability."),
                trainingLoad: TrainingLoadInsight(status: "Productive Load", summary: "Lucas has completed 3 high-intensity boxing sessions this week.", recommendation: "Replace tomorrow's conditioning with mobility and light footwork."),
                availability: AvailabilityConstraints(availableDays: ["Mon", "Tue", "Thu", "Sat"], timeAvailable: "6-7 AM or after 6 PM", equipmentAccess: "Home dumbbells + boxing gym", location: "Home / boxing gym", schoolOrWork: "Full-time desk job", practiceSchedule: "Boxing Tue/Thu", gameSchedule: "Sparring in 21 days", travelSchedule: "No travel planned", injuryLimitations: "Watch knee irritation with lunges", sleepSchedule: "11:30 PM - 6:00 AM", stressLevel: "Medium"),
                eventPrep: EventPrepPlan(title: "Fight Camp Lite", countdown: "21 days", weeklyFocus: "Conditioning + sharp footwork", readiness: "Moderate", taperPlan: "Lower volume 3 days before sparring", weightTarget: "Hold current range", recoveryPriority: "Sleep and hydration", coachAlert: "Avoid back-to-back hard conditioning days."),
                programCompliance: ProgramCompliance(score: 82, summary: "Strong overall. You usually follow the plan, but you often skip mobility."),
                videoReviews: [
                    VideoReviewClip(athleteID: lucasAthleteID, sport: .boxing, title: "Heavy Bag Round 3", thumbnail: "Boxing clip placeholder", date: "May 21", movementQualityScore: 79, timestampComments: [VideoTimestampComment(time: "0:12", note: "Your hands drop after the jab. Keep your right hand near your cheek."), VideoTimestampComment(time: "0:28", note: "Nice level change into the body shot.")], aiFeedback: "Punch rhythm is improving. Guard discipline drops when fatigue climbs.")
                ]
            ),
            CoachClient(
                id: alexAthleteID,
                name: "Alex",
                age: 35,
                sport: .generalFitness,
                position: "Lifestyle client",
                goal: "Weight loss",
                fitnessLevel: "Beginner",
                trainingAge: "3 months",
                injuryHistory: ["None reported"],
                limitations: ["Low confidence on gym days"],
                equipment: ["Gym access", "Treadmill"],
                weeklySchedule: ["Mon walk", "Wed circuit", "Fri lift"],
                competitionDate: "None",
                recoveryScore: RecoverySnapshot(score: 52, status: .recoveryRecommended, reason: "Low energy and missed routines.", sleepHours: 5.8, energy: 4, soreness: 5, mood: 5, pain: false, previousSessionFeedback: .skippedParts),
                healthScore: 48,
                complianceScore: 44,
                readinessStatus: .recoveryRecommended,
                risk: .high,
                statusText: "At Risk",
                currentProgram: "Fat Loss Starter",
                notes: ["Needs lower-friction wins.", "Does best with check-in accountability."],
                aiSummary: "Alex missed two workouts and has low confidence. Assign Minimum Win Mode.",
                lastWorkout: "4 days ago",
                coachNotes: "No-stress messaging works better than hard accountability.",
                nutritionNotes: "Logs breakfast but drops off by dinner.",
                adherenceSummary: "Misses sessions when the plan feels too big.",
                timeline: [
                    ClientTimelineEvent(title: "Missed two workouts", detail: "No logging since Tuesday."),
                    ClientTimelineEvent(title: "Confidence low", detail: "Reported that the gym felt overwhelming.")
                ],
                healthTrend: [DayScore(day: "Mon", value: 52), DayScore(day: "Tue", value: 50), DayScore(day: "Wed", value: 49), DayScore(day: "Thu", value: 48)],
                weightTrend: [WeightPoint(label: "Start", value: 242), WeightPoint(label: "Current", value: 239)],
                tests: [PerformanceTest(name: "Push-ups in 1 minute", sport: .generalFitness, category: "General", result: "12", unit: "reps", previousResult: "8", trend: "Up")],
                reportCard: AthleteReport(athleteID: alexAthleteID, week: "May 19-25", compliance: "44%", readiness: "Low", performance: "Flat", mainWin: "Still checked in twice", mainIssue: "Work stress killed momentum", coachNotes: "Use Minimum Win language.", aiSummary: "Reset with tiny wins and a shorter plan.", nextFocus: "Rebuild consistency"),
                movementQuality: MovementQualityScore(score: 71, summary: "Movement looks safe. Confidence is the bigger blocker right now."),
                trainingLoad: TrainingLoadInsight(status: "Low Load", summary: "Alex has not reached enough weekly training density.", recommendation: "Assign a 15-minute quick workout and one walk target."),
                availability: AvailabilityConstraints(availableDays: ["Mon", "Wed", "Fri"], timeAvailable: "Lunch break or early evening", equipmentAccess: "Treadmill and machines", location: "Commercial gym", schoolOrWork: "Full-time office schedule", practiceSchedule: "None", gameSchedule: "None", travelSchedule: "Occasional work trips", injuryLimitations: "None", sleepSchedule: "12:00 AM - 5:45 AM", stressLevel: "High"),
                eventPrep: EventPrepPlan(title: "Lifestyle Reset", countdown: "No hard deadline", weeklyFocus: "Consistency first", readiness: "Low", taperPlan: "Not applicable", weightTarget: "1-2 lbs / month", recoveryPriority: "Sleep", coachAlert: "Keep coaching shame-free and simple."),
                programCompliance: ProgramCompliance(score: 44, summary: "Usually falls off when the plan feels too long or too complex."),
                videoReviews: []
            ),
            CoachClient(
                id: mayaAthleteID,
                name: "Maya",
                age: 21,
                sport: .soccer,
                position: "Winger",
                goal: "Improve speed and match readiness",
                fitnessLevel: "Intermediate",
                trainingAge: "4 years",
                injuryHistory: ["Hamstring tightness last season"],
                limitations: ["Manage sprint volume near match day"],
                equipment: ["Field", "Cones", "Gym"],
                weeklySchedule: ["Mon speed", "Tue team training", "Thu gym", "Sat match"],
                competitionDate: "League match Saturday",
                recoveryScore: RecoverySnapshot(score: 81, status: .ready, reason: "Sleep and soreness are both solid.", sleepHours: 8.0, energy: 8, soreness: 3, mood: 8, pain: false, previousSessionFeedback: .justRight),
                healthScore: 88,
                complianceScore: 91,
                readinessStatus: .ready,
                risk: .low,
                statusText: "Strong",
                currentProgram: "Soccer Preseason Speed",
                notes: ["Recovers well when sprint volume is organized."],
                aiSummary: "Maya improved sprint performance and is ready for higher agility volume.",
                lastWorkout: "Today",
                coachNotes: "Use higher agility volume midweek, not the day before matches.",
                nutritionNotes: "Consistent hydration and recovery meals.",
                adherenceSummary: "Excellent follow-through with both field and gym work.",
                timeline: [
                    ClientTimelineEvent(title: "Hit sprint PR", detail: "10-yard split improved by 0.04 seconds."),
                    ClientTimelineEvent(title: "Completed agility block", detail: "All cone work logged.")
                ],
                healthTrend: [DayScore(day: "Mon", value: 80), DayScore(day: "Tue", value: 82), DayScore(day: "Wed", value: 81), DayScore(day: "Thu", value: 85)],
                weightTrend: [WeightPoint(label: "Start", value: 136), WeightPoint(label: "Current", value: 136)],
                tests: [
                    PerformanceTest(name: "10-yard sprint", sport: .soccer, category: "Speed", result: "1.78", unit: "sec", previousResult: "1.82", trend: "Up"),
                    PerformanceTest(name: "5-10-5 agility", sport: .soccer, category: "Agility", result: "4.71", unit: "sec", previousResult: "4.79", trend: "Up"),
                    PerformanceTest(name: "Passing accuracy", sport: .soccer, category: "Skill", result: "88", unit: "%", previousResult: "85", trend: "Up")
                ],
                reportCard: AthleteReport(athleteID: mayaAthleteID, week: "May 19-25", compliance: "91%", readiness: "Ready", performance: "Sharp", mainWin: "Sprint and agility both improved", mainIssue: "Need better taper on Fridays", coachNotes: "Do not overload the final pre-match session.", aiSummary: "Ready for a slightly higher agility load.", nextFocus: "Match readiness taper"),
                movementQuality: MovementQualityScore(score: 84, summary: "Explosive and balanced. Continue hamstring care."),
                trainingLoad: TrainingLoadInsight(status: "Productive Load", summary: "Maya is handling speed and agility volume well.", recommendation: "Keep match-week taper intact."),
                availability: AvailabilityConstraints(availableDays: ["Mon", "Tue", "Thu", "Sat"], timeAvailable: "Afternoons", equipmentAccess: "Field + team gym", location: "University facilities", schoolOrWork: "College schedule", practiceSchedule: "Team sessions Tue/Thu", gameSchedule: "Saturday matches", travelSchedule: "Away games every other week", injuryLimitations: "Watch hamstring tightness", sleepSchedule: "10:30 PM - 7:00 AM", stressLevel: "Medium"),
                eventPrep: EventPrepPlan(title: "Match Readiness Mode", countdown: "3 days", weeklyFocus: "Sharpness and freshness", readiness: "Ready", taperPlan: "Reduce sprint volume Friday", weightTarget: "Not relevant", recoveryPriority: "Sleep and light mobility", coachAlert: "Avoid late heavy gym work."),
                programCompliance: ProgramCompliance(score: 91, summary: "Highly compliant. Great execution across field and gym."),
                videoReviews: [
                    VideoReviewClip(athleteID: mayaAthleteID, sport: .soccer, title: "Finishing Drill", thumbnail: "Soccer clip placeholder", date: "May 20", movementQualityScore: 83, timestampComments: [VideoTimestampComment(time: "0:09", note: "Good plant foot position before the shot."), VideoTimestampComment(time: "0:31", note: "Open the hips a touch sooner.")], aiFeedback: "Movement is sharp. Keep the first-step angle consistent.")
                ]
            ),
            CoachClient(
                id: chrisAthleteID,
                name: "Chris",
                age: 24,
                sport: .basketball,
                position: "Guard",
                goal: "Improve vertical jump and conditioning",
                fitnessLevel: "Intermediate",
                trainingAge: "2 years",
                injuryHistory: ["Patellar tendon irritation"],
                limitations: ["Needs more mobility consistency"],
                equipment: ["Court", "Rack", "Sled"],
                weeklySchedule: ["Mon lift", "Wed court conditioning", "Fri jumps"],
                competitionDate: "Summer league in 5 weeks",
                recoveryScore: RecoverySnapshot(score: 73, status: .moderate, reason: "Overall okay, but calves are tight.", sleepHours: 7.1, energy: 7, soreness: 5, mood: 7, pain: false, previousSessionFeedback: .justRight),
                healthScore: 64,
                complianceScore: 76,
                readinessStatus: .moderate,
                risk: .medium,
                statusText: "Building",
                currentProgram: "Basketball Offseason Jump Stack",
                notes: ["Needs more consistency with mobility."],
                aiSummary: "Chris is progressing but needs more consistency with mobility.",
                lastWorkout: "Yesterday",
                coachNotes: "Calf and ankle prep matters more than extra volume right now.",
                nutritionNotes: "Undereats after late sessions.",
                adherenceSummary: "Completes the big sessions but skips recovery work.",
                timeline: [
                    ClientTimelineEvent(title: "Completed jump session", detail: "Vertical work plus split squat jumps."),
                    ClientTimelineEvent(title: "Skipped mobility", detail: "No cooldown logged.")
                ],
                healthTrend: [DayScore(day: "Mon", value: 66), DayScore(day: "Tue", value: 68), DayScore(day: "Wed", value: 64), DayScore(day: "Thu", value: 64)],
                weightTrend: [WeightPoint(label: "Start", value: 191), WeightPoint(label: "Current", value: 189)],
                tests: [
                    PerformanceTest(name: "Vertical jump", sport: .basketball, category: "Power", result: "28.5", unit: "in", previousResult: "27.0", trend: "Up"),
                    PerformanceTest(name: "Defensive slide test", sport: .basketball, category: "Agility", result: "18.2", unit: "sec", previousResult: "18.9", trend: "Up")
                ],
                reportCard: AthleteReport(athleteID: chrisAthleteID, week: "May 19-25", compliance: "76%", readiness: "Moderate", performance: "Improving", mainWin: "Vertical jump improved", mainIssue: "Mobility skipped twice", coachNotes: "Keep mobility attached to the end of jump days.", aiSummary: "Good progress, but recovery habits need help.", nextFocus: "Mobility consistency"),
                movementQuality: MovementQualityScore(score: 78, summary: "Explosive and coordinated. Ankle stiffness shows up on landing."),
                trainingLoad: TrainingLoadInsight(status: "High Load", summary: "Chris has stacked jump, court, and conditioning work in a tight week.", recommendation: "Swap the next extra conditioning day for mobility and tissue work."),
                availability: AvailabilityConstraints(availableDays: ["Mon", "Wed", "Fri"], timeAvailable: "Late afternoon", equipmentAccess: "Court + gym", location: "Private facility", schoolOrWork: "Part-time work", practiceSchedule: "Skill work on weekends", gameSchedule: "Summer league starts in 5 weeks", travelSchedule: "Minimal", injuryLimitations: "Watch patellar tendon load", sleepSchedule: "11:00 PM - 7:00 AM", stressLevel: "Medium"),
                eventPrep: EventPrepPlan(title: "Offseason Jump Build", countdown: "35 days", weeklyFocus: "Power and conditioning", readiness: "Moderate", taperPlan: "Lower jump contacts every fourth week", weightTarget: "Lean maintain", recoveryPriority: "Ankle and calf mobility", coachAlert: "Avoid piling jumps on low-sleep days."),
                programCompliance: ProgramCompliance(score: 76, summary: "Strong effort on main sessions, weak follow-through on mobility."),
                videoReviews: [
                    VideoReviewClip(athleteID: chrisAthleteID, sport: .basketball, title: "Jump Shot Mechanics", thumbnail: "Basketball clip placeholder", date: "May 18", movementQualityScore: 76, timestampComments: [VideoTimestampComment(time: "0:15", note: "Solid base, but the release drifts left."), VideoTimestampComment(time: "0:25", note: "Nice vertical pop.")], aiFeedback: "Shooting base is stable. Landing mechanics can get cleaner.")
                ]
            ),
            CoachClient(
                id: jordanAthleteID,
                name: "Jordan",
                age: 31,
                sport: .running,
                position: "10K athlete",
                goal: "Prepare for 10K",
                fitnessLevel: "Intermediate",
                trainingAge: "3 years",
                injuryHistory: ["Past shin tightness"],
                limitations: ["Needs one recovery run minimum each week"],
                equipment: ["Track", "Road shoes", "HR watch"],
                weeklySchedule: ["Tue intervals", "Thu tempo", "Sun long run"],
                competitionDate: "10K in 6 weeks",
                recoveryScore: RecoverySnapshot(score: 84, status: .ready, reason: "Mileage is landing well and soreness is controlled.", sleepHours: 7.8, energy: 8, soreness: 3, mood: 8, pain: false, previousSessionFeedback: .justRight),
                healthScore: 88,
                complianceScore: 88,
                readinessStatus: .ready,
                risk: .low,
                statusText: "Strong",
                currentProgram: "10K Build Block",
                notes: ["Responds well to simple pace zones."],
                aiSummary: "Jordan is adapting well. Maintain weekly mileage and add one recovery session.",
                lastWorkout: "Today",
                coachNotes: "Do not let easy runs creep too hard.",
                nutritionNotes: "Fuel before long runs is consistent.",
                adherenceSummary: "Solid mileage compliance and good recovery habits.",
                timeline: [
                    ClientTimelineEvent(title: "Hit tempo target", detail: "Maintained pace zone for full block."),
                    ClientTimelineEvent(title: "Recovery session added", detail: "Completed mobility after intervals.")
                ],
                healthTrend: [DayScore(day: "Mon", value: 82), DayScore(day: "Tue", value: 84), DayScore(day: "Wed", value: 85), DayScore(day: "Thu", value: 84)],
                weightTrend: [WeightPoint(label: "Start", value: 174), WeightPoint(label: "Current", value: 173)],
                tests: [
                    PerformanceTest(name: "Mile time", sport: .running, category: "Speed", result: "6:08", unit: "min", previousResult: "6:16", trend: "Up"),
                    PerformanceTest(name: "Weekly mileage", sport: .running, category: "Endurance", result: "27", unit: "mi", previousResult: "24", trend: "Up")
                ],
                reportCard: AthleteReport(athleteID: jordanAthleteID, week: "May 19-25", compliance: "88%", readiness: "Ready", performance: "Steady", mainWin: "Tempo pace improved", mainIssue: "None major", coachNotes: "Maintain one true recovery day.", aiSummary: "Adaptation is good. Stay patient with volume jumps.", nextFocus: "Long-run fueling"),
                movementQuality: MovementQualityScore(score: 81, summary: "Smooth stride. Slight overstride appears late in the run."),
                trainingLoad: TrainingLoadInsight(status: "Productive Load", summary: "Mileage and intensity are balanced.", recommendation: "Keep one easy recovery session after intervals."),
                availability: AvailabilityConstraints(availableDays: ["Tue", "Thu", "Sun"], timeAvailable: "Early morning", equipmentAccess: "Track + roads", location: "Outdoor", schoolOrWork: "Flexible schedule", practiceSchedule: "No team practices", gameSchedule: "10K in 6 weeks", travelSchedule: "Race weekend only", injuryLimitations: "Watch shin tightness", sleepSchedule: "10:45 PM - 6:45 AM", stressLevel: "Low"),
                eventPrep: EventPrepPlan(title: "10K Prep Mode", countdown: "42 days", weeklyFocus: "Mileage + threshold work", readiness: "Ready", taperPlan: "Reduce total volume in race week", weightTarget: "Not relevant", recoveryPriority: "Easy day quality", coachAlert: "Watch shin tightness if mileage jumps too fast."),
                programCompliance: ProgramCompliance(score: 88, summary: "Great consistency. One recovery day keeps things stable."),
                videoReviews: [
                    VideoReviewClip(athleteID: jordanAthleteID, sport: .running, title: "Sprint Mechanics", thumbnail: "Running clip placeholder", date: "May 17", movementQualityScore: 80, timestampComments: [VideoTimestampComment(time: "0:10", note: "Good posture through the drive phase."), VideoTimestampComment(time: "0:22", note: "Foot lands slightly ahead when tired.")], aiFeedback: "Mechanics are efficient. Stay patient during the last third of intervals.")
                ]
            )
        ]
    }()

    static let workoutLogs: [WorkoutLog] = [
        WorkoutLog(
            athleteID: lucasAthleteID,
            athleteName: "Lucas",
            workoutTemplateID: workoutTemplates.first(where: { $0.name == "Boxing Conditioning Builder" })?.id,
            workoutTitle: "Boxing Conditioning Builder",
            sport: .boxing,
            completedAt: daysAgo(1),
            durationMinutes: 42,
            exercises: [
                LoggedExercise(name: "Jump Rope", sets: "1", reps: "3 min", weight: "Bodyweight", note: "Warm-up stayed smooth."),
                LoggedExercise(name: "Heavy Bag Intervals", sets: "4", reps: "3 min", weight: "Bodyweight", note: "Kept output steady."),
                LoggedExercise(name: "Dead Bug", sets: "3", reps: "10", weight: "Bodyweight", note: "Core finisher felt clean.")
            ],
            notes: "Athlete logged the full boxing builder and added post-workout feedback.",
            source: .athleteManual,
            enteredByUserID: lucasAthleteID,
            enteredByRole: .client,
            enteredByName: "Lucas",
            verificationStatus: .athleteSubmitted
        ),
        WorkoutLog(
            athleteID: lucasAthleteID,
            athleteName: "Lucas",
            workoutTemplateID: workoutTemplates.first(where: { $0.name == "Beginner Full Body Strength" })?.id,
            workoutTitle: "Coach Added Strength Session",
            sport: .strength,
            completedAt: daysAgo(3),
            durationMinutes: 38,
            exercises: [
                LoggedExercise(name: "Goblet Squat", sets: "3", reps: "10", weight: "40 lb", note: "Coach entered from in-person session."),
                LoggedExercise(name: "Incline Push-Up", sets: "3", reps: "12", weight: "Bodyweight", note: "Used bench height adjustment."),
                LoggedExercise(name: "Romanian Deadlift", sets: "3", reps: "8", weight: "50 lb", note: "Tempo looked controlled.")
            ],
            notes: "Coach Marcus manually entered the session after a floor coaching block.",
            source: .coachManual,
            enteredByUserID: coachMarcusID,
            enteredByRole: .coach,
            enteredByName: "Coach Marcus",
            verificationStatus: .coachSubmitted
        ),
        WorkoutLog(
            athleteID: lucasAthleteID,
            athleteName: "Lucas",
            workoutTemplateID: nil,
            workoutTitle: "Heavy Bag Intervals Photo Import",
            sport: .boxing,
            completedAt: daysAgo(5),
            durationMinutes: 30,
            exercises: [
                LoggedExercise(name: "Shadowboxing Rounds", sets: "3", reps: "3 min", weight: "Bodyweight", note: "AI parsed from whiteboard photo."),
                LoggedExercise(name: "Heavy Bag Intervals", sets: "4", reps: "2 min", weight: "Bodyweight", note: "Detected from gym screenshot."),
                LoggedExercise(name: "Plank", sets: "2", reps: "45 sec", weight: "Bodyweight", note: "Auto-filled core finisher.")
            ],
            notes: "Parsed from a gym whiteboard photo and confirmed by Coach Marcus.",
            source: .aiPhotoParsed,
            enteredByUserID: coachMarcusID,
            enteredByRole: .coach,
            enteredByName: "Morphe AI + Coach Marcus",
            verificationStatus: .coachApproved
        ),
        WorkoutLog(
            athleteID: mayaAthleteID,
            athleteName: "Maya",
            workoutTemplateID: nil,
            workoutTitle: "Match Readiness Sprint Session",
            sport: .soccer,
            completedAt: daysAgo(2),
            durationMinutes: 36,
            exercises: [
                LoggedExercise(name: "Sprint Mechanics A-Skips", sets: "3", reps: "20 m", weight: "Bodyweight", note: "Crisp posture."),
                LoggedExercise(name: "5-10-5 Agility Drill", sets: "4", reps: "1 run", weight: "Bodyweight", note: "Times improved."),
                LoggedExercise(name: "Mobility Flow", sets: "1", reps: "8 min", weight: "Bodyweight", note: "Recovery finish.")
            ],
            notes: "Athlete entered a solid field session and tagged match-readiness focus.",
            source: .athleteManual,
            enteredByUserID: mayaAthleteID,
            enteredByRole: .client,
            enteredByName: "Maya",
            verificationStatus: .athleteSubmitted
        ),
        WorkoutLog(
            athleteID: alexAthleteID,
            athleteName: "Alex",
            workoutTemplateID: nil,
            workoutTitle: "Reset Walk + Circuit",
            sport: .generalFitness,
            completedAt: daysAgo(4),
            durationMinutes: 24,
            exercises: [
                LoggedExercise(name: "Treadmill Walk", sets: "1", reps: "12 min", weight: "Bodyweight", note: "Coach entered as a reset session."),
                LoggedExercise(name: "Bodyweight Squat", sets: "2", reps: "10", weight: "Bodyweight", note: "Comfortable pace."),
                LoggedExercise(name: "Glute Bridge", sets: "2", reps: "12", weight: "Bodyweight", note: "Simple confidence rebuild.")
            ],
            notes: "Coach logged a low-friction reset session after two missed workouts.",
            source: .coachManual,
            enteredByUserID: coachMarcusID,
            enteredByRole: .coach,
            enteredByName: "Coach Marcus",
            verificationStatus: .coachSubmitted
        )
    ]

    static let workoutAccessGrants: [AthleteAccessGrant] = coachClients.map { athlete in
        AthleteAccessGrant(
            athleteID: athlete.id,
            coachID: coachMarcusID,
            canViewWorkouts: true,
            canAddWorkouts: true,
            canEditWorkouts: true,
            canApproveAIEntries: true
        )
    }

    static let coachOverview = CoachOverview(
        activeClients: 18,
        atRiskClients: 4,
        checkInsNeeded: 6,
        sessionsToday: 5,
        painFlags: 3,
        messagesNeedingResponse: 4,
        alerts: [
            "Alex missed 2 workouts this week",
            "Maria's activity dropped 40%",
            "Jordan has not logged nutrition in 3 days",
            "Sam reported low recovery twice this week"
        ],
        wins: [
            "Lucas hit a 5-day streak",
            "Maya hit a sprint PR",
            "Chris improved vertical jump by 1.5 inches"
        ],
        todaySessions: [
            "8:00 AM - Lucas check-in",
            "12:00 PM - Maya strength session",
            "5:00 PM - Chris program update"
        ],
        sportAlerts: [
            "Lucas has low recovery before tomorrow's boxing session.",
            "Alex needs a Minimum Win reset.",
            "Maya is clear for a higher agility dose."
        ],
        weeklySummary: "You have 5 athletes needing attention today. Lucas has low recovery, Alex missed 2 sessions, and Maya hit a sprint PR.",
        insight: AIInsight(
            title: "Weekly AI Coach Summary",
            summary: "You have 5 athletes needing attention today. Alex reported knee pain, Jay missed 2 sessions, Maya hit a sprint PR, and Lucas has low recovery before tomorrow's boxing session.",
            risk: .medium,
            recommendation: "Handle the high-friction athletes first, then reinforce the wins.",
            suggestedAction: "Open the intervention queue"
        )
    )

    static let messageThreads: [MessageThread] = [
        MessageThread(participant: "Lucas", sport: .boxing, preview: "Workout felt good today.", isUnread: false, messages: [
            ThreadMessage(sender: .client, senderName: "Lucas", text: "Workout felt good today.", timestamp: "1:15 PM"),
            ThreadMessage(sender: .coach, senderName: "Coach Marcus", text: "Great. Keep tomorrow moderate and stay on protein.", timestamp: "1:20 PM")
        ]),
        MessageThread(participant: "Alex", sport: .generalFitness, preview: "I missed yesterday.", isUnread: true, messages: [
            ThreadMessage(sender: .client, senderName: "Alex", text: "I missed yesterday.", timestamp: "8:10 AM")
        ]),
        MessageThread(participant: "Maya", sport: .soccer, preview: "Can we increase weight next week?", isUnread: false, messages: [
            ThreadMessage(sender: .client, senderName: "Maya", text: "Can we increase weight next week?", timestamp: "Yesterday"),
            ThreadMessage(sender: .coach, senderName: "Coach Marcus", text: "Yes. Let's add load after Saturday's match.", timestamp: "Yesterday")
        ]),
        MessageThread(participant: "Chris", sport: .basketball, preview: "What should I do if my knees hurt?", isUnread: false, messages: [
            ThreadMessage(sender: .client, senderName: "Chris", text: "What should I do if my knees hurt?", timestamp: "Tue"),
            ThreadMessage(sender: .coach, senderName: "Coach Marcus", text: "Back off the jumps and send me a quick form clip.", timestamp: "Tue")
        ]),
        MessageThread(participant: "Coach Elena", sport: .generalFitness, preview: "I can share that onboarding flow I use for new clients.", isUnread: false, messages: [
            ThreadMessage(sender: .coach, senderName: "Coach Elena", text: "I can share that onboarding flow I use for new clients.", timestamp: "Wed"),
            ThreadMessage(sender: .coach, senderName: "Coach Marcus", text: "Please do. I want to tighten my first-week touchpoints.", timestamp: "Wed")
        ]),
        MessageThread(participant: "Coach Omar", sport: .boxing, preview: "The fight-camp taper is working well for my amateurs.", isUnread: false, messages: [
            ThreadMessage(sender: .coach, senderName: "Coach Omar", text: "The fight-camp taper is working well for my amateurs.", timestamp: "Thu"),
            ThreadMessage(sender: .coach, senderName: "Coach Marcus", text: "Love that. Send me the round structure when you can.", timestamp: "Thu")
        ]),
        MessageThread(participant: "Fight Camp Crew", sport: .boxing, preview: "Coach Marcus: gloves on by 6:00 PM sharp.", isUnread: true, isGroupChat: true, messages: [
            ThreadMessage(sender: .coach, senderName: "Coach Marcus", text: "Gloves on by 6:00 PM sharp. Keep round one technical.", timestamp: "Now"),
            ThreadMessage(sender: .client, senderName: "Lucas", text: "Got it. I’ll be early.", timestamp: "Now")
        ]),
        MessageThread(participant: "Speed Group", sport: .soccer, preview: "Maya: cones are already set up for tonight.", isUnread: false, isGroupChat: true, messages: [
            ThreadMessage(sender: .client, senderName: "Maya", text: "Cones are already set up for tonight.", timestamp: "Yesterday"),
            ThreadMessage(sender: .coach, senderName: "Coach Marcus", text: "Perfect. First set stays sharp, not heavy.", timestamp: "Yesterday")
        ])
    ]

    static let outreachSuggestions: [OutreachSuggestion] = [
        OutreachSuggestion(clientName: "Alex", summary: "Alex missed 2 workouts. Send reset message?", suggestedMessage: "Hey Alex, no stress about missing yesterday. Let's reset today with a shorter workout and keep the momentum going."),
        OutreachSuggestion(clientName: "Maya", summary: "Maya hit a new PR. Send celebration message?", suggestedMessage: "Huge win on the sprint PR. Let's keep the taper clean and build on that."),
        OutreachSuggestion(clientName: "Chris", summary: "Chris reported knee pain. Send form check message?", suggestedMessage: "Let's lower jump volume today and send me a quick clip so we can clean up the landing pattern."),
        OutreachSuggestion(clientName: "Lucas", summary: "Lucas improved adherence. Send encouragement?", suggestedMessage: "Nice work staying consistent this week. Keep the next boxing day moderate so recovery can catch up.")
    ]

    static let messageTemplates: [MessageTemplate] = [
        MessageTemplate(title: "Missed workout check-in", body: "No stress about missing yesterday. Let's reset with a shorter session today and keep the momentum going."),
        MessageTemplate(title: "Weekly progress review", body: "You did a lot right this week. Biggest win first, then we'll tighten the one thing that matters most next week."),
        MessageTemplate(title: "Motivation boost", body: "You do not need a perfect day. Finish one small win and let that count."),
        MessageTemplate(title: "Nutrition reminder", body: "Quick reminder: protein at the next meal will help recovery and make tomorrow easier."),
        MessageTemplate(title: "Session confirmation", body: "You're locked in for today's session. Reply if anything changed with energy, soreness, or schedule."),
        MessageTemplate(title: "Pain / injury follow-up", body: "Thank you for flagging that pain. Let's lower the load today and use the safer option while I review it."),
        MessageTemplate(title: "Competition prep reminder", body: "Game day is close. Today is about staying fresh, sharp, and recovered.")
    ]

    static let coachInterventions: [CoachIntervention] = {
        let athletes = coachClients
        return [
            CoachIntervention(athleteID: athletes[1].id, athleteName: "Alex", reason: "Missed 2 workouts and reported low motivation.", riskLevel: .high, suggestedAction: "Send reset message and assign Minimum Win plan.", status: "Needs action"),
            CoachIntervention(athleteID: athletes[0].id, athleteName: "Lucas", reason: "Low recovery before tomorrow's boxing session.", riskLevel: .medium, suggestedAction: "Lower intensity and check in after the first round.", status: "Watch"),
            CoachIntervention(athleteID: athletes[3].id, athleteName: "Chris", reason: "Mobility skipped twice and jump load stayed high.", riskLevel: .medium, suggestedAction: "Swap one conditioning day for mobility.", status: "Needs action"),
            CoachIntervention(athleteID: athletes[2].id, athleteName: "Maya", reason: "Match in 3 days, avoid overload.", riskLevel: .low, suggestedAction: "Keep taper clean and celebrate sprint progress.", status: "Monitor")
        ]
    }()

    static let teamGroups: [TeamGroup] = [
        TeamGroup(
            name: "Boxing Class",
            sport: .boxing,
            programName: "Beginner Boxing Foundation",
            readinessAverage: 74,
            leaderboard: ["Lucas - 82% compliance", "Jay - 79% compliance", "Andre - 75% compliance"],
            groupMessage: "Reminder: keep today's bag rounds technical, not reckless.",
            attendance: [
                TeamMemberAttendance(athleteName: "Lucas", status: .present, note: "Ready"),
                TeamMemberAttendance(athleteName: "Jay", status: .late, note: "Traffic"),
                TeamMemberAttendance(athleteName: "Andre", status: .partialCompletion, note: "Left after 45 min")
            ]
        ),
        TeamGroup(
            name: "Beginner Strength",
            sport: .generalFitness,
            programName: "Fat Loss Starter",
            readinessAverage: 69,
            leaderboard: ["Alex - 44% compliance", "Mina - 71% compliance", "Drew - 66% compliance"],
            groupMessage: "Show up for the small wins. Short still counts.",
            attendance: [
                TeamMemberAttendance(athleteName: "Alex", status: .absent, note: "Work conflict"),
                TeamMemberAttendance(athleteName: "Mina", status: .present, note: "Strong effort"),
                TeamMemberAttendance(athleteName: "Drew", status: .excused, note: "Travel")
            ]
        )
    ]

    static let playbooks: [CoachPlaybook] = [
        CoachPlaybook(title: "Beginner Boxing Foundation", philosophy: "Conditioning should support skill, not drown it.", warmUps: ["Jump rope", "Dynamic shoulders"], drills: ["Slip Rope Drill", "Shadowboxing Rounds"], templates: ["Boxing Conditioning Builder"], recoveryProtocols: ["Breathing reset", "Calf mobility"], progressionRules: ["Add rounds before adding chaos", "Keep one technical day easy"]),
        CoachPlaybook(title: "Soccer Preseason Speed", philosophy: "Fresh speed beats tired speed.", warmUps: ["Dynamic warm-up", "Sprint drills"], drills: ["Cone Dribble Weave", "5-10-5 Agility Drill"], templates: ["Soccer Match Fitness"], recoveryProtocols: ["Hamstring flush", "Sleep target"], progressionRules: ["Increase quality before volume", "Respect match-day taper"]),
        CoachPlaybook(title: "Fat Loss Starter", philosophy: "Low-friction consistency first.", warmUps: ["5-minute walk", "Bodyweight mobility"], drills: ["Mobility Flow"], templates: ["15-Minute Quick Workout"], recoveryProtocols: ["Minimum Win fallback"], progressionRules: ["Earn complexity through consistency"])
    ]

    static let leadRecords: [LeadRecord] = [
        LeadRecord(name: "Elena", sport: .generalFitness, status: .newLead, note: "Asked about beginner coaching.", aiSuggestion: "Send a welcoming intro and ask about her main goal."),
        LeadRecord(name: "Dev", sport: .boxing, status: .consultationBooked, note: "Interested in fight-camp structure.", aiSuggestion: "Share the Beginner Boxing Foundation playbook preview."),
        LeadRecord(name: "Nia", sport: .running, status: .pastClient, note: "Stopped 60 days ago after a 5K.", aiSuggestion: "This past client stopped training 60 days ago. Send comeback offer?"),
        LeadRecord(name: "Aaron", sport: .basketball, status: .trialClient, note: "Completed first jump session.", aiSuggestion: "This athlete completed a trial. Send program invite?")
    ]

    static let coachAnalytics = CoachAnalytics(
        clientRetention: 84,
        averageCompliance: 76,
        averageProgress: "Improving",
        dropOffRate: 12,
        painFlags: 3,
        messageResponseRate: 88,
        programSuccessRate: 81,
        sessionCompletion: 86,
        groupAttendance: 78,
        insight: "Your beginner strength program has an 84% completion rate, but clients often skip the third workout."
    )

    static let upcomingSessions: [CalendarEvent] = [
        CalendarEvent(
            day: "Monday",
            time: "8:00 AM",
            title: "Lucas check-in",
            detail: "Review recovery before boxing session.",
            type: .checkIn,
            athleteID: coachClients[0].id,
            attendance: [
                TeamMemberAttendance(athleteName: "Lucas", status: .present, note: "Checked in early")
            ]
        ),
        CalendarEvent(
            day: "Monday",
            time: "12:00 PM",
            title: "Maya strength session",
            detail: "Lower-body lift with reduced Friday volume.",
            type: .session,
            athleteID: coachClients[2].id,
            attendance: [
                TeamMemberAttendance(athleteName: "Maya", status: .present, note: "Ready for lift")
            ]
        ),
        CalendarEvent(
            day: "Tuesday",
            time: "9:00 AM",
            title: "Alex reset call",
            detail: "Simplify the week and turn on Minimum Win backup.",
            type: .review,
            athleteID: coachClients[1].id,
            attendance: [
                TeamMemberAttendance(athleteName: "Alex", status: .late, note: "Running behind")
            ]
        )
    ]

    static let sportMetrics: [SportFocus: [SportMetric]] = [
        .boxing: [
            SportMetric(label: "Rounds completed", value: "8"),
            SportMetric(label: "Footwork", value: "Cleaner exits"),
            SportMetric(label: "Conditioning", value: "Up 12%"),
            SportMetric(label: "Reaction", value: "82 / 100"),
            SportMetric(label: "Sparring notes", value: "Moderate intensity this week")
        ],
        .soccer: [
            SportMetric(label: "Sprint speed", value: "1.78 sec"),
            SportMetric(label: "Agility", value: "4.71 sec"),
            SportMetric(label: "Ball control", value: "Sharp"),
            SportMetric(label: "Match readiness", value: "Ready"),
            SportMetric(label: "Conditioning", value: "Strong")
        ],
        .strength: [
            SportMetric(label: "Main lift", value: "Goblet squat 40 x 10"),
            SportMetric(label: "Workout split", value: "3 days / week"),
            SportMetric(label: "Strength trend", value: "+10 lbs"),
            SportMetric(label: "Recovery", value: "Take It Easy")
        ],
        .running: [
            SportMetric(label: "Mile time", value: "6:08"),
            SportMetric(label: "400m pace", value: "1:18"),
            SportMetric(label: "Pace zones", value: "On target"),
            SportMetric(label: "Mileage", value: "27 mi"),
            SportMetric(label: "Recovery", value: "Ready")
        ],
        .generalFitness: [
            SportMetric(label: "Sessions this week", value: "3"),
            SportMetric(label: "Steps average", value: "7,240"),
            SportMetric(label: "Protein days", value: "3 / 5"),
            SportMetric(label: "Streak", value: "5 days")
        ]
    ]

    static func sportMetrics(for sport: SportFocus) -> [SportMetric] {
        sportMetrics[sport] ?? sportMetrics[.generalFitness] ?? []
    }

    static func goalTranslation(for goal: String, sport: SportFocus) -> GoalTranslation {
        if let exact = goalTranslations.first(where: { $0.goal.localizedCaseInsensitiveContains(goal) || goal.localizedCaseInsensitiveContains($0.goal) }) {
            return exact
        }

        switch sport {
        case .boxing:
            return GoalTranslation(goal: "Improve boxing conditioning", weeklyActions: ["2 conditioning sessions", "2 boxing skill sessions", "1 strength session", "Recovery score check-ins", "Weekly round capacity test"])
        case .soccer:
            return GoalTranslation(goal: "Get faster for soccer", weeklyActions: ["2 speed/agility sessions", "1 strength session", "1 mobility session", "Sprint test every 2 weeks", "Match readiness check-in"])
        default:
            return goalTranslations[3]
        }
    }

    static func aiCoachReply(to prompt: String, tone: CoachingTone = .supportive) -> String {
        let lowercased = prompt.lowercased()

        if lowercased.contains("sore") {
            return "Some soreness is normal, especially when consistency is building. Keep today's intensity moderate, move first, and report anything sharp."
        }

        if lowercased.contains("switch") || lowercased.contains("swap") {
            return "Yes. If the original plan feels unrealistic, choose a shorter session or a recovery option. Morphe cares more about momentum than perfect programming."
        }

        if lowercased.contains("eat") || lowercased.contains("protein") {
            return "After training, make the next meal easy: lean protein, a carb you digest well, and water."
        }

        if lowercased.contains("plan b") {
            return "Plan B is there to keep you moving when the day gets messy. Smaller still counts."
        }

        if lowercased.contains("pain") {
            return "Pain changes the plan. Report where it happened, how strong it felt, and which movement triggered it so Morphe can swap in a safer option."
        }

        switch tone {
        case .competitive:
            return "You do not need more overthinking. Pick the next small action and finish it."
        case .educational:
            return "Consistency works because repeatable training builds adaptation without blowing up recovery."
        default:
            return "Small wins first. If today feels heavy, use a lighter version, finish one meaningful task, and keep the streak alive."
        }
    }

    static func workoutFeedbackResponse(for option: WorkoutFeedbackOption) -> String {
        switch option {
        case .tooEasy:
            return "Great. Morphe will slightly increase your challenge next time."
        case .justRight:
            return "Perfect. Morphe will keep the next session in the same productive range."
        case .tooHard:
            return "No problem. Morphe will reduce the next session so you can keep momentum."
        case .pain:
            return "Pain reported. Morphe will suggest a safer option and notify your coach."
        case .skippedParts:
            return "Thanks for logging that. Morphe will trim the next plan so it fits real life better."
        }
    }

    static func planAdjustment(for reasons: [PlanAdjustmentReason]) -> PlanAdjustment {
        if reasons.contains(.painReported) {
            return PlanAdjustment(
                title: "Pain flag changed the plan",
                body: "Today's session was adjusted because you reported pain during a previous movement.",
                reasons: reasons,
                recommendation: "Use pain-free alternatives and send a note to your coach."
            )
        }

        if reasons.contains(.notEnoughTime) {
            return PlanAdjustment(
                title: "Today's plan has been adjusted to protect momentum",
                body: "Time is tight, so Morphe shortened the session instead of letting the whole day collapse.",
                reasons: reasons,
                recommendation: "Finish the 15-minute quick workout and keep the habit moving."
            )
        }

        if reasons.contains(.eventApproaching) {
            return PlanAdjustment(
                title: "Freshness first",
                body: "Today's session was adjusted because a game or competition is coming up soon.",
                reasons: reasons,
                recommendation: "Protect recovery and leave the session feeling sharper, not flatter."
            )
        }

        if reasons.contains(.workoutTooEasy) {
            return PlanAdjustment(
                title: "Challenge nudged up",
                body: "Today's session was adjusted because the last one felt too easy.",
                reasons: reasons,
                recommendation: "Add a little challenge without losing clean form."
            )
        }

        return defaultPlanAdjustment
    }

    static func planBResponse(for reason: PlanBReason) -> (PlanAdjustment, [TaskItem], String) {
        switch reason {
        case .tired:
            return (
                PlanAdjustment(title: "Today's plan has been adjusted to protect momentum", body: "Energy is low, so Morphe swapped the full session for a smaller win plan.", reasons: [.lowRecovery], recommendation: "Walk 5 minutes, stretch, drink water, and log your mood."),
                minimumWinTasks,
                "Today does not need to be perfect. Complete one small win to keep momentum."
            )
        case .busy, .traveling:
            return (
                PlanAdjustment(title: "Plan B loaded", body: "Time and context are tight, so Morphe shortened the day.", reasons: [.notEnoughTime], recommendation: "Finish the smallest version and move on."),
                minimumWinTasks,
                "Short and simple is enough today."
            )
        case .sore, .unmotivated:
            return (
                PlanAdjustment(title: "Recovery pivot", body: "Today's session was adjusted because soreness or stress is elevated.", reasons: [.lowRecovery], recommendation: "Use mobility, breathing, and a short walk."),
                minimumWinTasks,
                "Use the lighter version today and let recovery do its job."
            )
        case .noEquipment:
            return (
                PlanAdjustment(title: "Environment swap", body: "Your normal setup is not available.", reasons: [.noEquipment], recommendation: "Home and low-friction options loaded."),
                minimumWinTasks,
                "You can still win today without the perfect setup."
            )
        case .pain:
            return (
                planAdjustment(for: [.painReported]),
                minimumWinTasks,
                "Pain changes the plan. Use a safer option and report what happened."
            )
        case .competitionSoon:
            return (
                planAdjustment(for: [.eventApproaching]),
                minimumWinTasks,
                "Freshness matters. Keep effort low and quality high."
            )
        }
    }

    static func painAlternative(area: String, triggerExercise: String) -> (String, String) {
        let lowerArea = area.lowercased()
        let lowerExercise = triggerExercise.lowercased()

        if lowerArea.contains("knee") && lowerExercise.contains("lunge") {
            return ("Glute Bridge", "Switch to glute bridge or bodyweight squat and keep the range pain-free.")
        }

        if lowerArea.contains("shoulder") && lowerExercise.contains("push") {
            return ("Incline Push-Up", "Use incline push-up or band external rotation instead of standard push-ups.")
        }

        if lowerArea.contains("back") {
            return ("Dead Bug", "Swap the loaded movement for dead bug and a short walk while the coach reviews it.")
        }

        return ("Recovery Session", "Use a pain-free recovery option and let your coach review the trigger.")
    }

    static func generatedPlan(from draft: OnboardingDraft) -> (phase: String, goalTranslation: GoalTranslation, firstTask: String, message: String) {
        let goal = goalTranslation(for: draft.goal.rawValue, sport: draft.sport)
        let focusSummary = [
            draft.selectedSports.first.map { "\($0.rawValue) focus" },
            draft.selectedTrainingStyles.first.map { "\($0.rawValue.lowercased()) work" },
            draft.selectedGoals.first.map { "\($0.rawValue.lowercased()) priority" }
        ]
        .compactMap { $0 }
        .joined(separator: " with ")
        let physicalGoal = draft.physicalGoalTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightGoal = draft.weightGoalTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        let deadline = draft.goalDeadline.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetSummary = [
            physicalGoal.isEmpty ? nil : "Physical target: \(physicalGoal)",
            weightGoal.isEmpty ? nil : "Weight goal: \(weightGoal)",
            deadline.isEmpty ? nil : "Deadline: \(deadline)"
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        return (
            phase: "Build Consistency",
            goalTranslation: goal,
            firstTask: "Complete today's readiness check-in",
            message: "Your first phase is Build Consistency. This week, Morphe recommends \(draft.trainingDaysPerWeek) short training sessions, 2 recovery check-ins, and one simple nutrition habit\(focusSummary.isEmpty ? "" : " built around your \(focusSummary)").\(targetSummary.isEmpty ? "" : " \(targetSummary)")"
        )
    }

    static func partnerWorkoutPlan(
        for workout: WorkoutTemplate,
        partner: WorkoutPartner,
        mode: PartnerWorkoutMode
    ) -> PartnerWorkoutPlan {
        switch mode {
        case .live:
            return PartnerWorkoutPlan(
                headline: "Train with \(partner.name) live",
                detail: "Start the same session together, share your first set update, and finish with a quick recap.",
                xpBonus: 15,
                miniChallenge: "Finish the warm-up inside 6 minutes and both log the session."
            )
        case .async:
            return PartnerWorkoutPlan(
                headline: "Async accountability with \(partner.name)",
                detail: "You do not need matching schedules. Just complete the same session and send one proof-of-effort update.",
                xpBonus: 10,
                miniChallenge: "Each of you logs one win and one hard moment from \(workout.name)."
            )
        case .challenge:
            return PartnerWorkoutPlan(
                headline: "Mini challenge mode",
                detail: "Keep the main workout, then add one small competitive finisher that still fits the day.",
                xpBonus: 20,
                miniChallenge: "Best plank hold or cleanest final round wins the bragging rights."
            )
        }
    }

    static func makeWorkoutExercise(_ exerciseID: String, sets: String, reps: String) -> WorkoutExercise {
        guard let exercise = exerciseDatabase.first(where: { $0.id == exerciseID }) else {
            return WorkoutExercise(
                id: exerciseID,
                exerciseLibraryID: exerciseID,
                name: exerciseID,
                muscleGroup: .core,
                sets: sets,
                reps: reps,
                difficulty: .beginner,
                formCue: "Keep it smooth."
            )
        }

        return WorkoutExercise(
            id: exercise.id,
            exerciseLibraryID: exercise.id,
            name: exercise.name,
            muscleGroup: exercise.muscleGroup,
            sets: sets,
            reps: reps,
            difficulty: exercise.difficulty,
            formCue: exercise.formCue
        )
    }
}
