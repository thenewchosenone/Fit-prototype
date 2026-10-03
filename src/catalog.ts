import type { Exercise, TrackingType } from "./types";

type CatalogGroup = {
  bodyPart: string;
  equipment: string;
  movementType: string;
  names: string;
  trackingType?: TrackingType;
};

const groups: CatalogGroup[] = [
  { bodyPart: "Chest", equipment: "Dumbbells", movementType: "Horizontal Push", names: "Dumbbell Incline Press|Dumbbell Decline Press|Dumbbell Floor Press|Dumbbell Squeeze Press|Neutral-Grip Dumbbell Press|Single-Arm Dumbbell Bench Press|Dumbbell Fly|Incline Dumbbell Fly|Dumbbell Pullover|Dumbbell Around the World" },
  { bodyPart: "Chest", equipment: "Cable", movementType: "Isolation", names: "Standing Cable Chest Press|Single-Arm Cable Chest Press|Low-to-High Cable Fly|High-to-Low Cable Fly|Mid Cable Fly|Single-Arm Cable Fly|Cable Crossover|Lying Cable Fly|Cable Svend Press|Cable Pullover" },
  { bodyPart: "Chest", equipment: "Machine", movementType: "Horizontal Push", names: "Incline Chest Press Machine|Decline Chest Press Machine|Horizontal Chest Press Machine|Wide-Grip Chest Press Machine|Converging Chest Press Machine|Iso-Lateral Chest Press|Plate-Loaded Chest Press|Plate-Loaded Incline Press|Plate-Loaded Decline Press|High-Incline Chest Press Machine|Plate-Loaded Pec Fly|Assisted Dip Machine" },
  { bodyPart: "Back", equipment: "Dumbbells", movementType: "Horizontal Pull", names: "One-Arm Dumbbell Row|Chest-Supported Dumbbell Row|Incline Dumbbell Row|Dumbbell Seal Row|Renegade Row|Dumbbell Pullover|Dumbbell Shrug|Dumbbell Rear-Delt Row|Dumbbell High Row|Two-Arm Dumbbell Row" },
  { bodyPart: "Back", equipment: "Cable", movementType: "Pull", names: "Wide-Grip Lat Pulldown|Close-Grip Lat Pulldown|Neutral-Grip Lat Pulldown|Single-Arm Lat Pulldown|Straight-Arm Pulldown|Kneeling Cable Pulldown|High Cable Row|Low Cable Row|Single-Arm Cable Row|Rope Seated Row|Cable Pullover|Cable Shrug|Cable Rear-Delt Row|Half-Kneeling Cable Row" },
  { bodyPart: "Back", equipment: "Machine", movementType: "Pull", names: "Chest-Supported Row Machine|High Row Machine|Low Row Machine|Iso-Lateral Row Machine|Iso-Lateral Underhand Row|Plate-Loaded Row|Plate-Loaded High Row|Plate-Loaded Low Row|Front Lat Pulldown Machine|Fixed Pulldown Machine|Wide Pulldown Machine|Machine Pullover|Machine Shrug|Assisted Pull-Up Machine|T-Bar Row Machine" },
  { bodyPart: "Shoulders", equipment: "Dumbbells", movementType: "Vertical Push", names: "Seated Dumbbell Shoulder Press|Arnold Press|Single-Arm Dumbbell Press|Dumbbell Front Raise|Dumbbell Rear-Delt Fly|Incline Rear-Delt Fly|Dumbbell Upright Row|Dumbbell Cuban Press|Dumbbell Y-Raise|Dumbbell Scaption" },
  { bodyPart: "Shoulders", equipment: "Cable", movementType: "Isolation", names: "Single-Arm Cable Lateral Raise|Behind-the-Back Cable Lateral Raise|Cable Front Raise|Cable Rear-Delt Fly|Cable Upright Row|Cable Y-Raise|Cable External Rotation|Cable Internal Rotation|Cable Cuban Press|Cable Shoulder Press" },
  { bodyPart: "Shoulders", equipment: "Machine", movementType: "Vertical Push", names: "Shoulder Press Machine|Iso-Lateral Shoulder Press|Plate-Loaded Shoulder Press|Lateral Raise Machine|Rear Deltoid Fly Machine|Machine Upright Row|Machine Front Raise|Rotator Cuff Machine|Reverse Pec Deck|Standing Lateral Raise Machine" },
  { bodyPart: "Arms", equipment: "Dumbbells", movementType: "Isolation", names: "Hammer Curl|Incline Dumbbell Curl|Concentration Curl|Spider Curl|Zottman Curl|Cross-Body Hammer Curl|Preacher Dumbbell Curl|Dumbbell Skull Crusher|Dumbbell Overhead Triceps Extension|Dumbbell Tate Press|Dumbbell Kickback|Rolling Dumbbell Extension|Dumbbell Wrist Curl|Dumbbell Reverse Wrist Curl" },
  { bodyPart: "Arms", equipment: "Cable", movementType: "Isolation", names: "Rope Triceps Pushdown|Straight-Bar Triceps Pushdown|Single-Arm Triceps Pushdown|Overhead Cable Triceps Extension|Cable Skull Crusher|Reverse-Grip Pushdown|Cable Biceps Curl|Rope Hammer Curl|Bayesian Cable Curl|High Cable Curl|Cable Preacher Curl|Reverse Cable Curl|Cable Wrist Curl|Cable Reverse Wrist Curl" },
  { bodyPart: "Arms", equipment: "Machine", movementType: "Isolation", names: "Biceps Curl Machine|Preacher Curl Machine|Triceps Extension Machine|Dip Machine|Plate-Loaded Biceps Curl|Plate-Loaded Triceps Extension|Grip Machine|Wrist Curl Machine|Arm Curl Machine|Assisted Dip Machine" },
  { bodyPart: "Quads", equipment: "Dumbbells", movementType: "Squat", names: "Goblet Squat|Dumbbell Front Squat|Dumbbell Split Squat|Bulgarian Split Squat|Dumbbell Step-Up|Dumbbell Walking Lunge|Dumbbell Reverse Lunge|Dumbbell Lateral Lunge|Dumbbell Sissy Squat|Dumbbell Cyclist Squat" },
  { bodyPart: "Quads", equipment: "Machine", movementType: "Squat", names: "45-Degree Linear Leg Press|Iso-Lateral Leg Press|Horizontal Leg Press|Single-Leg Press|Pendulum Squat|V-Squat|Belt Squat Machine|Ground-Base Squat|Smith Machine Squat|Smith Machine Split Squat|Smith Machine Lunge|Sissy Squat Machine|Reverse Hack Squat|Power Squat Machine|Leverage Squat Machine" },
  { bodyPart: "Hamstrings", equipment: "Dumbbells", movementType: "Hinge", names: "Dumbbell Romanian Deadlift|Single-Leg Dumbbell Romanian Deadlift|Dumbbell Stiff-Leg Deadlift|Dumbbell Good Morning|Dumbbell Swing|Dumbbell Hamstring Curl|Dumbbell Nordic Curl|Dumbbell Sumo Deadlift" },
  { bodyPart: "Hamstrings", equipment: "Machine", movementType: "Hinge", names: "Seated Leg Curl|Standing Leg Curl|Single-Leg Curl|Iso-Lateral Leg Curl|Nordic Curl Machine|Glute-Ham Raise|Reverse Hyperextension|Back Extension Machine|Smith Machine Romanian Deadlift|Cable Pull-Through" },
  { bodyPart: "Glutes", equipment: "Machine", movementType: "Hinge", names: "Glute Drive Machine|Hip Thrust Machine|Standing Glute Kickback Machine|Kneeling Glute Kickback Machine|Hip Abduction Machine|Hip Adduction Machine|Cable Glute Kickback|Cable Hip Abduction|Cable Hip Adduction|Smith Machine Hip Thrust|Reverse Hyper Machine|Multi-Hip Machine" },
  { bodyPart: "Calves", equipment: "Machine", movementType: "Isolation", names: "Standing Calf Raise Machine|Seated Calf Raise Machine|Donkey Calf Raise Machine|Horizontal Calf Press|Leg Press Calf Raise|Single-Leg Calf Raise Machine|Smith Machine Calf Raise|Tibia Raise Machine|Tibia Dorsi Flexion|Hack Squat Calf Raise" },
  { bodyPart: "Core", equipment: "Cable", movementType: "Core", names: "Cable Wood Chop|Cable Pallof Press|Cable Rotation|Half-Kneeling Pallof Press|Cable Reverse Crunch|Cable Side Bend|Cable Lift|Cable Anti-Rotation Hold|Kneeling Rope Crunch|Standing Cable Crunch" },
  { bodyPart: "Core", equipment: "Machine", movementType: "Core", names: "Abdominal Crunch Machine|Rotary Torso Machine|Back Extension Machine|Decline Ab Crunch Machine|Hanging Knee Raise Station|Captain's Chair Leg Raise|Ground-Base Rotational Twist|Combo Twist Machine|Ab Coaster|Torso Rotation Machine" },
  { bodyPart: "Full Body", equipment: "Dumbbells", movementType: "Conditioning", names: "Dumbbell Thruster|Dumbbell Clean|Dumbbell Clean and Press|Dumbbell Snatch|Dumbbell Farmer Carry|Dumbbell Suitcase Carry|Dumbbell Man Maker|Dumbbell Devil Press|Dumbbell Burpee|Dumbbell Turkish Get-Up" },
  { bodyPart: "Full Body", equipment: "Bodyweight", movementType: "Conditioning", names: "Burpee|Mountain Climber|Bear Crawl|Inchworm|Jump Squat|Walking Lunge|Push-Up|Pike Push-Up|Chin-Up|Muscle-Up", trackingType: "Reps Only" }
];

