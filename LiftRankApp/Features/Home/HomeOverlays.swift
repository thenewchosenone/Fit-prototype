import AVKit
import SwiftUI

extension View {
    func homePanelStyle() -> some View {
        liftSurface()
    }
}

struct RecentPRSetContext {
    let workout: CompletedWorkout
    let exercise: WorkoutExerciseSnapshot
    let set: WorkoutSetLog
}

struct RecentPRDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let lift: LiftSubmission
    @State private var playbackURL: URL?
    @State private var isResolvingPlayback = false

    private var setContext: RecentPRSetContext? {
        let linked = appState.completedWorkouts.filter { $0.linkedSubmissionIDs.contains(lift.id) }
        for workout in linked {
            if let context = matchingContext(in: workout, requiresExactMatch: false) { return context }
        }

        return appState.completedWorkouts
            .filter { abs($0.completedAt.timeIntervalSince(lift.performedAt)) <= 172_800 }
            .sorted { abs($0.completedAt.timeIntervalSince(lift.performedAt)) < abs($1.completedAt.timeIntervalSince(lift.performedAt)) }
            .compactMap { matchingContext(in: $0, requiresExactMatch: true) }
            .first
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        attemptHeader

                        if let mediaID = lift.demoMediaID {
                            DemoMediaCard(
                                title: lift.exerciseName,
                                subtitle: MeasurementFormatting.recordedLiftSetText(weight: lift.weight, unit: lift.unit, repetitions: lift.repetitions),
                                mediaID: mediaID,
                                badge: "PR Video"
                            )
                        } else if let playbackURL {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("PR video")
                                    .font(.headline.weight(.bold))
                                VideoPlayer(player: AVPlayer(url: playbackURL))
                                    .frame(height: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .padding(14)
                            .liftSurface()
                        } else if isResolvingPlayback {
                            LiftCard {
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Preparing PR video…")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                        } else if lift.videoAssetID != nil || lift.localVideoURL != nil || lift.remoteVideoURL != nil {
                            LiftEmptyState(
                                title: "Video unavailable",
                                message: "The video could not be opened. Try this PR again after reconnecting.",
                                symbolName: "video.slash"
                            )
                        }

                        if let setContext {
                            workoutSetCard(setContext)
                        } else if lift.demoMediaID == nil && playbackURL == nil &&
                                    lift.videoAssetID == nil && lift.localVideoURL == nil && lift.remoteVideoURL == nil {
                            LiftEmptyState(
                                title: "Workout set unavailable",
                                message: "This PR was not linked to a completed workout and has no video attached.",
                                symbolName: "link.badge.plus"
                            )
                        }

                        attemptDetails
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("PR details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: lift.id) {
                guard lift.demoMediaID == nil else { return }
                isResolvingPlayback = true
                playbackURL = await appState.competitionStore.playbackURL(for: lift)
                isResolvingPlayback = false
            }
        }
    }

    private var attemptHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(Color.liftGold)
                    .frame(width: 46, height: 46)
                    .background(Color.liftGold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(lift.exerciseName)
                        .font(.headline.weight(.black))
                    Text(LiftTimeFormatter.shortDateTime(lift.performedAt))
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(MeasurementFormatting.formatWeight(lift.weight))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                Text(lift.unit.shortLabel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
                Text(MeasurementFormatting.repetitionText(lift.repetitions, includeLabel: true))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }

            VerificationBadge(evidenceStatus: lift.resolvedEvidenceStatus)
        }
        .padding(16)
        .liftSurface()
    }

    private func workoutSetCard(_ context: RecentPRSetContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PR workout set")
                        .font(.headline.weight(.bold))
                    Text("\(context.workout.name) · \(LiftTimeFormatter.shortDateTime(context.workout.completedAt))")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Image(systemName: "link.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.liftBlue)
            }

            HStack(spacing: 12) {
                Text(context.set.isWarmup ? "W" : "\(context.set.setNumber)")
                    .font(.caption.weight(.black).monospacedDigit())
                    .foregroundStyle(Color.liftBlue)
                    .frame(width: 34, height: 34)
                    .background(Color.liftBlue.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.exercise.exerciseName)
                        .font(.subheadline.weight(.bold))
                    Text("Set \(context.set.setNumber)")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(MeasurementFormatting.workoutSetText(set: context.set, trackingKind: trackingKind(for: context.exercise)))
                        .font(.subheadline.weight(.black).monospacedDigit())
                    if let rpe = context.set.rpe {
                        Text("RPE \(rpe)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftBlue)
                    }
                }
            }
            .padding(12)
            .background(Color.liftCardRaised.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            NavigationLink {
                CompletedWorkoutDetailView(workout: context.workout)
                    .environmentObject(appState)
            } label: {
                Label("View full workout", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiftSecondaryButtonStyle())
        }
        .padding(14)
        .liftSurface()
    }

    private var attemptDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attempt details")
                .font(.headline.weight(.bold))
            detailRow("Bodyweight", MeasurementFormatting.formatBodyweight(lift.bodyweightAtLift, preferredUnit: appState.currentProfile.preferredUnit))
            detailRow("Relative strength", RankingFormatting.ratioText(lift.bodyweightMultiple))
            detailRow("Evidence", lift.resolvedEvidenceStatus.rawValue)
            detailRow("Review status", lift.resolvedModerationStatus.rawValue)
        }
        .padding(14)
        .liftSurface()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.liftMuted)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func matchingContext(in workout: CompletedWorkout, requiresExactMatch: Bool) -> RecentPRSetContext? {
        let exercises = workout.exercises.filter(exerciseMatchesLift)
        let candidates = exercises.flatMap { exercise in
            workout.sets
                .filter { $0.prescriptionID == exercise.id && $0.isComplete && !$0.isWarmup }
                .map { RecentPRSetContext(workout: workout, exercise: exercise, set: $0) }
        }
        guard !candidates.isEmpty else { return nil }

        if let exact = candidates.first(where: { context in
            context.set.reps == lift.repetitions && abs(setWeightInPounds(context.set) - liftWeightInPounds) < 0.6
        }) {
            return exact
        }
        guard !requiresExactMatch else { return nil }
        return candidates.min { lhs, rhs in
            let lhsDistance = abs(setWeightInPounds(lhs.set) - liftWeightInPounds) + Double(abs((lhs.set.reps ?? 0) - lift.repetitions) * 20)
            let rhsDistance = abs(setWeightInPounds(rhs.set) - liftWeightInPounds) + Double(abs((rhs.set.reps ?? 0) - lift.repetitions) * 20)
            return lhsDistance < rhsDistance
        }
    }

    private func exerciseMatchesLift(_ exercise: WorkoutExerciseSnapshot) -> Bool {
        if exercise.exerciseID == lift.exerciseID || exercise.rankingExerciseID == lift.exerciseID { return true }
        let exerciseName = exercise.exerciseName.lowercased().filter(\.isLetter)
        let liftName = lift.exerciseName.lowercased().filter(\.isLetter)
        return exerciseName == liftName
    }

    private var liftWeightInPounds: Double {
        MeasurementFormatting.convert(lift.weight, from: lift.unit, to: .pounds)
    }

    private func setWeightInPounds(_ set: WorkoutSetLog) -> Double {
        guard let weight = set.weight else { return 0 }
        return MeasurementFormatting.convert(weight, from: set.recordedUnit, to: .pounds)
    }

    private func trackingKind(for exercise: WorkoutExerciseSnapshot) -> ExerciseTrackingKind {
        let catalog = appState.trainingExerciseLibrary.first { $0.id == exercise.exerciseID }
        return ExerciseTrackingKind(catalog?.trackingType ?? "Weight + Reps")
    }
}

