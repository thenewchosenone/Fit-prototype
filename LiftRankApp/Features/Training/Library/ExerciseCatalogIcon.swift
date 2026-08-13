import SwiftUI

struct ExerciseCatalogIcon: View {
    let exercise: TrainingExerciseCatalogItem

    var body: some View {
        ExerciseMuscleMap(profile: exercise.resolvedMuscleProfile, displayStyle: .compact)
        .frame(width: 54, height: 54)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let profile = exercise.resolvedMuscleProfile
        let secondary = profile.secondary.isEmpty ? "" : "; assisting \(profile.secondaryDescription)"
        return "\(exercise.name); primary muscles \(profile.primaryDescription)\(secondary)"
    }
}
