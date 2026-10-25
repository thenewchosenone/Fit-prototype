import type { ProgramExerciseTemplate, WorkoutProgramTemplate } from "./types";

const exercise = (
  exerciseId: string,
  sets: number,
  reps: string,
  restSeconds = 120,
  substitutionExerciseIds: string[] = [],
  notes?: string
): ProgramExerciseTemplate => ({ exerciseId, sets, reps, restSeconds, substitutionExerciseIds, notes });

const catalog = {
  inclineDumbbellPress: "catalog-chest-dumbbells-dumbbell-incline-press",
  chestSupportedRow: "catalog-back-dumbbells-chest-supported-dumbbell-row",
  cableLateralRaise: "catalog-shoulders-cable-single-arm-cable-lateral-raise",
  bulgarianSplitSquat: "catalog-quads-dumbbells-bulgarian-split-squat",
  standingCalfRaise: "catalog-calves-machine-standing-calf-raise-machine",
  seatedCalfRaise: "catalog-calves-machine-seated-calf-raise-machine",
  rearDeltFly: "catalog-shoulders-machine-rear-deltoid-fly-machine",
  overheadTricepsExtension: "catalog-arms-cable-overhead-cable-triceps-extension",
  inclineDumbbellCurl: "catalog-arms-dumbbells-incline-dumbbell-curl",
  seatedLegCurl: "catalog-hamstrings-machine-seated-leg-curl",
  machineShoulderPress: "catalog-shoulders-machine-shoulder-press-machine",
  cablePullover: "catalog-back-cable-cable-pullover"
} as const;

