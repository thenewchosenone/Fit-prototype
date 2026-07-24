# Codex continuation note for July 28, 2026

## Active goal
Continue the Product Consistency Bug-Finding Plan for LiftRank. Do not mark the goal complete until the full requirement-by-requirement audit proves every pass and acceptance criterion.

## Current status
The latest completed implementation slice added swipe-left actions for active workout exercises:

- Swipe left on an active workout exercise row to reveal `Substitute` and `Remove`.
- Substitute opens a picker backed by app exercise recommendations.
- Already-active exercises are disabled in the substitute list.
- Context menu also includes `Find Substitute`.
- Simulator build passed with:
  `xcodebuild -project LiftRank.xcodeproj -scheme LiftRank -destination 'platform=iOS Simulator,name=iPhone 17' build-for-testing`

## Last validated build result
`TEST BUILD SUCCEEDED`

## Work in progress when paused
Started a training/home presentation consistency audit. No code changes were made in this pass before pausing.

Files inspected in this pass:

- `LiftRankApp/Features/Home/HomeOverlays.swift`
- `LiftRankApp/Core/DesignSystem/MeasurementFormatting.swift`
- `LiftRankTests/WorkoutPresentationFormattingTests.swift`

Potential next bug to fix:

- In `HomeOverlays.swift`, `RecentPRDetailView.workoutSetCard(_:)` displays a completed workout set using:
  `MeasurementFormatting.liftSetText(weightKilograms: context.set.weight ?? 0, unit: context.set.recordedUnit, repetitions: context.set.reps ?? 0)`
- This is suspicious because `liftSetText(weightKilograms:unit:)` expects the input value to be normalized kilograms, then converts to the requested display unit.
- `WorkoutSetLog.weight` appears to be stored in the recorded unit, so a 500 lb recorded set can be converted again and displayed as 1102.3 lb.
- Likely fix: use `MeasurementFormatting.workoutSetText(set: context.set, trackingKind: context.exercise.trackingKind)` if `WorkoutExerciseSnapshot` exposes `trackingKind`; otherwise use `.weightReps` only after verifying the type.

Second potential consistency issue:

- In `HomeOverlays.swift`, `attemptDetails` displays bodyweight with:
  `MeasurementFormatting.formatRecordedWeight(lift.bodyweightAtLift, unit: .pounds)`
- `bodyweightAtLift` is pounds storage. If the viewer/user prefers kilograms, this should likely use:
  `MeasurementFormatting.formatBodyweight(lift.bodyweightAtLift, preferredUnit: appState.currentProfile.preferredUnit)`
- This aligns with leaderboard/bodyweight helpers.

Recommended July 28 restart plan

1. Patch `HomeOverlays.swift` PR set display to use the canonical recorded-set helper.
2. Patch PR bodyweight display to use preferred-unit bodyweight formatting.
3. Add/extend focused tests in `WorkoutPresentationFormattingTests.swift` if helper-level coverage is enough.
4. Run the simulator build gate.
5. Continue the product consistency audit with another small themed batch.

## Important constraints

- Do not use git unless the user explicitly asks.
- Do not rerun validation unless the active batch calls for the build gate or the user asks.
- Preserve unrelated user changes.
- Canonical weights are kilograms internally for ranking; raw workout sets use recorded units; bodyweight storage is pounds and converts at display.
