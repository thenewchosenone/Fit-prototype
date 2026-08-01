import SwiftUI

struct ProgramPlanDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedWeekID: UUID?
    @Binding var detailTab: String
    @Binding var selectedSessionForAdd: WorkoutSession?
    @Binding var selectedSessionToRun: WorkoutSession?
    @State private var showingAddSession = false
    @State private var newSessionName = "Strength Workout"
    @State private var newSessionDay = "Monday"

    private let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    private var selectedWeek: WorkoutWeek? {
        if let selectedWeekID, let week = appState.selectedPlanWeeks.first(where: { $0.id == selectedWeekID }) {
            return week
        }
        return appState.selectedPlanWeeks.first
    }

    private var selectedWeekPosition: Int? {
        guard let selectedWeek else { return nil }
        return appState.selectedPlanWeeks.firstIndex(where: { $0.id == selectedWeek.id })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.selectedWorkoutPlan?.name ?? "Workout Plan")
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                    Text("\(appState.selectedPlanPhases.first?.name ?? "Base Phase") • \(appState.selectedPlanWeeks.count) weeks")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Menu {
                    Button {
                        detailTab = "Weeks"
                    } label: {
                        Label("Workouts", systemImage: "calendar")
                    }
                    Button {
                        detailTab = "Overview"
                    } label: {
                        Label("Plan Overview", systemImage: "chart.bar")
                    }
                    Button {
                        detailTab = "Notes"
                    } label: {
                        Label("Plan Notes", systemImage: "note.text")
                    }
                    Divider()
                    Button {
                        let week = appState.addWeekToSelectedPlan()
                        selectedWeekID = week.id
                        detailTab = "Weeks"
                    } label: {
                        Label("Add Week", systemImage: "calendar.badge.plus")
                    }
                    if let selectedWeek {
                        Button {
                            let clone = appState.cloneWeek(selectedWeek)
                            selectedWeekID = clone.id
                            detailTab = "Weeks"
                        } label: {
                            Label("Clone Week", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive) {
                            appState.deleteWeek(selectedWeek)
                            selectedWeekID = appState.selectedPlanWeeks.first?.id
                        } label: {
                            Label("Delete Week", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Plan detail options")
            }

            if detailTab == "Weeks" {
                if appState.selectedPlanWeeks.isEmpty {
                    emptyWeeksState
                } else {
                    weekNavigator
                    weekSessions
                }
            } else if detailTab == "Overview" {
                overview
            } else {
                notes
            }
        }
        .sheet(isPresented: $showingAddSession) {
            NavigationStack {
                AppBackground {
                    LiftCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Add Workout Day")
                                .font(.title2.bold())
                            TextField("Workout name", text: $newSessionName)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color.black.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Picker("Day", selection: $newSessionDay) {
                                ForEach(days, id: \.self) { day in
                                    Text(day).tag(day)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Workout Day")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingAddSession = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            if let week = selectedWeek {
                                _ = appState.addSession(to: week, day: newSessionDay, name: newSessionName)
                            }
                            showingAddSession = false
                        }
                    }
                }
            }
        }
    }

    private var weekNavigator: some View {
        HStack(spacing: 8) {
            Button {
                selectAdjacentWeek(offset: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(selectedWeekPosition == 0 ? Color.liftMuted.opacity(0.35) : Color.liftMuted)
            .disabled(selectedWeekPosition == nil || selectedWeekPosition == 0)
            .accessibilityLabel("Previous week")

            Menu {
                ForEach(appState.selectedPlanWeeks) { week in
                    Button {
                        selectedWeekID = week.id
                    } label: {
                        if week.id == selectedWeek?.id {
                            Label(week.title, systemImage: "checkmark")
                        } else {
                            Text(week.title)
                        }
                    }
                }
            } label: {
                VStack(spacing: 1) {
                    Text(selectedWeek?.title ?? "Select week")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.liftText)
                    if let selectedWeekPosition {
                        Text("\(selectedWeekPosition + 1) of \(appState.selectedPlanWeeks.count)")
                            .font(.caption2)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .accessibilityLabel("Selected workout week")

            Button {
                selectAdjacentWeek(offset: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(selectedWeekPosition == appState.selectedPlanWeeks.count - 1 ? Color.liftMuted.opacity(0.35) : Color.liftMuted)
            .disabled(selectedWeekPosition == nil || selectedWeekPosition == appState.selectedPlanWeeks.count - 1)
            .accessibilityLabel("Next week")
        }
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private func selectAdjacentWeek(offset: Int) {
        guard let selectedWeekPosition else { return }
        let destination = selectedWeekPosition + offset
        guard appState.selectedPlanWeeks.indices.contains(destination) else { return }
        selectedWeekID = appState.selectedPlanWeeks[destination].id
    }

    private var emptyWeeksState: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                        .frame(width: 38, height: 38)
                        .background(Color.liftBlue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Build your first week")
                            .font(.headline.weight(.bold))
                        Text("Add a week, then create workout days for it.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                }

                Button {
                    let week = appState.addWeekToSelectedPlan()
                    selectedWeekID = week.id
                    detailTab = "Weeks"
                } label: {
                    Label("Add Week", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LiftCompactProminentButtonStyle())
            }
        }
    }

    private var weekSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedWeek {
                let sessions = appState.sessions(for: selectedWeek)
                if sessions.isEmpty {
                    LiftCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No workout days yet")
                                .font(.headline.weight(.bold))
                            Text("Add workout days like Monday Push, Tuesday Pull, or Friday Legs.")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                } else {
                    ForEach(sessions) { session in
                        ProgramSessionCard(session: session, week: selectedWeek, onStart: {
                            selectedSessionToRun = session
                        }, onAddExercise: {
                            selectedSessionForAdd = session
                        }, onDelete: {
                            appState.deleteSession(session)
                        })
                        .environmentObject(appState)
                    }
                }
                Button {
                    showingAddSession = true
                } label: {
                    Label("Add Workout Day", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LiftCompactProminentButtonStyle())
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedWeek {
                LiftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(selectedWeek.title) Overview")
                            .font(.headline)
                        Text("\(appState.sessions(for: selectedWeek).count) workout days")
                            .foregroundStyle(Color.liftMuted)
                        ProgressView(value: appState.weekCompletion(for: selectedWeek))
                            .tint(Color.liftGreen)
                    }
                }
            }
        }
    }

    private var notes: some View {
        TrackerMessageCard(
            title: "Plan notes",
            message: appState.selectedWorkoutPlan?.notes.isEmpty == false
                ? appState.selectedWorkoutPlan?.notes ?? ""
                : "No notes added."
        )
    }
}
