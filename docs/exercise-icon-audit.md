# Full iOS exercise icon audit

Date: 2026-10-03. Scope: current working-tree iOS source and supplied phone screenshots. This is a source-level inventory, not a claim that every icon was visually checked in a running app or that a phone/TestFlight artifact contains these changes. App artwork has not been changed by this audit.

## Coverage

- 337 unique built-in training exercises: 36 core entries plus 301 expanded entries; no duplicate training IDs in this inventory.
- 6 separate ranking exercise entries, all listed below.
- Every training row is listed once below under its effective current renderer, including the shoulder-press view override.
- User-created exercises and unresolved plan/session exercises are dynamic: their fallback paths are inspected below, but arbitrary user records are not enumerable from source.
- Utility icons, navigation icons and achievement artwork are outside this exercise-icon audit. The web UI is outside this iOS audit.

## Why the previous pass missed icons

1. Core catalog entries hard-code symbols in MockData.swift; expanded entries use PopularExerciseCatalog.symbol. Fixing one leaves the other unchanged.
2. ExerciseCatalogIcon overrides only names containing overhead press, shoulder press or push press. Other entries still render stored symbolName. This override also misses vertical presses with other names such as Arnold Press.
3. Leaderboard and Submit a Lift pickers use a separate six-item catalog and draw raw SF Symbols. They never reach the training icon override.
4. SubmitLiftView.exerciseSymbol contains yet another mapping for the selected exercise.
5. The expanded resolver prioritizes bodyPart containing core/oblique before movement. Single-Arm Dumbbell Bench Press and Renegade Row therefore render as core training. The pullover rule looks for pull_over but many IDs use pullover. Upright rows match the broad row rule. Band Pull-Apart reaches the dumbbell fallback.
6. Custom exercises store dumbbell.fill. Unresolved prescriptions construct generic symbol entries. A future fix must handle these paths without deleting or rewriting users' exercise records.
7. testCableExerciseIconsDescribeTheirMovement asserts arrows, climbing and generic seated figures as expected values. It verifies strings rather than visual meaning. The performance test renders only the first 50 exercises and discards the images without asserting rendering succeeded.
8. The TODO marked the first icon audit complete despite unchecked follow-up families. Compilation and a few example changes did not establish full-catalog coverage.

## Rendering surfaces

| Surface | Current path | Required verification |
| --- | --- | --- |
| Library rows | TrainingLibraryView → ExerciseCatalogIcon | Every built-in ID and custom entry |
| Add Exercises during workout | ActiveWorkoutAddExercisePickerView → ExerciseCatalogIcon | Both shoulder/lateral searches from the phone screenshots; all movement families |
| Tracker library/selectors | TrainingTrackerLibraryComponents → ExerciseCatalogIcon (two call sites) | Selection and search use the same visual identity |
| Active workout | PrescriptionTrackView and WorkoutSessionRunView → ExerciseCatalogIcon | Resolved entries and unresolved prescription fallback |
| Plan/session previews | ProgramSessionCard and WorkoutProgramTemplateDetailView → ExerciseCatalogIcon | Matching exercise visual; fallback entries included |
| Substitutions/detail recommendations | SubstituteExerciseListView, ExerciseLibraryDetailView and WorkoutSessionRunView → ExerciseCatalogIcon | Consistent with source exercise |
| Progress | TrainingProgressView → ExerciseCatalogIcon | Same exercise identity after completion |
| Leaderboard exercise picker | LeaderboardsLogic → MockData.exercises → LeaderboardOption → raw Image(systemName:) in LeaderboardComponents | All six ranking exercises; canonical ID translation |
| Submit a Lift picker | SubmitLiftView → MockData.exercises → LeaderboardOption | Same six ranking visuals |
| Submit a Lift selected exercise | SubmitLiftView.exerciseSymbol → LiftActionRow | Remove independent exercise mapping when unified renderer is implemented |
| Leaderboard row | LeaderboardRowAndFilters uses generic dumbbell label | Decide whether this represents an action/category or a specific exercise; use movement visual if specific |
| Custom exercise | ExerciseLibraryStore initializes dumbbell.fill | Recognized movements should use common rendering; genuinely unknown movements need an intentional custom-exercise fallback |

## Implementation and acceptance requirements

- Extend the existing exercise icon owner with movement-specific vector artwork and a single identity mapping. Route training, ranked exercise and submission surfaces through it. Keep normal utility SF Symbols unchanged.
- Use ID/canonical movement metadata with explicit exceptions for known catalog entries, not only broad body-part/string rules. Resolve bench/press/deadlift ranking aliases to the same visual identity as training entries.
- Distinguish movement families first, then meaningful posture/equipment variations: horizontal vs overhead press; barbell vs dumbbells; seated vs standing; squat vs hinge vs lunge; calf vs front raise; fly vs lateral raise; leg curl vs extension; pull-up vs pulldown; row vs upright row.
- Build a labeled contact sheet containing all 337 training exercises and six ranking choices. Review small picker size and 54-point tiles in light/dark appearances. Repetition within a true movement family is acceptable; unrelated movements must not share misleading art.
- Add coverage checks for every built-in ID, canonical ranking consistency, and exceptions above. Replace tests that enshrine weak placeholders. Include custom and unresolved-prescription behavior. Visual review is still required.
- Verify actual Add Exercises, Library, plan preview, active workout, substitute, Progress, leaderboard and submission screens. Check contrast, cropping, readable silhouette and accessibility labels.
- Record the version/build and source revision of the verified release artifact. Keep source-complete, simulator-verified and TestFlight-shipped statuses separate. Do not mark the task finished after compilation alone.

## Effective renderer counts

