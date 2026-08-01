import Foundation

enum MockData {
    static let demoGymID = UUID(uuidString: "C0000000-0000-0000-0000-000000000063")!
    static let demoUserID = UUID(uuidString: "20D85C0B-32F0-4144-8A0D-15D8820B3592")!
    static let defaultWorkoutPlanID = UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!

    static let exercises: [Exercise] = [
        Exercise(id: "bench", name: "Barbell bench press", symbolName: "figure.strengthtraining.traditional", isPowerlift: true),
        Exercise(id: "squat", name: "Back squat", symbolName: "figure.strengthtraining.functional", isPowerlift: true),
        Exercise(id: "deadlift", name: "Conventional deadlift", symbolName: "dumbbell", isPowerlift: true),
        Exercise(id: "sumo_deadlift", name: "Sumo deadlift", symbolName: "dumbbell.fill", isPowerlift: false),
        Exercise(id: "press", name: "Overhead press", symbolName: "arrow.up.circle", isPowerlift: false)
    ]

    static var trainingExerciseLibrary: [TrainingExerciseCatalogItem] {
        (coreTrainingExerciseLibrary + PopularExerciseCatalog.exercises).map { item in
            var enriched = item
            enriched.muscleProfile = item.muscleProfile ?? ExerciseMuscleProfileResolver.profile(name: item.name, bodyPart: item.bodyPart)
            enriched.searchAliases = Array(Set(item.searchAliases + exerciseAliases(for: item)))
            enriched.movementPattern = item.movementPattern == .other ? movementPattern(for: item) : item.movementPattern
            enriched.movementType = movementType(for: enriched)
            enriched.trackingType = trackingType(for: enriched)
            enriched.difficulty = difficulty(for: item)
            return enriched
        }
    }

    private static func exerciseAliases(for exercise: TrainingExerciseCatalogItem) -> [String] {
        var aliases = generatedAliases(for: exercise)
        switch exercise.id {
        case "machine_chest_press":
            aliases += [
                "Seated Chest Press",
                "Chest Press Machine",
                "Hammer Strength Chest Press",
                "Plate Loaded Chest Press",
                "Selectorized Chest Press",
                "Machine Press"
            ]
        case "leg_press":
            aliases += ["45 Degree Leg Press", "Linear Leg Press", "Plate Loaded Leg Press"]
        case "hack_squat":
            aliases += ["Hack Press", "Machine Hack Squat"]
        case "chest_supported_row":
            aliases += ["Supported Row", "Chest Supported Machine Row", "Hammer Strength Row"]
        default:
            break
        }
        return Array(Set(aliases)).sorted()
    }

