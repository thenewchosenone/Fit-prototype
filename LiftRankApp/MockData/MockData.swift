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
            enriched.difficulty = difficulty(for: item)
            enriched.demonstrationMediaID = item.demonstrationMediaID ?? demonstrationMediaID(for: enriched.movementPattern)
            return enriched
        }
    }

    private static func exerciseAliases(for exercise: TrainingExerciseCatalogItem) -> [String] {
        switch exercise.id {
        case "machine_chest_press":
            [
                "Seated Chest Press",
                "Chest Press Machine",
                "Hammer Strength Chest Press",
                "Plate Loaded Chest Press",
                "Selectorized Chest Press",
                "Machine Press"
            ]
        case "leg_press":
            ["45 Degree Leg Press", "Linear Leg Press", "Plate Loaded Leg Press"]
        case "hack_squat":
            ["Hack Press", "Machine Hack Squat"]
        case "chest_supported_row":
            ["Supported Row", "Chest Supported Machine Row", "Hammer Strength Row"]
        default:
            []
        }
    }

    private static func movementPattern(for exercise: TrainingExerciseCatalogItem) -> ExerciseMovementPattern {
        let name = exercise.name.lowercased()
        if name.contains("bench") || name.contains("chest press") || name.contains("pec deck") || name.contains("dip") || name.contains("fly") {
            return .horizontalPress
        }
        if name.contains("overhead") || name.contains("shoulder press") {
            return .verticalPress
        }
        if name.contains("row") {
            return .horizontalPull
        }
        if name.contains("pulldown") || name.contains("pull-up") || name.contains("pullover") {
            return .verticalPull
        }
        if name.contains("squat") || name.contains("leg press") || name.contains("leg extension") {
            return .squat
        }
        if name.contains("deadlift") || name.contains("hinge") || name.contains("hip thrust") {
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
        if name.contains("lateral raise") || name.contains("rear delt") {
            return .shoulderIsolation
        }
        if name.contains("calf") || name.contains("tibialis") {
            return .calf
        }
        if name.contains("crunch") || name.contains("plank") || name.contains("leg raise") {
            return .core
        }
        if name.contains("carry") {
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

    private static func demonstrationMediaID(for pattern: ExerciseMovementPattern) -> String {
        switch pattern {
        case .horizontalPress: "demo-horizontal-press"
        case .verticalPress: "demo-vertical-press"
        case .horizontalPull: "demo-horizontal-pull"
        case .verticalPull: "demo-vertical-pull"
        case .squat: "demo-squat"
        case .hinge: "demo-hinge"
        case .lunge: "demo-lunge"
        case .curl: "demo-curl"
        case .elbowExtension: "demo-extension"
        case .shoulderIsolation: "demo-shoulder"
        case .calf: "demo-calf"
        case .core: "demo-core"
        case .carry: "demo-carry"
        case .other: "demo-general"
        }
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

    static let maleWeightClasses: [WeightClass] = usaplClasses(
        sex: .male,
        prefix: "usapl-m",
        limits: [52, 56, 60, 67.5, 75, 82.5, 90, 100, 110, 125, 140]
    )

    static let femaleWeightClasses: [WeightClass] = usaplClasses(
        sex: .female,
        prefix: "usapl-f",
        limits: [44, 48, 52, 56, 60, 65, 70, 75, 82.5, 90, 100]
    )

    static var weightClasses: [WeightClass] { maleWeightClasses + femaleWeightClasses }

    static let standardAgeGroups = [
        "Under 18", "18-24", "25-29", "30-34", "35-39", "40-44", "45-49",
        "50-54", "55-59", "60-64", "65-69", "70+"
    ]

    static let legacyAgeGroups = ["40-49", "50-59", "60+"]

    private static func usaplClasses(sex: SexCategory, prefix: String, limits: [Double]) -> [WeightClass] {
        var previous: Double?
        var classes = limits.map { limit in
            defer { previous = limit }
            return WeightClass(
                id: "\(prefix)-\(RankingCalculator.format(limit))",
                sexCategory: sex,
                name: "\(RankingCalculator.format(limit)) kg",
                minKilograms: previous,
                maxKilograms: limit
            )
        }
        if let finalLimit = limits.last {
            classes.append(
                WeightClass(
                    id: "\(prefix)-\(RankingCalculator.format(finalLimit))-plus",
                    sexCategory: sex,
                    name: "\(RankingCalculator.format(finalLimit))+ kg",
                    minKilograms: finalLimit,
                    maxKilograms: nil
                )
            )
        }
        return classes
    }

    static let demoProfile = UserProfile(
        id: demoUserID,
        username: "rjrob23",
        displayName: "Robert",
        ageGroup: "30-34",
        sexCategory: .male,
        heightInches: 72,
        bodyweightPounds: 210,
        preferredUnit: .pounds,
        city: "Miami",
        state: "Florida",
        primaryGymID: demoGymID,
        primaryGymName: "Crunch Fitness - South Beach",
        yearsExperience: 7,
        experienceLevel: .advanced,
        profileImageName: "person.crop.circle.fill",
        followers: 348,
        following: 92,
        hideExactAge: false,
        hideBodyweight: false,
        hideCity: false,
        hideGym: false,
        hideLiftVideos: false
    )

    static let challenges: [Challenge] = [
        Challenge(id: UUID(), title: "Add 25 to your squat", description: "Build your squat over the next 90 days.", startDate: .now, endDate: .now.addingTimeInterval(60 * 60 * 24 * 90), goal: "+25 lb squat", eligibility: "All lifters", participantCount: 148, progress: 0.42, isJoined: false),
        Challenge(id: UUID(), title: "Bench your bodyweight", description: "Log a bodyweight bench press.", startDate: .now, endDate: .now.addingTimeInterval(60 * 60 * 24 * 45), goal: "1.0x bench", eligibility: "Public profile", participantCount: 302, progress: 0.74, isJoined: false),
        Challenge(id: UUID(), title: "Deadlift twice bodyweight", description: "Pull 2.0x bodyweight or better.", startDate: .now, endDate: .now.addingTimeInterval(60 * 60 * 24 * 120), goal: "2.0x deadlift", eligibility: "Video required", participantCount: 211, progress: 1.0, isJoined: true),
        Challenge(id: UUID(), title: "Eight training weeks", description: "Submit activity across eight weeks.", startDate: .now, endDate: .now.addingTimeInterval(60 * 60 * 24 * 56), goal: "8 active weeks", eligibility: "All lifters", participantCount: 96, progress: 0.25, isJoined: false),
        Challenge(id: UUID(), title: "Three verified PRs", description: "Set three video-verified PRs this month.", startDate: .now, endDate: .now.addingTimeInterval(60 * 60 * 24 * 30), goal: "3 verified PRs", eligibility: "Video required", participantCount: 87, progress: 0.33, isJoined: false)
    ]

    static func communityThreads(for _: [Challenge]) -> [CommunityThread] {
        [
            CommunityThread(id: UUID(), title: "Best angle for deadlift verification?", body: "What camera angle has worked best for getting pulls approved quickly?", authorID: demoUserID, authorName: "Robert", kind: .general, challengeID: nil, gymID: nil, replyCount: 12, likeCount: 34, createdAt: .now.addingTimeInterval(-3_600)),
            CommunityThread(id: UUID(), title: "Miami lifters checking in", body: "Post your next gym day and main lift.", authorID: demoUserID, authorName: "Robert", kind: .gym, challengeID: nil, gymID: demoGymID, replyCount: 8, likeCount: 21, createdAt: .now.addingTimeInterval(-8_600))
        ]
    }

    static func forumSeed(
        profiles: [UserProfile],
        lifts: [LiftSubmission],
        legacyThreads: [CommunityThread]
    ) -> ForumPersistenceSnapshot {
        let communitySpecs: [(UUID, String, String, String, String, String, String, [String], [String], Int)] = [
            (generalStrengthCommunityID, "general-strength", "General Strength", "Training, technique, and strength culture.", "The main room for strength athletes across every discipline.", "General", "bolt.fill", ["Keep advice constructive and evidence-aware.", "No harassment or spam."], ["Discussion", "Question", "News"], 8_420),
            (powerliftingCommunityID, "powerlifting", "Powerlifting", "Squat, bench, deadlift, and meet preparation.", "Programming, technique, federation rules, and platform-day discussion.", "Strength Sports", "figure.strengthtraining.traditional", ["State whether advice is tested or personal experience.", "Use Form Checks for detailed video review."], ["Meet Prep", "Technique", "Programming"], 6_180),
            (bodybuildingCommunityID, "bodybuilding", "Bodybuilding", "Hypertrophy, physique development, and posing.", "Discuss training volume, exercise selection, weak points, and contest preparation.", "Strength Sports", "figure.strengthtraining.functional", ["Critique physiques respectfully.", "Do not promote dangerous drug protocols."], ["Hypertrophy", "Exercise Selection", "Prep"], 5_760),
            (beginnerQuestionsCommunityID, "beginner-questions", "Beginner Questions", "A welcoming place to learn the fundamentals.", "No question is too basic. Experienced members should explain the why, not just the answer.", "Help", "questionmark.bubble.fill", ["Be patient and specific.", "Medical emergencies require a professional."], ["Getting Started", "Technique", "Routine Help"], 4_230),
            (formChecksCommunityID, "form-checks", "Form Checks", "Get constructive feedback on lifting technique.", "Post a clear angle, the load and reps, and what you want reviewers to inspect.", "Help", "video.fill", ["Critique the lift, never the lifter.", "Do not diagnose injuries."], ["Squat", "Bench", "Deadlift", "Other"], 3_980),
            (programmingCommunityID, "programming", "Programming", "Periodization, progression, fatigue, and exercise order.", "Compare templates and build training blocks that match goals and recovery.", "Training", "calendar.badge.clock", ["Include training age and schedule when requesting help.", "Credit coaches and original program authors."], ["Program Review", "Progression", "Deload"], 4_610),
            (equipmentCommunityID, "equipment", "Equipment", "Machines, bars, racks, shoes, and home gyms.", "Identify equipment, compare setups, and discuss how machines differ between brands.", "Equipment", "wrench.and.screwdriver.fill", ["Disclose affiliate relationships.", "Keep marketplace spam out of discussions."], ["Machine", "Home Gym", "Gear"], 2_940),
            (milestonesCommunityID, "prs-milestones", "PRs & Milestones", "Celebrate progress without turning the feed into noise.", "Share meaningful personal records, comeback lifts, consistency wins, and competition results.", "Achievements", "trophy.fill", ["All levels and loads are welcome.", "Verification claims must match the linked lift status."], ["PR", "Comeback", "Competition"], 7_110)
        ]

        var communities = communitySpecs.map { spec in
            ForumCommunity(
                id: spec.0,
                slug: spec.1,
                name: spec.2,
                summary: spec.3,
                details: spec.4,
                category: spec.5,
                symbolName: spec.6,
                accentHex: "3568FF",
                visibility: .publicOpen,
                rules: spec.7,
                availableTags: spec.8,
                staffOwnerID: demoUserID,
                memberCount: spec.9,
                postCount: 0,
                createdAt: .now.addingTimeInterval(-86_400 * 180),
                archivedAt: nil
            )
        }

        var memberships: [ForumMembership] = []
        let joinedIDs = [generalStrengthCommunityID, powerliftingCommunityID, milestonesCommunityID]
        for communityID in joinedIDs {
            memberships.append(ForumMembership(
                id: UUID(),
                communityID: communityID,
                userID: demoUserID,
                role: .member,
                status: .joined,
                notificationLevel: .mentions,
                joinedAt: .now.addingTimeInterval(-86_400 * 60),
                mutedUntil: nil,
                bannedAt: nil,
                restrictionReason: nil,
                invitedBy: nil
            ))
        }

        for (index, community) in communities.enumerated() {
            guard profiles.count > index + 1 else { continue }
            let moderator = profiles[index + 1]
            memberships.append(ForumMembership(
                id: UUID(),
                communityID: community.id,
                userID: moderator.id,
                role: .moderator,
                status: .joined,
                notificationLevel: .all,
                joinedAt: .now.addingTimeInterval(-86_400 * 120),
                mutedUntil: nil,
                bannedAt: nil,
                restrictionReason: nil,
                invitedBy: demoUserID
            ))
        }

        let postSeeds: [(UUID, Int, String, String, String, ForumPostKind)] = [
            (generalStrengthCommunityID, 1, "What finally made your training consistent?", "For me it was cutting the plan down to four repeatable days instead of chasing a perfect six-day split.", "Discussion", .discussion),
            (powerliftingCommunityID, 2, "Peaking: when do you take your final heavy deadlift?", "I respond better with ten days between my final heavy pull and meet day. Curious how other lifters structure it.", "Meet Prep", .discussion),
            (bodybuildingCommunityID, 3, "Choosing a stable row for upper-back volume", "Chest-supported machines have made progression easier, but the resistance curves vary wildly. Which setup do you prefer?", "Exercise Selection", .discussion),
            (beginnerQuestionsCommunityID, 4, "How should I choose my starting weights?", "I can complete every prescribed rep, but I am unsure how many reps I should have left in reserve during week one.", "Getting Started", .discussion),
            (formChecksCommunityID, 5, "Squat depth and bar path check", "Working on staying balanced over mid-foot. What would you change first?", "Squat", .discussion),
            (programmingCommunityID, 6, "When does a deload actually help you?", "Do you schedule deloads in advance or wait for performance and recovery markers to decline?", "Deload", .poll),
            (equipmentCommunityID, 7, "Generic name for this iso-lateral row?", "Different gyms use Hammer Strength, Arsenal, and other brands for nearly identical plate-loaded rows. How should we label them in the library?", "Machine", .discussion),
            (milestonesCommunityID, 8, "First 500 lb deadlift after rebuilding my setup", "The biggest change was treating every warmup rep like the top set. Happy to finally cross this milestone.", "PR", .liftShare)
        ]

        var posts: [ForumPost] = postSeeds.compactMap { seed in
            guard profiles.count > seed.1 else { return nil }
            let author = profiles[seed.1]
            let poll: ForumPoll? = seed.5 == .poll ? ForumPoll(
                id: UUID(),
                options: ["Scheduled every 4–6 weeks", "Based on performance", "Only before a meet", "I do not deload"].map {
                    ForumPollOption(id: UUID(), text: $0, voterIDs: [])
                },
                closesAt: .now.addingTimeInterval(86_400 * 7)
            ) : nil
            return ForumPost(
                id: UUID(),
                destination: .community(seed.0),
                authorID: author.id,
                authorName: author.displayName,
                kind: seed.5,
                title: seed.2,
                body: seed.3,
                tag: seed.4,
                attachments: [],
                poll: poll,
                liftID: seed.5 == .liftShare ? lifts.first(where: { $0.userID == demoUserID })?.id : nil,
                workoutID: nil,
                linkURL: nil,
                challengeID: nil,
                createdAt: .now.addingTimeInterval(TimeInterval(-seed.1 * 5_400)),
                editedAt: nil,
                commentCount: 0,
                votes: [:],
                savedByUserIDs: [],
                watchedByUserIDs: [],
                isPinned: seed.1 == 1,
                isLocked: false,
                removedAt: nil,
                removalReason: nil
            )
        }

        for thread in legacyThreads {
            let destination: ForumDestination = thread.kind == .gym && thread.gymID != nil
                ? .gym(thread.gymID!)
                : .community(generalStrengthCommunityID)
            posts.append(ForumPost(
                id: thread.id,
                destination: destination,
                authorID: thread.authorID,
                authorName: thread.authorName,
                kind: .discussion,
                title: thread.title,
                body: thread.body,
                tag: thread.kind == .challenge ? "Challenge" : "Discussion",
                attachments: [],
                poll: nil,
                liftID: nil,
                workoutID: nil,
                linkURL: nil,
                challengeID: thread.challengeID,
                createdAt: thread.createdAt,
                editedAt: nil,
                commentCount: 0,
                votes: thread.votes,
                savedByUserIDs: [],
                watchedByUserIDs: [],
                isPinned: false,
                isLocked: thread.isLocked,
                removedAt: thread.removedAt,
                removalReason: thread.removalReason
            ))
        }

        var comments: [ForumComment] = []
        for (index, post) in posts.enumerated() where post.destination.communityID != nil && profiles.count > index + 10 {
            let author = profiles[index + 10]
            comments.append(ForumComment(
                id: UUID(),
                postID: post.id,
                parentCommentID: nil,
                authorID: author.id,
                authorName: author.displayName,
                body: index.isMultiple(of: 2) ? "This matches what I have seen in my own training." : "Good question. The training context matters more than a universal rule here.",
                createdAt: post.createdAt.addingTimeInterval(1_800),
                editedAt: nil,
                votes: [:],
                removedAt: nil,
                removalReason: nil
            ))
        }

        for index in posts.indices {
            posts[index].commentCount = comments.filter { $0.postID == posts[index].id }.count
            if let communityID = posts[index].destination.communityID,
               let communityIndex = communities.firstIndex(where: { $0.id == communityID }) {
                communities[communityIndex].postCount += 1
            }
        }

        return ForumPersistenceSnapshot(
            schemaVersion: ForumPersistenceSnapshot.currentVersion,
            communities: communities,
            memberships: memberships,
            posts: posts,
            comments: comments,
            joinRequests: [],
            reports: [],
            moderationActions: [],
            notifications: [
                ForumNotification(
                    id: UUID(),
                    userID: demoUserID,
                    actorID: profiles.dropFirst().first?.id,
                    kind: .mention,
                    title: "You were mentioned in Powerlifting",
                    message: "A lifter asked about your meet-day setup.",
                    communityID: powerliftingCommunityID,
                    postID: posts.first(where: { $0.destination.communityID == powerliftingCommunityID })?.id,
                    commentID: nil,
                    createdAt: .now.addingTimeInterval(-3_600),
                    isRead: false
                )
            ],
            globalStaffUserIDs: [demoUserID]
        )
    }

    static func social(profiles: [UserProfile]) -> (friendRequests: [FriendRequest], messageThreads: [DirectMessageThread], messages: [DirectMessage]) {
        guard profiles.count > 4 else { return ([], [], []) }
        let currentUserID = demoUserID
        let incomingSender = profiles[1]
        let acceptedFriend = profiles[2]
        let outgoingRecipient = profiles[3]
        let messageOnlyProfile = profiles[4]
        let now = Date()

        let acceptedAt = now.addingTimeInterval(-20_000)
        let friendRequests = [
            FriendRequest(
                id: UUID(),
                fromUserID: incomingSender.id,
                toUserID: currentUserID,
                status: .pending,
                createdAt: now.addingTimeInterval(-3_900),
                respondedAt: nil
            ),
            FriendRequest(
                id: UUID(),
                fromUserID: currentUserID,
                toUserID: outgoingRecipient.id,
                status: .pending,
                createdAt: now.addingTimeInterval(-7_200),
                respondedAt: nil
            ),
            FriendRequest(
                id: UUID(),
                fromUserID: acceptedFriend.id,
                toUserID: currentUserID,
                status: .accepted,
                createdAt: now.addingTimeInterval(-86_000),
                respondedAt: acceptedAt
            )
        ]

        let friendThreadID = UUID()
        let messageOnlyThreadID = UUID()
        let messageThreads = [
            DirectMessageThread(id: friendThreadID, participantIDs: [currentUserID, acceptedFriend.id], createdAt: acceptedAt, updatedAt: now.addingTimeInterval(-1_200)),
            DirectMessageThread(id: messageOnlyThreadID, participantIDs: [currentUserID, messageOnlyProfile.id], createdAt: now.addingTimeInterval(-15_000), updatedAt: now.addingTimeInterval(-4_800))
        ]
        let messages = [
            DirectMessage(id: UUID(), threadID: friendThreadID, senderID: acceptedFriend.id, body: "Nice deadlift post. Are you training at Crunch Fitness - South Beach this week?", createdAt: now.addingTimeInterval(-5_000), isRead: true, isReported: false),
            DirectMessage(id: UUID(), threadID: friendThreadID, senderID: currentUserID, body: "Tuesday night. Pull day and some rows.", createdAt: now.addingTimeInterval(-3_600), isRead: true, isReported: false),
            DirectMessage(id: UUID(), threadID: friendThreadID, senderID: acceptedFriend.id, body: "I may join. Need a spot on bench after.", createdAt: now.addingTimeInterval(-1_200), isRead: false, isReported: false),
            DirectMessage(id: UUID(), threadID: messageOnlyThreadID, senderID: messageOnlyProfile.id, body: "Follow this link for cheap supplements", createdAt: now.addingTimeInterval(-4_800), isRead: false, isReported: false)
        ]
        return (friendRequests, messageThreads, messages)
    }

    static let achievements: [Achievement] = [
        "First Workout", "10 Workouts", "50 Workouts", "100 Workouts",
        "First Lift Logged", "First Verified Lift", "Ten Verified Lifts",
        "First PR", "10 PRs", "25 PRs",
        "135 Bench", "225 Bench", "315 Bench",
        "225 Squat", "315 Squat", "405 Squat",
        "315 Deadlift", "405 Deadlift", "500 Deadlift",
        "Bodyweight Bench", "1.5x Bodyweight Squat", "2x Bodyweight Deadlift",
        "7-Day Workout Streak", "30-Day Workout Streak", "90-Day Workout Streak",
        "50,000 kg Volume", "250,000 kg Volume", "1,000,000 kg Volume",
        "Global Top 100", "Gym Top 10", "Gym Record Holder", "Global Number One",
        "90-Day Improvement Leader", "Profile Complete"
    ].map { Achievement(id: UUID(), title: $0, description: "Unlocked by strength progress in LiftRank.", symbolName: "medal.fill") }

    static let workoutPlans: [WorkoutPlan] = [
        WorkoutPlan(id: defaultWorkoutPlanID, name: "Robert's Hypertrophy Plan", createdAt: .now)
    ]

    static var workoutEntries: [WorkoutExerciseEntry] {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 8)) ?? .now
        let rows: [(Int, Int, String, String, String, String, Int, String, [(Double?, Int?, Int?)], Bool, String)] = [
            (1, 0, "Monday", "Push + Quads", "Hack Squat or Leg Press", "Quads", 3, "8-10", [(90, 10, 3), (180, 10, 8), (180, 10, 9)], true, "Keep depth consistent."),
            (1, 0, "Monday", "Push + Quads", "Incline DB Press", "Upper Chest", 3, "8-10", [(90, 10, 4), (180, 10, 8), (230, 5, 9)], true, "Top set missed target range."),
            (1, 0, "Monday", "Push + Quads", "Machine Chest Press", "Chest", 3, "10-12", [(90, 12, 3), (180, 10, 6), (250, 6, 8)], true, "Use controlled eccentrics."),
            (1, 0, "Monday", "Push + Quads", "Cable Lateral Raise", "Shoulders", 3, "12-20", [(11, 15, 5), (16.5, 10, 6), (22, 8, 10)], true, "Reached RPE 10."),
            (1, 0, "Monday", "Push + Quads", "Leg Extension", "Quads", 2, "12-15", [(60, 12, 2), (130, 12, 6), (180, 8, 8)], true, "Top set below target."),
            (1, 1, "Tuesday", "Pull + Hamstrings", "Romanian Deadlift", "Hamstrings", 3, "6-8", [(135, 8, 4), (225, 8, 7), (275, 6, 9)], true, "Good hinge session."),
            (1, 1, "Tuesday", "Pull + Hamstrings", "Lat Pulldown", "Lats", 3, "8-12", [(100, 12, 4), (140, 10, 7), (160, 8, 8)], true, "Pause at chest."),
            (1, 1, "Tuesday", "Pull + Hamstrings", "Chest-Supported Row", "Upper Back", 3, "8-12", [(90, 12, 5), (135, 10, 7), (160, 9, 8)], true, "Strong finish."),
            (1, 3, "Thursday", "Shoulders/Arms + Legs", "Machine Shoulder Press", "Shoulders", 3, "8-10", [(90, 10, 5), (140, 9, 7), (160, 7, 9)], false, "Planned."),
            (1, 3, "Thursday", "Shoulders/Arms + Legs", "Bulgarian Split Squat", "Quads", 3, "8-10", [(60, 10, 6), (70, 8, 8)], false, "Planned."),
            (2, 7, "Monday", "Upper + Quads", "Smith Squat or Leg Press", "Quads", 3, "8-10", [(185, 10, 7), (205, 8, 8)], false, "Planned."),
            (2, 8, "Tuesday", "Pull/Chest + Hamstrings/Glutes", "Hip Thrust", "Glutes", 3, "8-12", [(225, 12, 6), (315, 8, 8)], false, "Planned.")
        ]

        return rows.map { row in
            WorkoutExerciseEntry(
                id: UUID(),
                planID: defaultWorkoutPlanID,
                week: row.0,
                date: Calendar.current.date(byAdding: .day, value: row.1, to: base) ?? base,
                day: row.2,
                workout: row.3,
                exercise: row.4,
                muscleGroup: row.5,
                targetSets: row.6,
                targetReps: row.7,
                sets: row.8.map { WorkoutSetEntry(id: UUID(), weight: $0.0, reps: $0.1, rpe: $0.2) },
                isDone: row.9,
                notes: row.10
            )
        }
    }

    static var bodyweightEntries: [BodyweightEntry] {
        let dates = [
            DateComponents(year: 2026, month: 6, day: 14),
            DateComponents(year: 2026, month: 6, day: 21),
            DateComponents(year: 2026, month: 6, day: 28),
            DateComponents(year: 2026, month: 7, day: 5)
        ]
        return dates.enumerated().map { index, components in
            BodyweightEntry(
                id: UUID(),
                week: index + 1,
                targetDate: Calendar.current.date(from: components) ?? .now,
                actual: index == 0 ? 210 : nil,
                notes: ""
            )
        }
    }

    static func community() -> (profiles: [UserProfile], lifts: [LiftSubmission], activities: [ActivityItem]) {
        var profiles = [demoProfile]
        var lifts: [LiftSubmission] = []
        let names = ["Maya", "Andre", "Sofia", "Jalen", "Chris", "Nina", "Mateo", "Priya", "Dante", "Elena"]
        let ageGroups = standardAgeGroups
        let statuses: [VerificationStatus] = [.selfReported, .videoSubmitted, .videoVerified, .communityVerified, .competitionVerified]

        for index in 1...50 {
            let gym = gyms[index % gyms.count]
            let sex: SexCategory = index % 4 == 0 ? .female : .male
            let bodyweight = sex == .female ? Double(115 + (index * 7) % 90) : Double(150 + (index * 9) % 130)
            profiles.append(UserProfile(
                id: UUID(uuidString: String(format: "AB000000-0000-0000-0000-%012d", index))!,
                username: "lifter\(index)",
                displayName: "\(names[index % names.count]) \(index)",
                ageGroup: ageGroups[index % ageGroups.count],
                sexCategory: sex,
                heightInches: Double(62 + index % 14),
                bodyweightPounds: bodyweight,
                preferredUnit: .pounds,
                city: gym.city,
                state: gym.state,
                primaryGymID: gym.id,
                primaryGymName: gym.name,
                yearsExperience: 1 + index % 13,
                experienceLevel: ExperienceLevel.allCases[min(ExperienceLevel.allCases.count - 1, index % ExperienceLevel.allCases.count)],
                profileImageName: "person.crop.circle.fill",
                followers: 20 + index * 6,
                following: 14 + index * 2,
                hideExactAge: index % 3 == 0,
                hideBodyweight: false,
                hideCity: index % 8 == 0,
                hideGym: false,
                hideLiftVideos: index % 5 == 0
            ))
        }

        func addLift(user: UserProfile, exercise: Exercise, weight: Double, reps: Int, status: VerificationStatus, daysAgo: Int, demoMediaID: String? = nil) {
            let oneRep = RankingCalculator.epleyOneRepMax(weight: weight, repetitions: reps)
            lifts.append(LiftSubmission(
                id: UUID(),
                userID: user.id,
                exerciseID: exercise.id == "sumo_deadlift" ? "deadlift" : exercise.id,
                exerciseName: exercise.name,
                weight: weight,
                unit: .pounds,
                normalizedWeightKilograms: RankingCalculator.poundsToKilograms(weight),
                repetitions: reps,
                isActualOneRepMax: reps == 1,
                estimatedOneRepMax: oneRep,
                bodyweightAtLift: user.bodyweightPounds,
                bodyweightMultiple: RankingCalculator.bodyweightMultiple(oneRepMax: oneRep, bodyweight: user.bodyweightPounds),
                equipmentType: .raw,
                variation: exercise.name,
                gymID: user.primaryGymID,
                performedAt: .now.addingTimeInterval(TimeInterval(-daysAgo * 86_400)),
                localVideoURL: nil,
                remoteVideoURL: nil,
                demoMediaID: demoMediaID,
                caption: "Logged \(RankingCalculator.format(weight)) \(exercise.name)",
                verificationStatus: status,
                visibility: .publicLift,
                createdAt: .now.addingTimeInterval(TimeInterval(-daysAgo * 86_400)),
                updatedAt: .now
            ))
        }

        addLift(user: demoProfile, exercise: exercises[0], weight: 245, reps: 1, status: .videoVerified, daysAgo: 12, demoMediaID: "demo-leaderboard-bench")
        addLift(user: demoProfile, exercise: exercises[1], weight: 275, reps: 1, status: .communityVerified, daysAgo: 17, demoMediaID: "demo-leaderboard-squat")
        addLift(user: demoProfile, exercise: exercises[2], weight: 495, reps: 1, status: .competitionVerified, daysAgo: 7, demoMediaID: "demo-leaderboard-deadlift")

        for (userIndex, user) in profiles.dropFirst().enumerated() {
            for liftIndex in 0..<5 {
                let exercise = exercises[liftIndex]
                let base = exercise.id.contains("deadlift") ? 255.0 : exercise.id == "squat" ? 225.0 : exercise.id == "bench" ? 160.0 : 110.0
                let bump = Double((userIndex * 17 + liftIndex * 23) % 210)
                let topEnd = (userIndex == 3 && exercise.id == "deadlift") ? 565.0 : base + bump
                let reps = exercise.isPowerlift ? 1 : 2 + ((userIndex + liftIndex) % 4)
                let verifiedStatuses: [VerificationStatus] = [.videoVerified, .communityVerified, .competitionVerified]
                let status = exercise.isPowerlift
                    ? verifiedStatuses[(userIndex + liftIndex) % verifiedStatuses.count]
                    : statuses[(userIndex + liftIndex) % statuses.count]
                let seededDemoMediaID: String? = switch (userIndex, liftIndex) {
                case (0, 0): "demo-leaderboard-bench"
                case (1, 1): "demo-leaderboard-squat"
                case (2, 2): "demo-leaderboard-deadlift"
                default: nil
                }
                addLift(user: user, exercise: exercise, weight: topEnd, reps: reps, status: status, daysAgo: (userIndex * 3 + liftIndex) % 120, demoMediaID: seededDemoMediaID)
            }
        }

        let activities = Array(lifts.prefix(20)).compactMap { lift -> ActivityItem? in
            guard let profile = profiles.first(where: { $0.id == lift.userID }) else { return nil }
            return ActivityItem(id: UUID(), profile: profile, title: "\(profile.displayName) logged \(lift.exerciseName)", detail: "\(RankingCalculator.format(lift.estimatedOneRepMax)) lb estimated max at \(profile.primaryGymName)", liftID: lift.id, createdAt: lift.createdAt, isLiked: false, isSaved: false)
        }

        return (profiles, lifts, activities)
    }
}