| Current renderer | Exercises |
| --- | ---: |
| figure.strengthtraining.traditional | 90 |
| figure.strengthtraining.functional | 88 |
| figure.rower | 31 |
| dumbbell.fill | 31 |
| figure.core.training | 25 |
| figure.arms.open | 13 |
| arrow.down.to.line.compact | 11 |
| composite: standing figure + overhead dumbbell | 11 |
| arrow.up | 11 |
| figure.climbing | 9 |
| arrow.left.and.right | 6 |
| figure.seated.side | 5 |
| arrow.up.and.down | 2 |
| arrow.triangle.2.circlepath | 2 |
| arrow.left.arrow.right | 1 |
| figure.flexibility | 1 |

## Complete training inventory

All groups below require replacement or visual review; none is signed off by this source-only audit. The stored symbol is shown separately where the view overrides it.

### figure.strengthtraining.traditional — 90 exercises

Replace generic upright lifting figure with the actual movement: distinguish horizontal bench/floor presses, seated machine presses, curls, triceps extension and push-ups. Preserve equipment and bench angle where readable.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Alternating Dumbbell Bench Press | `dumbbell_alternating_bench_press` | expanded | `figure.strengthtraining.traditional` |
| Alternating Dumbbell Curl | `dumbbell_alternating_curl` | expanded | `figure.strengthtraining.traditional` |
| Arnold Press | `dumbbell_arnold_press` | expanded | `figure.strengthtraining.traditional` |
| Assisted Dip Machine | `machine_assisted_dip` | expanded | `figure.strengthtraining.traditional` |
| Band Biceps Curl | `band_biceps_curl` | expanded | `figure.strengthtraining.traditional` |
| Band Chest Press | `band_chest_press` | expanded | `figure.strengthtraining.traditional` |
| Band Hammer Curl | `band_hammer_curl` | expanded | `figure.strengthtraining.traditional` |
| Band Overhead Triceps Extension | `band_overhead_triceps_extension` | expanded | `figure.strengthtraining.traditional` |
| Band Triceps Pushdown | `band_triceps_pushdown` | expanded | `figure.strengthtraining.traditional` |
| Band-Resisted Push-Up | `band_push_up` | expanded | `figure.strengthtraining.traditional` |
| Barbell Bench Press | `barbell_bench_press` | core | `figure.strengthtraining.traditional` |
| Barbell Floor Press | `barbell_floor_press` | expanded | `figure.strengthtraining.traditional` |
| Barbell Incline Bench Press | `barbell_incline_bench_press` | expanded | `figure.strengthtraining.traditional` |
| Barbell Preacher Curl | `barbell_preacher_curl` | expanded | `figure.strengthtraining.traditional` |
| Barbell Reverse Curl | `barbell_reverse_curl` | expanded | `figure.strengthtraining.traditional` |
| Bayesian Cable Curl | `cable_bayesian_curl` | expanded | `figure.strengthtraining.traditional` |
| Cable Biceps Curl | `cable_biceps_curl` | expanded | `figure.strengthtraining.traditional` |
| Cable Drag Curl | `cable_drag_curl` | expanded | `figure.strengthtraining.traditional` |
| Cable Preacher Curl | `cable_preacher_curl` | expanded | `figure.strengthtraining.traditional` |
| Cable Reverse Curl | `cable_reverse_curl` | expanded | `figure.strengthtraining.traditional` |
| Cable Skull Crusher | `cable_skull_crusher` | expanded | `figure.strengthtraining.traditional` |
| Cable Y Raise | `cable_y_raise` | expanded | `figure.strengthtraining.traditional` |
| Close-Grip Barbell Bench Press | `barbell_close_grip_bench_press` | expanded | `figure.strengthtraining.traditional` |
| Concentration Curl | `dumbbell_concentration_curl` | expanded | `figure.strengthtraining.traditional` |
| Cross-Body Cable Triceps Extension | `cable_cross_body_triceps_extension` | expanded | `figure.strengthtraining.traditional` |
| Cross-Body Hammer Curl | `dumbbell_cross_body_hammer_curl` | expanded | `figure.strengthtraining.traditional` |
| Decline Bench Press | `barbell_decline_bench_press` | expanded | `figure.strengthtraining.traditional` |
| Decline Cable Press | `cable_decline_press` | expanded | `figure.strengthtraining.traditional` |
| Decline Chest Press Machine | `machine_decline_chest_press` | expanded | `figure.strengthtraining.traditional` |
| Decline Dumbbell Bench Press | `dumbbell_decline_bench_press` | expanded | `figure.strengthtraining.traditional` |
| Decline Push-Up | `bodyweight_decline_push_up` | expanded | `figure.strengthtraining.traditional` |
| Diamond Push-Up | `bodyweight_diamond_push_up` | expanded | `figure.strengthtraining.traditional` |
| Dip | `bodyweight_dip` | expanded | `figure.strengthtraining.traditional` |
| Dumbbell Bench Press | `dumbbell_bench_press` | expanded | `figure.strengthtraining.traditional` |
| Dumbbell Cuban Press | `dumbbell_cuban_press` | expanded | `figure.strengthtraining.traditional` |
| Dumbbell Curl | `dumbbell_curl` | expanded | `figure.strengthtraining.traditional` |
| Dumbbell Floor Press | `dumbbell_floor_press` | expanded | `figure.strengthtraining.traditional` |
| Dumbbell Hammer Curl | `dumbbell_hammer_curl` | expanded | `figure.strengthtraining.traditional` |
| Dumbbell Preacher Curl | `dumbbell_preacher_curl` | expanded | `figure.strengthtraining.traditional` |
| Dumbbell Pullover | `dumbbell_pullover` | expanded | `figure.strengthtraining.traditional` |
| Dumbbell Skull Crusher | `dumbbell_skull_crusher` | expanded | `figure.strengthtraining.traditional` |
| Dumbbell Spider Curl | `dumbbell_spider_curl` | expanded | `figure.strengthtraining.traditional` |
| Dumbbell Squeeze Press | `dumbbell_squeeze_press` | expanded | `figure.strengthtraining.traditional` |
| Dumbbell Tate Press | `dumbbell_tate_press` | expanded | `figure.strengthtraining.traditional` |
| EZ-Bar Curl | `ez_bar_curl` | core | `figure.strengthtraining.traditional` |
| Flat Dumbbell Bench Press | `dumbbell_flat_bench_press` | expanded | `figure.strengthtraining.traditional` |
| High-Incline Chest Press Machine | `machine_high_incline_chest_press` | expanded | `figure.strengthtraining.traditional` |
| Incline Cable Press | `cable_incline_press` | expanded | `figure.strengthtraining.traditional` |
| Incline Chest Press Machine | `machine_incline_chest_press` | expanded | `figure.strengthtraining.traditional` |
| Incline DB Press | `incline_db_press` | core | `figure.strengthtraining.traditional` |
| Iso-Lateral Chest Press | `machine_iso_lateral_chest_press` | expanded | `figure.strengthtraining.traditional` |
| Iso-Lateral Decline Press | `machine_iso_lateral_decline_press` | expanded | `figure.strengthtraining.traditional` |
| Iso-Lateral Incline Press | `machine_iso_lateral_incline_press` | expanded | `figure.strengthtraining.traditional` |
| Kettlebell Curl | `kettlebell_curl` | expanded | `figure.strengthtraining.traditional` |
| Kettlebell Floor Press | `kettlebell_floor_press` | expanded | `figure.strengthtraining.traditional` |
| Kettlebell High Pull | `kettlebell_high_pull` | expanded | `figure.strengthtraining.traditional` |
| Kettlebell Triceps Extension | `kettlebell_triceps_extension` | expanded | `figure.strengthtraining.traditional` |
| Landmine Press | `barbell_landmine_press` | expanded | `figure.strengthtraining.traditional` |
| Lying Triceps Extension | `barbell_lying_triceps_extension` | expanded | `figure.strengthtraining.traditional` |
| Machine Chest Press | `machine_chest_press` | core | `figure.strengthtraining.traditional` |
| Military Press | `barbell_military_press` | expanded | `figure.strengthtraining.traditional` |
| Neutral-Grip Dumbbell Press | `dumbbell_neutral_grip_press` | expanded | `figure.strengthtraining.traditional` |
| One-Arm Push-Up | `bodyweight_one_arm_push_up` | expanded | `figure.strengthtraining.traditional` |
| Overhead Triceps Extension | `overhead_triceps_extension` | core | `figure.strengthtraining.traditional` |
| Pike Push-Up | `bodyweight_pike_push_up` | expanded | `figure.strengthtraining.traditional` |
| Plate-Loaded Chest Press | `machine_plate_loaded_chest_press` | expanded | `figure.strengthtraining.traditional` |
| Plate-Loaded Horizontal Bench Press | `machine_plate_loaded_horizontal_bench_press` | expanded | `figure.strengthtraining.traditional` |
| Preacher Curl Machine | `machine_preacher_curl` | expanded | `figure.strengthtraining.traditional` |
| Push-Up | `bodyweight_push_up` | expanded | `figure.strengthtraining.traditional` |
| Reverse-Grip Triceps Pushdown | `cable_reverse_grip_pushdown` | expanded | `figure.strengthtraining.traditional` |
| Rope Hammer Curl | `cable_rope_hammer_curl` | expanded | `figure.strengthtraining.traditional` |
| Rope Triceps Pushdown | `cable_rope_pushdown` | expanded | `figure.strengthtraining.traditional` |
| Seated Biceps Curl Machine | `machine_seated_biceps_curl` | expanded | `figure.strengthtraining.traditional` |
| Single-Arm Cable Chest Press | `cable_single_arm_chest_press` | expanded | `figure.strengthtraining.traditional` |
| Single-Arm Cable Curl | `cable_single_arm_curl` | expanded | `figure.strengthtraining.traditional` |
| Single-Arm Overhead Dumbbell Extension | `dumbbell_single_arm_overhead_extension` | expanded | `figure.strengthtraining.traditional` |
| Single-Arm Triceps Pushdown | `cable_single_arm_pushdown` | expanded | `figure.strengthtraining.traditional` |
| Smith Machine Bench Press | `machine_smith_bench_press` | expanded | `figure.strengthtraining.traditional` |
| Smith Machine Close-Grip Bench Press | `machine_smith_close_grip_bench_press` | expanded | `figure.strengthtraining.traditional` |
| Smith Machine Decline Press | `machine_smith_decline_press` | expanded | `figure.strengthtraining.traditional` |
| Smith Machine Floor Press | `machine_smith_floor_press` | expanded | `figure.strengthtraining.traditional` |
| Smith Machine Incline Press | `machine_smith_incline_press` | expanded | `figure.strengthtraining.traditional` |
| Standing Cable Chest Press | `cable_standing_chest_press` | expanded | `figure.strengthtraining.traditional` |
| Straight-Bar Triceps Pushdown | `cable_straight_bar_pushdown` | expanded | `figure.strengthtraining.traditional` |
| Triceps Dip Machine | `machine_triceps_dip` | expanded | `figure.strengthtraining.traditional` |
| Triceps Extension Machine | `machine_triceps_extension` | expanded | `figure.strengthtraining.traditional` |
| Triceps Pressdown | `triceps_pressdown` | core | `figure.strengthtraining.traditional` |
| Weighted Dip | `weighted_dip` | core | `figure.strengthtraining.traditional` |
| Wide-Grip Chest Press Machine | `machine_wide_grip_chest_press` | expanded | `figure.strengthtraining.traditional` |
| Zottman Curl | `dumbbell_zottman_curl` | expanded | `figure.strengthtraining.traditional` |

