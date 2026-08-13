import SwiftUI

private struct TodayRecoveryRow: Identifiable {
    let muscle: ExerciseMuscleRegion
    let setCount: Int
    let hoursSinceTraining: Int
    let loadFraction: Double
    let status: String
    let statusReason: String
    let recommendation: String
    let tint: Color

    var id: ExerciseMuscleRegion { muscle }
    var name: String { muscle.displayName }
    var symbol: String { "figure.strengthtraining.traditional" }

    var lastTrainedLabel: String {
        hoursSinceTraining == 0 ? "trained this hour" : "trained \(hoursSinceTraining)h ago"
    }

    var setSummary: String {
        "\(setCount) working \(setCount == 1 ? "set" : "sets") this week"
    }

    var statusBadgeColor: Color {
        switch status {
        case "Recovering":
            return Color.liftGold
        case "Moderate load":
            return Color.liftBlue
        default:
            return Color.liftGreen
        }
    }

    var loadPercent: Int {
        max(0, min(100, Int((loadFraction * 100).rounded())))
    }

    var detail: String {
        "\(setSummary) · \(lastTrainedLabel)"
    }
}

struct TrainingTodayView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedStrainEntry: StrainEntry?
    @State private var selectedInjuryEntry: InjuryEntry?
    @State private var isLoggingStrain = false
    @State private var isLoggingInjury = false
    @State private var showRecoveryExplanation = false

    let planName: String
    let selectedWeek: WorkoutWeek?
    let scheduledSession: WorkoutSession?
    let plateauInsight: PlateauInsight?
    let onOpenPlateau: (PlateauInsight) -> Void
    let onDismissPlateau: (PlateauInsight) -> Void
    let onResumeWorkout: () -> Void
    let onStartScheduledWorkout: (WorkoutSession) -> Void
    let onStartFreestyleWorkout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let plateauInsight {
                PlateauAlertCard(insight: plateauInsight) {
                    onOpenPlateau(plateauInsight)
                } dismiss: {
                    onDismissPlateau(plateauInsight)
                }
            }

            if let activeWorkout = appState.activeWorkout {
                ActiveWorkoutResumeCard(workout: activeWorkout, onResume: onResumeWorkout)
            } else {
                if let selectedWeek, let scheduledSession {
                    TodayWorkoutLaunchCard(planName: planName, week: selectedWeek, session: scheduledSession) {
                        onStartScheduledWorkout(scheduledSession)
                    }
                } else {
                    TrackerMessageCard(
                        title: "No scheduled workout",
                        message: "Create a workout day inside Plans or start freestyle now."
                    )
                }

                Button(action: onStartFreestyleWorkout) {
                    Label("Start empty workout", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: LiftDesign.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.liftBlue)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            healthSection
            recoverySection
        }
        .sheet(item: $selectedStrainEntry) { entry in
            StrainEntryEditor(entry: entry) { updatedEntry in
                appState.upsertStrainEntry(updatedEntry)
            }
        }
        .sheet(isPresented: $isLoggingStrain) {
            StrainEntryEditor(entry: StrainEntry(occurredAt: .now, strain: 5)) { appState.upsertStrainEntry($0) }
        }
        .sheet(item: $selectedInjuryEntry) { entry in
            InjuryEntryEditor(entry: entry) { updatedEntry in
                appState.upsertInjuryEntry(updatedEntry)
            }
        }
        .sheet(isPresented: $isLoggingInjury) {
            InjuryEntryEditor(entry: InjuryEntry(occurredAt: .now, area: "", description: "", intensity: 5)) { appState.upsertInjuryEntry($0) }
        }
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Readiness")
                        .font(.title3.weight(.black))
                        .foregroundStyle(Color.liftText)
                    Text("Track strain and injuries so today's plan stays informed")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer(minLength: 8)
            }

            VStack(spacing: 10) {
                Button {
                    isLoggingStrain = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption.weight(.black))
                            .foregroundStyle(Color.liftBlue)
                            .frame(width: 28, height: 28)
                            .background(Color.liftBlue.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Latest strain")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.liftMuted)
                            if let latest = appState.latestStrainEntry {
                                Text("\(latest.strain)/10")
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(Color.liftText)
                                if !latest.notes.isEmpty {
                                    Text(latest.notes)
                                        .font(.caption2)
                                        .foregroundStyle(Color.liftMuted)
                                        .lineLimit(2)
                                }
                            } else {
                                Text("No strain check-in yet")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.liftText)
                            }
                        }
                        Spacer()
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Color.liftBlue)
                    }
                    .padding(11)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.liftText)

                if appState.activeInjuries.isEmpty {
                    Button {
                        isLoggingInjury = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle")
                                .font(.caption.weight(.black))
                                .foregroundStyle(Color.liftBlue)
                                .frame(width: 28, height: 28)
                                .background(Color.liftBlue.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No active injuries")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.liftText)
                                Text("Log any pain or soreness before training decisions.")
                                    .font(.caption2)
                                    .foregroundStyle(Color.liftMuted)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "plus")
                                .foregroundStyle(Color.liftBlue)
                        }
                        .padding(11)
                        .background(Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.liftText)
                } else {
                    ForEach(appState.activeInjuries.prefix(4)) { injury in
                        Button {
                            selectedInjuryEntry = injury
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftGold)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(injury.area): \(injury.description)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.liftText)
                                        .lineLimit(1)
                                    Text("Pain score \(injury.intensity)/10")
                                        .font(.caption2)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Spacer()
                                Text(injury.status == .resolved ? "Resolved" : "Active")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(injury.status == .resolved ? Color.liftGreen : Color.liftGold)
                            }
                            .padding(10)
                            .background(Color.liftCard)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.liftText)
                    }
                }
            }
        }
        .padding(14)
        .liftSurface()
    }

    private var recoverySection: some View {
        let summaries = recoverySummaries
        let overall = recoveryOverallStatus(from: summaries)

        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Recovery")
                        .font(.title3.weight(.black))
                        .foregroundStyle(Color.liftText)
                    Text("Workout-load guidance from your completed working sets")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer(minLength: 8)
                Button {
                    showRecoveryExplanation.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text("EXPLAIN")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(0.6)
                        Image(systemName: "info.circle")
                    }
                    .foregroundStyle(Color.liftBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.liftBlue.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Toggle recovery explanation")
            }

            HStack(spacing: 10) {
                Circle()
                    .fill(overall.tint.opacity(0.16))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption.weight(.black))
                            .foregroundStyle(overall.tint)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Readiness now")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.liftText)
                        Spacer()
                        Text(overall.status)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(overall.tint)
                    }
                    Text(overall.text)
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .padding(10)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(overall.tint.opacity(0.24), lineWidth: 1)
            }

            if showRecoveryExplanation {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recovery scoring")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftText)
                    Text("Based on last 7 days of completed working sets:")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Text("• Ready: older sessions or lower set volume")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Text("• Moderate load: training was recent and moderate")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Text("• Recovering: trained in under 24 hours with higher load (6+ sets)")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                .padding(10)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if summaries.isEmpty {
                Label("Complete a workout to see how each muscle group is handling recent training load.", systemImage: "figure.strengthtraining.traditional")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .padding(.vertical, 8)
            } else {
                ForEach(summaries.prefix(4)) { summary in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 11) {
                            Circle()
                                .fill(summary.statusBadgeColor.opacity(0.16))
                                .frame(width: 38, height: 38)
                                .overlay {
                                    Image(systemName: summary.symbol)
                                        .font(.caption.weight(.black))
                                        .foregroundStyle(summary.statusBadgeColor)
                                }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(summary.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.liftText)
                                    Spacer()
                                    Text(summary.status)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(summary.statusBadgeColor)
                                }
                                Text(summary.detail)
                                    .font(.caption2)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Text("\(summary.loadPercent)%")
                                .font(.caption.weight(.black).monospacedDigit())
                                .foregroundStyle(summary.statusBadgeColor)
                        }

                        GeometryReader { geometry in
                            Capsule()
                                .fill(Color.liftSeparator)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(summary.statusBadgeColor)
                                        .frame(width: geometry.size.width * summary.loadFraction)
                                }
                        }
                        .frame(height: 6)

                        Text(summary.statusReason)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .lineLimit(2)
                        Text(summary.recommendation)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(summary.statusBadgeColor)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(summary.statusBadgeColor.opacity(0.25), lineWidth: 1)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(summary.name), \(summary.status). \(summary.statusReason). \(summary.recommendation)")
                }
            }
        }
        .padding(16)
        .liftSurface()
    }

    private var recoverySummaries: [TodayRecoveryRow] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        var workingSets: [ExerciseMuscleRegion: [(date: Date, sets: Int)]] = [:]

        for workout in appState.completedWorkouts where workout.completedAt >= weekAgo {
            for exercise in workout.exercises {
                let count = workout.sets.filter {
                    $0.prescriptionID == exercise.id && $0.isComplete && !$0.isWarmup
                }.count
                guard count > 0 else { continue }

                for muscle in exercise.muscleProfile?.primary ?? [] {
                    workingSets[muscle, default: []].append((workout.completedAt, count))
                }
            }
        }

        return workingSets.compactMap { muscle, entries in
            let setCount = entries.reduce(0) { $0 + $1.sets }
            guard let lastTrained = entries.map(\.date).max() else { return nil }
            let hours = max(0, Int(Date.now.timeIntervalSince(lastTrained) / 3_600))
            let loadFraction = min(1, Double(setCount) / 12)

            let status: String
            let tint: Color
            let reason: String
            let recommendation: String
            if hours < 24 && setCount >= 6 {
                status = "Recovering"
                tint = .liftGold
                reason = "Recent heavy work (6+ sets in 24h) indicates elevated fatigue."
                recommendation = "Keep the next load submaximal and prioritize recovery work."
            } else if hours < 36 {
                status = "Moderate load"
                tint = .liftBlue
                reason = "You trained recently, so fatigue may still be present."
                recommendation = "Use normal progressions but monitor form and joint comfort."
            } else {
                status = "Ready"
                tint = .liftGreen
                reason = "Enough time and low load indicate recovery readiness."
                recommendation = "Good window for heavier or technical work."
            }

            return TodayRecoveryRow(
                muscle: muscle,
                setCount: setCount,
                hoursSinceTraining: hours,
                loadFraction: loadFraction,
                status: status,
                statusReason: reason,
                recommendation: recommendation,
                tint: tint
            )
        }
        .sorted {
            if $0.hoursSinceTraining == $1.hoursSinceTraining {
                return $0.setCount > $1.setCount
            }
            return $0.hoursSinceTraining < $1.hoursSinceTraining
        }
    }

    private func recoveryOverallStatus(from summaries: [TodayRecoveryRow]) -> (status: String, text: String, tint: Color) {
        guard !summaries.isEmpty else {
            return (
                "No recent signal",
                "Log a completed workout to generate an updated recovery recommendation.",
                Color.liftTextSecondary
            )
        }

        let highestRisk = summaries.max {
            if $0.status == $1.status { return $0.loadPercent < $1.loadPercent }
            if $0.status == "Recovering" { return false }
            if $1.status == "Recovering" { return true }
            return $0.status == "Moderate load"
        }

        guard let leading = highestRisk else {
            return ("Ready", "Your recent loading is within a normal range.", Color.liftGreen)
        }

        switch leading.status {
        case "Recovering":
            let region = leading.name
            return (
                "Recovering",
                "Prioritize lower intensity or technical work before pushing \(region).",
                Color.liftGold
            )
        case "Moderate load":
            return (
                "Moderate load",
                "Frequencies look normal, but keep progression gradual for joint comfort.",
                Color.liftBlue
            )
        default:
            return (
                "Ready",
                "Recent loading profile is favorable for heavier or technical work.",
                Color.liftGreen
            )
        }
    }
}

struct TodayWorkoutLaunchCard: View {
    @EnvironmentObject private var appState: AppState
    let planName: String
    let week: WorkoutWeek
    let session: WorkoutSession
    let onStart: () -> Void

    var body: some View {
        let prescriptions = appState.prescriptions(for: session)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftBlue)
                    .frame(width: 44, height: 44)
                    .background(Color.liftBlue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("TODAY'S WORKOUT")
                        .font(.caption2.weight(.black))
                        .tracking(0.9)
                        .foregroundStyle(Color.liftBlue)
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
                    Text("Start Workout")
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
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
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
                        .foregroundStyle(Color.liftBlue)
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
