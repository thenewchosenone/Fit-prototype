import Foundation

enum PopularExerciseCatalog {
    private typealias Seed = (id: String, name: String, bodyPart: String, category: String, reps: String)

    static let exercises: [TrainingExerciseCatalogItem] =
        machineSeeds.map { make($0, equipment: "Machine") } +
        cableSeeds.map { make($0, equipment: "Cable") } +
        dumbbellSeeds.map { make($0, equipment: "Dumbbell") } +
        genericMachineSeeds.map { make($0, equipment: "Machine") }

    private static let machineSeeds: [Seed] = [
        ("machine_smith_bench_press", "Smith Machine Bench Press", "Chest", "Push", "6-10"),
        ("machine_smith_incline_press", "Smith Machine Incline Press", "Upper Chest", "Push", "6-10"),
        ("machine_smith_decline_press", "Smith Machine Decline Press", "Chest", "Push", "8-12"),
        ("machine_smith_shoulder_press", "Smith Machine Shoulder Press", "Shoulders", "Push", "6-10"),
        ("machine_smith_back_squat", "Smith Machine Back Squat", "Quads", "Legs", "6-10"),
        ("machine_smith_front_squat", "Smith Machine Front Squat", "Quads", "Legs", "6-10"),
        ("machine_smith_split_squat", "Smith Machine Split Squat", "Quads/Glutes", "Legs", "8-12"),
        ("machine_smith_romanian_deadlift", "Smith Machine Romanian Deadlift", "Hamstrings", "Legs", "6-10"),
        ("machine_smith_hip_thrust", "Smith Machine Hip Thrust", "Glutes", "Legs", "8-12"),
        ("machine_smith_calf_raise", "Smith Machine Calf Raise", "Calves", "Legs", "10-15"),
        ("machine_plate_loaded_chest_press", "Plate-Loaded Chest Press", "Chest", "Push", "6-10"),
        ("machine_incline_chest_press", "Incline Chest Press Machine", "Upper Chest", "Push", "8-12"),
        ("machine_decline_chest_press", "Decline Chest Press Machine", "Chest", "Push", "8-12"),
        ("machine_iso_lateral_chest_press", "Iso-Lateral Chest Press", "Chest", "Push", "8-12"),
        ("machine_assisted_dip", "Assisted Dip Machine", "Chest/Triceps", "Push", "8-12"),
        ("machine_assisted_pull_up", "Assisted Pull-Up Machine", "Lats", "Pull", "6-10"),
        ("machine_high_row", "High Row Machine", "Upper Back", "Pull", "8-12"),
        ("machine_low_row", "Low Row Machine", "Back", "Pull", "8-12"),
        ("machine_iso_lateral_row", "Iso-Lateral Row", "Back", "Pull", "8-12"),
        ("machine_t_bar_row", "T-Bar Row Machine", "Back", "Pull", "6-10"),
        ("machine_pullover", "Pullover Machine", "Lats", "Pull", "8-12"),
        ("machine_wide_grip_pulldown", "Wide-Grip Pulldown Machine", "Lats", "Pull", "8-12"),
        ("machine_neutral_grip_pulldown", "Neutral-Grip Pulldown Machine", "Lats", "Pull", "8-12"),
        ("machine_reverse_grip_pulldown", "Reverse-Grip Pulldown Machine", "Lats/Biceps", "Pull", "8-12"),
        ("machine_lateral_raise", "Lateral Raise Machine", "Shoulders", "Push", "10-15"),
        ("machine_reverse_pec_deck", "Reverse Pec Deck", "Rear Delts", "Pull", "10-15"),
        ("machine_seated_biceps_curl", "Seated Biceps Curl Machine", "Biceps", "Arms", "8-12"),
        ("machine_preacher_curl", "Preacher Curl Machine", "Biceps", "Arms", "8-12"),
        ("machine_triceps_extension", "Triceps Extension Machine", "Triceps", "Arms", "8-12"),
        ("machine_triceps_dip", "Triceps Dip Machine", "Triceps", "Arms", "8-12"),
        ("machine_abdominal_crunch", "Abdominal Crunch Machine", "Core", "Core", "10-15"),
        ("machine_rotary_torso", "Rotary Torso Machine", "Obliques", "Core", "10-15"),
        ("machine_back_extension", "Back Extension Machine", "Lower Back", "Pull", "10-15"),
        ("machine_glute_drive", "Glute Drive Machine", "Glutes", "Legs", "8-12"),
        ("machine_hip_abductor", "Hip Abductor Machine", "Glutes", "Legs", "12-20"),
        ("machine_hip_adductor", "Hip Adductor Machine", "Adductors", "Legs", "12-20"),
        ("machine_standing_glute_kickback", "Standing Glute Kickback Machine", "Glutes", "Legs", "10-15"),
        ("machine_vertical_leg_press", "Vertical Leg Press", "Quads/Glutes", "Legs", "8-12"),
        ("machine_horizontal_leg_press", "Horizontal Leg Press", "Quads/Glutes", "Legs", "8-12"),
        ("machine_single_leg_press", "Single-Leg Press Machine", "Quads/Glutes", "Legs", "8-12"),
        ("machine_pendulum_squat", "Pendulum Squat", "Quads", "Legs", "6-10"),
        ("machine_v_squat", "V-Squat Machine", "Quads/Glutes", "Legs", "6-10"),
        ("machine_belt_squat", "Belt Squat Machine", "Quads/Glutes", "Legs", "8-12"),
        ("machine_sissy_squat", "Sissy Squat Machine", "Quads", "Legs", "10-15"),
        ("machine_standing_leg_curl", "Standing Leg Curl Machine", "Hamstrings", "Legs", "10-15"),
        ("machine_kneeling_leg_curl", "Kneeling Leg Curl Machine", "Hamstrings", "Legs", "10-15"),
        ("machine_nordic_curl", "Nordic Curl Machine", "Hamstrings", "Legs", "6-10"),
        ("machine_standing_calf_raise", "Standing Calf Raise Machine", "Calves", "Legs", "10-15"),
        ("machine_seated_calf_raise", "Seated Calf Raise Machine", "Calves", "Legs", "10-15"),
        ("machine_tibialis_raise", "Tibialis Raise Machine", "Tibialis", "Legs", "12-20")
    ]

