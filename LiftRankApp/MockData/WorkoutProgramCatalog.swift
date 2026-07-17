import Foundation

enum WorkoutProgramCatalog {
    static let templates: [WorkoutProgramTemplate] = [
        fullBodyFoundation,
        bodybuildingUpperLower,
        bodybuildingPushPullLegs,
        beginnerPowerlifting,
        intermediatePowerlifting
    ]

    static func template(id: String) -> WorkoutProgramTemplate? {
        templates.first { $0.id == id }
    }

    static func phase(for week: Int) -> (name: String, goal: String, order: Int) {
        switch week {
        case 1...4: ("Foundation", "Build technique and work capacity", 0)
        case 5...8: ("Progressive Overload", "Add productive volume and load", 1)
        default: ("Intensification", "Practice heavier, high-quality work", 2)
        }
    }

    static func weekTitle(_ week: Int) -> String {
        switch week {
        case 4, 8: "Week \(week) · Deload"
        case 12: "Week 12 · Recovery & Performance Check"
        default: "Week \(week)"
        }
    }

    static func rirTarget(for week: Int) -> Int {
        switch week {
        case 1, 5: 3
        case 2, 6, 9: 2
        case 3, 7, 10, 11: 1
        case 4, 8, 12: 4
        default: 2
        }
    }

    static func volumeMultiplier(for week: Int) -> Double {
        switch week {
        case 4, 8, 12: 0.55
        case 9...11: 0.85
        default: 1
        }
    }

    static func percentage(for week: Int) -> Double {
        [0.65, 0.675, 0.70, 0.60, 0.725, 0.75, 0.775, 0.625, 0.80, 0.85, 0.90, 0.60][max(0, min(11, week - 1))]
    }

    private static func exercise(_ id: String, _ sets: Int, _ reps: String, _ rest: Int = 120, _ notes: String = "") -> WorkoutProgramExerciseTemplate {
        WorkoutProgramExerciseTemplate(exerciseID: id, sets: sets, reps: reps, restSeconds: rest, notes: notes)
    }

    private static let fullBodyFoundation = WorkoutProgramTemplate(
        id: "full_body_foundation_12",
        version: 1,
        name: "Full Body Foundation",
        summary: "A beginner-friendly three-day program for learning the major movement patterns and building balanced strength.",
        category: .general,
        level: .beginner,
        daysPerWeek: 3,
        defaultProgression: .rirRepRange,
        sessions: [
            .init(dayIndex: 2, name: "Full Body A", exercises: [
                exercise("back_squat", 3, "6-8", 180), exercise("barbell_bench_press", 3, "6-8", 180),
                exercise("seated_cable_row", 3, "8-12"), exercise("romanian_deadlift", 2, "8-10", 150), exercise("plank", 3, "30-60 sec", 60)
            ]),
            .init(dayIndex: 4, name: "Full Body B", exercises: [
                exercise("conventional_deadlift", 2, "4-6", 210), exercise("barbell_overhead_press", 3, "6-8", 150),
                exercise("lat_pulldown", 3, "8-12"), exercise("bulgarian_split_squat", 2, "8-10"), exercise("ez_bar_curl", 2, "10-12", 75)
            ]),
            .init(dayIndex: 6, name: "Full Body C", exercises: [
                exercise("leg_press", 3, "8-12", 150), exercise("incline_db_press", 3, "8-12", 120),
                exercise("chest_supported_row", 3, "8-12"), exercise("hip_thrust", 2, "8-12", 150), exercise("triceps_pressdown", 2, "10-15", 75)
            ])
        ],
        requiredTrainingMaxExerciseIDs: ["back_squat", "barbell_bench_press", "conventional_deadlift", "barbell_overhead_press"]
    )