### figure.strengthtraining.functional — 88 exercises

Replace shared lunge-like figure with distinct squat, hinge/deadlift, lunge, bridge/thrust, hip isolation and leg curl/extension silhouettes. Do not infer these movements from body part alone.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Back Squat | `back_squat` | core | `figure.strengthtraining.functional` |
| Band Glute Bridge | `band_glute_bridge` | expanded | `figure.strengthtraining.functional` |
| Band Good Morning | `band_good_morning` | expanded | `figure.strengthtraining.functional` |
| Band Hip Abduction | `band_hip_abduction` | expanded | `figure.strengthtraining.functional` |
| Band Lateral Walk | `band_lateral_walk` | expanded | `figure.strengthtraining.functional` |
| Band Romanian Deadlift | `band_romanian_deadlift` | expanded | `figure.strengthtraining.functional` |
| Band Squat | `band_squat` | expanded | `figure.strengthtraining.functional` |
| Barbell Glute Bridge | `barbell_glute_bridge` | expanded | `figure.strengthtraining.functional` |
| Barbell Hip Thrust | `barbell_hip_thrust` | expanded | `figure.strengthtraining.functional` |
| Barbell Reverse Lunge | `barbell_reverse_lunge` | expanded | `figure.strengthtraining.functional` |
| Barbell Stiff-Leg Deadlift | `barbell_stiff_leg_deadlift` | expanded | `figure.strengthtraining.functional` |
| Barbell Walking Lunge | `barbell_walking_lunge` | expanded | `figure.strengthtraining.functional` |
| Belt Squat Machine | `machine_belt_squat` | expanded | `figure.strengthtraining.functional` |
| Bodyweight Reverse Lunge | `bodyweight_reverse_lunge` | expanded | `figure.strengthtraining.functional` |
| Bodyweight Split Squat | `bodyweight_split_squat` | expanded | `figure.strengthtraining.functional` |
| Bodyweight Squat | `bodyweight_squat` | expanded | `figure.strengthtraining.functional` |
| Bodyweight Step-Up | `bodyweight_step_up` | expanded | `figure.strengthtraining.functional` |
| Bodyweight Walking Lunge | `bodyweight_walking_lunge` | expanded | `figure.strengthtraining.functional` |
| Bulgarian Split Squat | `bulgarian_split_squat` | core | `figure.strengthtraining.functional` |
| Cable Goblet Squat | `cable_goblet_squat` | expanded | `figure.strengthtraining.functional` |
| Cable Hip Abduction | `cable_hip_abduction` | expanded | `figure.strengthtraining.functional` |
| Cable Kickback | `cable_kickback` | core | `figure.strengthtraining.functional` |
| Cable Pull-Through | `cable_pull_through` | expanded | `figure.strengthtraining.functional` |
| Cable Reverse Lunge | `cable_lunge` | expanded | `figure.strengthtraining.functional` |
| Cable Romanian Deadlift | `cable_romanian_deadlift` | expanded | `figure.strengthtraining.functional` |
| Cable Squat | `cable_squat` | expanded | `figure.strengthtraining.functional` |
| Cable Step-Up | `cable_step_up` | expanded | `figure.strengthtraining.functional` |
| Conventional Deadlift | `conventional_deadlift` | core | `figure.strengthtraining.functional` |
| Dumbbell Deadlift | `dumbbell_deadlift` | expanded | `figure.strengthtraining.functional` |
| Dumbbell Front Squat | `dumbbell_front_squat` | expanded | `figure.strengthtraining.functional` |
| Dumbbell Glute Bridge | `dumbbell_glute_bridge` | expanded | `figure.strengthtraining.functional` |
| Dumbbell Goblet Squat | `dumbbell_goblet_squat` | expanded | `figure.strengthtraining.functional` |
| Dumbbell Hip Thrust | `dumbbell_hip_thrust` | expanded | `figure.strengthtraining.functional` |
| Dumbbell Lunge | `dumbbell_lunge` | expanded | `figure.strengthtraining.functional` |
| Dumbbell Reverse Lunge | `dumbbell_reverse_lunge` | expanded | `figure.strengthtraining.functional` |
| Dumbbell Romanian Deadlift | `dumbbell_romanian_deadlift` | expanded | `figure.strengthtraining.functional` |
| Dumbbell Step-Up | `dumbbell_step_up` | expanded | `figure.strengthtraining.functional` |
| Dumbbell Stiff-Leg Deadlift | `dumbbell_stiff_leg_deadlift` | expanded | `figure.strengthtraining.functional` |
| Dumbbell Sumo Squat | `dumbbell_sumo_squat` | expanded | `figure.strengthtraining.functional` |
| Dumbbell Walking Lunge | `dumbbell_walking_lunge` | expanded | `figure.strengthtraining.functional` |
| Farmer's Carry | `farmers_carry` | core | `figure.strengthtraining.functional` |
| Front Squat | `barbell_front_squat` | expanded | `figure.strengthtraining.functional` |
| Glute Bridge | `bodyweight_glute_bridge` | expanded | `figure.strengthtraining.functional` |
| Glute Drive Machine | `machine_glute_drive` | expanded | `figure.strengthtraining.functional` |
| Good Morning | `barbell_good_morning` | expanded | `figure.strengthtraining.functional` |
| Ground-Base Squat | `machine_ground_base_squat` | expanded | `figure.strengthtraining.functional` |
| Hack Squat | `hack_squat` | core | `figure.strengthtraining.functional` |
| Hip Abductor Machine | `machine_hip_abductor` | expanded | `figure.strengthtraining.functional` |
| Hip Thrust | `hip_thrust` | core | `figure.strengthtraining.functional` |
| Iso-Lateral Leg Curl | `machine_iso_lateral_leg_curl` | expanded | `figure.strengthtraining.functional` |
| Kettlebell Front Rack Squat | `kettlebell_front_rack_squat` | expanded | `figure.strengthtraining.functional` |
| Kettlebell Goblet Squat | `kettlebell_goblet_squat` | expanded | `figure.strengthtraining.functional` |
| Kettlebell Reverse Lunge | `kettlebell_reverse_lunge` | expanded | `figure.strengthtraining.functional` |
| Kettlebell Romanian Deadlift | `kettlebell_romanian_deadlift` | expanded | `figure.strengthtraining.functional` |
| Kettlebell Single-Leg Deadlift | `kettlebell_single_leg_deadlift` | expanded | `figure.strengthtraining.functional` |
| Kettlebell Step-Up | `kettlebell_step_up` | expanded | `figure.strengthtraining.functional` |
| Kettlebell Sumo Deadlift | `kettlebell_sum_deadlift` | expanded | `figure.strengthtraining.functional` |
| Kettlebell Swing | `kettlebell_swing` | expanded | `figure.strengthtraining.functional` |
| Kneeling Leg Curl Machine | `machine_kneeling_leg_curl` | expanded | `figure.strengthtraining.functional` |
| Lying Leg Curl | `lying_leg_curl` | core | `figure.strengthtraining.functional` |
| Nordic Curl Machine | `machine_nordic_curl` | expanded | `figure.strengthtraining.functional` |
| Nordic Hamstring Curl | `bodyweight_nordic_curl` | expanded | `figure.strengthtraining.functional` |
| Pause Squat | `barbell_pause_squat` | expanded | `figure.strengthtraining.functional` |
| Pendulum Squat | `machine_pendulum_squat` | expanded | `figure.strengthtraining.functional` |
| Pistol Squat | `bodyweight_single_leg_squat` | expanded | `figure.strengthtraining.functional` |
| Reverse Nordic | `bodyweight_reverse_nordic` | expanded | `figure.strengthtraining.functional` |
| Romanian Deadlift | `romanian_deadlift` | core | `figure.strengthtraining.functional` |
| Seated Leg Curl | `seated_leg_curl` | core | `figure.strengthtraining.functional` |
| Single-Leg Dumbbell Romanian Deadlift | `dumbbell_single_leg_romanian_deadlift` | expanded | `figure.strengthtraining.functional` |
| Single-Leg Glute Bridge | `bodyweight_single_leg_glute_bridge` | expanded | `figure.strengthtraining.functional` |
| Sissy Squat Machine | `machine_sissy_squat` | expanded | `figure.strengthtraining.functional` |
| Smith Machine Back Squat | `machine_smith_back_squat` | expanded | `figure.strengthtraining.functional` |
| Smith Machine Front Squat | `machine_smith_front_squat` | expanded | `figure.strengthtraining.functional` |
| Smith Machine Glute Bridge | `machine_smith_glute_bridge` | expanded | `figure.strengthtraining.functional` |
| Smith Machine Good Morning | `machine_smith_good_morning` | expanded | `figure.strengthtraining.functional` |
| Smith Machine Hack Squat | `machine_smith_hack_squat` | expanded | `figure.strengthtraining.functional` |
| Smith Machine Hip Thrust | `machine_smith_hip_thrust` | expanded | `figure.strengthtraining.functional` |
| Smith Machine Lunge | `machine_smith_lunge` | expanded | `figure.strengthtraining.functional` |
| Smith Machine Reverse Lunge | `machine_smith_reverse_lunge` | expanded | `figure.strengthtraining.functional` |
| Smith Machine Romanian Deadlift | `machine_smith_romanian_deadlift` | expanded | `figure.strengthtraining.functional` |
| Smith Machine Split Squat | `machine_smith_split_squat` | expanded | `figure.strengthtraining.functional` |
| Smith Machine Step-Up | `machine_smith_step_up` | expanded | `figure.strengthtraining.functional` |
| Smith Machine Stiff-Leg Deadlift | `machine_smith_stiff_leg_deadlift` | expanded | `figure.strengthtraining.functional` |
| Standing Glute Kickback Machine | `machine_standing_glute_kickback` | expanded | `figure.strengthtraining.functional` |
| Standing Leg Curl Machine | `machine_standing_leg_curl` | expanded | `figure.strengthtraining.functional` |
| Sumo Deadlift | `sumo_deadlift` | core | `figure.strengthtraining.functional` |
| V-Squat Machine | `machine_v_squat` | expanded | `figure.strengthtraining.functional` |
| Wall Sit | `bodyweight_wall_sit` | expanded | `figure.strengthtraining.functional` |