    private static let cableSeeds: [Seed] = [
        ("cable_standing_chest_press", "Standing Cable Chest Press", "Chest", "Push", "8-12"),
        ("cable_single_arm_chest_press", "Single-Arm Cable Chest Press", "Chest", "Push", "8-12"),
        ("cable_incline_press", "Incline Cable Press", "Upper Chest", "Push", "8-12"),
        ("cable_decline_press", "Decline Cable Press", "Chest", "Push", "8-12"),
        ("cable_low_to_high_fly", "Low-to-High Cable Fly", "Upper Chest", "Push", "10-15"),
        ("cable_high_to_low_fly", "High-to-Low Cable Fly", "Lower Chest", "Push", "10-15"),
        ("cable_single_arm_fly", "Single-Arm Cable Fly", "Chest", "Push", "10-15"),
        ("cable_crossover", "Cable Crossover", "Chest", "Push", "10-15"),
        ("cable_pullover", "Cable Pullover", "Lats", "Pull", "10-15"),
        ("cable_straight_arm_pulldown", "Straight-Arm Cable Pulldown", "Lats", "Pull", "10-15"),
        ("cable_wide_grip_pulldown", "Wide-Grip Cable Pulldown", "Lats", "Pull", "8-12"),
        ("cable_close_grip_pulldown", "Close-Grip Cable Pulldown", "Lats", "Pull", "8-12"),
        ("cable_reverse_grip_pulldown", "Reverse-Grip Cable Pulldown", "Lats/Biceps", "Pull", "8-12"),
        ("cable_single_arm_kneeling_pulldown", "Single-Arm Kneeling Pulldown", "Lats", "Pull", "8-12"),
        ("cable_half_kneeling_row", "Half-Kneeling Cable Row", "Back", "Pull", "8-12"),
        ("cable_standing_row", "Standing Cable Row", "Back", "Pull", "8-12"),
        ("cable_single_arm_row", "Single-Arm Cable Row", "Back", "Pull", "8-12"),
        ("cable_high_row", "High Cable Row", "Upper Back", "Pull", "8-12"),
        ("cable_low_row", "Low Cable Row", "Back", "Pull", "8-12"),
        ("cable_face_pull", "Cable Face Pull", "Rear Delts", "Pull", "10-15"),
        ("cable_rear_delt_fly", "Cable Rear Delt Fly", "Rear Delts", "Pull", "10-15"),
        ("cable_y_raise", "Cable Y Raise", "Shoulders", "Push", "10-15"),
        ("cable_front_raise", "Cable Front Raise", "Shoulders", "Push", "10-15"),
        ("cable_upright_row", "Cable Upright Row", "Shoulders", "Pull", "8-12"),
        ("cable_shoulder_press", "Cable Shoulder Press", "Shoulders", "Push", "8-12"),
        ("cable_external_rotation", "Cable External Rotation", "Rotator Cuff", "Shoulders", "12-20"),
        ("cable_internal_rotation", "Cable Internal Rotation", "Rotator Cuff", "Shoulders", "12-20"),
        ("cable_biceps_curl", "Cable Biceps Curl", "Biceps", "Arms", "8-12"),
        ("cable_rope_hammer_curl", "Rope Hammer Curl", "Biceps/Forearms", "Arms", "8-12"),
        ("cable_bayesian_curl", "Bayesian Cable Curl", "Biceps", "Arms", "8-12"),
        ("cable_preacher_curl", "Cable Preacher Curl", "Biceps", "Arms", "8-12"),
        ("cable_reverse_curl", "Cable Reverse Curl", "Forearms/Biceps", "Arms", "8-12"),
        ("cable_drag_curl", "Cable Drag Curl", "Biceps", "Arms", "8-12"),
        ("cable_single_arm_curl", "Single-Arm Cable Curl", "Biceps", "Arms", "8-12"),
        ("cable_straight_bar_pushdown", "Straight-Bar Triceps Pushdown", "Triceps", "Arms", "8-12"),
        ("cable_rope_pushdown", "Rope Triceps Pushdown", "Triceps", "Arms", "8-12"),
        ("cable_reverse_grip_pushdown", "Reverse-Grip Triceps Pushdown", "Triceps", "Arms", "8-12"),
        ("cable_single_arm_pushdown", "Single-Arm Triceps Pushdown", "Triceps", "Arms", "8-12"),
        ("cable_cross_body_triceps_extension", "Cross-Body Cable Triceps Extension", "Triceps", "Arms", "10-15"),
        ("cable_skull_crusher", "Cable Skull Crusher", "Triceps", "Arms", "8-12"),
        ("cable_squat", "Cable Squat", "Quads/Glutes", "Legs", "8-12"),
        ("cable_goblet_squat", "Cable Goblet Squat", "Quads/Glutes", "Legs", "8-12"),
        ("cable_pull_through", "Cable Pull-Through", "Glutes/Hamstrings", "Legs", "10-15"),
        ("cable_romanian_deadlift", "Cable Romanian Deadlift", "Hamstrings", "Legs", "8-12"),
        ("cable_lunge", "Cable Reverse Lunge", "Quads/Glutes", "Legs", "8-12"),
        ("cable_step_up", "Cable Step-Up", "Quads/Glutes", "Legs", "8-12"),
        ("cable_hip_abduction", "Cable Hip Abduction", "Glutes", "Legs", "12-20"),
        ("cable_hip_adduction", "Cable Hip Adduction", "Adductors", "Legs", "12-20"),
        ("cable_wood_chop", "Cable Wood Chop", "Obliques", "Core", "10-15"),
        ("cable_pallof_press", "Pallof Press", "Core", "Core", "10-15")
    ]

