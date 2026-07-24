import Foundation

enum MockData {
    static let demoGymID = UUID(uuidString: "C0000000-0000-0000-0000-000000000063")!
    static let demoUserID = UUID(uuidString: "20D85C0B-32F0-4144-8A0D-15D8820B3592")!
    static let defaultWorkoutPlanID = UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!
    static let generalStrengthCommunityID = UUID(uuidString: "B1000000-0000-0000-0000-000000000001")!
    static let powerliftingCommunityID = UUID(uuidString: "B1000000-0000-0000-0000-000000000002")!
    static let bodybuildingCommunityID = UUID(uuidString: "B1000000-0000-0000-0000-000000000003")!
    static let beginnerQuestionsCommunityID = UUID(uuidString: "B1000000-0000-0000-0000-000000000004")!
    static let formChecksCommunityID = UUID(uuidString: "B1000000-0000-0000-0000-000000000005")!
    static let programmingCommunityID = UUID(uuidString: "B1000000-0000-0000-0000-000000000006")!
    static let equipmentCommunityID = UUID(uuidString: "B1000000-0000-0000-0000-000000000007")!
    static let milestonesCommunityID = UUID(uuidString: "B1000000-0000-0000-0000-000000000008")!

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

    static let crunchGyms: [Gym] = [
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000001")!, name: "Crunch Fitness - Altamonte Springs", city: "Altamonte Springs", state: "Florida", memberCount: 180, verifiedLiftCount: 260),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000002")!, name: "Crunch Fitness - Apollo Beach", city: "Apollo Beach", state: "Florida", memberCount: 197, verifiedLiftCount: 291),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000003")!, name: "Crunch Fitness - Apopka", city: "Apopka", state: "Florida", memberCount: 214, verifiedLiftCount: 322),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000004")!, name: "Crunch Fitness - Belle Isle", city: "Orlando", state: "Florida", memberCount: 231, verifiedLiftCount: 353),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000005")!, name: "Crunch Fitness - Bloomingdale", city: "Valrico", state: "Florida", memberCount: 248, verifiedLiftCount: 384),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000006")!, name: "Crunch Fitness - Boy Scout", city: "Fort Myers", state: "Florida", memberCount: 265, verifiedLiftCount: 415),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000007")!, name: "Crunch Fitness - Bradenton", city: "Bradenton", state: "Florida", memberCount: 282, verifiedLiftCount: 446),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000008")!, name: "Crunch Fitness - Brandon", city: "Brandon", state: "Florida", memberCount: 299, verifiedLiftCount: 477),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000009")!, name: "Crunch Fitness - Cape Coral", city: "Cape Coral", state: "Florida", memberCount: 316, verifiedLiftCount: 508),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000010")!, name: "Crunch Fitness - Carrollwood", city: "Tampa", state: "Florida", memberCount: 193, verifiedLiftCount: 539),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000011")!, name: "Crunch Fitness - Casselberry", city: "Casselberry", state: "Florida", memberCount: 210, verifiedLiftCount: 570),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000012")!, name: "Crunch Fitness - Channelside", city: "Tampa", state: "Florida", memberCount: 227, verifiedLiftCount: 601),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000013")!, name: "Crunch Fitness - Clermont", city: "Clermont", state: "Florida", memberCount: 244, verifiedLiftCount: 632),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000014")!, name: "Crunch Fitness - Coral Ridge", city: "Coral Springs", state: "Florida", memberCount: 261, verifiedLiftCount: 663),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000015")!, name: "Crunch Fitness - Coral Springs", city: "Coral Springs", state: "Florida", memberCount: 278, verifiedLiftCount: 694),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000016")!, name: "Crunch Fitness - Countryside", city: "Clearwater", state: "Florida", memberCount: 295, verifiedLiftCount: 725),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000017")!, name: "Crunch Fitness - Cutler Bay", city: "Cutler Bay", state: "Florida", memberCount: 312, verifiedLiftCount: 756),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000018")!, name: "Crunch Fitness - Daytona Beach", city: "Daytona Beach", state: "Florida", memberCount: 189, verifiedLiftCount: 267),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000019")!, name: "Crunch Fitness - Deltona", city: "Deltona", state: "Florida", memberCount: 206, verifiedLiftCount: 298),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000020")!, name: "Crunch Fitness - Doral", city: "Miami", state: "Florida", memberCount: 223, verifiedLiftCount: 329),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000021")!, name: "Crunch Fitness - Dr. Phillips", city: "Orlando", state: "Florida", memberCount: 240, verifiedLiftCount: 360),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000022")!, name: "Crunch Fitness - East Colonial", city: "Orlando", state: "Florida", memberCount: 257, verifiedLiftCount: 391),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000023")!, name: "Crunch Fitness - East Sarasota", city: "Sarasota", state: "Florida", memberCount: 274, verifiedLiftCount: 422),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000024")!, name: "Crunch Fitness - Fort Myers", city: "Fort Myers", state: "Florida", memberCount: 291, verifiedLiftCount: 453),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000025")!, name: "Crunch Fitness - Gainesville", city: "Gainesville", state: "Florida", memberCount: 308, verifiedLiftCount: 484),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000026")!, name: "Crunch Fitness - Greenacres", city: "Greenacres", state: "Florida", memberCount: 185, verifiedLiftCount: 515),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000027")!, name: "Crunch Fitness - Haines City", city: "Haines City", state: "Florida", memberCount: 202, verifiedLiftCount: 546),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000028")!, name: "Crunch Fitness - Hallandale", city: "Hallandale Beach", state: "Florida", memberCount: 219, verifiedLiftCount: 577),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000029")!, name: "Crunch Fitness - Harbour Village", city: "Jacksonville", state: "Florida", memberCount: 236, verifiedLiftCount: 608),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000030")!, name: "Crunch Fitness - Hillsborough", city: "Tampa", state: "Florida", memberCount: 253, verifiedLiftCount: 639),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000031")!, name: "Crunch Fitness - Homestead", city: "Homestead", state: "Florida", memberCount: 270, verifiedLiftCount: 670),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000032")!, name: "Crunch Fitness - Kirkman", city: "Orlando", state: "Florida", memberCount: 287, verifiedLiftCount: 701),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000033")!, name: "Crunch Fitness - Kissimmee", city: "Kissimmee", state: "Florida", memberCount: 304, verifiedLiftCount: 732),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000034")!, name: "Crunch Fitness - Kissimmee West", city: "Kissimmee", state: "Florida", memberCount: 181, verifiedLiftCount: 763),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000035")!, name: "Crunch Fitness - Lake Mary", city: "Lake Mary", state: "Florida", memberCount: 198, verifiedLiftCount: 274),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000036")!, name: "Crunch Fitness - Lake Nona", city: "Orlando", state: "Florida", memberCount: 215, verifiedLiftCount: 305),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000037")!, name: "Crunch Fitness - Lake Worth", city: "Lake Worth", state: "Florida", memberCount: 232, verifiedLiftCount: 336),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000038")!, name: "Crunch Fitness - Lakeland", city: "Lakeland", state: "Florida", memberCount: 249, verifiedLiftCount: 367),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000039")!, name: "Crunch Fitness - Lakewood Ranch", city: "Bradenton", state: "Florida", memberCount: 266, verifiedLiftCount: 398),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000040")!, name: "Crunch Fitness - Land O'Lakes", city: "Land O' Lakes", state: "Florida", memberCount: 283, verifiedLiftCount: 429),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000041")!, name: "Crunch Fitness - Maitland", city: "Maitland", state: "Florida", memberCount: 300, verifiedLiftCount: 460),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000042")!, name: "Crunch Fitness - Miami Gardens", city: "Miami Gardens", state: "Florida", memberCount: 317, verifiedLiftCount: 491),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000043")!, name: "Crunch Fitness - Naples", city: "Naples", state: "Florida", memberCount: 194, verifiedLiftCount: 522),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000044")!, name: "Crunch Fitness - Oakland Park", city: "Oakland Park", state: "Florida", memberCount: 211, verifiedLiftCount: 553),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000045")!, name: "Crunch Fitness - Ocoee", city: "Ocoee", state: "Florida", memberCount: 228, verifiedLiftCount: 584),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000046")!, name: "Crunch Fitness - Orange Park", city: "Orange Park", state: "Florida", memberCount: 245, verifiedLiftCount: 615),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000047")!, name: "Crunch Fitness - Orlando Park", city: "Orlando", state: "Florida", memberCount: 262, verifiedLiftCount: 646),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000048")!, name: "Crunch Fitness - Palm Beach Gardens", city: "Palm Beach Gardens", state: "Florida", memberCount: 279, verifiedLiftCount: 677),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000049")!, name: "Crunch Fitness - Palm Harbor", city: "Palm Harbor", state: "Florida", memberCount: 296, verifiedLiftCount: 708),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000050")!, name: "Crunch Fitness - Parrish", city: "Parrish", state: "Florida", memberCount: 313, verifiedLiftCount: 739),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000051")!, name: "Crunch Fitness - Pembroke Pines", city: "Pembroke Pines", state: "Florida", memberCount: 190, verifiedLiftCount: 770),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000052")!, name: "Crunch Fitness - Pensacola", city: "Pensacola", state: "Florida", memberCount: 207, verifiedLiftCount: 281),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000053")!, name: "Crunch Fitness - Plantation", city: "Plantation", state: "Florida", memberCount: 224, verifiedLiftCount: 312),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000054")!, name: "Crunch Fitness - Poinciana", city: "Kissimmee", state: "Florida", memberCount: 241, verifiedLiftCount: 343),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000055")!, name: "Crunch Fitness - Pompano Beach", city: "Pompano Beach", state: "Florida", memberCount: 258, verifiedLiftCount: 374),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000056")!, name: "Crunch Fitness - Port St. Lucie", city: "Port St. Lucie", state: "Florida", memberCount: 275, verifiedLiftCount: 405),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000057")!, name: "Crunch Fitness - Regency Park", city: "Jacksonville", state: "Florida", memberCount: 292, verifiedLiftCount: 436),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000058")!, name: "Crunch Fitness - Riverview", city: "Riverview", state: "Florida", memberCount: 309, verifiedLiftCount: 467),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000059")!, name: "Crunch Fitness - Sarasota Bee Ridge", city: "Sarasota", state: "Florida", memberCount: 186, verifiedLiftCount: 498),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000060")!, name: "Crunch Fitness - Sarasota University", city: "Sarasota", state: "Florida", memberCount: 203, verifiedLiftCount: 529),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000061")!, name: "Crunch Fitness - Seminole", city: "Seminole", state: "Florida", memberCount: 220, verifiedLiftCount: 560),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000062")!, name: "Crunch Fitness - Six Mile", city: "Fort Myers", state: "Florida", memberCount: 237, verifiedLiftCount: 591),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000063")!, name: "Crunch Fitness - South Beach", city: "Miami Beach", state: "Florida", memberCount: 254, verifiedLiftCount: 622),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000064")!, name: "Crunch Fitness - South Tampa", city: "Tampa", state: "Florida", memberCount: 271, verifiedLiftCount: 653),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000065")!, name: "Crunch Fitness - St Cloud FL", city: "St. Cloud", state: "Florida", memberCount: 288, verifiedLiftCount: 684),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000066")!, name: "Crunch Fitness - St. Pete Northeast", city: "St Petersburg", state: "Florida", memberCount: 305, verifiedLiftCount: 715),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000067")!, name: "Crunch Fitness - Stuart", city: "Stuart", state: "Florida", memberCount: 182, verifiedLiftCount: 746),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000068")!, name: "Crunch Fitness - Sunrise", city: "Sunrise", state: "Florida", memberCount: 199, verifiedLiftCount: 777),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000069")!, name: "Crunch Fitness - Tallahassee", city: "Tallahassee", state: "Florida", memberCount: 216, verifiedLiftCount: 288),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000070")!, name: "Crunch Fitness - Tamarac", city: "Tamarac", state: "Florida", memberCount: 233, verifiedLiftCount: 319),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000071")!, name: "Crunch Fitness - Tampa Palms", city: "Tampa", state: "Florida", memberCount: 250, verifiedLiftCount: 350),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000072")!, name: "Crunch Fitness - Trinity", city: "New Port Richey", state: "Florida", memberCount: 267, verifiedLiftCount: 381),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000073")!, name: "Crunch Fitness - Tyrone", city: "St. Petersburg", state: "Florida", memberCount: 284, verifiedLiftCount: 412),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000074")!, name: "Crunch Fitness - Wellington", city: "Wellington", state: "Florida", memberCount: 301, verifiedLiftCount: 443),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000075")!, name: "Crunch Fitness - Wesley Chapel", city: "Wesley Chapel", state: "Florida", memberCount: 318, verifiedLiftCount: 474),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000076")!, name: "Crunch Fitness - West Melbourne", city: "Melbourne", state: "Florida", memberCount: 195, verifiedLiftCount: 505),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000077")!, name: "Crunch Fitness - West Pembroke", city: "Pembroke Pines", state: "Florida", memberCount: 212, verifiedLiftCount: 536),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000078")!, name: "Crunch Fitness - Wickham", city: "Melbourne", state: "Florida", memberCount: 229, verifiedLiftCount: 567),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000079")!, name: "Crunch Fitness - Winter Garden", city: "Winter Garden", state: "Florida", memberCount: 246, verifiedLiftCount: 598),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000080")!, name: "Crunch Fitness - Winter Park", city: "Winter Park", state: "Florida", memberCount: 263, verifiedLiftCount: 629),
        Gym(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000081")!, name: "Crunch Fitness - Winter Springs", city: "Winter Springs", state: "Florida", memberCount: 280, verifiedLiftCount: 660)
    ]

    static var gyms: [Gym] { crunchGyms }

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
        followers: 0,
        following: 0,
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
        followers: 0,
        following: 0,
        hideExactAge: false,
        hideBodyweight: false,
        hideCity: false,
        hideGym: false,
        hideLiftVideos: false
    )

    static let challenges: [Challenge] = []

    static func communityThreads(for _: [Challenge]) -> [CommunityThread] {
        []
    }

    static func forumSeed(
        profiles: [UserProfile],
        lifts: [LiftSubmission],
        legacyThreads: [CommunityThread]
    ) -> ForumPersistenceSnapshot {
        return ForumPersistenceSnapshot(
            schemaVersion: ForumPersistenceSnapshot.currentVersion,
            communities: [],
            memberships: [],
            posts: [],
            comments: [],
            joinRequests: [],
            reports: [],
            moderationActions: [],
            notifications: [],
            globalStaffUserIDs: []
        )
    }

    static func social(profiles: [UserProfile]) -> (friendRequests: [FriendRequest], messageThreads: [DirectMessageThread], messages: [DirectMessage]) {
        ([], [], [])
    }

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
        ("500 Workouts", "Complete 500 workouts.", "crown.circle.fill"),
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
        ("10,000 kg Volume", "Move 10,000 kg of working-set volume.", "gauge.with.dots.needle.67percent"),
        ("50,000 kg Volume", "Move 50,000 kg of working-set volume.", "shippingbox.fill"),
        ("100,000 kg Volume", "Move 100,000 kg of working-set volume.", "cube.box.fill"),
        ("250,000 kg Volume", "Move 250,000 kg of working-set volume.", "building.columns.fill"),
        ("500,000 kg Volume", "Move 500,000 kg of working-set volume.", "building.2.crop.circle.fill"),
        ("1,000,000 kg Volume", "Move 1,000,000 kg of working-set volume.", "globe.americas.fill"),
        ("2,500,000 kg Volume", "Move 2,500,000 kg of working-set volume.", "globe.americas"),
        ("5,000,000 kg Volume", "Move 5,000,000 kg of working-set volume.", "globe"),
        ("Global Top 100", "Reach the global top 100.", "list.number"),
        ("Global Top 50", "Reach the global top 50.", "50.circle.fill"),
        ("Global Top 10", "Reach the global top 10.", "10.circle.fill"),
        ("Gym Top 10", "Reach a gym top 10.", "building.2.fill"),
        ("Gym Record Holder", "Hold a gym record.", "rosette"),
        ("Global Number One", "Reach number one globally.", "1.circle.fill"),
        ("90-Day Improvement Leader", "Lead improvement over a 90-day window.", "arrow.up.right.circle.fill"),
        ("Profile Complete", "Complete your profile details.", "person.crop.circle.fill.badge.checkmark")
    ].map { Achievement(id: UUID(), title: $0.0, description: $0.1, symbolName: $0.2) }

    static let workoutPlans: [WorkoutPlan] = []

    static var workoutEntries: [WorkoutExerciseEntry] {
        []
    }

    static var bodyweightEntries: [BodyweightEntry] {
        []
    }

    static func community() -> (profiles: [UserProfile], lifts: [LiftSubmission], activities: [ActivityItem]) {
        ([], [], [])
    }
}
