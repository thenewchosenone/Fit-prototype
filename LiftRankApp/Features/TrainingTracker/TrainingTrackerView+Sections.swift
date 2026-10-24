import Charts
import SwiftUI

extension TrainingTrackerView {
    @ViewBuilder
    var featureBody: some View {
        NavigationStack {
            AppBackground {
                if !isEmbeddedInTab || appState.router.selectedTab == .track {
                    trackerContent
                } else {
                    Color.clear
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedLibraryExercise) { exercise in
                ExerciseLibraryDetailView(exercise: exercise)
            }
            .sheet(item: $selectedSessionForAdd) { session in
                ProgramAddExercisePickerView(session: session)
                    .environmentObject(appState)
                    .presentationDetents([.large])
            }
            .fullScreenCover(isPresented: $showingActiveWorkout) {
                WorkoutSessionRunView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingCreatePlan) {
                CreateWorkoutPlanView()
                    .environmentObject(appState)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingCreatePlanFromHistory) {
                CreateWorkoutPlanFromHistoryView(workouts: freestyleWorkoutsForPlan)
                    .environmentObject(appState)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedBodyweightEntry) { entry in
                BodyweightEntryEditor(entry: entry) { updatedEntry in
                    try await appState.updateBodyweight(updatedEntry)
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingLibraryFilters) {
                ExerciseLibraryFilterSheet(
                    applied: $libraryFilters,
                    exercises: appState.trainingExerciseLibrary,
                    searchText: librarySearch
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingCreateLibraryExercise) {
                LibraryCustomExerciseView { exercise in
                    selectedLibraryExercise = exercise
                }
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedProgramTemplate, onDismiss: {
                if appState.selectedWorkoutPlan != nil { isProgramLibraryExpanded = false }
            }) { template in
                WorkoutProgramTemplateDetailView(template: template)
                    .environmentObject(appState)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showingProgressionEditor) {
                if let settings = selectedProgramSettings,
                   let template = WorkoutProgramCatalog.template(id: settings.sourceTemplateID) {
                    WorkoutProgramProgressionEditorView(settings: settings, template: template)
                        .environmentObject(appState)
                        .presentationDetents([.large])
                }
            }
            .sheet(item: $selectedCompletedWorkout) { workout in
                CompletedWorkoutDetailView(workout: workout, focusedSetID: $focusedWorkoutSetID)
                    .environmentObject(appState)
                    .presentationDetents([.large])
            }
            .sheet(item: $selectedProgressMuscle) { muscle in
                MuscleTrainingDetailView(muscle: muscle, referenceDate: selectedProgressMuscleDate)
                    .environmentObject(appState)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showingWorkoutDatePicker) {
                HistoryWorkoutPickerView(date: workoutDateToLog) { session in
                    showingWorkoutDatePicker = false
                    requestStart(session, historyDate: workoutDateToLog)
                } onFreestyle: {
                    showingWorkoutDatePicker = false
                    startFreestyleWorkout(for: workoutDateToLog)
                }
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .alert("Rename Plan", isPresented: $showingRenamePlan) {
                TextField("Plan name", text: $renamePlanName)
                Button("Save") {
                    appState.renameSelectedWorkoutPlan(to: renamePlanName)
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete this plan?", isPresented: $showingDeletePlan, titleVisibility: .visible) {
                Button("Delete plan", role: .destructive) {
                    appState.deleteSelectedWorkoutPlan()
                    syncSelectedWeek()
                }
            } message: {
                Text("Removes the schedule and returns you to freestyle. Saved workout history and submitted lifts remain.")
            }
            .onAppear {
                syncSelectedWeek()
                appState.restoreSelectedWorkoutPlanIfNeeded()
                applyRequestedSegment()
                if !didOpenUITestFocusedWorkoutSet,
                   ProcessInfo.processInfo.arguments.contains("-uiTestingFocusedWorkoutSet"),
                   let workout = appState.trainingHistoryWorkouts.first,
                   let set = workout.completedWorkingSets.last {
                    focusedWorkoutSetID = set.id
                    selectedCompletedWorkout = workout
                    didOpenUITestFocusedWorkoutSet = true
                }
            }
            .onChange(of: appState.selectedWorkoutPlanID) {
                syncSelectedWeek()
                if appState.selectedWorkoutPlan != nil {
                    withAnimation(.snappy) { isProgramLibraryExpanded = false }
                }
            }
            .onChange(of: appState.workoutPlans) {
                appState.restoreSelectedWorkoutPlanIfNeeded()
            }
            .onChange(of: segment) { _, newSegment in
                if newSegment != .plans && isProgramLibraryExpanded {
                    withAnimation(.snappy) { isProgramLibraryExpanded = false }
                }
            }
            .onChange(of: appState.requestedTrackerSegment) {
                applyRequestedSegment()
            }
            .onChange(of: selectedSessionToRun) { _, session in
                guard let session else { return }
                requestStart(session)
                selectedSessionToRun = nil
            }
            .confirmationDialog("A workout is already active", isPresented: $showingWorkoutConflict, titleVisibility: .visible) {
                Button("Open Active Workout") {
                    showingActiveWorkout = true
                }
                Button("Discard Active & Start New", role: .destructive) {
                    appState.discardActiveWorkout()
                    SystemWorkoutRestNotificationScheduler.shared.cancel()
                    if let pendingSessionToStart {
                        _ = appState.startWorkout(pendingSessionToStart, historyDate: pendingWorkoutHistoryDate)
                    } else if pendingFreestyleStart {
                        _ = appState.startFreestyleWorkoutInstance(historyDate: pendingWorkoutHistoryDate)
                    }
                    clearPendingStart()
                    showingActiveWorkout = true
                }
                Button("Cancel") { clearPendingStart() }
            } message: {
                Text("Lift Rivals keeps one active workout at a time so sets and timers cannot be mixed between sessions.")
            }
        }
    }

    private var trackerContent: some View {
        let libraryPresentation = segment == .library
            ? appState.exerciseLibraryPresentation(query: librarySearch, filters: libraryFilters)
            : .empty
        return VStack(spacing: 0) {
            controls
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Color.clear
                            .frame(height: 1)
                            .id("tracker-content-top")
                        if segment == .today {
                            today
                        } else if segment == .plans {
                            plans
                        } else if segment == .library {
                            library(
                                scrollProxy: scrollProxy,
                                results: libraryPresentation.results,
                                sections: libraryPresentation.sections
                            )
                        } else {
                            progress
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, isEmbeddedInTab ? 168 : 36)
                }
                .id(segment)
                .scrollIndicators(.hidden)
                .onChange(of: selectedProgressCategory) {
                    guard segment == .progress else { return }
                    scrollProxy.scrollTo("tracker-content-top", anchor: .top)
                }
                .onChange(of: appState.completedWorkoutsRevision) {
                    guard segment == .progress, selectedProgressCategory == .muscle else { return }
                    scrollProxy.scrollTo("tracker-content-top", anchor: .top)
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Tracker")
                    .font(.title3.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer(minLength: 0)

                Menu {
                    Button {
                        appState.showingSubmitSheet = true
                    } label: {
                        Label("Submit a Lift", systemImage: "plus.circle")
                    }
                    Button {
                        showingCreatePlan = true
                    } label: {
                        Label("Create Plan", systemImage: "plus.circle")
                    }
                    .disabled(appState.activeWorkout != nil)
                    Button {
                        renamePlanName = selectedPlanName
                        showingRenamePlan = true
                    } label: {
                        Label("Rename Plan", systemImage: "pencil")
                    }
                    .disabled(appState.selectedWorkoutPlan == nil || appState.activeWorkout != nil)
                    Button {
                        appState.duplicateSelectedWorkoutPlan()
                        syncSelectedWeek()
                    } label: {
                        Label("Duplicate Plan", systemImage: "doc.on.doc")
                    }
                    .disabled(appState.activeWorkout != nil || appState.selectedWorkoutPlan == nil)
                    Button {
                        showingProgressionEditor = true
                    } label: {
                        Label("Change Progression", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(selectedProgramSettings == nil || appState.activeWorkout != nil)
                    Button(role: .destructive) {
                        showingDeletePlan = true
                    } label: {
                        Label("Delete Current Plan", systemImage: "trash")
                    }
                    .disabled(appState.selectedWorkoutPlan == nil || appState.activeWorkout != nil)
                    Button("Stop program · return to freestyle") {
                        _ = appState.selectWorkoutPlan(nil)
                    }
                    .disabled(appState.selectedWorkoutPlan == nil || appState.activeWorkout != nil)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                        .overlay { Circle().stroke(Color.liftOverlay, lineWidth: 1) }
                }
                .accessibilityLabel("Plan options")

                if !isEmbeddedInTab {
                    NativeIconButton(symbolName: "xmark", accessibilityLabel: "Close training tracker") {
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)

            if appState.selectedWorkoutPlan == nil && segment == .today {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.liftAccentText)
                    Text("Choose a program to schedule workouts, or start an empty workout to train freestyle.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No workout plan selected. Choose a program to schedule workouts, or start an empty workout to train freestyle.")
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                        ForEach(TrackerSegment.allCases, id: \.self) { option in
                            trackerSegmentButton(option)
                        }
                    }
                } else {
                    HStack(spacing: 0) {
                        ForEach(TrackerSegment.allCases, id: \.self) { option in
                            trackerSegmentButton(option)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.liftOverlay)
                    .frame(height: 1)
            }
        }
        .background(Color.liftBackground)
    }

    private func trackerSegmentButton(_ option: TrackerSegment) -> some View {
        Button {
            segment = option
            appState.requestedTrackerSegment = option.rawValue
        } label: {
            VStack(spacing: 8) {
                Text(option.rawValue)
                    .font(.subheadline.weight(segment == option ? .bold : .medium))
                    .foregroundStyle(segment == option ? Color.liftText : Color.liftMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Rectangle()
                    .fill(segment == option ? Color.liftBlue : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityIdentifier("tracker.segment.\(option.rawValue.lowercased())")
        .accessibilityAddTraits(segment == option ? .isSelected : [])
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's training")
                        .font(.title3.weight(.black))
                }
                Spacer()
            }

            todayWorkoutStatusSection

            if appState.selectedWorkoutPlan == nil {
                Button {
                    isProgramLibraryExpanded = true
                    withAnimation(.snappy) { segment = .plans }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "books.vertical.fill")
                            .font(.headline)
                            .foregroundStyle(Color.liftAccentText)
                            .frame(width: 44, height: 44)
                            .background(Color.liftBlue.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Browse Workout Programs")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.liftText)
                            Text("Bodybuilding, powerlifting, cables, free weights, and more")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        }

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftAccentText)
                    }
                    .padding(12)
                    .frame(minHeight: 72)
                    .liftSurface(radius: 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Browse \(appState.workoutProgramTemplates.count) workout programs")
                .accessibilityHint("Opens the workout program catalog")
            }

            Button {
                startFreestyleWorkout()
            } label: {
                Label("Start empty workout", systemImage: "plus")
            }
            .buttonStyle(LiftSecondaryButtonStyle())

        }
    }

    @ViewBuilder
    private var todayWorkoutStatusSection: some View {
        if let active = appState.activeWorkout {
            ActiveWorkoutResumeCard(workout: active) {
                showingActiveWorkout = true
            }
            .environmentObject(appState)
            if let todayWorkout = todayScheduledWorkout {
                TrackerMessageCard(
                    title: active.sourceSessionID == todayWorkout.session.id ? "Today’s planned workout" : "Today’s plan",
                    message: active.sourceSessionID == todayWorkout.session.id
                        ? "\(todayWorkout.session.name) is already in progress."
                        : "\(todayWorkout.session.name) is scheduled today. Finish your current workout before starting it."
                )
            } else if let nextWorkout = nextScheduledWorkout {
                TrackerMessageCard(
                    title: "Next planned workout",
                    message: "\(nextWorkout.session.name) · \(LiftTimeFormatter.shortDateNoTime(nextWorkout.date)). Finish your current workout first."
                )
            } else if appState.selectedWorkoutPlan != nil {
                TrackerMessageCard(
                    title: "No plan workout scheduled today",
                    message: "Your active plan is \(selectedPlanName). Review its schedule in Plans."
                )
            }
        } else if appState.selectedWorkoutPlan == nil {
            TrackerMessageCard(
                title: "Choose a workout plan",
                message: "Select a program to see scheduled training here, or start an empty workout."
            )
        } else if selectedProgramIsComplete {
            LiftCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Program finished", systemImage: "checkmark.seal.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.liftGreen)
                    Text("You reached the end of \(selectedPlanName). Review completed, shortened, and skipped sessions in your history, or choose another program.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Button {
                        isProgramLibraryExpanded = true
                        withAnimation(.snappy) { segment = .plans }
                    } label: {
                        Label("Choose another program", systemImage: "books.vertical")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiftCompactProminentButtonStyle())
                }
            }
        } else if appState.selectedPlanWeeks.flatMap(appState.sessions(for:)).isEmpty {
            LiftCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No workouts in this plan yet")
                        .font(.headline.weight(.bold))
                    Text("Add a workout day in Plans, or start an empty workout.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Button {
                        withAnimation(.snappy) { segment = .plans }
                    } label: {
                        Label("Add workout day", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiftCompactProminentButtonStyle())
                }
            }
        } else if let todayWorkout = todayScheduledWorkout,
                  !isWorkoutSessionComplete(todayWorkout.session) {
            TodayWorkoutLaunchCard(
                planName: selectedPlanName,
                week: todayWorkout.week,
                session: todayWorkout.session
            ) {
                requestStart(todayWorkout.session)
            }
            .environmentObject(appState)
        } else if let missedWorkout = missedScheduledWorkout {
            TodayWorkoutLaunchCard(
                planName: selectedPlanName,
                week: missedWorkout.week,
                session: missedWorkout.session,
                eyebrow: "MISSED WORKOUT",
                actionTitle: "Do this workout today"
            ) {
                requestStart(missedWorkout.session)
            }
            .environmentObject(appState)
        } else if let todayWorkout = todayScheduledWorkout {
            TrackerMessageCard(
                title: "Today’s session is recorded",
                message: "\(todayWorkout.session.name) is saved or marked skipped/rest. Review the details in your history."
            )
        } else if currentProgramWeekIsComplete {
            TrackerMessageCard(
                title: "Week complete",
                message: nextScheduledWorkout.map {
                    "You finished this week's sessions. Next up: \($0.session.name) on \(LiftTimeFormatter.shortDateNoTime($0.date))."
                } ?? "You finished this week's scheduled sessions. Check back when the next program week begins."
            )
        } else if let nextWorkout = nextScheduledWorkout {
            LiftCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Rest day", systemImage: "bed.double.fill")
                        .font(.headline.weight(.bold))
                    Text("Next up: \(nextWorkout.session.name) · \(LiftTimeFormatter.shortDateNoTime(nextWorkout.date))")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Button {
                        requestStart(nextWorkout.session)
                    } label: {
                        Label("Start next workout today", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiftSecondaryButtonStyle())
                }
            }
        } else {
            TrackerMessageCard(
                title: "Rest day",
                message: "No workout is scheduled today. Use the time to recover or start an empty workout."
            )
        }
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: 12) {
            programLibrary
            if appState.activeWorkout != nil {
                Text("Finish or discard your active workout before changing plans or scheduled workouts.")
                    .font(.caption).foregroundStyle(Color.liftMuted)
            }
            if appState.workoutSyncStore.planSyncState == .needsAttention {
                Button("Plan sync needs attention · Retry") {
                    Task { await appState.synchronizeWorkoutPlans() }
                }
                .font(.subheadline.weight(.semibold))
            }
            if appState.workoutPlans.filter(\.isActive).count > 1 {
                Text("More than one program is marked active. Choose the one you want to continue.")
                    .font(.caption).foregroundStyle(Color.liftGold)
            }

            if appState.workoutPlans.isEmpty {
                LiftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No saved plans yet")
                            .font(.headline.weight(.bold))
                        Text("Browse a ready-made program above or create your own plan.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        Button {
                            showingCreatePlan = true
                        } label: {
                            Label("Create plan", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LiftCompactProminentButtonStyle())
                        .disabled(appState.activeWorkout != nil)
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appState.workoutPlans.count > 1 ? "My Plans" : "Program")
                            .font(.headline)
                        if appState.workoutPlans.count > 1 {
                            Text("Select your active plan.")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                    Spacer()
                    Button {
                        showingCreatePlan = true
                    } label: {
                        Label("New", systemImage: "plus")
                            .font(.caption.weight(.bold))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.liftAccentText)
                    .disabled(appState.activeWorkout != nil)
                }

                if appState.workoutPlans.count > 1 {
                    VStack(spacing: 0) {
                        ForEach(Array(appState.workoutPlans.enumerated()), id: \.element.id) { index, plan in
                            Button {
                                if appState.selectWorkoutPlan(plan.id) {
                                    isProgramLibraryExpanded = false
                                    syncSelectedWeek()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(plan.id == appState.selectedWorkoutPlanID ? Color.liftAccentText : Color.liftMuted)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(plan.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.liftText)
                                        Text(plan.isActive ? "Active" : "Saved · tap to resume")
                                            .font(.caption)
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                    Spacer()
                                    Image(systemName: plan.id == appState.selectedWorkoutPlanID ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(plan.id == appState.selectedWorkoutPlanID ? Color.liftGreen : Color.liftMuted)
                                }
                                .padding(.horizontal, 14)
                                .frame(minHeight: 58)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(appState.activeWorkout != nil)

                            if index < appState.workoutPlans.count - 1 {
                                Divider()
                                    .overlay(Color.liftOverlay)
                                    .padding(.leading, 54)
                            }
                        }
                    }
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.liftOverlay, lineWidth: 1)
                    }
                }
            }

            if !freestyleWorkoutsForPlan.isEmpty {
                Button {
                    showingCreatePlanFromHistory = true
                } label: {
                    Label("Build plan from past workouts", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(appState.activeWorkout != nil)
                .accessibilityIdentifier("tracker.plans.buildFromHistory")
            }

            if appState.selectedWorkoutPlan != nil {
                ProgramPlanDetailView(
                    selectedWeekID: $selectedWeekID,
                    detailTab: $planDetailTab,
                    selectedSessionForAdd: $selectedSessionForAdd,
                    selectedSessionToRun: $selectedSessionToRun
                )
                .environmentObject(appState)
            }
        }
    }

    private var freestyleWorkoutsForPlan: [CompletedWorkout] {
        appState.completedWorkouts
            .filter { $0.source == .freestyle && !$0.exercisesWithCompletedWorkingSets.isEmpty }
            .sorted { $0.completedAt < $1.completedAt }
    }

    private var programLibrary: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button {
                withAnimation(.snappy) { isProgramLibraryExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(Color.liftAccentText)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Browse Workout Programs")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.liftText)
                        Text("\(appState.workoutProgramTemplates.count) ready-made programs")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                    Text(isProgramLibraryExpanded ? "Hide" : "Browse")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftAccentText)
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
            .accessibilityLabel("Workout program library, \(appState.workoutProgramTemplates.count) programs")
            .accessibilityValue(isProgramLibraryExpanded ? "Expanded" : "Collapsed")

            if isProgramLibraryExpanded {
                LazyVStack(spacing: 9) {
                    ForEach(appState.workoutProgramTemplates) { template in
                        Button {
                            selectedProgramTemplate = template
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: template.category == .powerlifting ? "trophy.fill" : "figure.strengthtraining.traditional")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.liftAccentText)
                                    .frame(width: 42, height: 42)
                                    .background(Color.liftBlue.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.liftText)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text("\(template.category.rawValue) · \(template.level.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)

                                    Text(appState.workoutPlanProgressionSettings.contains(where: { $0.sourceTemplateID == template.id }) ? "Saved program · resume or start a new cycle" : template.defaultProgression.rawValue)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.liftAccentText)
                                }

                                Spacer(minLength: 8)

                                VStack(alignment: .trailing, spacing: 5) {
                                    Text("\(template.daysPerWeek) DAYS")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .tracking(0.4)
                                        .foregroundStyle(Color.liftAccentText)
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
                                    .stroke(Color.liftOverlay, lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Preview \(template.name), \(template.category.rawValue), \(template.level.rawValue), \(template.daysPerWeek) days per week")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func syncSelectedWeek() {
        if let selectedWeekID, appState.selectedPlanWeeks.contains(where: { $0.id == selectedWeekID }) {
            return
        }
        selectedWeekID = appState.currentSelectedProgramWeek?.id ?? appState.selectedPlanWeeks.first?.id
    }

    func startFreestyleWorkout(for historyDate: Date? = nil) {
        if appState.activeWorkout != nil {
            pendingSessionToStart = nil
            pendingFreestyleStart = true
            pendingWorkoutHistoryDate = historyDate
            showingWorkoutConflict = true
            return
        }
        guard appState.startFreestyleWorkoutInstance(historyDate: historyDate) else { return }
        showingActiveWorkout = true
    }

    func requestStart(_ session: WorkoutSession, historyDate: Date? = nil) {
        if appState.activeWorkout != nil {
            pendingSessionToStart = session
            pendingFreestyleStart = false
            pendingWorkoutHistoryDate = historyDate
            showingWorkoutConflict = true
            return
        }
        guard appState.startWorkout(session, historyDate: historyDate) else { return }
        showingActiveWorkout = true
    }

    private func clearPendingStart() {
        pendingSessionToStart = nil
        pendingFreestyleStart = false
        pendingWorkoutHistoryDate = nil
    }

    private func applyRequestedSegment() {
        guard let requested = TrackerSegment(rawValue: appState.requestedTrackerSegment) else { return }
        segment = requested
    }
}

private struct HistoryWorkoutPickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let onSelectSession: (WorkoutSession) -> Void
    let onFreestyle: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: onFreestyle) {
                        Label("Freestyle workout", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.liftAccentText)
                    }
                } header: {
                    Text("Log for \(LiftTimeFormatter.shortDateNoTime(date))")
                }

                let scheduled = appState.scheduledPlanSessions(on: date)
                let scheduledIDs = Set(scheduled.map(\.session.id))
                if !scheduled.isEmpty {
                    Section("Scheduled for this date") {
                        ForEach(scheduled, id: \.session.id) { item in
                            historySessionButton(item.session, week: item.week)
                        }
                    }
                }

                Section("Other \(appState.selectedWorkoutPlan?.name ?? "selected plan") workouts") {
                    let weeks = appState.selectedPlanWeeks
                    if weeks.isEmpty {
                        Text("Select a workout plan to add one of its sessions.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                    } else {
                        ForEach(weeks) { week in
                            let otherSessions = appState.sessions(for: week).filter { !scheduledIDs.contains($0.id) }
                            ForEach(otherSessions) { session in
                                historySessionButton(session, week: week)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add missed workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func historySessionButton(_ session: WorkoutSession, week: WorkoutWeek) -> some View {
        Button {
            onSelectSession(session)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(session.day) · \(session.name)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liftText)
                Text("Week \(week.weekNumber) · \(appState.prescriptions(for: session).count) exercises")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