    private static let bodybuildingUpperLower = WorkoutProgramTemplate(
        id: "bodybuilding_upper_lower_12",
        version: 1,
        name: "Bodybuilding Upper / Lower",
        summary: "Four weekly sessions balancing compound lifts with focused machine, cable, and dumbbell volume.",
        category: .bodybuilding,
        level: .intermediate,
        daysPerWeek: 4,
        defaultProgression: .rirRepRange,
        sessions: [
            .init(dayIndex: 2, name: "Upper A", exercises: [exercise("barbell_bench_press", 3, "6-10", 180), exercise("lat_pulldown", 3, "8-12"), exercise("incline_db_press", 3, "8-12"), exercise("chest_supported_row", 3, "8-12"), exercise("cable_lateral_raise", 3, "12-20", 60), exercise("triceps_pressdown", 2, "10-15", 75), exercise("ez_bar_curl", 2, "10-12", 75)]),
            .init(dayIndex: 3, name: "Lower A", exercises: [exercise("back_squat", 3, "6-10", 180), exercise("romanian_deadlift", 3, "8-10", 150), exercise("leg_press", 3, "10-15", 150), exercise("lying_leg_curl", 3, "10-15", 90), exercise("machine_standing_calf_raise", 3, "10-15", 75), exercise("cable_crunch", 3, "10-15", 60)]),
            .init(dayIndex: 5, name: "Upper B", exercises: [exercise("barbell_overhead_press", 3, "6-10", 150), exercise("pull_up", 3, "6-10", 150), exercise("machine_chest_press", 3, "10-12"), exercise("seated_cable_row", 3, "10-12"), exercise("rear_delt_fly", 3, "12-20", 60), exercise("overhead_triceps_extension", 2, "10-15", 75), exercise("incline_db_curl", 2, "10-12", 75)]),
            .init(dayIndex: 6, name: "Lower B", exercises: [exercise("conventional_deadlift", 2, "5-6", 210), exercise("hack_squat", 3, "8-12", 150), exercise("hip_thrust", 3, "8-12", 150), exercise("leg_extension", 3, "12-15", 75), exercise("seated_leg_curl", 3, "10-15", 90), exercise("machine_seated_calf_raise", 3, "10-15", 75)])
        ],
        requiredTrainingMaxExerciseIDs: ["back_squat", "barbell_bench_press", "conventional_deadlift", "barbell_overhead_press"]
    )

    private static let bodybuildingPushPullLegs = WorkoutProgramTemplate(
        id: "bodybuilding_ppl_12",
        version: 1,
        name: "Bodybuilding Push / Pull / Legs",
        summary: "A higher-frequency six-day split with separate A and B sessions for complete muscular development.",
        category: .bodybuilding,
        level: .intermediate,
        daysPerWeek: 6,
        defaultProgression: .rirRepRange,
        sessions: [
            .init(dayIndex: 2, name: "Push A", exercises: [exercise("barbell_bench_press", 3, "6-10", 180), exercise("incline_db_press", 3, "8-12"), exercise("machine_shoulder_press", 3, "8-10"), exercise("cable_lateral_raise", 3, "12-20", 60), exercise("triceps_pressdown", 3, "10-15", 75)]),
            .init(dayIndex: 3, name: "Pull A", exercises: [exercise("conventional_deadlift", 2, "4-6", 210), exercise("lat_pulldown", 3, "8-12"), exercise("chest_supported_row", 3, "8-12"), exercise("rear_delt_fly", 3, "12-20", 60), exercise("ez_bar_curl", 3, "8-12", 75)]),
            .init(dayIndex: 4, name: "Legs A", exercises: [exercise("back_squat", 3, "6-10", 180), exercise("romanian_deadlift", 3, "8-10", 150), exercise("leg_press", 3, "10-15", 150), exercise("lying_leg_curl", 3, "10-15", 90), exercise("machine_standing_calf_raise", 3, "10-15", 75)]),
            .init(dayIndex: 5, name: "Push B", exercises: [exercise("barbell_overhead_press", 3, "6-10", 150), exercise("machine_chest_press", 3, "8-12"), exercise("cable_fly", 3, "10-15", 75), exercise("cable_lateral_raise", 3, "12-20", 60), exercise("overhead_triceps_extension", 3, "10-15", 75)]),
            .init(dayIndex: 6, name: "Pull B", exercises: [exercise("pull_up", 3, "6-10", 150), exercise("seated_cable_row", 3, "8-12"), exercise("cable_pullover", 3, "10-15", 75), exercise("rear_delt_fly", 3, "12-20", 60), exercise("incline_db_curl", 3, "10-12", 75)]),
            .init(dayIndex: 7, name: "Legs B", exercises: [exercise("hack_squat", 3, "8-12", 150), exercise("hip_thrust", 3, "8-12", 150), exercise("bulgarian_split_squat", 3, "8-10"), exercise("leg_extension", 3, "12-15", 75), exercise("seated_leg_curl", 3, "10-15", 90), exercise("machine_seated_calf_raise", 3, "10-15", 75)])
        ],
        requiredTrainingMaxExerciseIDs: ["back_squat", "barbell_bench_press", "conventional_deadlift", "barbell_overhead_press"]
    )

