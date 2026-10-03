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
                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                }

            Image(systemName: exercise.symbolName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.89, green: 1.0, blue: 0.38), Color.liftBlue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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
}
