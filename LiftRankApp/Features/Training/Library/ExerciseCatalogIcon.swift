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

            movementIcon
        }
        .frame(width: 54, height: 54)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let profile = exercise.resolvedMuscleProfile
        let secondary = profile.secondary.isEmpty ? "" : "; assisting \(profile.secondaryDescription)"
        return "\(exercise.name); primary muscles \(profile.primaryDescription)\(secondary)"
    }

    private var unresolvedFallbackSymbol: String {
        let weakSymbols = [
            "dumbbell.fill",
            "arrow.up",
            "arrow.down",
            "arrow.left.and.right",
            "arrow.up.and.down",
            "arrow.triangle.2.circlepath",
            "figure.arms.open",
            "figure.strengthtraining.traditional"
        ]
        guard weakSymbols.contains(exercise.symbolName) else { return exercise.symbolName }
        let bodyPart = exercise.bodyPart.lowercased()
        if bodyPart.contains("core") || bodyPart.contains("oblique") { return "figure.core.training" }
        if bodyPart.contains("back") || bodyPart.contains("lat") || bodyPart.contains("trap") { return "figure.rower" }
        if bodyPart.contains("chest") || bodyPart.contains("shoulder") || bodyPart.contains("bicep") || bodyPart.contains("tricep") {
            return "figure.strengthtraining.traditional"
        }
        return "figure.strengthtraining.functional"
    }

    @ViewBuilder
    private var movementIcon: some View {
        let name = exercise.name.lowercased()
        let gradient = LinearGradient(
            colors: [Color(red: 0.89, green: 1.0, blue: 0.38), Color.liftBlue],
            startPoint: .top,
            endPoint: .bottom
        )
        let equipment = exercise.equipment.lowercased()
        let implementSymbol = equipment.contains("barbell")
            ? "line.3.horizontal"
            : equipment.contains("machine") || equipment.contains("smith")
                ? "square.stack.3d.up.fill"
            : equipment.contains("band") || equipment.contains("cable")
                ? "arrow.left.and.right"
                : "dumbbell.fill"
        if name.contains("arnold press") {
            ZStack {
                Image(systemName: "figure.strengthtraining.functional")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12, weight: .black))
                    .offset(y: -10)
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .black))
                    .offset(y: 7)
            }
            .foregroundStyle(gradient)
        } else if name.contains("overhead press") || name.contains("shoulder press") || name.contains("push press") || name.contains("military press") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 25, weight: .semibold))
                Image(systemName: implementSymbol)
                    .font(.system(size: 18, weight: .bold))
                    .offset(y: -13)
            }
            .foregroundStyle(gradient)
        } else if name.contains("lateral raise") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 13, weight: .black))
                    .offset(y: -1)
                Image(systemName: implementSymbol)
                    .font(.system(size: 10, weight: .black))
                    .offset(y: -10)
            }
            .foregroundStyle(gradient)
        } else if name.contains("calf raise") {
            ZStack {
                Image(systemName: name.contains("seated") ? "figure.seated.side" : "figure.stand")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: implementSymbol)
                    .font(.system(size: 12, weight: .black))
                    .offset(y: -10)
                Image(systemName: "arrow.up.to.line.compact")
                    .font(.system(size: 13, weight: .black))
                    .offset(y: 10)
            }
            .foregroundStyle(gradient)
        } else if name.contains("front raise") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .black))
                    .offset(y: -10)
            }
            .foregroundStyle(gradient)
        } else if name.contains("neck") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: name.contains("lateral") ? "arrow.left.and.right" : "arrow.up.and.down")
                    .font(.system(size: 12, weight: .black))
                    .offset(y: -2)
            }
            .foregroundStyle(gradient)
        } else if name.contains("face pull") || name.contains("pull-apart") {
            ZStack {
                Image(systemName: "figure.strengthtraining.functional")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: implementSymbol)
                    .font(.system(size: 10, weight: .black))
                    .offset(y: -9)
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 11, weight: .black))
                    .offset(y: 1)
            }
            .foregroundStyle(gradient)
        } else if name.contains("fly") || name.contains("rear delt") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 13, weight: .black))
                    .offset(y: 1)
                Image(systemName: implementSymbol)
                    .font(.system(size: 10, weight: .black))
                    .offset(y: -10)
            }
            .foregroundStyle(gradient)
        } else if name.contains("leg press") && (name.contains("45") || name.contains("linear")) {
            ZStack {
                Image(systemName: "figure.seated.side")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .black))
                    .offset(x: 9, y: -1)
            }
            .foregroundStyle(gradient)
        } else if name.contains("vertical leg press") {
            ZStack {
                Image(systemName: "figure.seated.side")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .black))
                    .offset(y: -1)
            }
            .foregroundStyle(gradient)
        } else if name.contains("horizontal leg press") {
            ZStack {
                Image(systemName: "figure.seated.side")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .black))
                    .offset(x: 10, y: 2)
            }
            .foregroundStyle(gradient)
        } else if name.contains("leg press") {
            ZStack {
                Image(systemName: "figure.seated.side")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .black))
                    .offset(x: 10, y: 2)
            }
            .foregroundStyle(gradient)
        } else if (name.contains("assisted") || name.contains("assist")) && (name.contains("pull-up") || name.contains("pull up") || name.contains("chin-up") || name.contains("chin up")) {
            ZStack {
                Image(systemName: "figure.climbing")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 11, weight: .black))
                    .offset(y: 10)
            }
            .foregroundStyle(gradient)
        } else if name.contains("alternating") && name.contains("bench press") {
            ZStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 13, weight: .black))
                    .offset(y: -10)
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 10, weight: .black))
                    .offset(y: 7)
            }
            .foregroundStyle(gradient)
        } else if name.contains("pulldown") || name.contains("pull-down") || name.contains("pullover") {
            ZStack {
                Image(systemName: "figure.climbing")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.down")
                    .font(.system(size: 13, weight: .black))
                    .offset(y: -10)
            }
            .foregroundStyle(gradient)
        } else if name.contains("pull-up") || name.contains("pull up") || name.contains("chin-up") || name.contains("chin up") {
            Image(systemName: "figure.climbing")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(gradient)
        } else if name.contains("back extension") {
            ZStack {
                Image(systemName: "figure.flexibility")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .black))
                    .offset(y: 9)
            }
            .foregroundStyle(gradient)
        } else if name.contains("push-up") || name.contains("push up") || name.contains("dip") {
            ZStack {
                Image(systemName: "figure.strengthtraining.functional")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .black))
                    .offset(y: -1)
            }
            .foregroundStyle(gradient)
        } else if name.contains("bench press") || name.contains("chest press") || name.contains("floor press") || name.contains("incline press") {
            ZStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: implementSymbol)
                    .font(.system(size: 17, weight: .bold))
                    .offset(y: -10)
            }
            .foregroundStyle(gradient)
        } else if name.contains("shrug") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: implementSymbol)
                    .font(.system(size: 10, weight: .black))
                    .offset(y: -10)
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 12, weight: .black))
                    .offset(y: -1)
            }
            .foregroundStyle(gradient)
        } else if name.contains("wrist curl") || name.contains("wrist extension") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: implementSymbol)
                    .font(.system(size: 10, weight: .black))
                    .offset(y: -9)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .black))
                    .offset(y: 5)
            }
            .foregroundStyle(gradient)
        } else if name.contains("hip thrust") || name.contains("glute bridge") {
            ZStack {
                Image(systemName: "figure.core.training")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .black))
                    .offset(y: 9)
            }
            .foregroundStyle(gradient)
        } else if name.contains("leg curl") {
            ZStack {
                Image(systemName: "figure.seated.side")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .black))
                    .offset(x: 10, y: 2)
            }
            .foregroundStyle(gradient)
        } else if name.contains("leg extension") {
            ZStack {
                Image(systemName: "figure.seated.side")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .black))
                    .offset(x: 10, y: 2)
            }
            .foregroundStyle(gradient)
        } else if name.contains("deadlift") || name.contains("good morning") || name.contains("pull-through") {
            ZStack {
                Image(systemName: "figure.flexibility")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: implementSymbol)
                    .font(.system(size: 14, weight: .black))
                    .offset(y: -8)
            }
            .foregroundStyle(gradient)
        } else if name.contains("squat") {
            ZStack {
                Image(systemName: "figure.strengthtraining.functional")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: implementSymbol)
                    .font(.system(size: 14, weight: .black))
                    .offset(y: -8)
            }
            .foregroundStyle(gradient)
        } else if name.contains("lunge") || name.contains("step-up") || name.contains("step up") {
            Image(systemName: "figure.walk")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(gradient)
        } else if name.contains("curl") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: implementSymbol)
                    .font(.system(size: 10, weight: .black))
                    .offset(y: -9)
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .black))
                    .offset(y: 7)
            }
            .foregroundStyle(gradient)
        } else if name.contains("upright row") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: implementSymbol)
                    .font(.system(size: 13, weight: .black))
                    .offset(y: -8)
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .black))
                    .offset(y: 8)
            }
            .foregroundStyle(gradient)
        } else if name.contains("external rotation") || name.contains("internal rotation") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: implementSymbol)
                    .font(.system(size: 10, weight: .black))
                    .offset(y: -9)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .black))
                    .offset(y: -1)
            }
            .foregroundStyle(gradient)
        } else if name.contains("wood chop") || name.contains("pallof") || name.contains("twist") || name.contains("rotation") {
            ZStack {
                Image(systemName: "figure.core.training")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .black))
                    .offset(y: -1)
            }
            .foregroundStyle(gradient)
        } else if name.contains("kickback") || name.contains("abduction") || name.contains("adduction") || name.contains("lateral walk") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 12, weight: .black))
                    .offset(y: 3)
            }
            .foregroundStyle(gradient)
        } else if name.contains("triceps") || name.contains("pushdown") || name.contains("skull crusher") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .black))
                    .offset(y: -8)
            }
            .foregroundStyle(gradient)
        } else if name.contains("push-up") || name.contains("push up") || name.contains("dip") {
            Image(systemName: "figure.strengthtraining.functional")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(gradient)
        } else if name.contains("farmer") && name.contains("carry") {
            ZStack {
                Image(systemName: "figure.walk")
                    .font(.system(size: 24, weight: .semibold))
                Image(systemName: implementSymbol)
                    .font(.system(size: 12, weight: .black))
                    .offset(y: -1)
            }
            .foregroundStyle(gradient)
        } else if name.contains("crunch") || name.contains("plank") || name.contains("sit-up") || name.contains("sit up") {
            Image(systemName: "figure.core.training")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(gradient)
        } else if name.contains("row") && !name.contains("upright") {
            Image(systemName: "figure.rower")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(gradient)
        } else {
            Image(systemName: unresolvedFallbackSymbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(gradient)
        }
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
        "cable_kickback": "cable-kickback",
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
        "machine_back_extension": "machine-back-extension",
        "machine_chest_press": "chest-press-machine",
        "machine_converging_chest_press": "chest-press-machine",
        "machine_vertical_chest_press": "chest-press-machine",
        "machine_vertical_chest_fly": "machine-chest-fly",
        "machine_45_back_extension": "machine-back-extension",
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