### figure.rower — 31 exercises

Do not use a rowing-machine silhouette for all rows. Distinguish bent-over, supported, upright, inverted and seated rows; show equipment/support.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Band Row | `band_row` | expanded | `figure.rower` |
| Barbell Upright Row | `barbell_upright_row` | expanded | `figure.rower` |
| Bent-Over Barbell Row | `barbell_row` | expanded | `figure.rower` |
| Cable Upright Row | `cable_upright_row` | expanded | `figure.rower` |
| Chest-Supported Dumbbell Row | `dumbbell_chest_supported_row` | expanded | `figure.rower` |
| Chest-Supported Row | `chest_supported_row` | core | `figure.rower` |
| Dumbbell Bent-Over Row | `dumbbell_bent_over_row` | expanded | `figure.rower` |
| Dumbbell High Row | `dumbbell_high_row` | expanded | `figure.rower` |
| Dumbbell Rear Delt Row | `dumbbell_rear_delt_row` | expanded | `figure.rower` |
| Dumbbell Seal Row | `dumbbell_seal_row` | expanded | `figure.rower` |
| Dumbbell Upright Row | `dumbbell_upright_row` | expanded | `figure.rower` |
| Half-Kneeling Cable Row | `cable_half_kneeling_row` | expanded | `figure.rower` |
| High Cable Row | `cable_high_row` | expanded | `figure.rower` |
| High Row Machine | `machine_high_row` | expanded | `figure.rower` |
| Inverted Row | `bodyweight_inverted_row` | expanded | `figure.rower` |
| Iso-Lateral High Row | `machine_iso_lateral_high_row` | expanded | `figure.rower` |
| Iso-Lateral Low Row | `machine_iso_lateral_low_row` | expanded | `figure.rower` |
| Iso-Lateral Row | `machine_iso_lateral_row` | expanded | `figure.rower` |
| Iso-Lateral Underhand Row | `machine_iso_lateral_underhand_row` | expanded | `figure.rower` |
| Kettlebell Row | `kettlebell_row` | expanded | `figure.rower` |
| Landmine T-Bar Row | `barbell_t_bar_row` | expanded | `figure.rower` |
| Low Cable Row | `cable_low_row` | expanded | `figure.rower` |
| Low Row Machine | `machine_low_row` | expanded | `figure.rower` |
| Pendlay Row | `barbell_pendlay_row` | expanded | `figure.rower` |
| Ring Row | `bodyweight_ring_row` | expanded | `figure.rower` |
| Single-Arm Cable Row | `cable_single_arm_row` | expanded | `figure.rower` |
| Single-Arm DB Row | `single_arm_db_row` | core | `figure.rower` |
| Smith Machine Row | `machine_smith_row` | expanded | `figure.rower` |
| Smith Machine Upright Row | `machine_smith_upright_row` | expanded | `figure.rower` |
| Standing Cable Row | `cable_standing_row` | expanded | `figure.rower` |
| T-Bar Row Machine | `machine_t_bar_row` | expanded | `figure.rower` |

