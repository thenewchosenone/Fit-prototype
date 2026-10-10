import SwiftUI

struct ExerciseCatalogIcon: View {
    let exercise: TrainingExerciseCatalogItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.075, green: 0.082, blue: 0.105),
                            Color(red: 0.115, green: 0.122, blue: 0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.liftOverlay.opacity(0.7), lineWidth: 1)
                }

            VStack(spacing: 2) {
                Image(systemName: iconGroup.symbol)
                    .font(.system(size: 23, weight: .semibold))
                    .frame(height: 27)
                Text(iconGroup.rawValue)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.3)
            }
            .foregroundStyle(Color.liftAccentText)
        }
        .frame(width: 54, height: 54)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let profile = exercise.resolvedMuscleProfile
        let secondary = profile.secondary.isEmpty ? "" : "; assisting \(profile.secondaryDescription)"
        return "\(exercise.name); \(iconGroup.rawValue.lowercased()) exercise; primary muscles \(profile.primaryDescription)\(secondary)"
    }

    private enum IconGroup: String {
        case push = "PUSH"
        case pull = "PULL"
        case legs = "LEGS"
        case arms = "ARMS"
        case core = "CORE"
        case carry = "CARRY"
        case cardio = "CARDIO"
        case mobility = "MOBILITY"
        case strength = "STRENGTH"

        var symbol: String {
            switch self {
            case .push: return "arrow.up"
            case .pull: return "arrow.down"
            case .legs: return "figure.strengthtraining.functional"
            case .arms, .strength: return "dumbbell.fill"
            case .core: return "figure.core.training"
            case .carry: return "figure.walk"
            case .cardio: return "heart.fill"
            case .mobility: return "figure.flexibility"
            }
        }
    }

    private var iconGroup: IconGroup {
        let category = exercise.workoutCategory.lowercased()
        if category == "cardio" { return .cardio }
        if category == "mobility" { return .mobility }
        if category == "carry" || exercise.movementPattern == .carry { return .carry }
        if category == "core" { return .core }
        if category == "arms" { return .arms }
        if category == "push" { return .push }
        if category == "pull" { return .pull }
        if category == "legs" || category == "pull/legs" { return .legs }
        if category == "conditioning" { return .cardio }

        switch exercise.movementPattern {
        case .horizontalPress, .verticalPress: return .push
        case .horizontalPull, .verticalPull: return .pull
        case .squat, .hinge, .lunge, .calf: return .legs
        case .curl, .elbowExtension: return .arms
        case .shoulderIsolation: return .push
        case .core: return .core
        case .carry: return .carry
        case .other: break
        }

        let bodyPart = exercise.bodyPart.lowercased()
        if bodyPart.contains("core") || bodyPart.contains("oblique") { return .core }
        if bodyPart.contains("quad") || bodyPart.contains("hamstring") || bodyPart.contains("glute") || bodyPart.contains("calf") { return .legs }
        if bodyPart.contains("bicep") || bodyPart.contains("tricep") || bodyPart.contains("forearm") { return .arms }
        if bodyPart.contains("chest") || bodyPart.contains("shoulder") { return .push }
        if bodyPart.contains("back") || bodyPart.contains("lat") { return .pull }
        return .strength
    }
}

/// Resolves a persisted exercise name to the shared catalog artwork for surfaces
/// that only have a display name (for example, historical lifts and PR cards).

enum RepDBExerciseMedia {
    static let attribution = "Exercise data by RepDB (repdb.co)"

    static func imageURL(for exerciseID: String) -> URL? {
        guard let mediaID = imageIDs[exerciseID] else { return nil }
        return URL(string: "https://exercise-dataset.com/images/flat/\(mediaID)-peak.webp")
    }

