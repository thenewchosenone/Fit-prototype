import SwiftUI

struct TrainingPlansView: View {
    @EnvironmentObject private var appState: AppState

    @Binding var selectedWeekID: UUID?
    @Binding var detailTab: String
    @Binding var selectedSessionForAdd: WorkoutSession?
    @Binding var selectedSessionToRun: WorkoutSession?
    @Binding var selectedProgramTemplate: WorkoutProgramTemplate?
    @Binding var isProgramLibraryExpanded: Bool

    let onCreatePlan: () -> Void
    let onSelectPlan: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            programLibrary

            if !appState.strainEntries.isEmpty || !appState.injuryEntries.isEmpty {
                healthSummarySection
            }

            if appState.workoutPlans.count > 1 {
                planPicker
            }

            ProgramPlanDetailView(
                selectedWeekID: $selectedWeekID,
                detailTab: $detailTab,
                selectedSessionForAdd: $selectedSessionForAdd,
                selectedSessionToRun: $selectedSessionToRun
            )
            .environmentObject(appState)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var planPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Plans")
                    .font(.headline)
                Spacer()
                Button(action: onCreatePlan) {
                    Label("New", systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.liftBlue)
            }

            VStack(spacing: 0) {
                ForEach(Array(appState.workoutPlans.enumerated()), id: \.element.id) { index, plan in
                    Button {
                        onSelectPlan(plan.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(plan.id == appState.selectedWorkoutPlanID ? Color.liftBlue : Color.liftMuted)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(plan.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.liftText)
                                    .lineLimit(1)
                                Text(plan.goal)
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if plan.id == appState.selectedWorkoutPlanID {
                                Label("Active", systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftGreen)
                            } else {
                                Text("Make Active")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftBlue)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 58)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("training.plan.\(plan.id.uuidString)")
                    .accessibilityValue(plan.id == appState.selectedWorkoutPlanID ? "Selected" : "Not selected")

                    if index < appState.workoutPlans.count - 1 {
                        Divider()
                            .overlay(Color.white.opacity(0.07))
                            .padding(.leading, 54)
                    }
                }
            }
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
        }
    }

    private var healthSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Readiness")
                .font(.headline)
            Text("Strain and active injuries from your training health log.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)

            VStack(spacing: 8) {
                if let latest = appState.latestStrainEntry {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundStyle(Color.liftBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Latest strain: \(latest.strain)/10")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.liftText)
                            if !latest.notes.isEmpty {
                                Text(latest.notes)
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Text(latest.occurredAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    .padding(10)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundStyle(Color.liftBlue)
                        Text("No strain check-ins yet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftText)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }

                if appState.activeInjuries.isEmpty {
                    HStack(spacing: 10) {
                        Text("No active injuries")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftText)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                } else {
                    ForEach(appState.activeInjuries.prefix(4)) { injury in
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(Color.liftGold)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
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
                }
            }
        }
        .padding(14)
        .liftSurface()
    }

    private var programLibrary: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button {
                withAnimation(.snappy) { isProgramLibraryExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(Color.liftBlue)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Browse Workout Programs")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.liftText)
                        Text("\(appState.workoutProgramTemplates.count) ready-made programs")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(isProgramLibraryExpanded ? "Hide" : "Browse")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                        .rotationEffect(.degrees(isProgramLibraryExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 62)
                .liftSurface(radius: 12)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("training.programLibrary.toggle")
            .accessibilityLabel("Workout program library, \(appState.workoutProgramTemplates.count) programs")
            .accessibilityValue(isProgramLibraryExpanded ? "Expanded" : "Collapsed")

            if isProgramLibraryExpanded {
                LazyVStack(spacing: 9) {
                    ForEach(appState.workoutProgramTemplates) { template in
                        Button {
                            selectedProgramTemplate = template
                        } label: {
                            HStack(spacing: 12) {
                                programIcon(for: template)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.liftText)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text("\(template.category.rawValue) · \(template.level.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                        .lineLimit(1)

                                    Text(template.defaultProgression.rawValue)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.liftBlue)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                VStack(alignment: .trailing, spacing: 5) {
                                    Text("\(template.daysPerWeek) DAYS")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .tracking(0.4)
                                        .foregroundStyle(Color.liftBlue)
                                        .padding(.horizontal, 8)
                                        .frame(height: 24)
                                        .background(Color.liftBlue.opacity(0.10))
                                        .clipShape(Capsule())
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Color.liftMuted)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                            .background(Color.liftCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("training.programTemplate.\(template.id)")
                        .accessibilityLabel("Preview \(template.name), \(template.category.rawValue), \(template.level.rawValue), \(template.daysPerWeek) days per week")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func programIcon(for template: WorkoutProgramTemplate) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.liftBlue.opacity(0.22), Color.liftGreen.opacity(0.09)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.liftBlue.opacity(0.08))
                .frame(width: 34, height: 34)

            Image(systemName: programSymbolName(for: template))
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.liftBlue)
        }
        .frame(width: 46, height: 46)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.liftBlue.opacity(0.20), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private func programSymbolName(for template: WorkoutProgramTemplate) -> String {
        switch template.category {
        case .bodybuilding:
            return template.id.contains("upper_lower")
                ? "rectangle.split.2x1.fill"
                : "arrow.triangle.branch"
        case .powerlifting:
            return "scalemass.fill"
        case .cablesOnly:
            return "cable.connector.horizontal"
        case .freeWeightsOnly:
            return "dumbbell.fill"
        case .general:
            return "figure.strengthtraining.functional"
        }
    }
}