### dumbbell.fill — 31 exercises

Replace equipment-only fallback with a movement silhouette: neck motion, shrug, wrist flexion/extension, pullover, hip adduction, ankle dorsiflexion, Olympic lift, carry or bodyweight movement as named.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Band Pull-Apart | `band_pull_apart` | expanded | `dumbbell.fill` |
| Barbell Reverse Wrist Curl | `barbell_reverse_wrist_curl` | expanded | `dumbbell.fill` |
| Barbell Shrug | `barbell_shrug` | expanded | `dumbbell.fill` |
| Barbell Wrist Curl | `barbell_wrist_curl` | expanded | `dumbbell.fill` |
| Bear Crawl | `bodyweight_bear_crawl` | expanded | `dumbbell.fill` |
| Burpee | `bodyweight_burpee` | expanded | `dumbbell.fill` |
| Cable Hip Adduction | `cable_hip_adduction` | expanded | `dumbbell.fill` |
| Cable Pullover | `cable_pullover` | expanded | `dumbbell.fill` |
| Clean | `barbell_clean` | expanded | `dumbbell.fill` |
| Clean and Jerk | `barbell_clean_and_jerk` | expanded | `dumbbell.fill` |
| Clean Pull | `barbell_clean_pull` | expanded | `dumbbell.fill` |
| Dumbbell Shrug | `dumbbell_shrug` | expanded | `dumbbell.fill` |
| Dumbbell Thruster | `dumbbell_thruster` | expanded | `dumbbell.fill` |
| Grip Machine | `machine_grip` | expanded | `dumbbell.fill` |
| Hex Bar Deadlift | `barbell_hex_bar_deadlift` | expanded | `dumbbell.fill` |
| Hip Adductor Machine | `machine_hip_adductor` | expanded | `dumbbell.fill` |
| Incline DB Curl | `incline_db_curl` | core | `dumbbell.fill` |
| Kettlebell Farmer's Carry | `kettlebell_farmers_carry` | expanded | `dumbbell.fill` |
| Lateral Neck Flexion Machine | `machine_lateral_neck_flexion` | expanded | `dumbbell.fill` |
| Machine Shrug | `machine_shrug` | expanded | `dumbbell.fill` |
| Neck Extension Machine | `machine_neck_extension` | expanded | `dumbbell.fill` |
| Neck Flexion Machine | `machine_neck_flexion` | expanded | `dumbbell.fill` |
| Power Clean | `barbell_power_clean` | expanded | `dumbbell.fill` |
| Pullover Machine | `machine_pullover` | expanded | `dumbbell.fill` |
| Reverse Pec Deck | `machine_reverse_pec_deck` | expanded | `dumbbell.fill` |
| Smith Machine Behind-the-Back Shrug | `machine_smith_behind_back_shrug` | expanded | `dumbbell.fill` |
| Smith Machine Shrug | `machine_smith_shrug` | expanded | `dumbbell.fill` |
| Snatch | `barbell_snatch` | expanded | `dumbbell.fill` |
| Tibialis Raise | `bodyweight_tibialis_raise` | expanded | `dumbbell.fill` |
| Tibialis Raise Machine | `machine_tibialis_raise` | expanded | `dumbbell.fill` |
| Turkish Get-Up | `kettlebell_turkish_get_up` | expanded | `dumbbell.fill` |