struct HomeNotificationCenterView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if appState.notifications.isEmpty {
                            emptyState
                        } else {
                            ForEach(appState.sortedNotifications) { notification in
                                Button {
                                    appState.openNotification(notification)
                                    dismiss()
                                } label: {
                                    notificationRow(notification)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint(accessibilityHint(for: notification))
                            }
                        }
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if appState.unreadNotificationCount > 0 {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Read all") {
                            appState.markAllNotificationsRead()
                        }
                    }
                }
            }
        }
    }

    private func notificationRow(_ notification: NotificationItem) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol(for: notification.kind))
                .font(.headline.weight(.bold))
                .foregroundStyle(tint(for: notification.kind))
                .frame(width: 44, height: 44)
                .background(tint(for: notification.kind).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(notification.title)
                        .font(.headline)
                        .foregroundStyle(Color.liftText)
                    Spacer()
                    if !notification.isRead {
                        Circle()
                            .fill(Color.liftBlue)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LiftTimeFormatter.relativeNoSeconds(from: notification.createdAt))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.liftBlue)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftBlue)
                .frame(maxHeight: .infinity)
        }
        .padding(14)
        .background(notification.isRead ? Color.liftCard : Color.liftBlue.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(notification.isRead ? Color.liftSeparator : Color.liftBlue.opacity(0.32), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        LiftEmptyState(
            title: "You’re all caught up",
            message: "Ranking changes, lift reviews, and achievements will appear here.",
            symbolName: "bell.slash.fill"
        )
    }

    private func symbol(for kind: String) -> String {
        let value = kind.lowercased()
        if value.contains("approved") { return "checkmark.seal.fill" }
        if value.contains("ranking") { return "chart.line.uptrend.xyaxis" }
        if value.contains("achievement") { return "trophy.fill" }
        if value.contains("friend") { return "person.badge.plus" }
        return "bell.fill"
    }

    private func accessibilityHint(for notification: NotificationItem) -> String {
        let kind = notification.kind.lowercased()
        if kind.contains("ranking") { return "Opens your position on the leaderboard" }
        if kind.contains("friend") { return "Opens your profile" }
        if kind.contains("gym") { return "Opens your gym details" }
        if kind.contains("lift") || kind.contains("approved") || kind.contains("rejected") || kind.contains("achievement") {
            return "Opens your profile"
        }
        return "Opens the related area"
    }

    private func tint(for kind: String) -> Color {
        let value = kind.lowercased()
        if value.contains("approved") { return .liftGreen }
        if value.contains("ranking") { return .liftBlue }
        if value.contains("achievement") { return .liftGold }
        return .liftPurple
    }
}