    private static let beginnerPowerlifting = WorkoutProgramTemplate(
        id: "beginner_powerlifting_12",
        version: 1,
        name: "Beginner Powerlifting",
        summary: "Three focused days for practicing squat, bench press, and deadlift with simple repeatable prescriptions.",
        category: .powerlifting,
        level: .beginner,
        daysPerWeek: 3,
        defaultProgression: .fixed,
        sessions: [
            .init(dayIndex: 2, name: "Squat + Bench", exercises: [exercise("back_squat", 3, "5", 210), exercise("barbell_bench_press", 3, "5", 180), exercise("seated_cable_row", 3, "8-10"), exercise("cable_crunch", 3, "10-15", 60)]),
            .init(dayIndex: 4, name: "Deadlift + Press", exercises: [exercise("conventional_deadlift", 3, "5", 240), exercise("barbell_overhead_press", 3, "5", 180), exercise("lat_pulldown", 3, "8-10"), exercise("bulgarian_split_squat", 2, "8-10")]),
            .init(dayIndex: 6, name: "Squat + Bench Volume", exercises: [exercise("back_squat", 3, "5", 210, "Use a lighter, technically perfect load."), exercise("barbell_bench_press", 4, "5", 180), exercise("romanian_deadlift", 3, "6-8", 150), exercise("triceps_pressdown", 2, "10-15", 75)])
        ],
        requiredTrainingMaxExerciseIDs: ["back_squat", "barbell_bench_press", "conventional_deadlift", "barbell_overhead_press"]
    )

    private static let intermediatePowerlifting = WorkoutProgramTemplate(
        id: "intermediate_powerlifting_12",
        version: 1,
        name: "Intermediate Powerlifting",
        summary: "A four-day base-to-peak cycle using competition lifts, controlled intensity, and tapered accessories.",
        category: .powerlifting,
        level: .intermediate,
        daysPerWeek: 4,
        defaultProgression: .percentage,
        sessions: [
            .init(dayIndex: 2, name: "Squat + Bench", exercises: [exercise("back_squat", 4, "5", 240), exercise("barbell_bench_press", 4, "5", 210), exercise("leg_press", 3, "8-12", 120), exercise("chest_supported_row", 3, "8-12")]),
            .init(dayIndex: 3, name: "Deadlift + Bench", exercises: [exercise("conventional_deadlift", 3, "4", 270), exercise("barbell_bench_press", 3, "6", 180, "Use a controlled volume load."), exercise("lat_pulldown", 3, "8-12"), exercise("lying_leg_curl", 3, "10-15", 90)]),
            .init(dayIndex: 5, name: "Squat Volume + Press", exercises: [exercise("back_squat", 3, "6", 210, "Use a controlled volume load."), exercise("barbell_overhead_press", 3, "6", 180), exercise("romanian_deadlift", 3, "6-8", 150), exercise("cable_crunch", 3, "10-15", 60)]),
            .init(dayIndex: 7, name: "Bench Intensity + Pull", exercises: [exercise("barbell_bench_press", 4, "3", 210), exercise("conventional_deadlift", 2, "5", 240, "Use a lighter technique load."), exercise("seated_cable_row", 3, "8-12"), exercise("triceps_pressdown", 3, "10-15", 75)])
        ],
        requiredTrainingMaxExerciseIDs: ["back_squat", "barbell_bench_press", "conventional_deadlift", "barbell_overhead_press"]
    )
}

