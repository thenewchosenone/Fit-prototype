import SwiftUI

struct ProgramPlanDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedWeekID: UUID?
    @Binding var detailTab: String
    @Binding var selectedSessionForAdd: WorkoutSession?
    @Binding var selectedSessionToRun: WorkoutSession?
    @Binding var selectedProgramTemplate: WorkoutProgramTemplate?
    @Binding var renamePlanName: String
    @Binding var showingRenamePlan: Bool
    @Binding var planToDeleteID: UUID?
    @Binding var showingDeletePlan: Bool
    @State private var weekToDelete: WorkoutWeek?
    @State private var sessionToDelete: WorkoutSession?
    @State private var showingDeleteConfirmation = false
    @State private var showingAddSession = false
    @State private var newSessionName = "Strength Workout"
    @State private var newSessionDay = "Monday"

    private let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        let weeks = appState.selectedPlanWeeks
        let selectedWeek = selectedWeekID.flatMap { id in weeks.first { $0.id == id } } ?? weeks.first
        let selectedWeekPosition = selectedWeek.flatMap { selected in weeks.firstIndex { $0.id == selected.id } }
        let selectedPhase = selectedWeek.flatMap { appState.phase(for: $0) }
        let selectedPhaseWeeks = selectedPhase.map { phase in
            weeks.filter { $0.phaseID == phase.id }.sorted { $0.weekNumber < $1.weekNumber }
        } ?? []
        let selectedPhaseWeekNumber = selectedWeek.flatMap { week in
            selectedPhaseWeeks.firstIndex(where: { $0.id == week.id }).map { $0 + 1 }
        }
        let isRecoveryWeek = selectedWeek.map { week in
            let text = "\(week.title) \(week.notes)".lowercased()
            return text.contains("deload") || text.contains("rest") || text.contains("recovery")
        } ?? false
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.selectedWorkoutPlan?.name ?? "Program details")
                        .font(.headline.weight(.bold))
                    Text("\(weeks.count) scheduled weeks")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Menu {
                    if let settings = appState.workoutPlanProgressionSettings.first(where: { $0.planID == appState.selectedWorkoutPlanID }),
                       let template = WorkoutProgramCatalog.template(id: settings.sourceTemplateID) {
                        Button {
                            selectedProgramTemplate = template
                        } label: {
                            Label("Edit schedule and progression", systemImage: "slider.horizontal.3")
                        }
                    }
                    Button {
                        renamePlanName = appState.selectedWorkoutPlan?.name ?? ""
                        showingRenamePlan = true
                    } label: {
                        Label("Rename plan", systemImage: "pencil")
                    }
                    Button {
                        appState.duplicateSelectedWorkoutPlan()
                    } label: {
                        Label("Duplicate plan", systemImage: "doc.on.doc")
                    }
                    Divider()
                    Button {
                        let week = appState.addWeekToSelectedPlan()
                        selectedWeekID = week.id
                        detailTab = "Weeks"
                    } label: {
                        Label("Add Week", systemImage: "calendar.badge.plus")
                    }
                    .disabled(appState.activeWorkout != nil)
                    if let selectedWeek {
                        Button {
                            let clone = appState.cloneWeek(selectedWeek)
                            selectedWeekID = clone.id
                            detailTab = "Weeks"
                        } label: {
                            Label("Clone Week", systemImage: "doc.on.doc")
                        }
                        .disabled(appState.activeWorkout != nil)
                        Button(role: .destructive) {
                            weekToDelete = selectedWeek
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Week", systemImage: "trash")
                        }
                        .disabled(appState.activeWorkout != nil)
                    }
                    Divider()
                    Button {
                        _ = appState.setSelectedPlanQueueEnabled(!appState.selectedPlanQueueEnabled)
                    } label: {
                        Label(
                            appState.selectedPlanQueueEnabled ? "Disable session queue" : "Use session queue",
                            systemImage: appState.selectedPlanQueueEnabled ? "list.number" : "play.list"
                        )
                    }
                    .disabled(appState.activeWorkout != nil)
                    Button(role: .destructive) {
                        planToDeleteID = appState.selectedWorkoutPlanID
                        showingDeletePlan = true
                    } label: {
                        Label("Delete plan", systemImage: "trash")
                    }
                    .disabled(appState.activeWorkout != nil)
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

            if let selectedWeek {
                LiftCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: isRecoveryWeek ? "figure.mind.and.body" : "arrow.up.right")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(isRecoveryWeek ? Color.liftGold : Color.liftAccentText)
                            .frame(width: 38, height: 38)
                            .background((isRecoveryWeek ? Color.liftGold : Color.liftBlue).opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedPhase?.name ?? "Base Phase")
                                .font(.subheadline.weight(.bold))
                            Text(isRecoveryWeek ? "Recovery week within this phase" : (selectedPhase?.goal ?? "Build consistent training momentum."))
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(selectedPhaseWeekNumber.map { "Phase week \($0) of \(selectedPhaseWeeks.count) · Program week \(selectedWeek.weekNumber)" } ?? "Program week \(selectedWeek.weekNumber)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isRecoveryWeek ? Color.liftGold : Color.liftMuted)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach([(title: "Workouts", value: "Weeks"), (title: "Overview", value: "Overview"), (title: "Notes", value: "Notes")], id: \.value) { item in
                    Button {
                        detailTab = item.value
                    } label: {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(detailTab == item.value ? Color.liftText : Color.liftMuted)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(detailTab == item.value ? Color.liftBlue.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button("Stop program and return to freestyle", systemImage: "stop.circle") {
                _ = appState.selectWorkoutPlan(nil)
            }
            .buttonStyle(.bordered)
            .disabled(appState.activeWorkout != nil)
            .accessibilityIdentifier("tracker.program.stop")

            if detailTab == "Weeks" {
                if weeks.isEmpty {
                    emptyWeeksState
                } else {
                    weekNavigator(weeks: weeks, selectedWeek: selectedWeek, selectedWeekPosition: selectedWeekPosition)
                    weekSessions(selectedWeek: selectedWeek)
                }
            } else if detailTab == "Overview" {
                overview(selectedWeek: selectedWeek)
            } else {
                notes
            }
        }
        .confirmationDialog("Remove from the plan?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let weekToDelete {
                    let previousPosition = appState.selectedPlanWeeks.firstIndex { $0.id == weekToDelete.id } ?? 0
                    appState.deleteWeek(weekToDelete)
                    let remainingWeeks = appState.selectedPlanWeeks
                    selectedWeekID = remainingWeeks.isEmpty
                        ? nil
                        : remainingWeeks[min(previousPosition, remainingWeeks.count - 1)].id
                } else if let sessionToDelete {
                    appState.deleteSession(sessionToDelete)
                }
                weekToDelete = nil
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                weekToDelete = nil
                sessionToDelete = nil
            }
        } message: {
            Text("This removes scheduled training. Saved workout history and submitted lifts remain.")
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
                                .background(Color.liftScrim)
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

    private func weekNavigator(
        weeks: [WorkoutWeek],
        selectedWeek: WorkoutWeek?,
        selectedWeekPosition: Int?
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                selectAdjacentWeek(offset: -1, weeks: weeks, selectedWeekPosition: selectedWeekPosition)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(selectedWeekPosition == 0 ? Color.liftMuted.opacity(0.35) : Color.liftMuted)
            .disabled(selectedWeekPosition == nil || selectedWeekPosition == 0)
            .accessibilityLabel("Previous week")

            Menu {
                ForEach(weeks) { week in
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
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let selectedWeekPosition {
                        Text("\(selectedWeekPosition + 1) of \(weeks.count)")
                            .font(.caption2)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
            }
            .accessibilityLabel("Selected workout week")

            Button {
                selectAdjacentWeek(offset: 1, weeks: weeks, selectedWeekPosition: selectedWeekPosition)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(selectedWeekPosition == weeks.count - 1 ? Color.liftMuted.opacity(0.35) : Color.liftMuted)
            .disabled(selectedWeekPosition == nil || selectedWeekPosition == weeks.count - 1)
            .accessibilityLabel("Next week")
        }
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
    }

    private func selectAdjacentWeek(offset: Int, weeks: [WorkoutWeek], selectedWeekPosition: Int?) {
        guard let selectedWeekPosition else { return }
        let destination = selectedWeekPosition + offset
        guard weeks.indices.contains(destination) else { return }
        selectedWeekID = weeks[destination].id
    }

    private var emptyWeeksState: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.liftAccentText)
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

    private func weekSessions(selectedWeek: WorkoutWeek?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedWeek {
                let presentation = appState.programWeekPresentation(for: selectedWeek)
                let sessions = presentation.sessions
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
                        let prescriptions = presentation.prescriptionsBySessionID[session.id] ?? []
                        ProgramSessionCard(
                            session: session,
                            prescriptions: prescriptions,
                            completedPrescriptionCount: prescriptions.lazy.filter {
                                presentation.completedPrescriptionIDs.contains($0.id)
                            }.count,
                            catalogByID: presentation.catalogByID,
                            onStart: {
                            selectedSessionToRun = session
                        }, onAddExercise: {
                            selectedSessionForAdd = session
                        }, onDelete: {
                            sessionToDelete = session
                            showingDeleteConfirmation = true
                        })
                    }
                }
                Button {
                    showingAddSession = true
                } label: {
                    Label("Add Workout Day", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LiftCompactProminentButtonStyle())
                .disabled(appState.activeWorkout != nil)
            }
        }
    }

    private func overview(selectedWeek: WorkoutWeek?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let nextQueuedSession = appState.nextQueuedWorkoutSession {
                LiftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Session queue", systemImage: "play.list")
                                .font(.headline.weight(.bold))
                            Spacer()
                            Text("\(appState.selectedPlanQueuedSessions.count) sessions")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.liftMuted)
                        }
                        Text("The next workout follows your queue, even when it is not the next calendar day.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        ForEach(Array(appState.selectedPlanQueuedSessions.enumerated()), id: \.element.id) { index, session in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                                    .frame(width: 20)
                                Text(session.name)
                                    .font(.caption)
                                Spacer()
                                Button {
                                    var ids = appState.selectedPlanQueuedSessions.map(\.id)
                                    ids.swapAt(index, index - 1)
                                    _ = appState.reorderSelectedPlanQueue(ids)
                                } label: {
                                    Image(systemName: "chevron.up")
                                }
                                .disabled(index == 0 || appState.activeWorkout != nil)
                                .accessibilityLabel("Move \(session.name) earlier in queue")
                                Button {
                                    var ids = appState.selectedPlanQueuedSessions.map(\.id)
                                    ids.swapAt(index, index + 1)
                                    _ = appState.reorderSelectedPlanQueue(ids)
                                } label: {
                                    Image(systemName: "chevron.down")
                                }
                                .disabled(index == appState.selectedPlanQueuedSessions.count - 1 || appState.activeWorkout != nil)
                                .accessibilityLabel("Move \(session.name) later in queue")
                            }
                            .foregroundStyle(Color.liftMuted)
                        }
                        Button {
                            selectedSessionToRun = nextQueuedSession
                        } label: {
                            Label("Start next: \(nextQueuedSession.name)", systemImage: "play.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.liftAccentText)
                    }
                }
            } else if appState.selectedPlanQueueEnabled {
                TrackerMessageCard(
                    title: "No queued workout is ready",
                    message: "Add a workout day or clone a week to refill the queue."
                )
            }
            if let selectedWeek {
                let presentation = appState.programWeekPresentation(for: selectedWeek)
                let sessions = presentation.sessions
                let plannedSessions = sessions.filter { session in
                    !(presentation.prescriptionsBySessionID[session.id] ?? []).isEmpty
                }
                let completedSessions = plannedSessions.filter { session in
                    presentation.completedSessionIDs.contains(session.id)
                }
                let scheduledSession = appState.scheduledPlanSessions(on: .now)
                    .first(where: { $0.week.id == selectedWeek.id })?.session
                let nextScheduledSession = appState.nextScheduledWorkout()
                    .flatMap { $0.week.id == selectedWeek.id ? $0.session : nil }
                let nextSession = appState.selectedPlanQueueEnabled ? nil : (
                    scheduledSession ?? nextScheduledSession
                )
                let plannedPlanSessions = appState.selectedPlanWeeks
                    .flatMap(appState.sessions(for:))
                    .filter { !appState.prescriptions(for: $0).isEmpty }
                let planIsComplete = !plannedPlanSessions.isEmpty && plannedPlanSessions.allSatisfy(sessionIsComplete)
                let incompleteWeeks = appState.selectedPlanWeeks.filter { week in
                    appState.sessions(for: week).contains {
                        !appState.prescriptions(for: $0).isEmpty && !sessionIsComplete($0)
                    }
                }
                let nextIncompleteWeek = incompleteWeeks.first {
                    $0.id == appState.currentSelectedProgramWeek?.id
                } ?? incompleteWeeks.first
                let progression = appState.workoutPlanProgressionSettings.first {
                    $0.planID == appState.selectedWorkoutPlanID
                }?.method
                LiftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Current week · \(selectedWeek.title)")
                            .font(.headline.weight(.bold))
                        if !plannedSessions.isEmpty {
                            Text("\(completedSessions.count) of \(plannedSessions.count) workouts have all planned sets completed")
                                .foregroundStyle(Color.liftMuted)
                        } else {
                            Text("No workouts with exercises are planned for this week yet.")
                                .foregroundStyle(Color.liftMuted)
                        }
                        Text("\(presentation.completedSetCount) of \(presentation.plannedSetCount) planned sets logged")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        ProgressView(
                            value: plannedSessions.isEmpty
                                ? 0
                                : Double(completedSessions.count) / Double(plannedSessions.count)
                        )
                            .tint(Color.liftGreen)
                        if let nextSession {
                            Button {
                                selectedSessionToRun = nextSession
                            } label: {
                                Label("Start next workout: \(nextSession.name)", systemImage: "play.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.liftAccentText)
                        } else if planIsComplete {
                            Label("Program complete", systemImage: "checkmark.seal.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.liftGreen)
                            Button {
                                let nextWeek = appState.addWeekToSelectedPlan()
                                selectedWeekID = nextWeek.id
                                detailTab = "Weeks"
                            } label: {
                                Label("Add next week", systemImage: "calendar.badge.plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.liftAccentText)
                            .disabled(appState.activeWorkout != nil)
                        } else if let nextIncompleteWeek, nextIncompleteWeek.id != selectedWeek.id {
                            Button {
                                selectedWeekID = nextIncompleteWeek.id
                                detailTab = "Weeks"
                            } label: {
                                Label("Review unfinished week: \(nextIncompleteWeek.title)", systemImage: "arrow.uturn.backward.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.liftAccentText)
                        } else if completedSessions.count < plannedSessions.count {
                            Label("Unfinished sets remain in this week", systemImage: "arrow.uturn.backward.circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.liftAccentText)
                        }
                        if let progression {
                            Label("Progression: \(progression.rawValue)", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                }
            }
        }
    }

    private func sessionIsComplete(_ session: WorkoutSession) -> Bool {
        let prescriptionCount = appState.prescriptions(for: session).count
        return prescriptionCount > 0 && appState.completedPrescriptionCount(for: session) >= prescriptionCount
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