    private static func generatedAliases(for exercise: TrainingExerciseCatalogItem) -> [String] {
        var aliases: [String] = []
        let name = exercise.name
        let replacements: [(String, String)] = [
            ("DB", "Dumbbell"),
            ("Dumbbell", "DB"),
            ("Barbell", "BB"),
            ("BB", "Barbell"),
            ("Machine", ""),
            ("Cable", ""),
            ("Single-Arm", "One-Arm"),
            ("Single-Leg", "One-Leg"),
            ("Pull-Up", "Pullup"),
            ("Pushdown", "Pressdown"),
            ("Pressdown", "Pushdown")
        ]
        for (source, replacement) in replacements where name.localizedCaseInsensitiveContains(source) {
            aliases.append(name.replacingOccurrences(of: source, with: replacement).replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        aliases.append("\(exercise.equipment) \(exercise.bodyPart)")
        aliases.append("\(exercise.bodyPart) \(exercise.movementPattern.rawValue)")
        return aliases.filter { !$0.isEmpty && $0.caseInsensitiveCompare(name) != .orderedSame }
    }

    private static func movementPattern(for exercise: TrainingExerciseCatalogItem) -> ExerciseMovementPattern {
        let name = exercise.name.lowercased()
        if name.contains("bench") || name.contains("chest press") || name.contains("pec deck") || name.contains("dip") || name.contains("fly") || name.contains("push-up") || name.contains("push up") || name.contains("floor press") {
            return .horizontalPress
        }
        if name.contains("overhead") || name.contains("shoulder press") || name.contains("pike push") || name.contains("landmine press") || name.contains("push press") {
            return .verticalPress
        }
        if name.contains("row") || name.contains("pull-apart") || name.contains("pull apart") || name.contains("face pull") {
            return .horizontalPull
        }
        if name.contains("pulldown") || name.contains("pull-up") || name.contains("pullup") || name.contains("chin-up") || name.contains("pullover") || name.contains("scapular pull") {
            return .verticalPull
        }
        if name.contains("squat") || name.contains("leg press") || name.contains("leg extension") || name.contains("reverse nordic") || name.contains("wall sit") {
            return .squat
        }
        if name.contains("deadlift") || name.contains("hinge") || name.contains("hip thrust") || name.contains("good morning") || name.contains("glute bridge") || name.contains("swing") || name.contains("clean pull") || name.contains("power clean") || name == "clean" || name.contains("clean and jerk") || name.contains("snatch") {
            return .hinge
        }
        if name.contains("split squat") || name.contains("lunge") || name.contains("step-up") {
            return .lunge
        }
        if name.contains("curl") && !name.contains("leg curl") {
            return .curl
        }
        if name.contains("pressdown") || name.contains("triceps") || name.contains("extension") {
            return .elbowExtension
        }
        if name.contains("lateral raise") || name.contains("rear delt") || name.contains("upright row") || name.contains("high pull") || name.contains("shrug") {
            return .shoulderIsolation
        }
        if name.contains("calf") || name.contains("tibialis") {
            return .calf
        }
        if name.contains("crunch") || name.contains("plank") || name.contains("leg raise") || name.contains("rollout") || name.contains("dead bug") || name.contains("bird dog") || name.contains("hollow") || name.contains("pallof") || name.contains("wood chop") || name.contains("twist") || name.contains("windmill") {
            return .core
        }
        if name.contains("carry") || name.contains("crawl") || name.contains("burpee") || name.contains("turkish get-up") || name.contains("muscle-up") {
            return .carry
        }
        return .other
    }

    private static func difficulty(for exercise: TrainingExerciseCatalogItem) -> ExerciseDifficulty {
        switch movementPattern(for: exercise) {
        case .horizontalPress, .horizontalPull, .verticalPull, .squat, .hinge, .lunge:
            return exercise.equipment == "Machine" || exercise.equipment == "Cable" ? .moderate : .advanced
        case .verticalPress:
            return exercise.equipment == "Machine" ? .moderate : .advanced
        case .curl, .elbowExtension, .shoulderIsolation, .calf, .core:
            return .beginner
        case .carry:
            return .moderate
        case .other:
            return .moderate
        }
    }

    private static func movementType(for exercise: TrainingExerciseCatalogItem) -> String {
        switch exercise.movementPattern {
        case .curl, .elbowExtension, .shoulderIsolation, .calf, .core:
            return "Accessory"
        case .carry:
            return "Conditioning"
        case .other:
            return exercise.workoutCategory == "Custom" ? "Custom" : "Strength"
        default:
            return exercise.rankingExerciseID == nil ? "Hypertrophy" : "Strength"
        }
    }

    private static func trackingType(for exercise: TrainingExerciseCatalogItem) -> String {
        let name = exercise.name.lowercased()
        let reps = exercise.defaultReps.lowercased()
        if exercise.movementPattern == .carry { return "Weight + Time" }
        if reps.contains("sec") || exercise.movementPattern == .core && name.contains("plank") { return "Time" }
        if name.contains("assisted") { return "Assisted Bodyweight" }
        if name.contains("weighted") { return "Weight + Reps" }
        if exercise.equipment == "Bodyweight" { return "Bodyweight Reps" }
        if exercise.equipment == "Band" { return "Reps Only" }
        return "Weight + Reps"
    }

    private static let coreTrainingExerciseLibrary: [TrainingExerciseCatalogItem] = [
        TrainingExerciseCatalogItem(id: "barbell_bench_press", name: "Barbell Bench Press", bodyPart: "Chest", workoutCategory: "Push", defaultSets: 3, defaultReps: "5-8", symbolName: "figure.strengthtraining.traditional", equipment: "Barbell", rankingExerciseID: "bench"),
        TrainingExerciseCatalogItem(id: "incline_db_press", name: "Incline DB Press", bodyPart: "Upper Chest", workoutCategory: "Push", defaultSets: 3, defaultReps: "8-10", symbolName: "figure.strengthtraining.traditional", equipment: "Dumbbell"),
        TrainingExerciseCatalogItem(id: "machine_chest_press", name: "Machine Chest Press", bodyPart: "Chest", workoutCategory: "Push", defaultSets: 3, defaultReps: "10-12", symbolName: "figure.strengthtraining.traditional", equipment: "Machine"),
        TrainingExerciseCatalogItem(id: "cable_fly", name: "Cable Fly", bodyPart: "Chest", workoutCategory: "Push", defaultSets: 2, defaultReps: "12-15", symbolName: "arrow.left.and.right", equipment: "Cable"),
        TrainingExerciseCatalogItem(id: "pec_deck", name: "Pec Deck", bodyPart: "Chest", workoutCategory: "Push", defaultSets: 3, defaultReps: "10-15", symbolName: "figure.strengthtraining.traditional", equipment: "Machine"),
        TrainingExerciseCatalogItem(id: "weighted_dip", name: "Weighted Dip", bodyPart: "Chest/Triceps", workoutCategory: "Push", defaultSets: 3, defaultReps: "6-10", symbolName: "figure.strengthtraining.traditional", equipment: "Bodyweight"),
        TrainingExerciseCatalogItem(id: "lat_pulldown", name: "Lat Pulldown", bodyPart: "Lats", workoutCategory: "Pull", defaultSets: 3, defaultReps: "8-12", symbolName: "arrow.down.to.line.compact", equipment: "Cable"),
        TrainingExerciseCatalogItem(id: "pull_up", name: "Pull-Up", bodyPart: "Lats", workoutCategory: "Pull", defaultSets: 3, defaultReps: "6-10", symbolName: "arrow.down.to.line.compact", equipment: "Bodyweight"),
        TrainingExerciseCatalogItem(id: "chest_supported_row", name: "Chest-Supported Row", bodyPart: "Upper Back", workoutCategory: "Pull", defaultSets: 3, defaultReps: "8-12", symbolName: "arrow.left.arrow.right", equipment: "Machine"),
        TrainingExerciseCatalogItem(id: "seated_cable_row", name: "Seated Cable Row", bodyPart: "Back", workoutCategory: "Pull", defaultSets: 3, defaultReps: "10-12", symbolName: "arrow.left.arrow.right", equipment: "Cable"),
        TrainingExerciseCatalogItem(id: "single_arm_db_row", name: "Single-Arm DB Row", bodyPart: "Back", workoutCategory: "Pull", defaultSets: 3, defaultReps: "8-12", symbolName: "dumbbell.fill", equipment: "Dumbbell"),
        TrainingExerciseCatalogItem(id: "back_squat", name: "Back Squat", bodyPart: "Quads", workoutCategory: "Legs", defaultSets: 3, defaultReps: "5-8", symbolName: "figure.strengthtraining.functional", equipment: "Barbell", rankingExerciseID: "squat"),
        TrainingExerciseCatalogItem(id: "conventional_deadlift", name: "Conventional Deadlift", bodyPart: "Hamstrings/Back", workoutCategory: "Pull/Legs", defaultSets: 3, defaultReps: "3-5", symbolName: "dumbbell.fill", equipment: "Barbell", rankingExerciseID: "deadlift"),
        TrainingExerciseCatalogItem(id: "sumo_deadlift", name: "Sumo Deadlift", bodyPart: "Glutes/Adductors", workoutCategory: "Pull/Legs", defaultSets: 3, defaultReps: "3-5", symbolName: "dumbbell.fill", equipment: "Barbell", rankingExerciseID: "deadlift"),
        TrainingExerciseCatalogItem(id: "barbell_overhead_press", name: "Barbell Overhead Press", bodyPart: "Shoulders", workoutCategory: "Push", defaultSets: 3, defaultReps: "5-8", symbolName: "arrow.up.circle.fill", equipment: "Barbell", rankingExerciseID: "press"),
        TrainingExerciseCatalogItem(id: "hack_squat", name: "Hack Squat", bodyPart: "Quads", workoutCategory: "Legs", defaultSets: 3, defaultReps: "8-10", symbolName: "figure.strengthtraining.functional", equipment: "Machine"),
        TrainingExerciseCatalogItem(id: "leg_press", name: "Leg Press", bodyPart: "Quads", workoutCategory: "Legs", defaultSets: 3, defaultReps: "10-12", symbolName: "figure.strengthtraining.functional", equipment: "Machine"),
        TrainingExerciseCatalogItem(id: "leg_extension", name: "Leg Extension", bodyPart: "Quads", workoutCategory: "Legs", defaultSets: 2, defaultReps: "12-15", symbolName: "figure.strengthtraining.functional", equipment: "Machine"),
        TrainingExerciseCatalogItem(id: "bulgarian_split_squat", name: "Bulgarian Split Squat", bodyPart: "Quads/Glutes", workoutCategory: "Legs", defaultSets: 3, defaultReps: "8-10", symbolName: "figure.strengthtraining.functional", equipment: "Dumbbell"),
        TrainingExerciseCatalogItem(id: "romanian_deadlift", name: "Romanian Deadlift", bodyPart: "Hamstrings", workoutCategory: "Pull/Legs", defaultSets: 3, defaultReps: "6-8", symbolName: "dumbbell.fill", equipment: "Barbell"),
        TrainingExerciseCatalogItem(id: "lying_leg_curl", name: "Lying Leg Curl", bodyPart: "Hamstrings", workoutCategory: "Legs", defaultSets: 3, defaultReps: "10-15", symbolName: "figure.strengthtraining.functional", equipment: "Machine"),
        TrainingExerciseCatalogItem(id: "seated_leg_curl", name: "Seated Leg Curl", bodyPart: "Hamstrings", workoutCategory: "Legs", defaultSets: 3, defaultReps: "10-15", symbolName: "figure.strengthtraining.functional", equipment: "Machine"),
        TrainingExerciseCatalogItem(id: "hip_thrust", name: "Hip Thrust", bodyPart: "Glutes", workoutCategory: "Legs", defaultSets: 3, defaultReps: "8-12", symbolName: "figure.strengthtraining.functional", equipment: "Barbell"),
        TrainingExerciseCatalogItem(id: "cable_kickback", name: "Cable Kickback", bodyPart: "Glutes", workoutCategory: "Legs", defaultSets: 2, defaultReps: "12-15", symbolName: "figure.strengthtraining.functional", equipment: "Cable"),
        TrainingExerciseCatalogItem(id: "machine_shoulder_press", name: "Machine Shoulder Press", bodyPart: "Shoulders", workoutCategory: "Push", defaultSets: 3, defaultReps: "8-10", symbolName: "arrow.up.circle.fill", equipment: "Machine"),
        TrainingExerciseCatalogItem(id: "db_shoulder_press", name: "DB Shoulder Press", bodyPart: "Shoulders", workoutCategory: "Push", defaultSets: 3, defaultReps: "8-10", symbolName: "arrow.up.circle.fill", equipment: "Dumbbell"),
        TrainingExerciseCatalogItem(id: "cable_lateral_raise", name: "Cable Lateral Raise", bodyPart: "Shoulders", workoutCategory: "Push", defaultSets: 3, defaultReps: "12-20", symbolName: "arrow.up.circle.fill", equipment: "Cable"),
        TrainingExerciseCatalogItem(id: "rear_delt_fly", name: "Rear Delt Fly", bodyPart: "Rear Delts", workoutCategory: "Pull", defaultSets: 3, defaultReps: "12-20", symbolName: "arrow.up.circle.fill", equipment: "Machine"),
        TrainingExerciseCatalogItem(id: "ez_bar_curl", name: "EZ-Bar Curl", bodyPart: "Biceps", workoutCategory: "Arms", defaultSets: 3, defaultReps: "8-12", symbolName: "dumbbell.fill", equipment: "Barbell"),
        TrainingExerciseCatalogItem(id: "incline_db_curl", name: "Incline DB Curl", bodyPart: "Biceps", workoutCategory: "Arms", defaultSets: 3, defaultReps: "10-12", symbolName: "dumbbell.fill", equipment: "Dumbbell"),
        TrainingExerciseCatalogItem(id: "triceps_pressdown", name: "Triceps Pressdown", bodyPart: "Triceps", workoutCategory: "Arms", defaultSets: 3, defaultReps: "10-15", symbolName: "dumbbell.fill", equipment: "Cable"),
        TrainingExerciseCatalogItem(id: "overhead_triceps_extension", name: "Overhead Triceps Extension", bodyPart: "Triceps", workoutCategory: "Arms", defaultSets: 3, defaultReps: "10-15", symbolName: "dumbbell.fill", equipment: "Cable"),
        TrainingExerciseCatalogItem(id: "cable_crunch", name: "Cable Crunch", bodyPart: "Core", workoutCategory: "Core", defaultSets: 3, defaultReps: "10-15", symbolName: "figure.core.training", equipment: "Cable"),
        TrainingExerciseCatalogItem(id: "hanging_leg_raise", name: "Hanging Leg Raise", bodyPart: "Core", workoutCategory: "Core", defaultSets: 3, defaultReps: "8-12", symbolName: "figure.core.training", equipment: "Bodyweight"),
        TrainingExerciseCatalogItem(id: "plank", name: "Plank", bodyPart: "Core", workoutCategory: "Core", defaultSets: 3, defaultReps: "30-60 sec", symbolName: "figure.core.training", equipment: "Bodyweight"),
        TrainingExerciseCatalogItem(id: "farmers_carry", name: "Farmer's Carry", bodyPart: "Full Body", workoutCategory: "Conditioning", defaultSets: 3, defaultReps: "30-60 sec", symbolName: "figure.strengthtraining.functional", equipment: "Dumbbell")
    ]

    static let maleWeightClasses = WeightClassCatalog.male
    static let femaleWeightClasses = WeightClassCatalog.female
    static var weightClasses: [WeightClass] { WeightClassCatalog.all }

    static let standardAgeGroups = [
        "Under 18", "18-24", "25-29", "30-34", "35-39", "40-44", "45-49",
        "50-54", "55-59", "60-64", "65-69", "70+"
    ]

    static let legacyAgeGroups = ["40-49", "50-59", "60+"]

    static let emptyProfile = UserProfile(
        id: UUID(),
        username: "",
        displayName: "",
        ageGroup: "",
        sexCategory: .open,
        heightInches: 0,
        bodyweightPounds: 0,
        preferredUnit: .pounds,
        city: "",
        state: "",
        primaryGymID: UUID(),
        primaryGymName: "",
        yearsExperience: 0,
        experienceLevel: .beginner,
        profileImageName: "person.crop.circle.fill",
        hideExactAge: false,
        hideBodyweight: false,
        hideCity: false,
        hideGym: false,
        hideLiftVideos: false
    )

    static let demoProfile = UserProfile(
        id: demoUserID,
        username: "",
        displayName: "",
        ageGroup: "",
        sexCategory: .male,
        heightInches: 0,
        bodyweightPounds: 0,
        preferredUnit: .pounds,
        city: "",
        state: "",
        primaryGymID: UUID(),
        primaryGymName: "",
        yearsExperience: 0,
        experienceLevel: .beginner,
        profileImageName: "person.crop.circle.fill",
        hideExactAge: false,
        hideBodyweight: false,
        hideCity: false,
        hideGym: false,
        hideLiftVideos: false
    )

    static let achievements: [Achievement] = [
        ("First Workout", "Finish your first workout.", "figure.strengthtraining.traditional"),
        ("2 Workouts", "Complete 2 workouts.", "calendar.badge.plus"),
        ("3 Workouts", "Build your first training rhythm.", "calendar.badge.checkmark"),
        ("5 Workouts", "Complete 5 workouts.", "calendar.circle"),
        ("10 Workouts", "Complete 10 workouts.", "checkmark.seal.fill"),
        ("25 Workouts", "Complete 25 workouts.", "flame.fill"),
        ("75 Workouts", "Complete 75 workouts.", "trophy.circle.fill"),
        ("50 Workouts", "Complete 50 workouts.", "trophy.fill"),
        ("100 Workouts", "Complete 100 workouts.", "crown.fill"),
        ("200 Workouts", "Complete 200 workouts.", "star.circle.fill"),
        ("300 Workouts", "Complete 300 workouts.", "star.square.fill"),
        ("500 Workouts", "Complete 500 workouts.", "crown.fill"),
        ("1,000 Workouts", "Complete 1,000 workouts.", "laurel.leading"),
        ("First Lift Logged", "Log your first ranked lift.", "plus.circle.fill"),
        ("3 Lifts Logged", "Log three ranked lifts.", "3.circle.fill"),
        ("10 Lifts Logged", "Log ten ranked lifts.", "10.circle"),
        ("First Verified Lift", "Record your first verified lift.", "video.badge.checkmark"),
        ("Five Verified Lifts", "Record five verified lifts.", "5.circle.fill"),
        ("Ten Verified Lifts", "Record ten verified lifts.", "10.circle.fill"),
        ("25 Verified Lifts", "Record twenty-five verified lifts.", "25.circle.fill"),
        ("50 Verified Lifts", "Record fifty verified lifts.", "checkmark.seal"),
        ("100 Verified Lifts", "Record one hundred verified lifts.", "checkmark.seal.fill"),
        ("First PR", "Set your first personal record.", "sparkles"),
        ("5 PRs", "Set five personal records.", "bolt.fill"),
        ("10 PRs", "Set ten personal records.", "bolt.circle.fill"),
        ("25 PRs", "Set twenty-five personal records.", "bolt.shield.fill"),
        ("50 PRs", "Set fifty personal records.", "bolt.badge.clock.fill"),
        ("100 PRs", "Set one hundred personal records.", "bolt.ring.closed"),
        ("1,000 Reps", "Complete 1,000 working-set reps.", "repeat.circle.fill"),
        ("5,000 Reps", "Complete 5,000 working-set reps.", "repeat.circle"),
        ("10,000 Reps", "Complete 10,000 working-set reps.", "infinity.circle.fill"),
        ("15,000 Reps", "Complete 15,000 working-set reps.", "repeat.circle.fill"),
        ("25,000 Reps", "Complete 25,000 working-set reps.", "infinity"),
        ("50,000 Reps", "Complete 50,000 working-set reps.", "repeat.1.circle.fill"),
        ("100,000 Reps", "Complete 100,000 working-set reps.", "repeat.1.circle"),
        ("10 Training Hours", "Accumulate 10 hours of training time.", "clock.fill"),
        ("50 Training Hours", "Accumulate 50 hours of training time.", "timer.circle.fill"),
        ("100 Training Hours", "Accumulate 100 hours of training time.", "hourglass.circle.fill"),
        ("150 Training Hours", "Accumulate 150 hours of training time.", "clock.badge"),
        ("250 Training Hours", "Accumulate 250 hours of training time.", "clock.badge.checkmark.fill"),
        ("500 Training Hours", "Accumulate 500 hours of training time.", "hourglass.bottomhalf.filled"),
        ("1,000 Training Hours", "Accumulate 1,000 hours of training time.", "hourglass.tophalf.filled"),
        ("135 Bench", "Bench press 135 lb.", "figure.strengthtraining.traditional"),
        ("185 Bench", "Bench press 185 lb.", "dumbbell.fill"),
        ("225 Bench", "Bench press 225 lb.", "medal.fill"),
        ("315 Bench", "Bench press 315 lb.", "shield.lefthalf.filled"),
        ("405 Bench", "Bench press 405 lb.", "shield.fill"),
        ("500 Bench", "Bench press 500 lb.", "figure.strengthtraining.traditional.circle.fill"),
        ("225 Squat", "Squat 225 lb.", "figure.strengthtraining.functional"),
        ("315 Squat", "Squat 315 lb.", "medal.fill"),
        ("405 Squat", "Squat 405 lb.", "trophy.fill"),
        ("500 Squat", "Squat 500 lb.", "figure.strengthtraining.functional.circle.fill"),
        ("600 Squat", "Squat 600 lb.", "mountain.2.circle.fill"),
        ("315 Deadlift", "Deadlift 315 lb.", "arrow.up.circle.fill"),
        ("405 Deadlift", "Deadlift 405 lb.", "trophy.fill"),
        ("500 Deadlift", "Deadlift 500 lb.", "mountain.2.fill"),
        ("600 Deadlift", "Deadlift 600 lb.", "arrow.up.circle"),
        ("700 Deadlift", "Deadlift 700 lb.", "mountain.2.circle"),
        ("500 lb Total", "Build a 500 lb bench, squat, and deadlift total.", "sum"),
        ("750 lb Total", "Build a 750 lb bench, squat, and deadlift total.", "chart.bar.fill"),
        ("1,000 lb Total", "Build a 1,000 lb bench, squat, and deadlift total.", "chart.line.uptrend.xyaxis"),
        ("1,250 lb Total", "Build a 1,250 lb bench, squat, and deadlift total.", "chart.bar.xaxis"),
        ("1,500 lb Total", "Build a 1,500 lb bench, squat, and deadlift total.", "chart.line.uptrend.xyaxis.circle.fill"),
        ("2,000 lb Total", "Build a 2,000 lb bench, squat, and deadlift total.", "chart.xyaxis.line"),
        ("Bodyweight Bench", "Bench press your bodyweight.", "person.crop.circle.badge.checkmark"),
        ("1.5x Bodyweight Bench", "Bench press one and a half times your bodyweight.", "person.crop.circle.badge.plus"),
        ("1.5x Bodyweight Squat", "Squat one and a half times your bodyweight.", "figure.run.circle.fill"),
        ("2x Bodyweight Squat", "Squat twice your bodyweight.", "figure.run.square.stack.fill"),
        ("2x Bodyweight Deadlift", "Deadlift twice your bodyweight.", "figure.strengthtraining.traditional.circle.fill"),
        ("2.5x Bodyweight Deadlift", "Deadlift two and a half times your bodyweight.", "figure.strengthtraining.traditional.circle"),
        ("Novice Rival", "Reach the Novice Rival Tier across squat, bench, and deadlift.", "medal"),
        ("Beginner Rival", "Reach the Beginner Rival Tier across squat, bench, and deadlift.", "medal.fill"),
        ("Intermediate Rival", "Reach the Intermediate Rival Tier across squat, bench, and deadlift.", "shield.lefthalf.filled"),
        ("Advanced Rival", "Reach the Advanced Rival Tier across squat, bench, and deadlift.", "shield.fill"),
        ("Elite Rival", "Reach the Elite Rival Tier across squat, bench, and deadlift.", "trophy.fill"),
        ("Legend Rival", "Reach the Legend Rival Tier across squat, bench, and deadlift.", "crown.fill"),
        ("Bodyweight Logged", "Log your first bodyweight entry.", "scalemass.fill"),
        ("4 Bodyweight Logs", "Log four bodyweight entries.", "calendar"),
        ("12 Bodyweight Logs", "Log twelve bodyweight entries.", "calendar.circle.fill"),
        ("18 Bodyweight Logs", "Log eighteen bodyweight entries.", "calendar.badge.exclamationmark"),
        ("26 Bodyweight Logs", "Log twenty-six bodyweight entries.", "calendar.badge.plus"),
        ("52 Bodyweight Logs", "Log fifty-two bodyweight entries.", "calendar.badge.clock"),
        ("3-Day Workout Streak", "Train three days in a row.", "flame.circle.fill"),
        ("7-Day Workout Streak", "Train seven days in a row.", "flame.fill"),
        ("14-Day Workout Streak", "Train fourteen days in a row.", "flame.circle"),
        ("30-Day Workout Streak", "Train thirty days in a row.", "30.circle.fill"),
        ("60-Day Workout Streak", "Train sixty days in a row.", "60.circle.fill"),
        ("90-Day Workout Streak", "Train ninety days in a row.", "calendar.badge.clock"),
        ("180-Day Workout Streak", "Train one hundred eighty days in a row.", "calendar.circle"),
        ("365-Day Workout Streak", "Train every day for a year.", "calendar.circle.fill"),
        ("10,000 kg Lifted Volume", "Move 10,000 kg of lifted working-set volume.", "gauge.with.dots.needle.67percent"),
        ("50,000 kg Lifted Volume", "Move 50,000 kg of lifted working-set volume.", "shippingbox.fill"),
        ("100,000 kg Lifted Volume", "Move 100,000 kg of lifted working-set volume.", "cube.box.fill"),
        ("250,000 kg Lifted Volume", "Move 250,000 kg of lifted working-set volume.", "building.columns.fill"),
        ("500,000 kg Lifted Volume", "Move 500,000 kg of lifted working-set volume.", "building.2.crop.circle.fill"),
        ("1,000,000 kg Lifted Volume", "Move 1,000,000 kg of lifted working-set volume.", "globe.americas.fill"),
        ("2,500,000 kg Lifted Volume", "Move 2,500,000 kg of lifted working-set volume.", "globe.americas"),
        ("5,000,000 kg Lifted Volume", "Move 5,000,000 kg of lifted working-set volume.", "globe"),
        ("Global Top 100", "Reach the global top 100.", "list.number"),
        ("Global Top 50", "Reach the global top 50.", "50.circle.fill"),
        ("Global Top 10", "Reach the global top 10.", "10.circle.fill"),
        ("Gym Top 10", "Reach a gym top 10.", "building.2.fill"),
        ("Gym Record Holder", "Hold a gym record.", "rosette"),
        ("Global Number One", "Reach number one globally.", "1.circle.fill"),
        ("90-Day Improvement Leader", "Lead improvement over a 90-day window.", "arrow.up.right.circle.fill"),
        ("Profile Complete", "Complete your profile details.", "person.crop.circle.fill.badge.checkmark")
    ].map { Achievement(id: UUID(), title: $0.0, description: $0.1, symbolName: $0.2) }

}