    private static let dumbbellSeeds: [Seed] = [
        ("dumbbell_flat_bench_press", "Flat Dumbbell Bench Press", "Chest", "Push", "6-10"),
        ("dumbbell_decline_bench_press", "Decline Dumbbell Bench Press", "Chest", "Push", "8-12"),
        ("dumbbell_neutral_grip_press", "Neutral-Grip Dumbbell Press", "Chest/Triceps", "Push", "8-12"),
        ("dumbbell_floor_press", "Dumbbell Floor Press", "Chest/Triceps", "Push", "6-10"),
        ("dumbbell_squeeze_press", "Dumbbell Squeeze Press", "Chest", "Push", "8-12"),
        ("dumbbell_alternating_bench_press", "Alternating Dumbbell Bench Press", "Chest", "Push", "8-12"),
        ("dumbbell_single_arm_bench_press", "Single-Arm Dumbbell Bench Press", "Chest/Core", "Push", "8-12"),
        ("dumbbell_fly", "Dumbbell Fly", "Chest", "Push", "10-15"),
        ("dumbbell_incline_fly", "Incline Dumbbell Fly", "Upper Chest", "Push", "10-15"),
        ("dumbbell_pullover", "Dumbbell Pullover", "Chest/Lats", "Push", "8-12"),
        ("dumbbell_chest_supported_row", "Chest-Supported Dumbbell Row", "Upper Back", "Pull", "8-12"),
        ("dumbbell_renegade_row", "Renegade Row", "Back/Core", "Pull", "6-10"),
        ("dumbbell_seal_row", "Dumbbell Seal Row", "Back", "Pull", "8-12"),
        ("dumbbell_bent_over_row", "Dumbbell Bent-Over Row", "Back", "Pull", "8-12"),
        ("dumbbell_high_row", "Dumbbell High Row", "Upper Back", "Pull", "8-12"),
        ("dumbbell_rear_delt_row", "Dumbbell Rear Delt Row", "Rear Delts", "Pull", "10-15"),
        ("dumbbell_arnold_press", "Arnold Press", "Shoulders", "Push", "8-12"),
        ("dumbbell_seated_lateral_raise", "Seated Dumbbell Lateral Raise", "Shoulders", "Push", "10-15"),
        ("dumbbell_lean_away_lateral_raise", "Lean-Away Dumbbell Lateral Raise", "Shoulders", "Push", "10-15"),
        ("dumbbell_front_raise", "Dumbbell Front Raise", "Shoulders", "Push", "10-15"),
        ("dumbbell_rear_delt_fly", "Dumbbell Rear Delt Fly", "Rear Delts", "Pull", "10-15"),
        ("dumbbell_upright_row", "Dumbbell Upright Row", "Shoulders", "Pull", "8-12"),
        ("dumbbell_shrug", "Dumbbell Shrug", "Traps", "Pull", "8-12"),
        ("dumbbell_cuban_press", "Dumbbell Cuban Press", "Shoulders", "Push", "10-15"),
        ("dumbbell_alternating_curl", "Alternating Dumbbell Curl", "Biceps", "Arms", "8-12"),
        ("dumbbell_hammer_curl", "Dumbbell Hammer Curl", "Biceps/Forearms", "Arms", "8-12"),
        ("dumbbell_concentration_curl", "Concentration Curl", "Biceps", "Arms", "8-12"),
        ("dumbbell_preacher_curl", "Dumbbell Preacher Curl", "Biceps", "Arms", "8-12"),
        ("dumbbell_spider_curl", "Dumbbell Spider Curl", "Biceps", "Arms", "8-12"),
        ("dumbbell_zottman_curl", "Zottman Curl", "Biceps/Forearms", "Arms", "8-12"),
        ("dumbbell_cross_body_hammer_curl", "Cross-Body Hammer Curl", "Biceps/Forearms", "Arms", "8-12"),
        ("dumbbell_skull_crusher", "Dumbbell Skull Crusher", "Triceps", "Arms", "8-12"),
        ("dumbbell_tate_press", "Dumbbell Tate Press", "Triceps", "Arms", "8-12"),
        ("dumbbell_single_arm_overhead_extension", "Single-Arm Overhead Dumbbell Extension", "Triceps", "Arms", "8-12"),
        ("dumbbell_goblet_squat", "Dumbbell Goblet Squat", "Quads/Glutes", "Legs", "8-12"),
        ("dumbbell_front_squat", "Dumbbell Front Squat", "Quads", "Legs", "8-12"),
        ("dumbbell_sumo_squat", "Dumbbell Sumo Squat", "Glutes/Adductors", "Legs", "8-12"),
        ("dumbbell_reverse_lunge", "Dumbbell Reverse Lunge", "Quads/Glutes", "Legs", "8-12"),
        ("dumbbell_walking_lunge", "Dumbbell Walking Lunge", "Quads/Glutes", "Legs", "8-12"),
        ("dumbbell_step_up", "Dumbbell Step-Up", "Quads/Glutes", "Legs", "8-12"),
        ("dumbbell_romanian_deadlift", "Dumbbell Romanian Deadlift", "Hamstrings", "Legs", "8-12"),
        ("dumbbell_single_leg_romanian_deadlift", "Single-Leg Dumbbell Romanian Deadlift", "Hamstrings/Glutes", "Legs", "8-12"),
        ("dumbbell_stiff_leg_deadlift", "Dumbbell Stiff-Leg Deadlift", "Hamstrings", "Legs", "8-12"),
        ("dumbbell_hip_thrust", "Dumbbell Hip Thrust", "Glutes", "Legs", "8-12"),
        ("dumbbell_glute_bridge", "Dumbbell Glute Bridge", "Glutes", "Legs", "10-15"),
        ("dumbbell_calf_raise", "Dumbbell Calf Raise", "Calves", "Legs", "10-15"),
        ("dumbbell_dead_bug", "Dumbbell Dead Bug", "Core", "Core", "8-12"),
        ("dumbbell_russian_twist", "Dumbbell Russian Twist", "Obliques", "Core", "10-20"),
        ("dumbbell_side_bend", "Dumbbell Side Bend", "Obliques", "Core", "10-15"),
        ("dumbbell_thruster", "Dumbbell Thruster", "Full Body", "Conditioning", "8-12")
    ]