struct PersonalWorkoutPlanSeed {
    var plan: WorkoutPlan
    var phases: [WorkoutPhase]
    var weeks: [WorkoutWeek]
    var sessions: [WorkoutSession]
    var prescriptions: [WorkoutExercisePrescription]
}

/// A local-only program imported for the demo owner's personal use. It is
/// intentionally excluded from `WorkoutProgramCatalog.templates` so it can
/// never appear as a public/bundled program choice.
enum PersonalWorkoutPlanCatalog {
    static let planID = UUID(uuidString: "A1000000-0000-0000-0000-0000000000B1")!
    static let name = "BTS Beginner (Private)"

    private struct Movement {
        var id: String
        var name: String
        var bodyPart: String
        var equipment: String
    }

    private struct PrescriptionSeed {
        var movement: Movement
        var sets: Int
        var reps: String
        var restSeconds: Int
        var targetRIR: Int
        var sourceRPE: String
        var toFailure: Bool
    }

    private struct SessionSeed {
        var day: String
        var name: String
        var exercises: [PrescriptionSeed]
    }

    static func makeSeed(createdAt: Date = .now) -> PersonalWorkoutPlanSeed {
        let plan = WorkoutPlan(
            id: planID,
            name: name,
            createdAt: createdAt,
            goal: "Complete the private 12-week beginner bodybuilding transformation program.",
            notes: "Private PDF import for Robert. Five workouts per week. Complete a 5-10 minute general warm-up and exercise-specific warm-up before each session.",
            isActive: false
        )

        let foundation = WorkoutPhase(
            id: UUID(), planID: planID, name: "Foundation Block", order: 0,
            goal: "Master technique and progressively build working volume.", durationWeeks: 5
        )
        let ramping = WorkoutPhase(
            id: UUID(), planID: planID, name: "Ramping Week", order: 1,
            goal: "Introduce the second exercise rotation at low volume.", durationWeeks: 1
        )
        let progression = WorkoutPhase(
            id: UUID(), planID: planID, name: "Progression Block", order: 2,
            goal: "Progress the second rotation with higher volume and controlled high effort.", durationWeeks: 6
        )
        let phases = [foundation, ramping, progression]

        var weeks: [WorkoutWeek] = []
        var sessions: [WorkoutSession] = []
        var prescriptions: [WorkoutExercisePrescription] = []

        for weekNumber in 1...12 {
            let phase = weekNumber <= 5 ? foundation : (weekNumber == 6 ? ramping : progression)
            let week = WorkoutWeek(
                id: UUID(),
                planID: planID,
                phaseID: phase.id,
                weekNumber: weekNumber,
                title: "Week \(weekNumber) · \(phase.name)",
                notes: weekNotes(weekNumber)
            )
            weeks.append(week)

            for (sessionOrder, sourceSession) in sessionSeeds(for: weekNumber).enumerated() {
                let session = WorkoutSession(
                    id: UUID(),
                    weekID: week.id,
                    day: sourceSession.day,
                    name: sourceSession.name,
                    order: sessionOrder,
                    notes: "Complete the general and exercise-specific warm-up before working sets."
                )
                sessions.append(session)

                for (exerciseOrder, source) in sourceSession.exercises.enumerated() {
                    let profile = ExerciseMuscleProfileResolver.profile(
                        name: source.movement.name,
                        bodyPart: source.movement.bodyPart
                    )
                    let effortNote = source.toFailure
                        ? "Source target: early sets RPE \(source.sourceRPE); final set to technical failure (RPE 10)."
                        : "Source target: \(source.sourceRPE)."
                    prescriptions.append(
                        WorkoutExercisePrescription(
                            id: UUID(),
                            sessionID: session.id,
                            exerciseID: source.movement.id,
                            exerciseName: source.movement.name,
                            bodyPart: source.movement.bodyPart,
                            equipment: source.movement.equipment,
                            sets: source.sets,
                            reps: source.reps,
                            restSeconds: source.restSeconds,
                            order: exerciseOrder,
                            notes: effortNote,
                            muscleProfile: profile,
                            targetRIR: source.targetRIR
                        )
                    )
                }
            }
        }

        return PersonalWorkoutPlanSeed(
            plan: plan,
            phases: phases,
            weeks: weeks,
            sessions: sessions,
            prescriptions: prescriptions
        )
    }