const aliasMap: Record<string, string[]> = {
  "Iso-Lateral Underhand Row": ["Hammer Strength D.Y. Row", "DY Row"],
  "Horizontal Chest Press Machine": ["Hammer Strength Horizontal Bench Press"],
  "High-Incline Chest Press Machine": ["Hammer Strength Super Incline Press"],
  "Front Lat Pulldown Machine": ["Hammer Strength Front Lat Pulldown"],
  "45-Degree Linear Leg Press": ["Hammer Strength Linear Leg Press"],
  "Ground-Base Squat": ["Hammer Strength Ground Base Squat"],
  "Ground-Base Rotational Twist": ["Hammer Strength Ground Base Twist"]
};

const slug = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");

function regions(bodyPart: string): string[] {
  if (bodyPart === "Full Body") return ["Chest", "Back", "Arms", "Core", "Quads", "Hamstrings", "Glutes"];
  return [bodyPart];
}

const expandedRows: Exercise[] = groups.flatMap((group) =>
  group.names.split("|").map((name) => ({
    id: `catalog-${slug(group.bodyPart)}-${slug(group.equipment)}-${slug(name)}`,
    name,
    bodyPart: group.bodyPart,
    secondaryMuscles: [],
    equipment: group.equipment,
    movementType: group.movementType,
    trackingType: group.trackingType ?? "Weight + Reps",
    searchAliases: aliasMap[name] ?? [],
    bodyRegions: regions(group.bodyPart)
  }))
);

export const expandedExercises: Exercise[] = [...new Map(expandedRows.map((exercise) => [exercise.name, exercise])).values()];