    private static let genericMachineSeeds: [Seed] = [
        ("machine_iso_lateral_underhand_row", "Iso-Lateral Underhand Row", "Lats/Mid Back", "Pull", "6-10"),
        ("machine_plate_loaded_horizontal_bench_press", "Plate-Loaded Horizontal Bench Press", "Chest/Triceps", "Push", "6-10"),
        ("machine_high_incline_chest_press", "High-Incline Chest Press Machine", "Upper Chest/Shoulders", "Push", "6-10"),
        ("machine_wide_grip_chest_press", "Wide-Grip Chest Press Machine", "Chest", "Push", "8-12"),
        ("machine_front_lat_pulldown", "Front Lat Pulldown Machine", "Lats", "Pull", "8-12"),
        ("machine_plate_loaded_pec_fly", "Plate-Loaded Pec Fly", "Chest", "Push", "10-15"),
        ("machine_shrug", "Machine Shrug", "Traps", "Pull", "8-12"),
        ("machine_grip", "Grip Machine", "Forearms", "Arms", "10-15"),
        ("machine_neck_flexion", "Neck Flexion Machine", "Neck", "Neck", "10-15"),
        ("machine_neck_extension", "Neck Extension Machine", "Neck", "Neck", "10-15"),
        ("machine_lateral_neck_flexion", "Lateral Neck Flexion Machine", "Neck", "Neck", "10-15"),
        ("machine_linear_45_leg_press", "45-Degree Linear Leg Press", "Quads/Glutes", "Legs", "8-12"),
        ("machine_iso_lateral_leg_press", "Iso-Lateral Leg Press", "Quads/Glutes", "Legs", "8-12"),
        ("machine_iso_lateral_leg_curl", "Iso-Lateral Leg Curl", "Hamstrings", "Legs", "8-12"),
        ("machine_ground_base_squat", "Ground-Base Squat", "Quads/Glutes", "Legs", "8-12"),
        ("machine_ground_base_rotational_twist", "Ground-Base Rotational Twist", "Core/Obliques", "Core", "10-15")
    ]