### figure.core.training — 25 exercises

Replace blanket core mapping with named movement. It currently overrides non-core movements when core appears as a secondary body part. Distinguish anti-rotation press, crunch, plank, rollout, carry, bench press and renegade row.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Abdominal Crunch Machine | `machine_abdominal_crunch` | expanded | `figure.core.training` |
| Band Pallof Press | `band_pallof_press` | expanded | `figure.core.training` |
| Band Wood Chop | `band_wood_chop` | expanded | `figure.core.training` |
| Barbell Rollout | `barbell_rollout` | expanded | `figure.core.training` |
| Bird Dog | `bodyweight_bird_dog` | expanded | `figure.core.training` |
| Cable Wood Chop | `cable_wood_chop` | expanded | `figure.core.training` |
| Crunch | `bodyweight_crunch` | expanded | `figure.core.training` |
| Dead Bug | `bodyweight_dead_bug` | expanded | `figure.core.training` |
| Dumbbell Dead Bug | `dumbbell_dead_bug` | expanded | `figure.core.training` |
| Dumbbell Russian Twist | `dumbbell_russian_twist` | expanded | `figure.core.training` |
| Dumbbell Side Bend | `dumbbell_side_bend` | expanded | `figure.core.training` |
| Ground-Base Rotational Twist | `machine_ground_base_rotational_twist` | expanded | `figure.core.training` |
| Hollow Hold | `bodyweight_hollow_hold` | expanded | `figure.core.training` |
| Hanging Leg Raise | `hanging_leg_raise` | core | `figure.core.training` |
| Kettlebell Russian Twist | `kettlebell_russian_twist` | expanded | `figure.core.training` |
| Kettlebell Suitcase Carry | `kettlebell_suitcase_carry` | expanded | `figure.core.training` |
| Kettlebell Windmill | `kettlebell_windmill` | expanded | `figure.core.training` |
| Mountain Climber | `bodyweight_mountain_climber` | expanded | `figure.core.training` |
| Pallof Press | `cable_pallof_press` | expanded | `figure.core.training` |
| Plank | `plank` | core | `figure.core.training` |
| Renegade Row | `dumbbell_renegade_row` | expanded | `figure.core.training` |
| Rotary Torso Machine | `machine_rotary_torso` | expanded | `figure.core.training` |
| Side Plank | `bodyweight_side_plank` | expanded | `figure.core.training` |
| Single-Arm Dumbbell Bench Press | `dumbbell_single_arm_bench_press` | expanded | `figure.core.training` |
| Sit-Up | `bodyweight_sit_up` | expanded | `figure.core.training` |

