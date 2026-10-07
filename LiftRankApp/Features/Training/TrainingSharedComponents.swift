import SwiftUI

struct TrackerMessageCard: View {
    let title: String
    let message: String

    var body: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TodayWorkoutLaunchCard: View {
    @EnvironmentObject private var appState: AppState
    let planName: String
    let week: WorkoutWeek
    let session: WorkoutSession
    let eyebrow: String
    let actionTitle: String
    let onStart: () -> Void

    init(
        planName: String,
        week: WorkoutWeek,
        session: WorkoutSession,
        eyebrow: String = "TODAY'S WORKOUT",
        actionTitle: String = "Start Workout",
        onStart: @escaping () -> Void
    ) {
        self.planName = planName
        self.week = week
        self.session = session
        self.eyebrow = eyebrow
        self.actionTitle = actionTitle
        self.onStart = onStart
    }

    var body: some View {
        let prescriptions = appState.prescriptions(for: session)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftAccentText)
                    .frame(width: 44, height: 44)
                    .background(Color.liftBlue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(eyebrow)
                        .font(.caption2.weight(.black))
                        .tracking(0.9)
                        .foregroundStyle(Color.liftAccentText)
                    Text(planName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(1)
                    Text(session.name)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                }

                Spacer()
            }

            if prescriptions.isEmpty {
                Text("No exercises yet. Build the workout as you train.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            } else {
                Text("\(prescriptions.count) exercises • \(session.day) • \(week.title)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
            }

            Button(action: onStart) {
                HStack {
                    Text(actionTitle)
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Color.liftOnAccent)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Color.liftBlue)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("training.today.startScheduledWorkout")
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

struct ActiveWorkoutResumeCard: View {
    @EnvironmentObject private var appState: AppState
    let workout: ActiveWorkoutState
    let onResume: () -> Void

    var body: some View {
        Button(action: onResume) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 12) {
                    Image(systemName: workout.pausedAt == nil ? "waveform.path.ecg" : "pause.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.liftOnAccent)
                        .frame(width: 44, height: 44)
                        .background(Color.liftGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout.pausedAt == nil ? "ACTIVE WORKOUT" : "PAUSED WORKOUT")
                            .font(.caption2.weight(.black))
                            .tracking(1)
                            .foregroundStyle(Color.liftGreen)
                        Text(workout.name)
                            .font(.headline.weight(.black))
                            .foregroundStyle(Color.liftText)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.liftAccentText)
                }

                HStack {
                    Label("\(workout.exercises.count) exercises", systemImage: "dumbbell.fill")
                    Spacer()
                    Label("\(appState.activeWorkoutCompletedWorkingSetCount) sets logged", systemImage: "checkmark.circle.fill")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            }
            .padding(14)
            .background(Color.liftGreen.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.liftGreen.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume active workout, \(workout.name)")
    }
}