    private static func weekNotes(_ week: Int) -> String {
        switch week {
        case 1:
            return "Intro week. Keep most working sets around RPE 6-7 with 3-4 reps in reserve."
        case 2:
            return "Continue the foundation rotation and increase effort slightly while preserving technique."
        case 3...5:
            return "Foundation volume phase. Early sets remain controlled; final sets are moderately harder."
        case 6:
            return "Ramping week. Learn the second exercise rotation with one working set per exercise."
        default:
            return "Progression phase. Follow the listed RIR target and stop failure sets at technical failure."
        }
    }

    private static func sessionSeeds(for week: Int) -> [SessionSeed] {
        week <= 5 ? foundationSessions(week: week) : progressionSessions(week: week)
    }

    private static func foundationSessions(week: Int) -> [SessionSeed] {
        let sets = week <= 2 ? 1 : 2
        func effort(_ harder: Bool) -> (rir: Int, text: String) {
            if week == 1 { return (harder ? 3 : 4, "last set RPE ~\(harder ? 7 : 6)") }
            return (harder ? 2 : 3, week == 2 ? "last set RPE ~\(harder ? 8 : 7)" : "early sets RPE ~7; last set RPE ~\(harder ? 8 : 7)")
        }
        func p(_ key: String, _ reps: String, _ rest: Int, harder: Bool) -> PrescriptionSeed {
            let target = effort(harder)
            return PrescriptionSeed(movement: movement(key), sets: sets, reps: reps, restSeconds: rest, targetRIR: target.rir, sourceRPE: target.text, toFailure: false)
        }

        return [
            SessionSeed(day: "Monday", name: "Upper (Strength Focus)", exercises: [
                p("inclineBarbell", "6-8", 240, harder: false), p("crossoverLadder", "8-10", 90, harder: true),
                p("widePullUp", "8-10", 150, harder: false), p("highCableLateral", "8-10", 90, harder: week != 1),
                p("pendlayDeficit", "6-8", 150, harder: false), p("overheadCableBar", "8-10", 90, harder: true),
                p("bayesianCurl", "8-10", 90, harder: true)
            ]),
            SessionSeed(day: "Tuesday", name: "Lower (Strength Focus)", exercises: [
                p("lyingLegCurl", "8-10", 90, harder: true), p("smithSquat", "6-8", 240, harder: false),
                p("barbellRDL", "6-8", 150, harder: false), p("legExtension", "8-10", 90, harder: true),
                p("standingCalf", "6-8", 90, harder: true), p("cableCrunch", "8-10", 90, harder: true)
            ]),
            SessionSeed(day: "Thursday", name: "Pull (Hypertrophy Focus)", exercises: [
                p("neutralPulldown", "8-10", 150, harder: false), p("chestSupportedMachineRow", "8-10", 150, harder: false),
                p("oneArmRearDelt", "10-12", 90, harder: true), p("machineShrug", "10-12", 90, harder: false),
                p("ezCableCurl", "10-12", 90, harder: true), p("machinePreacher", "12-15", 90, harder: true)
            ]),
            SessionSeed(day: "Friday", name: "Push (Hypertrophy Focus)", exercises: [
                p("benchPress", "8-10", 240, harder: false), p("machineShoulder", "8-10", 150, harder: false),
                p("bottomHalfDBFly", "10-12", 90, harder: true), p("highCableLateral", "10-12", 90, harder: true),
                p("overheadCableBar", "10-12", 90, harder: true), p("cableTricepsKickback", "12-15", 90, harder: true),
                p("lyingLegRaise", "10-20", 90, harder: true)
            ]),
            SessionSeed(day: "Saturday", name: "Legs (Hypertrophy Focus)", exercises: [
                p("legPress", "8-10", 150, harder: false), p("seatedLegCurl", "10-12", 90, harder: week != 1),
                p("walkingLunge", "8-10", 150, harder: true), p("hipAbduction", "10-12", 90, harder: week != 1),
                p("standingCalf", "10-12", 90, harder: true)
            ])
        ]
    }

