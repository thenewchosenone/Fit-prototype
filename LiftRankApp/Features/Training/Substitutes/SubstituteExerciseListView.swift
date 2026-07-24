import SwiftUI

struct SubstituteExerciseListView: View {
    let sourceExercise: TrainingExerciseCatalogItem
    let recommendations: [ExerciseSubstitutionRecommendation]

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Alternatives to")
                            .font(.caption.weight(.black))
                            .tracking(1)
                            .foregroundStyle(Color.liftBlue)
                        Text(sourceExercise.name)
                            .font(.title2.weight(.black))
                        Text("Choose an exercise to review its muscles, technique, history, and records.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, recommendation in
                            NavigationLink {
                                ExerciseLibraryDetailView(exercise: recommendation.exercise)
                            } label: {
                                HStack(spacing: 13) {
                                    ExerciseCatalogIcon(exercise: recommendation.exercise)
                                        .frame(width: 48, height: 48)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(recommendation.exercise.name)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(Color.liftText)
                                        Text(recommendation.reasons.joined(separator: " • "))
                                            .font(.caption)
                                            .foregroundStyle(Color.liftMuted)
                                            .lineLimit(2)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.liftMuted)
                                }
                                .padding(14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(recommendation.exercise.name) exercise details")
                            .accessibilityIdentifier("substitute.exercise.\(recommendation.exercise.id)")

                            if index < recommendations.count - 1 {
                                Divider().overlay(Color.liftSeparator).padding(.leading, 74)
                            }
                        }
                    }
                    .liftSurface()
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Substitutes")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("substitutes.screen")
    }
}