export const workoutProgramTemplates: readonly WorkoutProgramTemplate[] = [
  {
    id: "full-body-foundation-12",
    version: 1,
    name: "Full Body Foundation",
    summary: "A beginner-friendly three-day program for learning the major movement patterns and building balanced strength.",
    category: "General",
    level: "Beginner",
    durationWeeks: 12,
    daysPerWeek: 3,
    progressionMethod: "RIR + Rep Range",
    sessions: [
      { day: "Monday", name: "Full Body A", exercises: [exercise("back-squat", 3, "6-8", 180, ["front-squat", "leg-press"]), exercise("barbell-bench", 3, "6-8", 180, ["db-bench", "machine-chest"]), exercise("seated-row", 3, "8-12", 120, ["barbell-row", catalog.chestSupportedRow]), exercise("rdl", 2, "8-10", 150, ["deadlift", "leg-curl"]), exercise("plank", 3, "30-60 sec", 60, ["cable-crunch"])] },
      { day: "Wednesday", name: "Full Body B", exercises: [exercise("deadlift", 2, "4-6", 210, ["rdl"]), exercise("ohp", 3, "6-8", 150, [catalog.machineShoulderPress]), exercise("lat-pulldown", 3, "8-12", 120, ["pull-up"]), exercise(catalog.bulgarianSplitSquat, 2, "8-10", 120, ["leg-press", "front-squat"]), exercise("barbell-curl", 2, "10-12", 75, [catalog.inclineDumbbellCurl])] },
      { day: "Friday", name: "Full Body C", exercises: [exercise("leg-press", 3, "8-12", 150, ["back-squat", "hack-squat"]), exercise(catalog.inclineDumbbellPress, 3, "8-12", 120, ["incline-bench", "db-bench"]), exercise(catalog.chestSupportedRow, 3, "8-12", 120, ["seated-row", "barbell-row"]), exercise("hip-thrust", 2, "8-12", 150, ["rdl"]), exercise("tricep-pushdown", 2, "10-15", 75, [catalog.overheadTricepsExtension])] }
    ]
  },
  {
    id: "bodybuilding-upper-lower-12",
    version: 1,
    name: "Bodybuilding Upper / Lower",
    summary: "Four weekly sessions balancing compound lifts with focused machine, cable, and dumbbell volume.",
    category: "Bodybuilding",
    level: "Intermediate",
    durationWeeks: 12,
    daysPerWeek: 4,
    progressionMethod: "RIR + Rep Range",
    sessions: [
      { day: "Monday", name: "Upper A", exercises: [exercise("barbell-bench", 3, "6-10", 180, ["db-bench", "machine-chest"]), exercise("lat-pulldown", 3, "8-12", 120, ["pull-up"]), exercise(catalog.inclineDumbbellPress, 3, "8-12", 120, ["incline-bench"]), exercise(catalog.chestSupportedRow, 3, "8-12", 120, ["seated-row"]), exercise(catalog.cableLateralRaise, 3, "12-20", 60, ["lateral-raise"]), exercise("tricep-pushdown", 2, "10-15", 75, [catalog.overheadTricepsExtension]), exercise("barbell-curl", 2, "10-12", 75, [catalog.inclineDumbbellCurl])] },
      { day: "Tuesday", name: "Lower A", exercises: [exercise("back-squat", 3, "6-10", 180, ["front-squat", "leg-press"]), exercise("rdl", 3, "8-10", 150, ["deadlift"]), exercise("leg-press", 3, "10-15", 150, ["hack-squat"]), exercise("leg-curl", 3, "10-15", 90, [catalog.seatedLegCurl]), exercise(catalog.standingCalfRaise, 3, "10-15", 75, [catalog.seatedCalfRaise]), exercise("cable-crunch", 3, "10-15", 60, ["plank"])] },
      { day: "Thursday", name: "Upper B", exercises: [exercise("ohp", 3, "6-10", 150, [catalog.machineShoulderPress]), exercise("pull-up", 3, "6-10", 150, ["lat-pulldown"]), exercise("machine-chest", 3, "10-12", 120, ["db-bench"]), exercise("seated-row", 3, "10-12", 120, [catalog.chestSupportedRow]), exercise(catalog.rearDeltFly, 3, "12-20", 60, ["face-pull"]), exercise(catalog.overheadTricepsExtension, 2, "10-15", 75, ["tricep-pushdown"]), exercise(catalog.inclineDumbbellCurl, 2, "10-12", 75, ["barbell-curl"])] },
      { day: "Friday", name: "Lower B", exercises: [exercise("deadlift", 2, "5-6", 210, ["rdl"]), exercise("hack-squat", 3, "8-12", 150, ["leg-press"]), exercise("hip-thrust", 3, "8-12", 150, ["rdl"]), exercise("leg-extension", 3, "12-15", 75, ["leg-press"]), exercise(catalog.seatedLegCurl, 3, "10-15", 90, ["leg-curl"]), exercise(catalog.seatedCalfRaise, 3, "10-15", 75, [catalog.standingCalfRaise])] }
    ]
  },
  {
    id: "bodybuilding-push-pull-legs-12",
    version: 1,
    name: "Bodybuilding Push / Pull / Legs",
    summary: "A higher-frequency six-day split with separate A and B sessions for complete muscular development.",
    category: "Bodybuilding",
    level: "Intermediate",
    durationWeeks: 12,
    daysPerWeek: 6,
    progressionMethod: "RIR + Rep Range",
    sessions: [
      { day: "Monday", name: "Push A", exercises: [exercise("barbell-bench", 3, "6-10", 180, ["db-bench"]), exercise(catalog.inclineDumbbellPress, 3, "8-12", 120, ["incline-bench"]), exercise(catalog.machineShoulderPress, 3, "8-10", 120, ["ohp"]), exercise(catalog.cableLateralRaise, 3, "12-20", 60, ["lateral-raise"]), exercise("tricep-pushdown", 3, "10-15", 75, [catalog.overheadTricepsExtension])] },
      { day: "Tuesday", name: "Pull A", exercises: [exercise("deadlift", 2, "4-6", 210, ["rdl"]), exercise("lat-pulldown", 3, "8-12", 120, ["pull-up"]), exercise(catalog.chestSupportedRow, 3, "8-12", 120, ["seated-row"]), exercise(catalog.rearDeltFly, 3, "12-20", 60, ["face-pull"]), exercise("barbell-curl", 3, "8-12", 75, [catalog.inclineDumbbellCurl])] },
      { day: "Wednesday", name: "Legs A", exercises: [exercise("back-squat", 3, "6-10", 180, ["front-squat"]), exercise("rdl", 3, "8-10", 150, ["deadlift"]), exercise("leg-press", 3, "10-15", 150, ["hack-squat"]), exercise("leg-curl", 3, "10-15", 90, [catalog.seatedLegCurl]), exercise(catalog.standingCalfRaise, 3, "10-15", 75, [catalog.seatedCalfRaise])] },
      { day: "Thursday", name: "Push B", exercises: [exercise("ohp", 3, "6-10", 150, [catalog.machineShoulderPress]), exercise("machine-chest", 3, "8-12", 120, ["db-bench"]), exercise("cable-fly", 3, "10-15", 75, ["pec-deck"]), exercise("lateral-raise", 3, "12-20", 60, [catalog.cableLateralRaise]), exercise(catalog.overheadTricepsExtension, 3, "10-15", 75, ["tricep-pushdown"])] },
      { day: "Friday", name: "Pull B", exercises: [exercise("pull-up", 3, "6-10", 150, ["lat-pulldown"]), exercise("seated-row", 3, "8-12", 120, ["barbell-row"]), exercise(catalog.cablePullover, 3, "10-15", 75, ["lat-pulldown"]), exercise("face-pull", 3, "12-20", 60, [catalog.rearDeltFly]), exercise(catalog.inclineDumbbellCurl, 3, "10-12", 75, ["barbell-curl"])] },
      { day: "Saturday", name: "Legs B", exercises: [exercise("hack-squat", 3, "8-12", 150, ["leg-press"]), exercise("hip-thrust", 3, "8-12", 150, ["rdl"]), exercise(catalog.bulgarianSplitSquat, 3, "8-10", 120, ["front-squat"]), exercise("leg-extension", 3, "12-15", 75, ["leg-press"]), exercise(catalog.seatedLegCurl, 3, "10-15", 90, ["leg-curl"]), exercise(catalog.seatedCalfRaise, 3, "10-15", 75, [catalog.standingCalfRaise])] }
    ]
  },
  {
    id: "beginner-powerlifting-12",
    version: 1,
    name: "Beginner Powerlifting",
    summary: "Three focused days for practicing squat, bench press, and deadlift with simple repeatable prescriptions.",
    category: "Powerlifting",
    level: "Beginner",
    durationWeeks: 12,
    daysPerWeek: 3,
    progressionMethod: "Fixed Sets + Reps",
    sessions: [
      { day: "Monday", name: "Squat + Bench", exercises: [exercise("back-squat", 3, "5", 210, ["front-squat"]), exercise("barbell-bench", 3, "5", 180, ["db-bench"]), exercise("seated-row", 3, "8-10", 120, ["barbell-row"]), exercise("cable-crunch", 3, "10-15", 60, ["plank"])] },
      { day: "Wednesday", name: "Deadlift + Press", exercises: [exercise("deadlift", 3, "5", 240, ["rdl"]), exercise("ohp", 3, "5", 180, [catalog.machineShoulderPress]), exercise("lat-pulldown", 3, "8-10", 120, ["pull-up"]), exercise(catalog.bulgarianSplitSquat, 2, "8-10", 120, ["leg-press"])] },
      { day: "Friday", name: "Squat + Bench Volume", exercises: [exercise("back-squat", 3, "5", 210, ["front-squat"], "Use a lighter, technically perfect load."), exercise("barbell-bench", 4, "5", 180, ["db-bench"]), exercise("rdl", 3, "6-8", 150, ["deadlift"]), exercise("tricep-pushdown", 2, "10-15", 75, [catalog.overheadTricepsExtension])] }
    ]
  },
  {
    id: "intermediate-powerlifting-12",
    version: 1,
    name: "Intermediate Powerlifting",
    summary: "A four-day base-to-peak cycle using competition lifts, controlled intensity, and tapered accessories.",
    category: "Powerlifting",
    level: "Intermediate",
    durationWeeks: 12,
    daysPerWeek: 4,
    progressionMethod: "Percentage",
    sessions: [
      { day: "Monday", name: "Squat + Bench", exercises: [exercise("back-squat", 4, "5", 240, ["front-squat"]), exercise("barbell-bench", 4, "5", 210, ["db-bench"]), exercise("leg-press", 3, "8-12", 120, ["hack-squat"]), exercise(catalog.chestSupportedRow, 3, "8-12", 120, ["seated-row"])] },
      { day: "Tuesday", name: "Deadlift + Bench", exercises: [exercise("deadlift", 3, "4", 270, ["rdl"]), exercise("barbell-bench", 3, "6", 180, ["db-bench"], "Use a controlled volume load."), exercise("lat-pulldown", 3, "8-12", 120, ["pull-up"]), exercise("leg-curl", 3, "10-15", 90, [catalog.seatedLegCurl])] },
      { day: "Thursday", name: "Squat Volume + Press", exercises: [exercise("back-squat", 3, "6", 210, ["front-squat"], "Use a controlled volume load."), exercise("ohp", 3, "6", 180, [catalog.machineShoulderPress]), exercise("rdl", 3, "6-8", 150, ["deadlift"]), exercise("cable-crunch", 3, "10-15", 60, ["plank"])] },
      { day: "Saturday", name: "Bench Intensity + Pull", exercises: [exercise("barbell-bench", 4, "3", 210, ["db-bench"]), exercise("deadlift", 2, "5", 240, ["rdl"], "Use a lighter technique load."), exercise("seated-row", 3, "8-12", 120, [catalog.chestSupportedRow]), exercise("tricep-pushdown", 3, "10-15", 75, [catalog.overheadTricepsExtension])] }
    ]
  }
] as const;

export function workoutProgramTemplate(id: string): WorkoutProgramTemplate | undefined {
  return workoutProgramTemplates.find((template) => template.id === id);
}