    private static func progressionSessions(week: Int) -> [SessionSeed] {
        let isRamp = week == 6
        func p(_ key: String, _ sets: Int, _ reps: String, _ rest: Int, lastRPE: Int, failure: Bool = false) -> PrescriptionSeed {
            let resolvedSets = isRamp ? 1 : sets
            let resolvedRPE = isRamp ? (lastRPE >= 9 ? 7 : 6) : lastRPE
            let rir = max(0, 10 - resolvedRPE)
            let source = isRamp ? "last set RPE ~\(resolvedRPE)" : (failure ? "RPE 8-9 before final set" : "last set RPE ~\(lastRPE == 8 ? "7-8" : "8-9")")
            return PrescriptionSeed(movement: movement(key), sets: resolvedSets, reps: reps, restSeconds: rest, targetRIR: rir, sourceRPE: source, toFailure: !isRamp && failure)
        }

        return [
            SessionSeed(day: "Monday", name: "Upper (Strength Focus)", exercises: [
                p("inclineDB", 3, "8-10", 240, lastRPE: 8), p("pecDeck", 2, "10-12", 90, lastRPE: 9),
                p("dualHandlePulldown", 3, "10-12", 150, lastRPE: 8), p("highCableLateral", 2, "10-12", 90, lastRPE: 10, failure: true),
                p("smithRow", 2, "8-10", 150, lastRPE: 8), p("overheadCableBar", 2, "10-12", 90, lastRPE: 10, failure: true),
                p("bayesianCurl", 2, "10-12", 90, lastRPE: 10, failure: true)
            ]),
            SessionSeed(day: "Tuesday", name: "Lower (Strength Focus)", exercises: [
                p("lyingLegCurl", 2, "10-12", 90, lastRPE: 9), p("elevatedSmithLunge", 3, "8-10", 240, lastRPE: 8),
                p("hyperextension45", 3, "8-10", 150, lastRPE: 8), p("legExtension", 2, "10-12", 90, lastRPE: 10, failure: true),
                p("legPressCalf", 2, "8-10", 90, lastRPE: 10, failure: true), p("machineCrunch", 2, "10-12", 90, lastRPE: 10, failure: true)
            ]),
            SessionSeed(day: "Thursday", name: "Pull (Hypertrophy Focus)", exercises: [
                p("leanBackPulldown", 2, "10-12", 150, lastRPE: 8), p("chestSupportedTBar", 3, "10-12", 150, lastRPE: 10, failure: true),
                p("oneArmRearDelt", 2, "12-15", 90, lastRPE: 10, failure: true), p("pausedShrugIn", 2, "12-15", 90, lastRPE: 9),
                p("ropeHammerCurl", 3, "12-15", 90, lastRPE: 9), p("concentrationCurl", 2, "15-20", 90, lastRPE: 10, failure: true)
            ]),
            SessionSeed(day: "Friday", name: "Push (Hypertrophy Focus)", exercises: [
                p("machineChest", 3, "10-12", 240, lastRPE: 8), p("seatedDBShoulder", 2, "10-12", 150, lastRPE: 8),
                p("bottomHalfCableFly", 2, "12-15", 90, lastRPE: 10, failure: true), p("highCableLateral", 2, "12-15", 90, lastRPE: 10, failure: true),
                p("ezSkullCrusher", 3, "12-15", 90, lastRPE: 9), p("straightBarPressdown", 2, "15-20", 90, lastRPE: 10, failure: true),
                p("abWheel", 2, "12-15", 90, lastRPE: 10, failure: true)
            ]),
            SessionSeed(day: "Saturday", name: "Legs (Hypertrophy Focus)", exercises: [
                p("hackSquat", 3, "10-12", 150, lastRPE: 8), p("seatedLegCurl", 2, "12-15", 90, lastRPE: 10, failure: true),
                p("walkingLunge", 2, "10-12", 150, lastRPE: 8), p("hipAbduction", 2, "12-15", 90, lastRPE: 10, failure: true),
                p("standingCalf", 3, "12-15", 90, lastRPE: 10, failure: true)
            ])
        ]
    }

    private static func movement(_ key: String) -> Movement {
        guard let movement = movements[key] else {
            preconditionFailure("Unknown private workout movement: \(key)")
        }
        return movement
    }

