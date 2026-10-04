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

    @ViewBuilder
    private var movementIcon: some View {
        let name = exercise.name.lowercased()
        let gradient = LinearGradient(
            colors: [Color(red: 0.89, green: 1.0, blue: 0.38), Color.liftBlue],
            startPoint: .top,
            endPoint: .bottom
        )
        if name.contains("overhead press") || name.contains("shoulder press") || name.contains("push press") {
            ZStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 25, weight: .semibold))
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18, weight: .bold))
                    .offset(y: -13)
            }
            .foregroundStyle(gradient)
        } else {
            Image(systemName: exercise.symbolName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(gradient)
        }
    }
}