    private static let aliasesByID: [String: [String]] = [
        "machine_iso_lateral_underhand_row": ["Hammer Strength D.Y. Row", "Hammer D.Y. Row", "Dorian Yates Row", "DY Row"],
        "machine_plate_loaded_horizontal_bench_press": ["Hammer Strength Horizontal Bench Press", "Hammer Horizontal Bench Press"],
        "machine_high_incline_chest_press": ["Hammer Strength Super Incline Press", "Hammer Super Incline"],
        "machine_wide_grip_chest_press": ["Hammer Strength Wide Chest", "Hammer Wide Chest Press"],
        "machine_front_lat_pulldown": ["Hammer Strength Front Lat Pulldown", "Hammer Front Pulldown"],
        "machine_plate_loaded_pec_fly": ["Hammer Strength Super Fly", "Hammer Super Fly"],
        "machine_shrug": ["Hammer Strength Seated Standing Shrug", "Hammer Strength Shrug"],
        "machine_grip": ["Hammer Strength Gripper", "Hammer Gripper"],
        "machine_neck_flexion": ["Hammer Strength 4 Way Neck Flexion"],
        "machine_neck_extension": ["Hammer Strength 4 Way Neck Extension"],
        "machine_lateral_neck_flexion": ["Hammer Strength 4 Way Neck Lateral Flexion"],
        "machine_linear_45_leg_press": ["Hammer Strength Linear Leg Press", "Hammer Linear Leg Press"],
        "machine_iso_lateral_leg_press": ["Hammer Strength Iso-Lateral Leg Press", "Hammer Iso Leg Press"],
        "machine_iso_lateral_leg_curl": ["Hammer Strength Iso-Lateral Leg Curl", "Hammer Iso Leg Curl"],
        "machine_ground_base_squat": ["Hammer Strength Ground Base Multi-Squat", "Hammer Multi Squat"],
        "machine_ground_base_rotational_twist": ["Hammer Strength Combo Twist", "Hammer Combo Twist"],
        "machine_plate_loaded_chest_press": ["Hammer Strength Bench Press", "Hammer Iso-Lateral Bench Press"],
        "machine_incline_chest_press": ["Hammer Strength Incline Press", "Hammer Iso-Lateral Incline Press"],
        "machine_decline_chest_press": ["Hammer Strength Decline Press", "Hammer Iso-Lateral Decline Press"],
        "machine_iso_lateral_chest_press": ["Hammer Strength Chest Press", "Hammer Iso Chest Press"],
        "machine_high_row": ["Hammer Strength High Row", "Hammer Iso-Lateral High Row"],
        "machine_low_row": ["Hammer Strength Low Row", "Hammer Iso-Lateral Low Row"],
        "machine_iso_lateral_row": ["Hammer Strength Iso-Lateral Row", "Hammer Strength Row"],
        "machine_pullover": ["Hammer Strength Pullover", "Hammer Pullover"],
        "machine_wide_grip_pulldown": ["Hammer Strength Wide Pulldown", "Hammer Wide Pulldown"],
        "machine_lateral_raise": ["Hammer Strength Lateral Raise"],
        "machine_seated_biceps_curl": ["Hammer Strength Seated Biceps", "Hammer Seated Biceps Curl"],
        "machine_glute_drive": ["Hammer Strength Glute Drive"],
        "machine_v_squat": ["Hammer Strength V-Squat", "Hammer V Squat"],
        "machine_belt_squat": ["Hammer Strength Belt Squat"],
        "machine_pendulum_squat": ["Hammer Strength Pendulum-X Squat", "Hammer Pendulum Squat"],
        "machine_seated_calf_raise": ["Hammer Strength Seated Calf Raise"],
        "machine_tibialis_raise": ["Hammer Strength Tibia Dorsi Flexion"]
    ]