    private static let movements: [String: Movement] = [
        "inclineBarbell": .init(id: "private_bts_incline_barbell_press", name: "45° Incline Barbell Press", bodyPart: "Upper Chest", equipment: "Barbell"),
        "crossoverLadder": .init(id: "private_bts_cable_crossover_ladder", name: "Cable Crossover Ladder", bodyPart: "Chest", equipment: "Cable"),
        "widePullUp": .init(id: "private_bts_wide_grip_pull_up", name: "Wide-Grip Pull-Up", bodyPart: "Lats", equipment: "Bodyweight"),
        "highCableLateral": .init(id: "private_bts_high_cable_lateral_raise", name: "High-Cable Lateral Raise", bodyPart: "Side Delts", equipment: "Cable"),
        "pendlayDeficit": .init(id: "private_bts_pendlay_deficit_row", name: "Pendlay Deficit Row", bodyPart: "Upper Back", equipment: "Barbell"),
        "overheadCableBar": .init(id: "private_bts_overhead_cable_triceps_bar", name: "Overhead Cable Triceps Extension (Bar)", bodyPart: "Triceps", equipment: "Cable"),
        "bayesianCurl": .init(id: "cable_bayesian_curl", name: "Bayesian Cable Curl", bodyPart: "Biceps", equipment: "Cable"),
        "lyingLegCurl": .init(id: "lying_leg_curl", name: "Lying Leg Curl", bodyPart: "Hamstrings", equipment: "Machine"),
        "smithSquat": .init(id: "machine_smith_back_squat", name: "Smith Machine Squat", bodyPart: "Quads", equipment: "Machine"),
        "barbellRDL": .init(id: "romanian_deadlift", name: "Barbell RDL", bodyPart: "Hamstrings", equipment: "Barbell"),
        "legExtension": .init(id: "leg_extension", name: "Leg Extension", bodyPart: "Quads", equipment: "Machine"),
        "standingCalf": .init(id: "machine_standing_calf_raise", name: "Standing Calf Raise", bodyPart: "Calves", equipment: "Machine"),
        "cableCrunch": .init(id: "cable_crunch", name: "Cable Crunch", bodyPart: "Core", equipment: "Cable"),
        "neutralPulldown": .init(id: "machine_neutral_grip_pulldown", name: "Neutral-Grip Lat Pulldown", bodyPart: "Lats", equipment: "Cable"),
        "chestSupportedMachineRow": .init(id: "chest_supported_row", name: "Chest-Supported Machine Row", bodyPart: "Upper Back", equipment: "Machine"),
        "oneArmRearDelt": .init(id: "private_bts_one_arm_45_cable_rear_delt", name: "1-Arm 45° Cable Rear Delt Flye", bodyPart: "Rear Delts", equipment: "Cable"),
        "machineShrug": .init(id: "machine_shrug", name: "Machine Shrug", bodyPart: "Traps", equipment: "Machine"),
        "ezCableCurl": .init(id: "private_bts_ez_bar_cable_curl", name: "EZ-Bar Cable Curl", bodyPart: "Biceps", equipment: "Cable"),
        "machinePreacher": .init(id: "machine_preacher_curl", name: "Machine Preacher Curl", bodyPart: "Biceps", equipment: "Machine"),
        "benchPress": .init(id: "barbell_bench_press", name: "Barbell Bench Press", bodyPart: "Chest", equipment: "Barbell"),
        "machineShoulder": .init(id: "machine_shoulder_press", name: "Machine Shoulder Press", bodyPart: "Shoulders", equipment: "Machine"),
        "bottomHalfDBFly": .init(id: "private_bts_bottom_half_db_fly", name: "Bottom-Half DB Flye", bodyPart: "Chest", equipment: "Dumbbell"),
        "cableTricepsKickback": .init(id: "private_bts_cable_triceps_kickback", name: "Cable Triceps Kickback", bodyPart: "Triceps", equipment: "Cable"),
        "lyingLegRaise": .init(id: "private_bts_lying_leg_raise", name: "Lying Leg Raise", bodyPart: "Core", equipment: "Bodyweight"),
        "legPress": .init(id: "leg_press", name: "Leg Press", bodyPart: "Quads/Glutes", equipment: "Machine"),
        "seatedLegCurl": .init(id: "seated_leg_curl", name: "Seated Leg Curl", bodyPart: "Hamstrings", equipment: "Machine"),
        "walkingLunge": .init(id: "dumbbell_walking_lunge", name: "Walking Lunge", bodyPart: "Quads/Glutes", equipment: "Dumbbell"),
        "hipAbduction": .init(id: "machine_hip_abductor", name: "Machine Hip Abduction", bodyPart: "Glutes", equipment: "Machine"),
        "inclineDB": .init(id: "incline_db_press", name: "45° Incline DB Press", bodyPart: "Upper Chest", equipment: "Dumbbell"),
        "pecDeck": .init(id: "pec_deck", name: "Pec Deck", bodyPart: "Chest", equipment: "Machine"),
        "dualHandlePulldown": .init(id: "private_bts_dual_handle_lat_pulldown", name: "Dual-Handle Lat Pulldown", bodyPart: "Lats/Mid Back", equipment: "Cable"),
        "smithRow": .init(id: "private_bts_smith_machine_row", name: "Smith Machine Row", bodyPart: "Upper Back", equipment: "Machine"),
        "elevatedSmithLunge": .init(id: "private_bts_elevated_smith_lunge", name: "Smith Machine Static Lunge w/ Elevated Front Foot", bodyPart: "Quads/Glutes", equipment: "Machine"),
        "hyperextension45": .init(id: "private_bts_45_hyperextension", name: "45° Hyperextension", bodyPart: "Glutes/Hamstrings/Lower Back", equipment: "Bodyweight"),
        "legPressCalf": .init(id: "private_bts_leg_press_calf_press", name: "Leg Press Calf Press", bodyPart: "Calves", equipment: "Machine"),
        "machineCrunch": .init(id: "machine_abdominal_crunch", name: "Machine Crunch", bodyPart: "Core", equipment: "Machine"),
        "leanBackPulldown": .init(id: "private_bts_lean_back_lat_pulldown", name: "Lean-Back Lat Pulldown", bodyPart: "Lats/Mid Back", equipment: "Cable"),
        "chestSupportedTBar": .init(id: "machine_t_bar_row", name: "Chest-Supported T-Bar Row", bodyPart: "Upper Back", equipment: "Machine"),
        "pausedShrugIn": .init(id: "private_bts_cable_paused_shrug_in", name: "Cable Paused Shrug-In", bodyPart: "Traps", equipment: "Cable"),
        "ropeHammerCurl": .init(id: "cable_rope_hammer_curl", name: "Cable Rope Hammer Curl", bodyPart: "Biceps/Forearms", equipment: "Cable"),
        "concentrationCurl": .init(id: "dumbbell_concentration_curl", name: "DB Concentration Curl", bodyPart: "Biceps", equipment: "Dumbbell"),
        "machineChest": .init(id: "machine_chest_press", name: "Machine Chest Press", bodyPart: "Chest", equipment: "Machine"),
        "seatedDBShoulder": .init(id: "db_shoulder_press", name: "Seated DB Shoulder Press", bodyPart: "Shoulders", equipment: "Dumbbell"),
        "bottomHalfCableFly": .init(id: "private_bts_bottom_half_seated_cable_fly", name: "Bottom-Half Seated Cable Flye", bodyPart: "Chest", equipment: "Cable"),
        "ezSkullCrusher": .init(id: "private_bts_ez_bar_skull_crusher", name: "EZ-Bar Skull Crusher", bodyPart: "Triceps", equipment: "Barbell"),
        "straightBarPressdown": .init(id: "cable_straight_bar_pushdown", name: "Triceps Pressdown (Bar)", bodyPart: "Triceps", equipment: "Cable"),
        "abWheel": .init(id: "private_bts_ab_wheel_rollout", name: "Ab Wheel Rollout", bodyPart: "Core", equipment: "Other"),
        "hackSquat": .init(id: "hack_squat", name: "Hack Squat", bodyPart: "Quads", equipment: "Machine")
    ]
}
