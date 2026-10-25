import Foundation

enum PopularExerciseCatalog {
    private typealias Seed = (id: String, name: String, bodyPart: String, category: String, reps: String)


    private static let expandedSeeds: [(id: String, name: String, bodyPart: String, category: String, reps: String, equipment: String)] = [
        ("machine_converging_chest_press", "Converging Chest Press", "Chest", "Push", "8-12", "Machine"),
        ("machine_chest_supported_row", "Chest-Supported Row Machine", "Upper Back", "Pull", "8-12", "Machine"),
        ("machine_rear_delt", "Rear Delt Machine", "Rear Delts", "Pull", "10-15", "Machine"),
        ("machine_shoulder_press_neutral", "Neutral-Grip Shoulder Press", "Shoulders", "Push", "8-12", "Machine"),
        ("machine_single_leg_curl", "Single-Leg Curl", "Hamstrings", "Legs", "10-15", "Machine"),
        ("machine_hip_abduction", "Hip Abduction Machine", "Glutes", "Legs", "12-20", "Machine"),
        ("machine_hip_adduction", "Hip Adduction Machine", "Adductors", "Legs", "12-20", "Machine"),
        ("machine_standing_calf", "Standing Calf Machine", "Calves", "Legs", "10-20", "Machine"),
        ("machine_seated_calf", "Seated Calf Machine", "Calves", "Legs", "10-20", "Machine"),
        ("machine_biceps_curl", "Biceps Curl Machine", "Biceps", "Pull", "10-15", "Machine"),
        ("machine_ab_crunch", "Ab Crunch Machine", "Core", "Core", "10-15", "Machine"),
        ("cable_chest_press", "Cable Chest Press", "Chest", "Push", "8-12", "Cable"),
        ("cable_single_arm_press", "Single-Arm Cable Press", "Chest", "Push", "8-12", "Cable"),
        ("cable_landmine_press", "Cable Landmine Press", "Shoulders", "Push", "8-12", "Cable"),
        ("cable_broad_grip_row", "Wide-Grip Cable Row", "Back", "Pull", "8-12", "Cable"),
        ("cable_close_grip_row", "Close-Grip Cable Row", "Back", "Pull", "8-12", "Cable"),
        ("cable_reverse_grip_row", "Reverse-Grip Cable Row", "Lats", "Pull", "8-12", "Cable"),
        ("cable_half_kneeling_pulldown", "Half-Kneeling Pulldown", "Lats", "Pull", "8-12", "Cable"),
        ("cable_single_arm_pulldown", "Single-Arm Pulldown", "Lats", "Pull", "10-15", "Cable"),
        ("cable_face_pull_rope", "Rope Face Pull", "Rear Delts", "Pull", "12-20", "Cable"),
        ("cable_rear_delt_cross", "Cable Rear-Delt Cross", "Rear Delts", "Pull", "12-20", "Cable"),
        ("cable_bent_over_lateral", "Bent-Over Cable Lateral Raise", "Rear Delts", "Pull", "12-20", "Cable"),
        ("cable_biceps_curl_bar", "Bar Cable Curl", "Biceps", "Pull", "8-12", "Cable"),
        ("cable_biceps_curl_rope", "Rope Cable Curl", "Biceps", "Pull", "10-15", "Cable"),
        ("cable_triceps_pressdown_bar", "Straight-Bar Pressdown", "Triceps", "Push", "8-12", "Cable"),
        ("cable_triceps_pressdown_single", "Single-Arm Pressdown", "Triceps", "Push", "10-15", "Cable"),
        ("cable_triceps_crossbody", "Cross-Body Triceps Extension", "Triceps", "Push", "10-15", "Cable"),
        ("cable_overhead_single", "Single-Arm Overhead Extension", "Triceps", "Push", "10-15", "Cable"),
        ("cable_glute_kickback", "Cable Glute Kickback", "Glutes", "Legs", "12-20", "Cable"),
        ("cable_leg_abduction", "Cable Leg Abduction", "Glutes", "Legs", "12-20", "Cable"),
        ("cable_leg_adduction", "Cable Leg Adduction", "Adductors", "Legs", "12-20", "Cable"),
        ("cable_lift", "Cable Lift", "Core", "Core", "10-15", "Cable"),
        ("db_lateral_raise_seated", "Seated Lateral Raise", "Shoulders", "Push", "12-20", "Dumbbell"),
        ("db_rear_delt_row", "Rear-Delt Dumbbell Row", "Rear Delts", "Pull", "10-15", "Dumbbell"),
        ("db_incline_row", "Incline Dumbbell Row", "Upper Back", "Pull", "8-12", "Dumbbell"),
        ("db_single_leg_rdl", "Single-Leg Dumbbell RDL", "Hamstrings", "Legs", "8-12", "Dumbbell"),
        ("db_deficit_lunge", "Deficit Dumbbell Lunge", "Quads/Glutes", "Legs", "8-12", "Dumbbell"),
        ("db_goblet_squat", "Goblet Squat", "Quads", "Legs", "8-15", "Dumbbell"),
        ("db_cossack_squat", "Dumbbell Cossack Squat", "Adductors", "Legs", "8-12", "Dumbbell"),
        ("db_split_squat", "Dumbbell Split Squat", "Quads/Glutes", "Legs", "8-12", "Dumbbell"),
        ("db_hamstring_bridge", "Dumbbell Hamstring Bridge", "Hamstrings", "Legs", "10-15", "Dumbbell"),
        ("db_suitcase_carry", "Dumbbell Suitcase Carry", "Core", "Carry", "20-40 sec", "Dumbbell"),
        ("db_farmer_carry", "Dumbbell Farmer Carry", "Grip", "Carry", "20-40 sec", "Dumbbell"),
        ("db_wrist_curl", "Dumbbell Wrist Curl", "Forearms", "Pull", "12-20", "Dumbbell"),
        ("db_reverse_wrist_curl", "Reverse Wrist Curl", "Forearms", "Pull", "12-20", "Dumbbell"),
        ("db_tate_press", "Tate Press", "Triceps", "Push", "10-15", "Dumbbell"),
        ("db_skullcrusher", "Dumbbell Skullcrusher", "Triceps", "Push", "10-15", "Dumbbell"),
        ("kb_front_squat", "Double Kettlebell Front Squat", "Quads", "Legs", "6-12", "Kettlebell"),
        ("kb_rack_lunge", "Kettlebell Rack Lunge", "Quads/Glutes", "Legs", "8-12", "Kettlebell"),
        ("kb_single_arm_swing", "Single-Arm Kettlebell Swing", "Glutes", "Legs", "10-20", "Kettlebell"),
        ("kb_clean", "Kettlebell Clean", "Full Body", "Pull", "6-12", "Kettlebell"),
        ("kb_snatch", "Kettlebell Snatch", "Full Body", "Pull", "6-12", "Kettlebell"),
        ("kb_deadlift", "Kettlebell Deadlift", "Hamstrings", "Legs", "8-15", "Kettlebell"),
        ("kb_rack_carry", "Kettlebell Rack Carry", "Core", "Carry", "20-40 sec", "Kettlebell"),
        ("kb_bottoms_up_press", "Bottoms-Up Press", "Shoulders", "Push", "6-10", "Kettlebell"),
        ("kb_figure_eight", "Kettlebell Figure Eight", "Core", "Core", "10-20", "Kettlebell"),
        ("bb_close_grip_bench", "Close-Grip Bench Press", "Triceps", "Push", "5-10", "Barbell"),
        ("bb_wide_grip_bench", "Wide-Grip Bench Press", "Chest", "Push", "5-10", "Barbell"),
        ("bb_paused_bench", "Paused Bench Press", "Chest", "Push", "3-8", "Barbell"),
        ("bb_spoto_press", "Spoto Press", "Chest", "Push", "5-10", "Barbell"),
        ("bb_behind_neck_press", "Behind-Neck Press", "Shoulders", "Push", "8-12", "Barbell"),
        ("bb_zercher_squat", "Zercher Squat", "Quads", "Legs", "5-10", "Barbell"),
        ("bb_front_squat_paused", "Paused Front Squat", "Quads", "Legs", "3-8", "Barbell"),
        ("bb_box_squat", "Box Squat", "Quads", "Legs", "5-10", "Barbell"),
        ("bb_high_bar_squat", "High-Bar Squat", "Quads", "Legs", "5-10", "Barbell"),
        ("bb_stiff_leg_deadlift", "Stiff-Leg Deadlift", "Hamstrings", "Legs", "6-10", "Barbell"),
        ("bb_deficit_deadlift", "Deficit Deadlift", "Hamstrings", "Legs", "3-8", "Barbell"),
        ("bb_block_pull", "Block Pull", "Back", "Pull", "3-8", "Barbell"),
        ("bb_snatch_grip_deadlift", "Snatch-Grip Deadlift", "Back", "Pull", "5-10", "Barbell"),
        ("bb_yates_row", "Yates Row", "Back", "Pull", "8-12", "Barbell"),
        ("bb_landmine_row", "Landmine Row", "Back", "Pull", "8-12", "Barbell"),
        ("bb_overhead_carry", "Barbell Overhead Carry", "Core", "Carry", "20-40 sec", "Barbell"),
        ("bw_assisted_dip", "Assisted Dip", "Chest/Triceps", "Push", "6-12", "Bodyweight"),
        ("bw_ring_dip", "Ring Dip", "Chest/Triceps", "Push", "6-12", "Bodyweight"),
        ("bw_archer_pullup", "Archer Pull-Up", "Lats", "Pull", "3-8", "Bodyweight"),
        ("bw_deficit_pushup", "Deficit Push-Up", "Chest", "Push", "8-20", "Bodyweight"),
        ("bw_shrimp_squat", "Shrimp Squat", "Quads", "Legs", "5-12", "Bodyweight"),
        ("bw_sissy_squat", "Bodyweight Sissy Squat", "Quads", "Legs", "8-15", "Bodyweight"),
        ("bw_hanging_knee_raise", "Hanging Knee Raise", "Core", "Core", "8-15", "Bodyweight"),
        ("bw_ab_wheel", "Ab Wheel Rollout", "Core", "Core", "6-15", "Bodyweight"),
        ("bw_hollow_hold", "Hollow Body Hold", "Core", "Core", "20-40 sec", "Bodyweight"),
        ("bw_copenhagen_plank", "Copenhagen Plank", "Adductors", "Core", "20-40 sec", "Bodyweight"),
        ("bw_back_extension", "Bodyweight Back Extension", "Back", "Pull", "10-20", "Bodyweight"),
        ("cardio_rower", "Rowing Machine", "Full Body", "Cardio", "20-30 min", "Cardio"),
        ("cardio_assault_bike", "Assault Bike", "Full Body", "Cardio", "10-20 min", "Cardio"),
        ("cardio_ski_erg", "Ski Erg", "Full Body", "Cardio", "10-20 min", "Cardio"),
        ("cardio_stair_climber", "Stair Climber", "Legs", "Cardio", "15-30 min", "Cardio"),
        ("cardio_incline_walk", "Incline Treadmill Walk", "Legs", "Cardio", "20-40 min", "Cardio"),
        ("cardio_sled_push", "Sled Push", "Full Body", "Cardio", "20-40 m", "Cardio"),
        ("cardio_sled_drag", "Sled Drag", "Legs", "Cardio", "20-40 m", "Cardio"),
        ("cardio_battle_rope", "Battle Rope", "Full Body", "Cardio", "20-40 sec", "Cardio"),
        ("cardio_jump_rope", "Jump Rope", "Full Body", "Cardio", "5-15 min", "Cardio"),
        ("cardio_shuttle_run", "Shuttle Run", "Full Body", "Cardio", "10-20 rounds", "Cardio"),
        ("mobility_couch_stretch", "Couch Stretch", "Quads", "Mobility", "30-60 sec", "Bodyweight"),
        ("mobility_90_90", "90/90 Hip Switch", "Hips", "Mobility", "8-12", "Bodyweight"),
        ("mobility_world_greatest", "World’s Greatest Stretch", "Full Body", "Mobility", "5-8", "Bodyweight"),
        ("mobility_cat_cow", "Cat-Cow", "Back", "Mobility", "8-12", "Bodyweight"),
        ("mobility_wall_slide", "Wall Slide", "Shoulders", "Mobility", "8-15", "Bodyweight"),
        ("mobility_band_external_rotation", "Band External Rotation", "Rotator Cuff", "Mobility", "12-20", "Band"),
        ("mobility_band_dislocate", "Band Dislocate", "Shoulders", "Mobility", "8-15", "Band"),
        ("mobility_ankle_rocker", "Ankle Rocker", "Calves", "Mobility", "10-15", "Bodyweight"),
        ("mobility_adductor_rockback", "Adductor Rockback", "Adductors", "Mobility", "8-12", "Bodyweight"),
        ("machine_single_arm_row", "Single-Arm Row Machine", "Back", "Pull", "8-12", "Machine"),
        ("machine_vertical_chest_press", "Vertical Chest Press", "Chest", "Push", "8-12", "Machine"),
        ("machine_glute_kickback", "Glute Kickback Machine", "Glutes", "Legs", "10-15", "Machine"),
        ("machine_inner_thigh", "Inner Thigh Machine", "Adductors", "Legs", "12-20", "Machine"),
        ("machine_outer_thigh", "Outer Thigh Machine", "Glutes", "Legs", "12-20", "Machine"),
        ("machine_dip_chest", "Chest Dip Machine", "Chest", "Push", "8-12", "Machine"),
        ("machine_wrist_curl", "Wrist Curl Machine", "Forearms", "Pull", "12-20", "Machine"),
        ("cable_press_around", "Cable Press-Around", "Chest", "Push", "10-15", "Cable"),
        ("cable_reverse_fly", "Cable Reverse Fly", "Rear Delts", "Pull", "12-20", "Cable"),
        ("cable_shrug", "Cable Shrug", "Traps", "Pull", "10-15", "Cable"),
        ("cable_lean_away_raise", "Lean-Away Cable Raise", "Shoulders", "Push", "12-20", "Cable"),
        ("cable_split_stance_row", "Split-Stance Cable Row", "Back", "Pull", "8-12", "Cable"),
        ("cable_hip_flexion", "Cable Hip Flexion", "Hip Flexors", "Legs", "12-20", "Cable"),
        ("cable_reverse_crunch", "Cable Reverse Crunch", "Core", "Core", "10-15", "Cable"),
        ("cable_anti_rotation_walkout", "Anti-Rotation Walkout", "Core", "Core", "8-12", "Cable"),
        ("cable_side_bend", "Cable Side Bend", "Obliques", "Core", "10-15", "Cable"),
        ("cable_lateral_lunge", "Cable Lateral Lunge", "Adductors", "Legs", "8-12", "Cable"),
        ("db_floor_fly", "Dumbbell Floor Fly", "Chest", "Push", "10-15", "Dumbbell"),
        ("db_leaning_lateral_raise", "Leaning Lateral Raise", "Shoulders", "Push", "12-20", "Dumbbell"),
        ("db_high_pull", "Dumbbell High Pull", "Shoulders", "Pull", "8-12", "Dumbbell"),
        ("db_rear_delt_fly", "Dumbbell Rear-Delt Fly", "Rear Delts", "Pull", "12-20", "Dumbbell"),
        ("db_windmill", "Dumbbell Windmill", "Core", "Core", "8-12", "Dumbbell"),
        ("db_hindu_squat", "Dumbbell Hindu Squat", "Quads", "Legs", "10-20", "Dumbbell"),
        ("db_lateral_lunge", "Dumbbell Lateral Lunge", "Adductors", "Legs", "8-12", "Dumbbell"),
        ("db_curtsy_lunge", "Dumbbell Curtsy Lunge", "Glutes", "Legs", "8-12", "Dumbbell"),
        ("bb_reverse_grip_bench", "Reverse-Grip Bench Press", "Chest", "Push", "6-10", "Barbell"),
        ("bb_incline_row", "Incline Barbell Row", "Back", "Pull", "8-12", "Barbell"),
        ("bb_split_squat", "Barbell Split Squat", "Quads/Glutes", "Legs", "8-12", "Barbell"),
        ("bb_lateral_lunge", "Barbell Lateral Lunge", "Adductors", "Legs", "8-12", "Barbell"),
        ("bb_zercher_carry", "Zercher Carry", "Core", "Carry", "20-40 sec", "Barbell"),
        ("kb_dead_clean", "Kettlebell Dead Clean", "Full Body", "Pull", "6-12", "Kettlebell"),
        ("kb_lateral_lunge", "Kettlebell Lateral Lunge", "Adductors", "Legs", "8-12", "Kettlebell"),
        ("kb_carry_farmer", "Kettlebell Farmer Carry", "Grip", "Carry", "20-40 sec", "Kettlebell"),
        ("kb_seated_press", "Seated Kettlebell Press", "Shoulders", "Push", "8-12", "Kettlebell"),
        ("bw_handstand_pushup", "Handstand Push-Up", "Shoulders", "Push", "3-10", "Bodyweight"),
        ("bw_l_sit", "L-Sit", "Core", "Core", "10-30 sec", "Bodyweight"),
        ("bw_v_up", "V-Up", "Core", "Core", "8-15", "Bodyweight"),
        ("bw_reverse_hyper", "Bodyweight Reverse Hyperextension", "Glutes", "Legs", "10-20", "Bodyweight"),
        ("bw_hamstring_walkout", "Hamstring Walkout", "Hamstrings", "Legs", "6-12", "Bodyweight"),
        ("bw_incline_pushup", "Incline Push-Up", "Chest", "Push", "10-25", "Bodyweight"),
        ("bw_close_grip_pushup", "Close-Grip Push-Up", "Triceps", "Push", "8-20", "Bodyweight"),
        ("cardio_bike", "Stationary Bike", "Legs", "Cardio", "20-40 min", "Cardio"),
        ("cardio_elliptical", "Elliptical", "Full Body", "Cardio", "20-40 min", "Cardio"),
        ("cardio_treadmill_run", "Treadmill Run", "Full Body", "Cardio", "15-30 min", "Cardio"),
        ("cardio_farmer_walk", "Loaded Farmer Walk", "Full Body", "Cardio", "20-40 m", "Dumbbell"),
        ("mobility_deep_squat_hold", "Deep Squat Hold", "Hips", "Mobility", "20-60 sec", "Bodyweight"),
        ("mobility_pigeon", "Pigeon Stretch", "Glutes", "Mobility", "30-60 sec", "Bodyweight"),
        ("mobility_thoracic_rotation", "Thoracic Rotation", "Back", "Mobility", "8-12", "Bodyweight"),
        ("mobility_shoulder_pass", "Shoulder Pass-Through", "Shoulders", "Mobility", "8-15", "Band"),
        ("machine_standing_shoulder_press", "Standing Shoulder Press Machine", "Shoulders", "Push", "8-12", "Machine"),
        ("cable_single_arm_lateral_raise", "Single-Arm Cable Lateral Raise", "Shoulders", "Push", "12-20", "Cable"),
        ("db_front_rack_carry", "Dumbbell Front-Rack Carry", "Core", "Carry", "20-40 sec", "Dumbbell"),
        ("machine_iso_lateral_press", "Iso-Lateral Press Machine", "Chest", "Push", "8-12", "Machine"),
        ("machine_iso_lateral_row_machine", "Iso-Lateral Row Machine", "Back", "Pull", "8-12", "Machine"),
        ("machine_reverse_fly", "Reverse Fly Machine", "Rear Delts", "Pull", "10-15", "Machine"),
        ("machine_vertical_chest_fly", "Vertical Chest Fly Machine", "Chest", "Push", "10-15", "Machine"),
        ("machine_glute_ham_raise", "Glute-Ham Raise Machine", "Hamstrings", "Legs", "6-12", "Machine"),
        ("machine_reverse_hyper", "Reverse Hyperextension Machine", "Glutes", "Legs", "10-15", "Machine"),
        ("machine_donkey_calf", "Donkey Calf Raise Machine", "Calves", "Legs", "10-20", "Machine"),
        ("machine_45_back_extension", "45-Degree Back Extension Machine", "Back", "Pull", "10-15", "Machine"),
        ("machine_torso_rotation", "Torso Rotation Machine", "Obliques", "Core", "10-15", "Machine"),
        ("machine_hip_thrust", "Hip Thrust Machine", "Glutes", "Legs", "8-12", "Machine"),
        ("cable_low_row_single", "Single-Arm Low Cable Row", "Back", "Pull", "8-12", "Cable"),
        ("cable_mid_fly", "Mid-Height Cable Fly", "Chest", "Push", "10-15", "Cable"),
        ("cable_kneeling_crunch", "Kneeling Cable Crunch", "Core", "Core", "10-15", "Cable"),
        ("cable_reverse_fly_high", "High Cable Reverse Fly", "Rear Delts", "Pull", "12-20", "Cable"),
        ("cable_crossbody_curl", "Cross-Body Cable Curl", "Biceps", "Pull", "10-15", "Cable"),
        ("cable_triceps_kickback", "Cable Triceps Kickback", "Triceps", "Push", "10-15", "Cable"),
        ("cable_standing_leg_curl", "Standing Cable Leg Curl", "Hamstrings", "Legs", "10-15", "Cable"),
        ("cable_marching", "Cable Resisted March", "Core", "Core", "10-20", "Cable"),
        ("db_decline_press", "Decline Dumbbell Press", "Chest", "Push", "8-12", "Dumbbell"),
        ("db_decline_fly", "Decline Dumbbell Fly", "Chest", "Push", "10-15", "Dumbbell"),
        ("db_seated_press", "Seated Dumbbell Press", "Shoulders", "Push", "8-12", "Dumbbell"),
        ("db_reverse_lunge_front_rack", "Front-Rack Dumbbell Reverse Lunge", "Quads/Glutes", "Legs", "8-12", "Dumbbell"),
        ("db_hack_squat", "Dumbbell Hack Squat", "Quads", "Legs", "8-15", "Dumbbell"),
        ("db_lying_leg_raise", "Dumbbell Lying Leg Raise", "Core", "Core", "8-15", "Dumbbell"),
        ("db_overhead_carry", "Dumbbell Overhead Carry", "Core", "Carry", "20-40 sec", "Dumbbell"),
        ("bb_decline_bench", "Barbell Decline Bench Press", "Chest", "Push", "5-10", "Barbell"),
        ("bb_seated_press", "Seated Barbell Press", "Shoulders", "Push", "6-10", "Barbell"),
        ("bb_hang_clean", "Hang Power Clean", "Full Body", "Pull", "3-6", "Barbell"),
        ("bb_snatch", "Barbell Snatch", "Full Body", "Pull", "1-5", "Barbell"),
        ("bb_front_rack_lunge", "Front-Rack Barbell Lunge", "Quads/Glutes", "Legs", "8-12", "Barbell"),
        ("bb_romanian_single_leg", "Single-Leg Barbell RDL", "Hamstrings", "Legs", "8-12", "Barbell"),
        ("kb_double_clean", "Double Kettlebell Clean", "Full Body", "Pull", "6-12", "Kettlebell"),
        ("kb_double_push_press", "Double Kettlebell Push Press", "Shoulders", "Push", "6-12", "Kettlebell"),
        ("kb_front_rack_reverse_lunge", "Kettlebell Front-Rack Reverse Lunge", "Quads/Glutes", "Legs", "8-12", "Kettlebell"),
        ("kb_dead_bug", "Kettlebell Dead Bug", "Core", "Core", "8-12", "Kettlebell"),
        ("kb_overhead_carry", "Kettlebell Overhead Carry", "Core", "Carry", "20-40 sec", "Kettlebell"),
        ("bw_pullup_hold", "Pull-Up Isometric Hold", "Lats", "Pull", "10-30 sec", "Bodyweight"),
        ("bw_dip_hold", "Dip Isometric Hold", "Triceps", "Push", "10-30 sec", "Bodyweight"),
        ("bw_elevated_pike_pushup", "Elevated Pike Push-Up", "Shoulders", "Push", "6-15", "Bodyweight"),
        ("bw_lateral_stepdown", "Lateral Step-Down", "Quads", "Legs", "8-15", "Bodyweight"),
        ("bw_single_leg_squat_box", "Single-Leg Box Squat", "Quads", "Legs", "5-12", "Bodyweight"),
        ("bw_glute_ham_walkout", "Glute-Ham Walkout", "Hamstrings", "Legs", "6-12", "Bodyweight"),
        ("bw_prone_y_raise", "Prone Y Raise", "Rear Delts", "Pull", "10-20", "Bodyweight"),
        ("band_monster_walk", "Band Monster Walk", "Glutes", "Legs", "10-20", "Band"),
        ("band_clamshell", "Band Clamshell", "Glutes", "Legs", "12-20", "Band"),
        ("band_pullthrough", "Band Pull-Through", "Glutes", "Legs", "12-20", "Band"),
        ("cardio_spin_bike", "Spin Bike", "Legs", "Cardio", "20-40 min", "Cardio"),
        ("cardio_fan_bike_sprint", "Fan Bike Sprint", "Full Body", "Cardio", "10-30 sec", "Cardio"),
        ("cardio_sled_lateral_drag", "Lateral Sled Drag", "Legs", "Cardio", "20-40 m", "Cardio"),
        ("mobility_thread_needle", "Thread the Needle", "Shoulders", "Mobility", "8-12", "Bodyweight"),
        ("mobility_hip_flexor_reach", "Half-Kneeling Hip Flexor Reach", "Hips", "Mobility", "30-60 sec", "Bodyweight"),
        ("mobility_wrist_extension", "Wrist Extension Stretch", "Forearms", "Mobility", "20-40 sec", "Bodyweight"),
        ("machine_prone_leg_curl", "Prone Single-Leg Curl Machine", "Hamstrings", "Legs", "10-15", "Machine"),
        ("cable_standing_chest_fly", "Standing Cable Chest Fly", "Chest", "Push", "10-15", "Cable"),
        ("db_squat_to_press", "Dumbbell Squat to Press", "Full Body", "Push", "8-15", "Dumbbell"),
        ("bb_overhead_squat", "Barbell Overhead Squat", "Full Body", "Legs", "5-10", "Barbell"),
        ("kb_clean_and_press", "Kettlebell Clean and Press", "Full Body", "Push", "6-12", "Kettlebell"),
        ("bw_lateral_bound", "Lateral Bound", "Legs", "Cardio", "8-16", "Bodyweight"),
        ("mobility_scapular_wall_slide", "Scapular Wall Slide", "Shoulders", "Mobility", "8-15", "Bodyweight"),
    ]