### figure.arms.open — 13 exercises

Distinguish chest fly, rear-delt fly, lateral raise and face pull; open arms alone is ambiguous.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Band Lateral Raise | `band_lateral_raise` | expanded | `figure.arms.open` |
| Cable Face Pull | `cable_face_pull` | expanded | `figure.arms.open` |
| Cable Rear Delt Fly | `cable_rear_delt_fly` | expanded | `figure.arms.open` |
| Dumbbell Fly | `dumbbell_fly` | expanded | `figure.arms.open` |
| Dumbbell Rear Delt Fly | `dumbbell_rear_delt_fly` | expanded | `figure.arms.open` |
| High-to-Low Cable Fly | `cable_high_to_low_fly` | expanded | `figure.arms.open` |
| Incline Dumbbell Fly | `dumbbell_incline_fly` | expanded | `figure.arms.open` |
| Lateral Raise Machine | `machine_lateral_raise` | expanded | `figure.arms.open` |
| Lean-Away Dumbbell Lateral Raise | `dumbbell_lean_away_lateral_raise` | expanded | `figure.arms.open` |
| Low-to-High Cable Fly | `cable_low_to_high_fly` | expanded | `figure.arms.open` |
| Plate-Loaded Pec Fly | `machine_plate_loaded_pec_fly` | expanded | `figure.arms.open` |
| Seated Dumbbell Lateral Raise | `dumbbell_seated_lateral_raise` | expanded | `figure.arms.open` |
| Single-Arm Cable Fly | `cable_single_arm_fly` | expanded | `figure.arms.open` |

### arrow.down.to.line.compact — 11 exercises

Replace standalone down arrow with a pulldown/pullover or crunch posture, chosen by the actual exercise.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Cable Crunch | `cable_crunch` | core | `arrow.down.to.line.compact` |
| Close-Grip Cable Pulldown | `cable_close_grip_pulldown` | expanded | `arrow.down.to.line.compact` |
| Iso-Lateral Front Pulldown | `machine_iso_lateral_front_pulldown` | expanded | `arrow.down.to.line.compact` |
| Lat Pulldown | `lat_pulldown` | core | `arrow.down.to.line.compact` |
| Neutral-Grip Pulldown Machine | `machine_neutral_grip_pulldown` | expanded | `arrow.down.to.line.compact` |
| Reverse-Grip Cable Pulldown | `cable_reverse_grip_pulldown` | expanded | `arrow.down.to.line.compact` |
| Reverse-Grip Pulldown Machine | `machine_reverse_grip_pulldown` | expanded | `arrow.down.to.line.compact` |
| Single-Arm Kneeling Pulldown | `cable_single_arm_kneeling_pulldown` | expanded | `arrow.down.to.line.compact` |
| Straight-Arm Cable Pulldown | `cable_straight_arm_pulldown` | expanded | `arrow.down.to.line.compact` |
| Wide-Grip Cable Pulldown | `cable_wide_grip_pulldown` | expanded | `arrow.down.to.line.compact` |
| Wide-Grip Pulldown Machine | `machine_wide_grip_pulldown` | expanded | `arrow.down.to.line.compact` |

### composite: standing figure + overhead dumbbell — 11 exercises

Shared override is only partial: standing figure plus one overhead dumbbell does not distinguish seated/barbell/dumbbell/machine/band/kettlebell variations or show bent pressing arms. Use actual equipment and pressing posture.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Band Overhead Press | `band_overhead_press` | expanded | `arrow.up.circle` |
| Barbell Overhead Press | `barbell_overhead_press` | core | `arrow.up.circle` |
| Cable Shoulder Press | `cable_shoulder_press` | expanded | `arrow.up.circle` |
| DB Shoulder Press | `db_shoulder_press` | core | `arrow.up.circle.fill` |
| Iso-Lateral Shoulder Press | `machine_iso_lateral_shoulder_press` | expanded | `arrow.up.circle` |
| Kettlebell Overhead Press | `kettlebell_overhead_press` | expanded | `arrow.up.circle` |
| Kettlebell Push Press | `kettlebell_push_press` | expanded | `arrow.up.circle` |
| Machine Shoulder Press | `machine_shoulder_press` | core | `arrow.up.circle.fill` |
| Push Press | `barbell_push_press` | expanded | `arrow.up.circle` |
| Seated Barbell Shoulder Press | `barbell_seated_shoulder_press` | expanded | `arrow.up.circle` |
| Smith Machine Shoulder Press | `machine_smith_shoulder_press` | expanded | `arrow.up.circle` |