struct StreakDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let streakDays: Int

    var body: some View {
        AppBackground {
            VStack(spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CONSISTENCY")
                            .font(.caption2.weight(.black))
                            .tracking(1.3)
                            .foregroundStyle(.orange)
                        Text("Workout streak")
                            .font(.title2.weight(.black))
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 40, height: 40)
                            .background(Color.liftCard)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 150, height: 150)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom)
                        )
                    Text("\(streakDays)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .offset(y: 65)
                }
                .padding(.bottom, 12)

                Text(streakDays == 1 ? "1 day streak" : "\(streakDays) day streak")
                    .font(.title.weight(.black))
                Text(streakMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                    .multilineTextAlignment(.center)

                HStack(spacing: 7) {
                    ForEach(1...7, id: \.self) { day in
                        VStack(spacing: 7) {
                            Circle()
                                .fill(day <= streakDays ? Color.orange : Color.liftSeparator)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: day <= streakDays ? "checkmark" : "circle")
                                        .font(.caption2.weight(.black))
                                        .foregroundStyle(day <= streakDays ? Color.liftBackground : Color.liftMuted)
                                }
                            Text("\(day)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.liftMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private var streakMessage: String {
        if streakDays == 0 {
            return "Complete a workout today to begin a new streak."
        }
        if streakDays < 7 {
            return "Keep training consistently. Your next milestone unlocks at 7 days."
        }
        return "Your streak is active. Complete another workout by tomorrow to keep it going."
    }
}