    private static func make(_ seed: Seed, equipment: String) -> TrainingExerciseCatalogItem {
        var exercise = TrainingExerciseCatalogItem(
            id: seed.id,
            name: seed.name,
            bodyPart: seed.bodyPart,
            workoutCategory: seed.category,
            defaultSets: 3,
            defaultReps: seed.reps,
            symbolName: symbol(for: seed.bodyPart),
            equipment: equipment
        )
        exercise.defaultRestSeconds = restSeconds(for: seed.reps)
        exercise.searchAliases = aliasesByID[seed.id] ?? []
        return exercise
    }

    private static func restSeconds(for reps: String) -> Int {
        if reps.contains("6-10") || reps.contains("6-8") { return 120 }
        if reps.contains("12-20") || reps.contains("10-20") { return 60 }
        return 90
    }

    private static func symbol(for bodyPart: String) -> String {
        let value = bodyPart.lowercased()
        if value.contains("core") || value.contains("oblique") { return "figure.core.training" }
        if value.contains("quad") || value.contains("hamstring") || value.contains("glute") || value.contains("calf") || value.contains("leg") { return "figure.strengthtraining.functional" }
        if value.contains("chest") || value.contains("shoulder") || value.contains("tricep") { return "figure.strengthtraining.traditional" }
        return "dumbbell.fill"
    }
}