### arrow.up — 11 exercises

Replace standalone up arrow with a heel raise or front raise silhouette; distinguish seated calf raise and standing calf raise.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Barbell Calf Raise | `barbell_calf_raise` | expanded | `arrow.up` |
| Barbell Seated Calf Raise | `barbell_seated_calf_raise` | expanded | `arrow.up` |
| Cable Front Raise | `cable_front_raise` | expanded | `arrow.up` |
| Dumbbell Calf Raise | `dumbbell_calf_raise` | expanded | `arrow.up` |
| Dumbbell Front Raise | `dumbbell_front_raise` | expanded | `arrow.up` |
| Seated Calf Raise Machine | `machine_seated_calf_raise` | expanded | `arrow.up` |
| Single-Leg Calf Raise | `bodyweight_single_leg_calf_raise` | expanded | `arrow.up` |
| Smith Machine Calf Raise | `machine_smith_calf_raise` | expanded | `arrow.up` |
| Smith Machine Seated Calf Raise | `machine_smith_seated_calf_raise` | expanded | `arrow.up` |
| Standing Calf Raise | `bodyweight_standing_calf_raise` | expanded | `arrow.up` |
| Standing Calf Raise Machine | `machine_standing_calf_raise` | expanded | `arrow.up` |

### figure.climbing — 9 exercises

Replace climbing figure with a seated/kneeling pulldown or hanging pull-up silhouette. Muscle-up and scapular pull-up need distinct poses.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Assisted Pull-Up Machine | `machine_assisted_pull_up` | expanded | `figure.climbing` |
| Band Lat Pulldown | `band_lat_pulldown` | expanded | `figure.climbing` |
| Chin-Up | `bodyweight_chin_up` | expanded | `figure.climbing` |
| Front Lat Pulldown Machine | `machine_front_lat_pulldown` | expanded | `figure.climbing` |
| Muscle-Up | `bodyweight_muscle_up` | expanded | `figure.climbing` |
| Negative Pull-Up | `bodyweight_negative_pull_up` | expanded | `figure.climbing` |
| Neutral-Grip Pull-Up | `bodyweight_neutral_grip_pull_up` | expanded | `figure.climbing` |
| Pull-Up | `pull_up` | core | `figure.climbing` |
| Scapular Pull-Up | `bodyweight_scapular_pull_up` | expanded | `figure.climbing` |

### arrow.left.and.right — 6 exercises

Replace standalone horizontal arrows with arms and equipment showing fly, lateral raise or face pull; these movements must be distinguishable.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Band Face Pull | `band_face_pull` | expanded | `arrow.left.and.right` |
| Cable Crossover | `cable_crossover` | expanded | `arrow.left.and.right` |
| Cable Fly | `cable_fly` | core | `arrow.left.and.right` |
| Cable Lateral Raise | `cable_lateral_raise` | core | `arrow.left.and.right` |
| Pec Deck | `pec_deck` | core | `arrow.left.and.right` |
| Rear Delt Fly | `rear_delt_fly` | core | `arrow.left.and.right` |

### figure.seated.side — 5 exercises

Show the leg press footplate, sled and pressing legs; sitting alone does not identify leg press.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| 45-Degree Linear Leg Press | `machine_linear_45_leg_press` | expanded | `figure.seated.side` |
| Horizontal Leg Press | `machine_horizontal_leg_press` | expanded | `figure.seated.side` |
| Iso-Lateral Leg Press | `machine_iso_lateral_leg_press` | expanded | `figure.seated.side` |
| Single-Leg Press Machine | `machine_single_leg_press` | expanded | `figure.seated.side` |
| Vertical Leg Press | `machine_vertical_leg_press` | expanded | `figure.seated.side` |

### arrow.up.and.down — 2 exercises

Replace vertical arrows with the actual leg curl/extension or press mechanism.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Leg Extension | `leg_extension` | core | `arrow.up.and.down` |
| Leg Press | `leg_press` | core | `arrow.up.and.down` |

### arrow.triangle.2.circlepath — 2 exercises

Show bent elbow/forearm rotation; circular arrows alone do not communicate shoulder rotation.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Cable External Rotation | `cable_external_rotation` | expanded | `arrow.triangle.2.circlepath` |
| Cable Internal Rotation | `cable_internal_rotation` | expanded | `arrow.triangle.2.circlepath` |

### arrow.left.arrow.right — 1 exercises

Replace bidirectional arrows with a seated cable row silhouette.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Seated Cable Row | `seated_cable_row` | core | `arrow.left.arrow.right` |

### figure.flexibility — 1 exercises

Show a supported hip hinge/back extension, not a generic flexibility pose.

| Exercise | Stable ID | Source | Stored symbol |
| --- | --- | --- | --- |
| Back Extension Machine | `machine_back_extension` | expanded | `figure.flexibility` |

## Complete ranking inventory

These use raw SF Symbols in ranking/submission pickers and bypass ExerciseCatalogIcon.

| Exercise | Ranking ID | Current symbol |
| --- | --- | --- |
| Barbell bench press | `bench` | `figure.strengthtraining.traditional` |
| Back squat | `squat` | `figure.strengthtraining.functional` |
| Conventional deadlift | `deadlift` | `figure.strengthtraining.functional` |
| Sumo deadlift | `sumo_deadlift` | `figure.strengthtraining.functional` |
| Overhead press | `press` | `figure.strengthtraining.traditional` |
| Dumbbell bench press | `dumbbell_bench_press` | `figure.strengthtraining.traditional` |