    static let exercises: [TrainingExerciseCatalogItem] =
        machineSeeds.map { make($0, equipment: $0.id.hasPrefix("machine_smith_") ? "Smith Machine" : "Machine") } +
        cableSeeds.map { make($0, equipment: "Cable") } +
        dumbbellSeeds.map { make($0, equipment: "Dumbbell") } +
        genericMachineSeeds.map { make($0, equipment: "Machine") } +
        barbellSeeds.map { make($0, equipment: "Barbell") } +
        bodyweightSeeds.map { make($0, equipment: "Bodyweight") } +
        kettlebellSeeds.map { make($0, equipment: "Kettlebell") } +
        bandSeeds.map { make($0, equipment: "Band") } +
        expandedSeeds.map { make(($0.id, $0.name, $0.bodyPart, $0.category, $0.reps), equipment: $0.equipment) }

    private static let machineSeeds: [Seed] = [
        ("machine_smith_bench_press", "Smith Machine Bench Press", "Chest", "Push", "6-10"),
        ("machine_smith_incline_press", "Smith Machine Incline Press", "Upper Chest", "Push", "6-10"),
        ("machine_smith_decline_press", "Smith Machine Decline Press", "Chest", "Push", "8-12"),
        ("machine_smith_shoulder_press", "Smith Machine Shoulder Press", "Shoulders", "Push", "6-10"),
        ("machine_smith_back_squat", "Smith Machine Back Squat", "Quads", "Legs", "6-10"),
        ("machine_smith_front_squat", "Smith Machine Front Squat", "Quads", "Legs", "6-10"),
        ("machine_smith_hack_squat", "Smith Machine Hack Squat", "Quads", "Legs", "8-12"),
        ("machine_smith_lunge", "Smith Machine Lunge", "Quads/Glutes", "Legs", "8-12"),
        ("machine_smith_reverse_lunge", "Smith Machine Reverse Lunge", "Quads/Glutes", "Legs", "8-12"),
        ("machine_smith_split_squat", "Smith Machine Split Squat", "Quads/Glutes", "Legs", "8-12"),
        ("machine_smith_step_up", "Smith Machine Step-Up", "Quads/Glutes", "Legs", "8-12"),
        ("machine_smith_romanian_deadlift", "Smith Machine Romanian Deadlift", "Hamstrings", "Legs", "6-10"),
        ("machine_smith_stiff_leg_deadlift", "Smith Machine Stiff-Leg Deadlift", "Hamstrings", "Legs", "6-10"),
        ("machine_smith_good_morning", "Smith Machine Good Morning", "Hamstrings/Back", "Legs", "8-12"),
        ("machine_smith_hip_thrust", "Smith Machine Hip Thrust", "Glutes", "Legs", "8-12"),
        ("machine_smith_glute_bridge", "Smith Machine Glute Bridge", "Glutes", "Legs", "8-12"),
        ("machine_smith_calf_raise", "Smith Machine Calf Raise", "Calves", "Legs", "10-15"),
        ("machine_smith_seated_calf_raise", "Smith Machine Seated Calf Raise", "Calves", "Legs", "10-15"),
        ("machine_smith_behind_back_shrug", "Smith Machine Behind-the-Back Shrug", "Traps", "Pull", "8-12"),
        ("machine_smith_shrug", "Smith Machine Shrug", "Traps", "Pull", "8-12"),
        ("machine_smith_upright_row", "Smith Machine Upright Row", "Shoulders/Traps", "Pull", "8-12"),
        ("machine_smith_close_grip_bench_press", "Smith Machine Close-Grip Bench Press", "Triceps/Chest", "Push", "6-10"),
        ("machine_smith_floor_press", "Smith Machine Floor Press", "Chest/Triceps", "Push", "6-10"),
        ("machine_smith_row", "Smith Machine Row", "Back", "Pull", "8-12"),
        ("machine_plate_loaded_chest_press", "Plate-Loaded Chest Press", "Chest", "Push", "6-10"),
        ("machine_incline_chest_press", "Incline Chest Press Machine", "Upper Chest", "Push", "8-12"),
        ("machine_decline_chest_press", "Decline Chest Press Machine", "Chest", "Push", "8-12"),
        ("machine_iso_lateral_incline_press", "Iso-Lateral Incline Press", "Upper Chest", "Push", "8-12"),
        ("machine_iso_lateral_decline_press", "Iso-Lateral Decline Press", "Chest", "Push", "8-12"),
        ("machine_iso_lateral_shoulder_press", "Iso-Lateral Shoulder Press", "Shoulders", "Push", "8-12"),
        ("machine_iso_lateral_chest_press", "Iso-Lateral Chest Press", "Chest", "Push", "8-12"),
        ("machine_assisted_dip", "Assisted Dip Machine", "Chest/Triceps", "Push", "8-12"),
        ("machine_assisted_pull_up", "Assisted Pull-Up Machine", "Lats", "Pull", "6-10"),
        ("machine_high_row", "High Row Machine", "Upper Back", "Pull", "8-12"),
        ("machine_low_row", "Low Row Machine", "Back", "Pull", "8-12"),
        ("machine_iso_lateral_high_row", "Iso-Lateral High Row", "Upper Back", "Pull", "8-12"),
        ("machine_iso_lateral_low_row", "Iso-Lateral Low Row", "Back", "Pull", "8-12"),
        ("machine_iso_lateral_row", "Iso-Lateral Row", "Back", "Pull", "8-12"),
        ("machine_t_bar_row", "T-Bar Row Machine", "Back", "Pull", "6-10"),
        ("machine_pullover", "Pullover Machine", "Lats", "Pull", "8-12"),
        ("machine_wide_grip_pulldown", "Wide-Grip Pulldown Machine", "Lats", "Pull", "8-12"),
        ("machine_neutral_grip_pulldown", "Neutral-Grip Pulldown Machine", "Lats", "Pull", "8-12"),
        ("machine_reverse_grip_pulldown", "Reverse-Grip Pulldown Machine", "Lats/Biceps", "Pull", "8-12"),
        ("machine_iso_lateral_front_pulldown", "Iso-Lateral Front Pulldown", "Lats", "Pull", "8-12"),
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
        ("dumbbell_bench_press", "Dumbbell Bench Press", "Chest", "Push", "6-10"),
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
        ("dumbbell_curl", "Dumbbell Curl", "Biceps", "Arms", "8-12"),
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
        ("dumbbell_lunge", "Dumbbell Lunge", "Quads/Glutes", "Legs", "8-12"),
        ("dumbbell_walking_lunge", "Dumbbell Walking Lunge", "Quads/Glutes", "Legs", "8-12"),
        ("dumbbell_step_up", "Dumbbell Step-Up", "Quads/Glutes", "Legs", "8-12"),
        ("dumbbell_romanian_deadlift", "Dumbbell Romanian Deadlift", "Hamstrings", "Legs", "8-12"),
        ("dumbbell_deadlift", "Dumbbell Deadlift", "Hamstrings/Glutes", "Legs", "8-12"),
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

    private static let barbellSeeds: [Seed] = [
        ("barbell_incline_bench_press", "Barbell Incline Bench Press", "Upper Chest", "Push", "6-10"),
        ("barbell_close_grip_bench_press", "Close-Grip Barbell Bench Press", "Triceps/Chest", "Push", "6-10"),
        ("barbell_decline_bench_press", "Decline Bench Press", "Chest", "Push", "6-10"),
        ("barbell_floor_press", "Barbell Floor Press", "Chest/Triceps", "Push", "6-10"),
        ("barbell_front_squat", "Front Squat", "Quads", "Legs", "5-8"),
        ("barbell_pause_squat", "Pause Squat", "Quads/Glutes", "Legs", "5-8"),
        ("barbell_hex_bar_deadlift", "Hex Bar Deadlift", "Full Body", "Pull", "3-6"),
        ("barbell_good_morning", "Good Morning", "Hamstrings/Back", "Legs", "6-10"),
        ("barbell_stiff_leg_deadlift", "Barbell Stiff-Leg Deadlift", "Hamstrings", "Legs", "6-10"),
        ("barbell_row", "Bent-Over Barbell Row", "Back", "Pull", "6-10"),
        ("barbell_pendlay_row", "Pendlay Row", "Upper Back", "Pull", "5-8"),
        ("barbell_t_bar_row", "Landmine T-Bar Row", "Back", "Pull", "8-12"),
        ("barbell_landmine_press", "Landmine Press", "Shoulders", "Push", "8-12"),
        ("barbell_military_press", "Military Press", "Shoulders", "Push", "5-8"),
        ("barbell_seated_shoulder_press", "Seated Barbell Shoulder Press", "Shoulders", "Push", "6-10"),
        ("barbell_push_press", "Push Press", "Shoulders", "Push", "3-6"),
        ("barbell_upright_row", "Barbell Upright Row", "Shoulders/Traps", "Pull", "8-12"),
        ("barbell_shrug", "Barbell Shrug", "Traps", "Pull", "8-12"),
        ("barbell_hip_thrust", "Barbell Hip Thrust", "Glutes", "Legs", "8-12"),
        ("barbell_glute_bridge", "Barbell Glute Bridge", "Glutes", "Legs", "8-12"),
        ("barbell_reverse_lunge", "Barbell Reverse Lunge", "Quads/Glutes", "Legs", "8-12"),
        ("barbell_walking_lunge", "Barbell Walking Lunge", "Quads/Glutes", "Legs", "8-12"),
        ("barbell_calf_raise", "Barbell Calf Raise", "Calves", "Legs", "10-15"),
        ("barbell_seated_calf_raise", "Barbell Seated Calf Raise", "Calves", "Legs", "10-15"),
        ("barbell_reverse_curl", "Barbell Reverse Curl", "Forearms/Biceps", "Arms", "8-12"),
        ("barbell_preacher_curl", "Barbell Preacher Curl", "Biceps", "Arms", "8-12"),
        ("barbell_wrist_curl", "Barbell Wrist Curl", "Forearms", "Arms", "10-15"),
        ("barbell_reverse_wrist_curl", "Barbell Reverse Wrist Curl", "Forearms", "Arms", "10-15"),
        ("barbell_lying_triceps_extension", "Lying Triceps Extension", "Triceps", "Arms", "8-12"),
        ("barbell_rollout", "Barbell Rollout", "Core", "Core", "8-12"),
        ("barbell_clean_pull", "Clean Pull", "Full Body", "Conditioning", "3-6"),
        ("barbell_power_clean", "Power Clean", "Full Body", "Conditioning", "1-5"),
        ("barbell_clean", "Clean", "Full Body", "Conditioning", "1-5"),
        ("barbell_clean_and_jerk", "Clean and Jerk", "Full Body", "Conditioning", "1-5"),
        ("barbell_snatch", "Snatch", "Full Body", "Conditioning", "1-5")
    ]

    private static let bodyweightSeeds: [Seed] = [
        ("bodyweight_push_up", "Push-Up", "Chest", "Push", "8-20"),
        ("bodyweight_one_arm_push_up", "One-Arm Push-Up", "Chest/Triceps", "Push", "3-8"),
        ("bodyweight_decline_push_up", "Decline Push-Up", "Upper Chest", "Push", "8-20"),
        ("bodyweight_diamond_push_up", "Diamond Push-Up", "Triceps/Chest", "Push", "8-20"),
        ("bodyweight_pike_push_up", "Pike Push-Up", "Shoulders", "Push", "6-12"),
        ("bodyweight_dip", "Dip", "Chest/Triceps", "Push", "6-12"),
        ("bodyweight_chin_up", "Chin-Up", "Lats/Biceps", "Pull", "6-10"),
        ("bodyweight_neutral_grip_pull_up", "Neutral-Grip Pull-Up", "Lats/Biceps", "Pull", "6-10"),
        ("bodyweight_muscle_up", "Muscle-Up", "Full Body", "Pull", "1-5"),
        ("bodyweight_inverted_row", "Inverted Row", "Upper Back", "Pull", "8-15"),
        ("bodyweight_ring_row", "Ring Row", "Back", "Pull", "8-15"),
        ("bodyweight_negative_pull_up", "Negative Pull-Up", "Lats", "Pull", "3-6"),
        ("bodyweight_squat", "Bodyweight Squat", "Quads/Glutes", "Legs", "10-20"),
        ("bodyweight_split_squat", "Bodyweight Split Squat", "Quads/Glutes", "Legs", "8-15"),
        ("bodyweight_reverse_lunge", "Bodyweight Reverse Lunge", "Quads/Glutes", "Legs", "8-15"),
        ("bodyweight_walking_lunge", "Bodyweight Walking Lunge", "Quads/Glutes", "Legs", "10-20"),
        ("bodyweight_step_up", "Bodyweight Step-Up", "Quads/Glutes", "Legs", "8-15"),
        ("bodyweight_single_leg_squat", "Pistol Squat", "Quads/Glutes", "Legs", "3-8"),
        ("bodyweight_glute_bridge", "Glute Bridge", "Glutes", "Legs", "10-20"),
        ("bodyweight_single_leg_glute_bridge", "Single-Leg Glute Bridge", "Glutes/Hamstrings", "Legs", "8-15"),
        ("bodyweight_nordic_curl", "Nordic Hamstring Curl", "Hamstrings", "Legs", "3-8"),
        ("bodyweight_reverse_nordic", "Reverse Nordic", "Quads", "Legs", "6-12"),
        ("bodyweight_standing_calf_raise", "Standing Calf Raise", "Calves", "Legs", "12-25"),
        ("bodyweight_single_leg_calf_raise", "Single-Leg Calf Raise", "Calves", "Legs", "8-20"),
        ("bodyweight_tibialis_raise", "Tibialis Raise", "Tibialis", "Legs", "12-25"),
        ("bodyweight_crunch", "Crunch", "Core", "Core", "10-25"),
        ("bodyweight_sit_up", "Sit-Up", "Core", "Core", "10-25"),
        ("bodyweight_side_plank", "Side Plank", "Obliques", "Core", "20-60 sec"),
        ("bodyweight_hollow_hold", "Hollow Hold", "Core", "Core", "20-60 sec"),
        ("bodyweight_dead_bug", "Dead Bug", "Core", "Core", "8-12"),
        ("bodyweight_bird_dog", "Bird Dog", "Core", "Core", "8-12"),
        ("bodyweight_mountain_climber", "Mountain Climber", "Core", "Conditioning", "20-60 sec"),
        ("bodyweight_burpee", "Burpee", "Full Body", "Conditioning", "8-15"),
        ("bodyweight_bear_crawl", "Bear Crawl", "Full Body", "Conditioning", "20-60 sec"),
        ("bodyweight_wall_sit", "Wall Sit", "Quads", "Legs", "20-60 sec"),
        ("bodyweight_scapular_pull_up", "Scapular Pull-Up", "Lats/Upper Back", "Pull", "8-12")
    ]

    private static let kettlebellSeeds: [Seed] = [
        ("kettlebell_swing", "Kettlebell Swing", "Glutes/Hamstrings", "Conditioning", "10-20"),
        ("kettlebell_goblet_squat", "Kettlebell Goblet Squat", "Quads/Glutes", "Legs", "8-12"),
        ("kettlebell_front_rack_squat", "Kettlebell Front Rack Squat", "Quads", "Legs", "6-10"),
        ("kettlebell_sum_deadlift", "Kettlebell Sumo Deadlift", "Glutes/Hamstrings", "Legs", "8-12"),
        ("kettlebell_romanian_deadlift", "Kettlebell Romanian Deadlift", "Hamstrings", "Legs", "8-12"),
        ("kettlebell_single_leg_deadlift", "Kettlebell Single-Leg Deadlift", "Hamstrings/Glutes", "Legs", "8-12"),
        ("kettlebell_reverse_lunge", "Kettlebell Reverse Lunge", "Quads/Glutes", "Legs", "8-12"),
        ("kettlebell_step_up", "Kettlebell Step-Up", "Quads/Glutes", "Legs", "8-12"),
        ("kettlebell_floor_press", "Kettlebell Floor Press", "Chest/Triceps", "Push", "8-12"),
        ("kettlebell_overhead_press", "Kettlebell Overhead Press", "Shoulders", "Push", "6-10"),
        ("kettlebell_push_press", "Kettlebell Push Press", "Shoulders", "Push", "6-10"),
        ("kettlebell_row", "Kettlebell Row", "Back", "Pull", "8-12"),
        ("kettlebell_high_pull", "Kettlebell High Pull", "Traps/Shoulders", "Pull", "8-12"),
        ("kettlebell_curl", "Kettlebell Curl", "Biceps", "Arms", "8-12"),
        ("kettlebell_triceps_extension", "Kettlebell Triceps Extension", "Triceps", "Arms", "8-12"),
        ("kettlebell_farmers_carry", "Kettlebell Farmer's Carry", "Full Body", "Conditioning", "30-60 sec"),
        ("kettlebell_suitcase_carry", "Kettlebell Suitcase Carry", "Core/Forearms", "Conditioning", "30-60 sec"),
        ("kettlebell_turkish_get_up", "Turkish Get-Up", "Full Body", "Conditioning", "1-5"),
        ("kettlebell_russian_twist", "Kettlebell Russian Twist", "Obliques", "Core", "10-20"),
        ("kettlebell_windmill", "Kettlebell Windmill", "Core/Shoulders", "Core", "6-10")
    ]

    private static let bandSeeds: [Seed] = [
        ("band_chest_press", "Band Chest Press", "Chest", "Push", "10-20"),
        ("band_push_up", "Band-Resisted Push-Up", "Chest/Triceps", "Push", "8-15"),
        ("band_overhead_press", "Band Overhead Press", "Shoulders", "Push", "10-15"),
        ("band_lateral_raise", "Band Lateral Raise", "Shoulders", "Push", "12-20"),
        ("band_pull_apart", "Band Pull-Apart", "Rear Delts", "Pull", "12-25"),
        ("band_face_pull", "Band Face Pull", "Rear Delts", "Pull", "12-20"),
        ("band_lat_pulldown", "Band Lat Pulldown", "Lats", "Pull", "10-20"),
        ("band_row", "Band Row", "Back", "Pull", "10-20"),
        ("band_biceps_curl", "Band Biceps Curl", "Biceps", "Arms", "10-20"),
        ("band_hammer_curl", "Band Hammer Curl", "Biceps/Forearms", "Arms", "10-20"),
        ("band_triceps_pushdown", "Band Triceps Pushdown", "Triceps", "Arms", "10-20"),
        ("band_overhead_triceps_extension", "Band Overhead Triceps Extension", "Triceps", "Arms", "10-20"),
        ("band_squat", "Band Squat", "Quads/Glutes", "Legs", "10-20"),
        ("band_good_morning", "Band Good Morning", "Hamstrings/Back", "Legs", "10-20"),
        ("band_romanian_deadlift", "Band Romanian Deadlift", "Hamstrings", "Legs", "10-20"),
        ("band_glute_bridge", "Band Glute Bridge", "Glutes", "Legs", "12-25"),
        ("band_lateral_walk", "Band Lateral Walk", "Glutes", "Legs", "10-20"),
        ("band_hip_abduction", "Band Hip Abduction", "Glutes", "Legs", "12-25"),
        ("band_pallof_press", "Band Pallof Press", "Core", "Core", "10-20"),
        ("band_wood_chop", "Band Wood Chop", "Obliques", "Core", "10-20")
    ]

    private static let aliasesByID: [String: [String]] = [
        "barbell_row": ["Barbell Row", "Bent Over Barbell Row", "Bent-Over Row"],
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
        "machine_incline_chest_press": ["Hammer Strength Incline Press"],
        "machine_decline_chest_press": ["Hammer Strength Decline Press"],
        "machine_iso_lateral_incline_press": ["Hammer Strength Iso-Lateral Incline Press", "Hammer Iso-Lateral Incline Press"],
        "machine_iso_lateral_decline_press": ["Hammer Strength Iso-Lateral Decline Press", "Hammer Iso-Lateral Decline Press"],
        "machine_iso_lateral_shoulder_press": ["Hammer Strength Iso-Lateral Shoulder Press", "Hammer Iso-Lateral Shoulder Press"],
        "machine_iso_lateral_chest_press": ["Hammer Strength Iso-Lateral Chest Press", "Hammer Iso Chest Press"],
        "machine_high_row": ["Hammer Strength High Row"],
        "machine_low_row": ["Hammer Strength Low Row"],
        "machine_iso_lateral_high_row": ["Hammer Strength Iso-Lateral High Row", "Hammer Iso-Lateral High Row"],
        "machine_iso_lateral_low_row": ["Hammer Strength Iso-Lateral Low Row", "Hammer Iso-Lateral Low Row"],
        "machine_iso_lateral_row": ["Hammer Strength Iso-Lateral Row", "Hammer Strength Row"],
        "machine_iso_lateral_front_pulldown": ["Hammer Strength Iso-Lateral Front Pulldown", "Hammer Iso-Lateral Front Pulldown"],
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
            symbolName: symbol(for: seed.id, bodyPart: seed.bodyPart),
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

    private static func symbol(for id: String, bodyPart: String) -> String {
        let exerciseID = id.lowercased()
        let value = bodyPart.lowercased()
        if exerciseID.contains("wood_chop") || exerciseID.contains("pallof") || exerciseID.contains("crunch") || exerciseID.contains("plank") || exerciseID.contains("twist") {
            return "figure.core.training"
        }
        if exerciseID == "machine_back_extension" { return "figure.flexibility" }
        if exerciseID == "band_face_pull" { return "figure.strengthtraining.functional" }
        if exerciseID == "band_lat_pulldown" { return "figure.climbing" }
        if exerciseID == "machine_front_lat_pulldown" { return "figure.climbing" }
        if exerciseID.contains("face_pull") { return "figure.strengthtraining.functional" }
        if exerciseID.contains("external_rotation") || exerciseID.contains("internal_rotation") { return "figure.stand" }
        if exerciseID.contains("front_raise") { return "figure.stand" }
        if exerciseID.contains("neck") { return "figure.stand" }
        if exerciseID.contains("overhead_press") || exerciseID.contains("shoulder_press") || exerciseID.contains("push_press") || exerciseID.contains("arnold_press") || exerciseID.contains("military_press") { return "figure.stand" }
        if exerciseID.contains("calf_raise") {
            return exerciseID.contains("seated") ? "figure.seated.side" : "figure.stand"
        }
        if exerciseID.contains("leg_press") { return "figure.seated.side" }
        if exerciseID.contains("leg_extension") || exerciseID.contains("leg_curl") { return "figure.strengthtraining.functional" }
        if exerciseID.contains("push_up") || exerciseID.contains("pushup") || exerciseID.contains("dip") { return "figure.strengthtraining.functional" }
        if exerciseID.contains("stiff_leg_deadlift") || exerciseID.contains("romanian_deadlift") || exerciseID.contains("good_morning") { return "figure.flexibility" }
        if exerciseID.contains("hip_thrust") || exerciseID.contains("glute_bridge") { return "figure.strengthtraining.functional" }
        if exerciseID.contains("shrug") { return "figure.stand" }
        if exerciseID.contains("wrist_curl") || exerciseID.contains("wrist_extension") { return "figure.stand" }
        if exerciseID.contains("pull_apart") { return "figure.strengthtraining.functional" }
        if exerciseID.contains("overhead_triceps_extension") { return "figure.stand" }
        if exerciseID.contains("pull_up") || exerciseID.contains("chin_up") || exerciseID.contains("muscle_up") { return "figure.climbing" }
        if exerciseID.contains("pulldown") || exerciseID.contains("pull_over") || exerciseID.contains("pullover") { return "figure.climbing" }
        if exerciseID.contains("upright_row") || exerciseID.contains("upright row") { return "figure.stand" }
        if exerciseID == "barbell_row" || exerciseID.contains("chest_supported") || exerciseID.contains("seal_row") || exerciseID.contains("renegade_row") { return "figure.rower" }
        if (exerciseID.contains("cable") && exerciseID.contains("row")) || exerciseID.contains("seated_row") { return "figure.rower" }
        if exerciseID.contains("row") { return "figure.rower" }
        if exerciseID.contains("lateral_raise") { return "figure.stand" }
        if exerciseID.contains("fly") || exerciseID.contains("rear_delt") { return "figure.stand" }
        if value.contains("core") || value.contains("oblique") { return "figure.core.training" }
        if value.contains("quad") || value.contains("hamstring") || value.contains("glute") || value.contains("calf") || value.contains("leg") { return "figure.strengthtraining.functional" }
        if value.contains("chest") || value.contains("shoulder") || value.contains("tricep") || value.contains("bicep") {
            return "figure.strengthtraining.functional"
        }
        // Keep unresolved catalog entries neutral; a dumbbell implies equipment
        // that may not match the custom or prescription movement.
        return "figure.strengthtraining.functional"
    }
}

enum ExerciseGuidanceCatalog {
    static func guidance(for exercise: TrainingExerciseCatalogItem) -> ExerciseGuidance? {
        if let guidance = entries[exercise.id] { return guidance }
        let name = exercise.name.lowercased()
        if name.contains("back extension") {
            return .init(
                summary: "A controlled back extension for the glutes, hamstrings, and spinal erectors.",
                steps: ["Adjust the support and secure your feet before starting.", "Lower your torso through a comfortable range while keeping your spine controlled.", "Return to a controlled neutral position without arching backward."],
                cues: ["Avoid hyperextending at the top", "Use a slow, controlled range"]
            )
        }
        if name.contains("hyperextension") {
            return .init(
                summary: "A supported reverse hyperextension for the glutes, hamstrings, and lower back.",
                steps: ["Support your torso on the pad and hold the handles.", "Raise your legs using your hips while keeping your trunk steady.", "Lower your legs with control without swinging."],
                cues: ["Stop before your lower back arches", "Start with a light load"]
            )
        }
        if name.contains("leg extension") {
            return .init(
                summary: "A seated knee-extension movement for the quadriceps.",
                steps: ["Align your knees with the machine pivot and position the pad above your ankles.", "Extend your knees through a comfortable range while keeping your hips on the seat.", "Lower the pad slowly to the starting position."],
                cues: ["Keep your torso supported", "Avoid kicking or bouncing the load"]
            )
        }
        return fallbackGuidance(for: exercise)
    }

    private static let entries: [String: ExerciseGuidance] = [
        "barbell_bench_press": .init(
            summary: "A horizontal press for the chest, triceps, and front shoulders.",
            steps: ["Set your eyes beneath the bar and plant both feet.", "Retract your shoulder blades and lower the bar with control.", "Touch the lower chest, then press while keeping your upper back set."],
            cues: ["Use a spotter or safeties", "Keep wrists stacked over elbows"]
        ),
        "incline_db_press": .init(
            summary: "An angled dumbbell press emphasizing the upper chest and front shoulders.",
            steps: ["Set the bench to a moderate incline and brace your feet.", "Lower the dumbbells beside the upper chest with controlled elbows.", "Press upward and slightly inward without losing shoulder position."],
            cues: ["Avoid an excessively steep bench", "Control the bottom position"]
        ),
        "lat_pulldown": .init(
            summary: "A vertical pull that trains the lats and upper back through a controlled overhead range.",
            steps: ["Secure your thighs and take a comfortable overhand grip.", "Set your shoulders down before bending the elbows.", "Pull toward the upper chest, then return overhead under control."],
            cues: ["Keep the torso mostly still", "Do not pull behind the neck"]
        ),
        "pull_up": .init(
            summary: "A bodyweight vertical pull for the lats, upper back, and arms.",
            steps: ["Begin from a controlled hang with your ribs braced.", "Drive the elbows down as your chest rises toward the bar.", "Lower to a comfortable full range without dropping into the shoulders."],
            cues: ["Avoid swinging", "Use assistance when full reps break down"]
        ),
        "seated_cable_row": .init(
            summary: "A seated horizontal pull for the middle back, lats, and elbow flexors.",
            steps: ["Sit tall with the cable aligned near the lower ribs.", "Pull the handle toward your torso while keeping the chest steady.", "Reach forward under control without rounding aggressively."],
            cues: ["Lead with the elbows", "Keep momentum minimal"]
        ),
        "single_arm_db_row": .init(
            summary: "A supported single-arm row that trains the lats and upper back.",
            steps: ["Brace one hand and keep your spine long.", "Let the working shoulder reach naturally at the bottom.", "Row the dumbbell toward the hip, then lower it with control."],
            cues: ["Keep the hips square", "Do not twist to finish the rep"]
        ),
        "back_squat": .init(
            summary: "A barbell squat for the quads, glutes, and trunk.",
            steps: ["Set the bar securely, brace, and walk out with controlled steps.", "Descend between your hips while keeping balanced pressure through the feet.", "Drive upward with the torso and hips rising together."],
            cues: ["Use rack safeties", "Choose depth you can control"]
        ),
        "conventional_deadlift": .init(
            summary: "A floor pull that trains the posterior chain, back, and grip.",
            steps: ["Stand with the bar over mid-foot and take your grip.", "Brace, set your back, and remove slack from the bar.", "Push the floor away and stand tall without leaning backward."],
            cues: ["Keep the bar close", "Reset when position is lost"]
        ),
        "sumo_deadlift": .init(
            summary: "A wide-stance floor pull emphasizing the hips, legs, and back.",
            steps: ["Choose a stable wide stance and grip inside the legs.", "Brace and wedge the hips toward the bar before it leaves the floor.", "Push through the floor and finish with the knees and hips extended."],
            cues: ["Keep knees tracking with toes", "Do not jerk the bar from the floor"]
        ),
        "romanian_deadlift": .init(
            summary: "A hip hinge for the hamstrings, glutes, and spinal erectors.",
            steps: ["Start tall with the load close to the thighs.", "Push the hips back while maintaining a softly bent knee.", "Stop at your controlled hamstring range, then drive the hips forward."],
            cues: ["Keep the load close", "Do not chase floor depth"]
        ),
        "leg_press": .init(
            summary: "A supported machine press for the quads and glutes.",
            steps: ["Set your feet where the knees can track comfortably.", "Lower the platform until your pelvis is about to roll from the pad.", "Press through the whole foot without locking the knees forcefully."],
            cues: ["Keep hips against the pad", "Use the machine safeties"]
        ),
        "barbell_overhead_press": .init(
            summary: "A standing vertical press for the shoulders, triceps, and upper body.",
            steps: ["Hold the bar near the upper chest with wrists stacked.", "Brace the trunk and press while moving your head clear of the bar.", "Finish overhead with control, then return to the shoulders."],
            cues: ["Avoid excessive back extension", "Keep the bar path close"]
        ),
        "db_shoulder_press": .init(
            summary: "A dumbbell vertical press for the shoulders and triceps.",
            steps: ["Set the bench and begin with the dumbbells beside the shoulders.", "Press overhead while keeping the ribs controlled.", "Lower to a comfortable depth without bouncing."],
            cues: ["Keep forearms stacked", "Use a controlled setup"]
        ),
        "ez_bar_curl": .init(
            summary: "An elbow-flexion exercise for the biceps and forearms.",
            steps: ["Stand tall with a comfortable grip on the angled bar.", "Curl without allowing the upper arms to drift far forward.", "Squeeze briefly, then lower until the elbows extend under control."],
            cues: ["Keep the torso quiet", "Do not force painful wrist angles"]
        ),
        "triceps_pressdown": .init(
            summary: "A cable isolation movement for the triceps.",
            steps: ["Stand stable with the elbows near your sides.", "Extend the elbows until the arms are straight without shrugging.", "Return the handle under control while keeping the upper arms steady."],
            cues: ["Avoid leaning on the cable", "Use a pain-free attachment"]
        ),
        "plank": .init(
            summary: "An isometric trunk exercise that challenges full-body bracing.",
            steps: ["Set the elbows beneath the shoulders and extend the legs.", "Brace the abdomen and glutes to create a straight body line.", "Hold while breathing steadily and stop when position breaks."],
            cues: ["Do not let the lower back sag", "Quality matters more than duration"]
        )
    ]

    private static func fallbackGuidance(for exercise: TrainingExerciseCatalogItem) -> ExerciseGuidance {
        switch exercise.movementPattern {
        case .horizontalPress:
            return .init(
                summary: "A press pattern for the chest, triceps, and front shoulders.",
                steps: ["Set a stable base before unracking or starting the handles.", "Lower with control until the shoulders stay comfortable.", "Press smoothly while keeping wrists and elbows stacked."],
                cues: ["Control the bottom", "Keep the upper back set"]
            )
        case .verticalPress:
            return .init(
                summary: "An overhead press pattern for the shoulders and triceps.",
                steps: ["Brace your ribs and set the load near shoulder height.", "Press overhead without leaning back aggressively.", "Lower to the starting position under control."],
                cues: ["Keep the bar path close", "Use a range you can control"]
            )
        case .horizontalPull:
            return .init(
                summary: "A row pattern for the upper back, lats, and arms.",
                steps: ["Brace the torso and let the shoulder reach slightly at the start.", "Pull by driving the elbows back.", "Return with control without collapsing posture."],
                cues: ["Lead with elbows", "Avoid momentum"]
            )
        case .verticalPull:
            return .init(
                summary: "A vertical pull pattern for the lats, upper back, and arms.",
                steps: ["Start with the shoulders controlled and ribs braced.", "Pull the elbows down toward your sides.", "Return overhead under control."],
                cues: ["Do not yank from the bottom", "Keep reps smooth"]
            )
        case .squat:
            return .init(
                summary: "A knee-dominant leg movement for quads, glutes, and trunk control.",
                steps: ["Set your feet where your knees can track comfortably.", "Descend with control while staying balanced.", "Drive through the foot and stand tall."],
                cues: ["Knees track with toes", "Stay balanced"]
            )
        case .hinge:
            return .init(
                summary: "A hip-hinge pattern for hamstrings, glutes, and back.",
                steps: ["Start braced with the load close to the body.", "Push the hips back while keeping a controlled spine position.", "Drive the hips forward to finish the rep."],
                cues: ["Keep the load close", "Do not chase extra range"]
            )
        case .lunge:
            return .init(
                summary: "A single-leg pattern for quads, glutes, balance, and control.",
                steps: ["Set the front foot firmly and brace.", "Lower under control while the knee tracks comfortably.", "Push through the working leg to return."],
                cues: ["Own the balance", "Use a controlled stride"]
            )
        case .curl:
            return .init(
                summary: "An elbow-flexion accessory movement for the biceps and forearms.",
                steps: ["Set the upper arms steady.", "Curl through a pain-free range without swinging.", "Lower until the elbows extend under control."],
                cues: ["Keep shoulders quiet", "Control the negative"]
            )
        case .elbowExtension:
            return .init(
                summary: "An elbow-extension accessory movement for the triceps.",
                steps: ["Set the upper arms in a stable position.", "Extend the elbows without shrugging or rushing.", "Return to the start with control."],
                cues: ["Move at the elbow", "Use a comfortable attachment"]
            )
        case .shoulderIsolation:
            return .init(
                summary: "A shoulder accessory movement for delt-focused training.",
                steps: ["Start light enough to control the path.", "Raise through a comfortable range without swinging.", "Lower slowly and keep tension on the target muscle."],
                cues: ["Lead with the target area", "Avoid heaving"]
            )
        case .calf:
            return .init(
                summary: "A lower-leg accessory movement for calves or tibialis.",
                steps: ["Set the feet and brace on the machine or implement.", "Move through a controlled ankle range.", "Pause briefly at the hardest point before lowering."],
                cues: ["Use full controlled reps", "Avoid bouncing"]
            )
        case .core:
            return .init(
                summary: "A trunk-focused movement for bracing, flexion, or rotation control.",
                steps: ["Set your ribs and pelvis before starting.", "Move or hold without losing trunk position.", "Stop the set when position breaks."],
                cues: ["Breathe steadily", "Quality beats duration"]
            )
        case .carry:
            return .init(
                summary: "A loaded carry for grip, trunk stiffness, and conditioning.",
                steps: ["Pick up the load with a strong brace.", "Walk with controlled steps and tall posture.", "Set the load down safely before grip or posture fails."],
                cues: ["Do not rush", "Stay tall"]
            )
        case .other:
            return .init(
                summary: "A general training movement. Match the load and range to the goal of the workout.",
                steps: ["Set up with a stable position.", "Move through a controlled range.", "Stop if technique breaks down."],
                cues: ["Control every rep", "Use coach guidance when unsure"]
            )
        }
    }
}