    private static let imageIDs: [String: String] = [
        "band_pull_apart": "band-pull-apart",
        "barbell_bench_press": "bench-press",
        "barbell_calf_raise": "barbell-calf-raise",
        "barbell_clean": "clean",
        "barbell_clean_and_jerk": "clean-and-jerk",
        "barbell_decline_bench_press": "decline-bench-press",
        "barbell_front_squat": "front-squat",
        "barbell_glute_bridge": "barbell-glute-bridge",
        "barbell_good_morning": "good-morning",
        "barbell_hex_bar_deadlift": "hex-bar-deadlift",
        "barbell_hip_thrust": "hip-thrust",
        "barbell_landmine_press": "landmine-press",
        "barbell_overhead_press": "seated-barbell-overhead-press",
        "barbell_pause_squat": "pause-squat",
        "barbell_pendlay_row": "pendlay-row",
        "barbell_preacher_curl": "barbell-preacher-curl",
        "barbell_push_press": "push-press",
        "barbell_reverse_lunge": "barbell-reverse-lunge",
        "barbell_row": "barbell-row",
        "barbell_seated_calf_raise": "barbell-calf-raise",
        "barbell_shrug": "shrug",
        "barbell_snatch": "snatch",
        "barbell_upright_row": "upright-row",
        "barbell_wrist_curl": "barbell-wrist-curl",
        "bb_box_squat": "box-squat",
        "bb_close_grip_bench": "close-grip-bench-press",
        "bb_deficit_deadlift": "deficit-deadlift",
        "bb_behind_neck_press": "behind-the-neck-press",
        "bb_hang_clean": "hang-power-clean",
        "bb_paused_bench": "paused-bench-press",
        "bb_spoto_press": "spoto-press",
        "bb_stiff_leg_deadlift": "stiff-leg-deadlift",
        "bb_wide_grip_bench": "wide-grip-bench-press",
        "bodyweight_bear_crawl": "bear-crawl",
        "bodyweight_bird_dog": "bird-dog",
        "bodyweight_crunch": "machine-seated-crunch",
        "bodyweight_dead_bug": "dead-bug",
        "bodyweight_decline_push_up": "decline-push-up",
        "bodyweight_glute_bridge": "glute-bridge",
        "bodyweight_inverted_row": "inverted-row",
        "bodyweight_nordic_curl": "nordic-hamstring-curl",
        "bodyweight_push_up": "push-up",
        "bodyweight_reverse_lunge": "bodyweight-reverse-lunge",
        "bodyweight_ring_row": "ring-row",
        "bodyweight_side_plank": "side-plank",
        "bodyweight_single_leg_calf_raise": "single-leg-calf-raise",
        "bodyweight_single_leg_glute_bridge": "single-leg-glute-bridge",
        "bodyweight_single_leg_squat": "pistol-squat",
        "bodyweight_squat": "bodyweight-squat",
        "bodyweight_standing_calf_raise": "standing-calf-raise",
        "bodyweight_wall_sit": "wall-sit",
        "bulgarian_split_squat": "bulgarian-split-squat",
        "bw_ab_wheel": "ab-wheel-rollout",
        "bw_hanging_knee_raise": "hanging-knee-raise",
        "bw_hollow_hold": "hollow-body-hold",
        "bw_incline_pushup": "incline-push-ups",
        "bw_l_sit": "l-sit",
        "cable_broad_grip_row": "wide-grip-seated-cable-row",
        "cable_chest_press": "cable-chest-press",
        "cable_crunch": "cable-crunch",
        "cable_external_rotation": "cable-external-rotation",
        "cable_face_pull": "face-pull",
        "cable_fly": "cable-fly",
        "cable_front_raise": "cable-front-raise",
        "cable_glute_kickback": "cable-kickback",
        "cable_lateral_raise": "cable-lateral-raise",
        "cable_pull_through": "cable-pull-through",
        "cable_single_arm_pulldown": "one-arm-lat-pulldown",
        "cable_standing_chest_press": "cable-chest-press",
        "cable_standing_row": "seated-cable-row",
        "cable_upright_row": "cable-upright-row",
        "cardio_bike": "stationary-bike",
        "cardio_incline_walk": "incline-treadmill-walk",
        "cardio_jump_rope": "jump-rope",
        "cardio_rower": "rowing-machine",
        "cardio_ski_erg": "ski-erg",
        "cardio_stair_climber": "stair-climber",
        "db_decline_fly": "decline-db-fly",
        "db_goblet_squat": "goblet-squat",
        "db_overhead_carry": "db-overhead-carry",
        "db_shoulder_press": "seated-db-press",
        "db_skullcrusher": "db-skull-crusher",
        "db_split_squat": "dumbbell-split-squat",
        "db_windmill": "dumbbell-windmill",
        "db_wrist_curl": "dumbbell-wrist-curl",
        "db_reverse_wrist_curl": "db-reverse-wrist-curl",
        "dumbbell_arnold_press": "arnold-press",
        "dumbbell_bench_press": "db-bench-press",
        "dumbbell_calf_raise": "dumbbell-calf-raise",
        "dumbbell_chest_supported_row": "chest-supported-db-row",
        "dumbbell_concentration_curl": "concentration-curl",
        "dumbbell_cross_body_hammer_curl": "cross-body-hammer-curl",
        "dumbbell_curl": "seated-dumbbell-curl",
        "dumbbell_deadlift": "dumbbell-deadlift",
        "dumbbell_floor_press": "dumbbell-floor-press",
        "dumbbell_fly": "db-fly",
        "dumbbell_front_raise": "dumbbell-front-raise",
        "dumbbell_front_squat": "dumbbell-front-squat",
        "dumbbell_hammer_curl": "hammer-curl",
        "dumbbell_hip_thrust": "dumbbell-hip-thrust",
        "dumbbell_incline_fly": "incline-dumbbell-fly",
        "dumbbell_lunge": "db-lunge",
        "dumbbell_pullover": "db-pullover",
        "dumbbell_romanian_deadlift": "dumbbell-romanian-deadlift",
        "dumbbell_seated_lateral_raise": "seated-dumbbell-lateral-raise",
        "dumbbell_shrug": "db-shrug",
        "dumbbell_side_bend": "dumbbell-side-bend",
        "dumbbell_skull_crusher": "db-skull-crusher",
        "dumbbell_sumo_squat": "db-sumo-squat",
        "dumbbell_upright_row": "dumbbell-upright-row",
        "dumbbell_zottman_curl": "zottman-curl",
        "ez_bar_curl": "ez-bar-curl",
        "hack_squat": "hack-squat",
        "hanging_leg_raise": "hanging-leg-raise",
        "incline_db_curl": "incline-db-curl",
        "incline_db_press": "incline-db-press",
        "bb_overhead_squat": "overhead-squat",
        "kb_deadlift": "kettlebell-deadlift",
        "kb_bottoms_up_press": "one-arm-kettlebell-bottoms-up-press",
        "kb_clean_and_press": "double-kettlebell-clean-and-press",
        "kb_single_arm_swing": "one-arm-kettlebell-swing",
        "kb_double_clean": "double-kettlebell-clean",
        "kb_double_push_press": "double-kettlebell-push-press",
        "kb_overhead_carry": "kettlebell-overhead-carry",
        "kettlebell_floor_press": "kettlebell-floor-press",
        "kettlebell_reverse_lunge": "kettlebell-reverse-lunge",
        "kettlebell_russian_twist": "kettlebell-russian-twist",
        "kettlebell_single_leg_deadlift": "kettlebell-single-leg-deadlift",
        "kettlebell_sum_deadlift": "kettlebell-sumo-deadlift",
        "kettlebell_swing": "kettlebell-swing",
        "lat_pulldown": "lat-pulldown",
        "leg_extension": "leg-extension",
        "leg_press": "leg-press",
        "lying_leg_curl": "leg-curl",
        "machine_chest_press": "chest-press-machine",
        "machine_converging_chest_press": "chest-press-machine",
        "machine_vertical_chest_press": "chest-press-machine",
        "machine_vertical_chest_fly": "machine-chest-fly",
        "machine_donkey_calf": "donkey-calf-raise",
        "machine_single_leg_curl": "single-leg-lying-leg-curl",
        "machine_glute_kickback": "glute-kickback",
        "machine_hip_abduction": "hip-abduction",
        "machine_hip_adduction": "hip-adduction",
        "machine_horizontal_leg_press": "horizontal-leg-press",
        "machine_preacher_curl": "preacher-curl",
        "machine_seated_calf_raise": "standing-calf-raise",
        "machine_shoulder_press": "machine-shoulder-press",
        "machine_single_leg_press": "single-leg-press",
        "machine_smith_bench_press": "smith-machine-bench-press",
        "machine_smith_calf_raise": "smith-machine-calf-raise",
        "machine_smith_front_squat": "smith-machine-front-squat",
        "machine_smith_good_morning": "smith-machine-good-morning",
        "machine_smith_hip_thrust": "smith-machine-hip-thrust",
        "machine_smith_reverse_lunge": "smith-machine-reverse-lunge",
        "machine_smith_romanian_deadlift": "smith-machine-rdl",
        "machine_smith_seated_calf_raise": "smith-machine-calf-raise",
        "machine_smith_shoulder_press": "smith-machine-shoulder-press",
        "machine_smith_shrug": "smith-machine-shrug",
        "machine_smith_split_squat": "smith-machine-split-squat",
        "machine_smith_upright_row": "smith-machine-upright-row",
        "machine_standing_calf_raise": "standing-calf-raise",
        "machine_standing_glute_kickback": "glute-kickback",
        "machine_standing_leg_curl": "seated-leg-curl",
        "machine_standing_shoulder_press": "machine-shoulder-press",
        "machine_t_bar_row": "t-bar-row",
        "machine_triceps_extension": "machine-triceps-extension",
        "mobility_cat_cow": "cat-cow",
        "mobility_pigeon": "pigeon-stretch",
        "mobility_thread_needle": "thread-the-needle",
        "pec_deck": "pec-deck",
        "plank": "plank",
        "pull_up": "pull-up",
        "rear_delt_fly": "rear-delt-fly",
        "romanian_deadlift": "romanian-deadlift",
        "seated_cable_row": "seated-cable-row",
        "seated_leg_curl": "seated-leg-curl",
        "single_arm_db_row": "single-arm-db-row",
        "sumo_deadlift": "sumo-deadlift",
    ]
}

struct ExerciseNameIcon: View {
    let name: String
    let fallbackSymbol: String

    private var resolvedFallbackSymbol: String {
        let weakSymbols = [
            "dumbbell.fill",
            "arrow.up",
            "arrow.down",
            "arrow.left.and.right",
            "figure.arms.open",
            "figure.strengthtraining.traditional"
        ]
        return weakSymbols.contains(fallbackSymbol)
            ? "figure.strengthtraining.functional"
            : fallbackSymbol
    }

    private var catalogExercise: TrainingExerciseCatalogItem? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return MockData.trainingExerciseLibrary.first { exercise in
            exercise.name.lowercased() == normalizedName ||
            exercise.searchAliases.contains { $0.lowercased() == normalizedName }
        }
    }

    var body: some View {
        if let catalogExercise {
            ExerciseCatalogIcon(exercise: catalogExercise)
                .scaleEffect(0.72)
        } else {
            Image(systemName: resolvedFallbackSymbol)
                .foregroundStyle(Color.liftAccentText)
        }
    }
}
