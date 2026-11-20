import Charts
import SwiftUI

extension TrainingTrackerView {
    @ViewBuilder
    var featureBody: some View {
        NavigationStack {
            AppBackground {
                if !isEmbeddedInTab || isActiveTab {
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
            .sheet(item: $selectedBodyweightEntry) { entry in
                BodyweightEntryEditor(entry: entry) { appState.updateBodyweight($0) }
                    onDelete: { appState.deleteBodyweight($0) }
                    .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showingActiveWorkout) {
                WorkoutSessionRunView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingPlanSwitcher) {
                NavigationStack {
                    AppBackground {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Switching plans keeps your saved workouts and progress.")
                                    .font(.subheadline).foregroundStyle(Color.liftMuted)
                                VStack(spacing: 0) {
                                    ForEach(Array(appState.workoutPlans.enumerated()), id: \.element.id) { index, plan in
                                        Button {
                                            if appState.selectWorkoutPlan(plan.id) {
                                                showingPlanSwitcher = false
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
                                                        .lineLimit(1)
                                                    Text(plan.isActive ? "Active" : "Use plan")
                                                        .font(.caption)
                                                        .foregroundStyle(Color.liftMuted)
                                                        .lineLimit(1)
                                                    Text(appState.workoutPlanSummary(plan))
                                                        .font(.caption)
                                                        .foregroundStyle(Color.liftMuted)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                }
                                                Spacer()
                                                Image(systemName: plan.id == appState.selectedWorkoutPlanID ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(plan.id == appState.selectedWorkoutPlanID ? Color.liftGreen : Color.liftMuted)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
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

                                Button("Use freestyle") {
                                    if appState.selectWorkoutPlan(nil) {
                                        showingPlanSwitcher = false
                                        syncSelectedWeek()
                                    }
                                }
                                .frame(minHeight: 44)
                                .disabled(appState.activeWorkout != nil)
                            }
                            .padding(20)
                        }
                    }
                    .navigationTitle("Switch plan")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingPlanSwitcher = false } } }
                }
            }
            .sheet(isPresented: $showingCreatePlan) {
                CreateWorkoutPlanView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingProgramImport) {
                ImportWorkoutPlanView()
                    .environmentObject(appState)
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
            }
            .sheet(item: $selectedProgramTemplate) { template in
                WorkoutProgramTemplateDetailView(template: template, onUsePlan: { isProgramLibraryExpanded = false })
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
            .sheet(item: $selectedPlateauInsight) { insight in
                PlateauInsightDetailView(insight: insight)
                    .environmentObject(appState)
                    .presentationDetents([.medium, .large])
            }
            .alert("Rename Plan", isPresented: $showingRenamePlan) {
                TextField("Plan name", text: $renamePlanName)
                Button("Save") {
                    appState.renameSelectedWorkoutPlan(to: renamePlanName)
                }
                .disabled(renamePlanName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.activeWorkout != nil)
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete “\(selectedPlanName)”?", isPresented: $showingDeletePlan, titleVisibility: .visible) {
                Button("Delete plan", role: .destructive) {
                    appState.deleteSelectedWorkoutPlan()
                    syncSelectedWeek()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes the schedule and returns you to freestyle. Saved workout history and submitted lifts remain.")
            }
            .onAppear {
                syncSelectedWeek()
                appState.restoreSelectedWorkoutPlanIfNeeded()
                applyRequestedSegment()
#if DEBUG
                if !didOpenUITestFocusedWorkoutSet,
                   ProcessInfo.processInfo.arguments.contains("-uiTestingFocusedWorkoutSet"),
                   let workout = appState.trainingHistoryWorkouts.first,
                   let set = workout.completedWorkingSets.last {
                    focusedWorkoutSetID = set.id
                    selectedCompletedWorkout = workout
                    didOpenUITestFocusedWorkoutSet = true
                }
#endif
            }
            .onChange(of: appState.selectedWorkoutPlanID) {
                movedWorkoutMessage = nil
                syncSelectedWeek()
                if appState.selectedWorkoutPlan != nil {
                    withAnimation(reduceMotion ? nil : .snappy) { isProgramLibraryExpanded = false }
                }
            }
            .onChange(of: appState.workoutPlans) {
                appState.restoreSelectedWorkoutPlanIfNeeded()
            }
            .onChange(of: segment) { _, newSegment in
                appState.requestedTrackerSegment = newSegment.rawValue
                if newSegment != .today { movedWorkoutMessage = nil }
                if newSegment != .plans && isProgramLibraryExpanded {
                    withAnimation(reduceMotion ? nil : .snappy) { isProgramLibraryExpanded = false }
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
                Button("Resume workout") {
                    showingActiveWorkout = true
                }
                Button("Discard workout and start new", role: .destructive) {
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
                Button("Cancel", role: .cancel) { clearPendingStart() }
            } message: {
                Text(appState.activeWorkout?.name ?? "Finish or discard your current workout before starting another.")
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
                .onChange(of: appState.selectedWorkoutPlanID) {
                    if segment == .plans { scrollProxy.scrollTo("tracker-content-top", anchor: .top) }
                }
                .onChange(of: isProgramLibraryExpanded) { _, expanded in
                    if segment == .plans && expanded {
                        scrollProxy.scrollTo("tracker-program-library", anchor: .top)
                    }
                }
                .onChange(of: segment) { _, selected in
                    if selected == .plans && isProgramLibraryExpanded {
                        scrollProxy.scrollTo("tracker-program-library", anchor: .top)
                    }
                }
                .onChange(of: selectedProgressCategory) {
                    guard segment == .progress else { return }
                    scrollProxy.scrollTo("tracker-content-top", anchor: .top)
                }
                .onChange(of: appState.completedWorkoutsRevision) {
                    guard segment == .progress, selectedProgressCategory == .muscle else { return }
                    scrollProxy.scrollTo("tracker-content-top", anchor: .top)
                }
                .overlay(alignment: .trailing) {
                    if segment == .library && librarySearch.isEmpty && !dynamicTypeSize.isAccessibilitySize {
                        libraryAlphabetIndex(scrollProxy: scrollProxy, sections: libraryPresentation.sections)
                            .padding(.trailing, 2)
                    }
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if segment == .progress && selectedProgressCategory != .consistency {
                    NativeIconButton(symbolName: "chevron.left", accessibilityLabel: "Back to Progress") {
                        selectedProgressCategory = .consistency
                    }
                    .accessibilityIdentifier("tracker.progress.overview")
                }
                Text("Tracker")
                    .font(LiftTypography.sectionTitle)
                Spacer(minLength: 0)
                trackerHeaderActions
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)

            if appState.selectedWorkoutPlan == nil && segment == .today {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.liftAccentText)
                    Text("Choose a program to schedule workouts, or start a freestyle workout and add exercises as you go.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No workout plan selected. Choose a program to schedule workouts, or start a freestyle workout and add exercises as you go.")
            }

            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                    ForEach(TrackerSegment.allCases, id: \.self) { option in
                        trackerSegmentButton(option, fillsAvailableWidth: true)
                    }
                }
                .padding(.horizontal, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.liftOverlay)
                        .frame(height: 1)
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(TrackerSegment.allCases, id: \.self) { option in
                        trackerSegmentButton(option, fillsAvailableWidth: true)
                    }
                }
                .padding(.horizontal, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.liftOverlay)
                        .frame(height: 1)
                }
            }
        }
        .background(Color.liftBackground)
    }

    @ViewBuilder
    private var trackerHeaderActions: some View {
        if segment == .plans {
            Menu {
                if appState.activeWorkout == nil {
                    Button { showingCreatePlan = true } label: { Label("Create plan", systemImage: "plus.circle") }
                    Button { showingProgramImport = true } label: { Label("Import plan", systemImage: "square.and.arrow.down") }
                    if appState.selectedWorkoutPlan != nil {
                        Menu("Plan settings") {
                            Picker("Schedule", selection: Binding(
                                get: { appState.selectedPlanScheduleMode },
                                set: { _ = appState.setSelectedPlanScheduleMode($0); syncSelectedWeek() }
                            )) {
                                ForEach(WorkoutScheduleMode.allCases) { Text($0.rawValue).tag($0) }
                            }
                            if let settings = selectedProgramSettings,
                               WorkoutProgramCatalog.template(id: settings.sourceTemplateID) != nil {
                                Button("Progression") { showingProgressionEditor = true }
                            }
                        }
                        Button("Rename", systemImage: "pencil") {
                            renamePlanName = selectedPlanName
                            showingRenamePlan = true
                        }
                        Button("Duplicate & activate today", systemImage: "doc.on.doc") {
                            appState.duplicateSelectedWorkoutPlan()
                            syncSelectedWeek()
                        }
                        Button("Delete plan", role: .destructive) { showingDeletePlan = true }
                    }
                } else {
                    Button("Resume workout", systemImage: "play.fill") { showingActiveWorkout = true }
                }
                if let planID = appState.selectedWorkoutPlan?.id,
                   let shareText = appState.shareableWorkoutPlanText(planID: planID) {
                    ShareLink(item: shareText) { Label("Share plan", systemImage: "square.and.arrow.up") }
                }
            } label: {
                trackerOptionsButtonLabel
            }
            .accessibilityLabel("Plan options")
            .simultaneousGesture(TapGesture().onEnded { isLibrarySearchFocused = false })
        } else if segment == .today {
            Button {
                appState.showingSubmitSheet = true
            } label: {
                Label("Submit lift for rankings", systemImage: "dumbbell")
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.liftAccentText)
            .accessibilityHint("Separate from private workout logging; choose visibility when submitting.")
        }

        if !isEmbeddedInTab {
            NativeIconButton(symbolName: "xmark", accessibilityLabel: "Close training tracker") {
                dismiss()
            }
        }
    }

    private var trackerOptionsButtonLabel: some View {
        Image(systemName: "ellipsis")
            .font(LiftTypography.cardTitle)
            .frame(width: 44, height: 44)
            .background(Color.liftCard)
            .clipShape(Circle())
            .overlay { Circle().stroke(Color.liftOverlay, lineWidth: 1) }
    }

    private func trackerSegmentButton(_ option: TrackerSegment, fillsAvailableWidth: Bool) -> some View {
        Button {
            isLibrarySearchFocused = false
            segment = option
            appState.requestedTrackerSegment = option.rawValue
        } label: {
            VStack(spacing: 8) {
                Text(option.rawValue)
                    .font(.subheadline.weight(segment == option ? .bold : .medium))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(segment == option ? Color.liftText : Color.liftMuted)
                Rectangle()
                    .fill(segment == option ? Color.liftBlue : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: fillsAvailableWidth ? .infinity : nil)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, minHeight: 44)
        .fixedSize(horizontal: !fillsAvailableWidth, vertical: false)
        .accessibilityIdentifier("tracker.segment.\(option.rawValue.lowercased())")
        .accessibilityAddTraits(segment == option ? .isSelected : [])
        .accessibilityShowsLargeContentViewer { Text(option.rawValue) }
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's training")
                        .font(LiftTypography.sectionTitle)
                }
                Spacer()
            }

            if let movedWorkoutMessage {
                LiftCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(movedWorkoutMessage)
                            .font(.subheadline.weight(.semibold))
                        Button("View in Plans") { segment = .plans }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            todayWorkoutStatusSection

            if !selectedProgramIsComplete && !appState.selectedProgramCycleHasEnded {
            Button {
                isProgramLibraryExpanded = true
                withAnimation(reduceMotion ? nil : .snappy) { segment = .plans }
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
                            .font(LiftTypography.rowEmphasis)
                            .foregroundStyle(Color.liftText)
                        Text("Bodybuilding, powerlifting, cables, free weights, and more")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(LiftTypography.compactEmphasis)
                        .foregroundStyle(Color.liftAccentText)
                }
                .padding(12)
                .frame(minHeight: appState.selectedWorkoutPlan == nil ? 72 : 44)
                .liftSurface(radius: 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Browse \(appState.workoutProgramTemplates.count) workout programs")
            .accessibilityHint("Opens the workout program catalog")

            }

            if appState.activeWorkout == nil {
                Button {
                    startFreestyleWorkout()
                } label: {
                    Label("Start freestyle workout", systemImage: "plus")
                }
                .buttonStyle(LiftSecondaryButtonStyle())
            }

            if let insight = visiblePlateauInsights.first {
                PlateauAlertCard(insight: insight) {
                    selectedPlateauInsight = insight
                } dismiss: {
                    dismissPlateauInsight(insight)
                }
            }

        }
    }

    @ViewBuilder
    private var todayWorkoutStatusSection: some View {
        if let active = appState.activeWorkout {
            ActiveWorkoutResumeCard(workout: active) {
                showingActiveWorkout = true
            }
            .environmentObject(appState)
        } else if appState.selectedWorkoutPlan == nil {
            TrackerMessageCard(
                title: "Choose a workout plan",
                message: "Select a program to see scheduled training here, or start a freestyle workout."
            )
        } else if selectedProgramIsComplete || appState.selectedProgramCycleHasEnded {
            LiftCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label(selectedProgramIsComplete ? "Program complete" : "Cycle ended", systemImage: "checkmark.seal.fill")
                        .font(LiftTypography.cardTitle)
                        .foregroundStyle(Color.liftGreen)
                    Text(selectedProgramIsComplete ? "You completed \(selectedPlanName). Choose your next program or revisit this cycle in Plans." : "\(selectedPlanName) has ended. Some sessions were shortened or skipped.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Button("Review this cycle") { segment = .plans }
                        .frame(minHeight: LiftDesign.minimumTouchTarget)
                    Button {
                        isProgramLibraryExpanded = true
                        withAnimation(reduceMotion ? nil : .snappy) { segment = .plans }
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
                        .font(LiftTypography.cardTitle)
                    Text("Add a workout day in Plans, or start a freestyle workout.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy) { segment = .plans }
                    } label: {
                        Label("Add workout day", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiftCompactProminentButtonStyle())
                }
            }
        } else if appState.selectedPlanIsFlexible {
            LiftCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose today's workout").font(LiftTypography.cardTitle)
                    Text("Pick what fits your energy and recovery. No fixed days or required order.")
                        .font(.subheadline).foregroundStyle(Color.liftMuted)
                    if let week = appState.currentSelectedProgramWeek {
                        Text("Week \(week.weekNumber) · Workouts remaining")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.liftMuted)
                        ForEach(appState.availableFlexibleWorkoutSessions.filter { $0.weekID == week.id }) { session in
                            let exercises = appState.prescriptions(for: session)
                            Button { requestStart(session) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(session.name).font(.headline)
                                        Text("\(exercises.count) exercises · \(exercises.reduce(0) { $0 + $1.sets }) sets")
                                            .font(.caption).foregroundStyle(Color.liftMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill").font(.title2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).foregroundStyle(Color.liftAccentText)
                        }
                    }
                    Button("Browse all plan workouts") {
                        syncSelectedWeek()
                        segment = .plans
                    }
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                    Text("Training weeks are groups of workouts, not calendar deadlines. Saved workouts remain available to repeat in Plans.")
                        .font(.caption).foregroundStyle(Color.liftMuted)
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
            if rescheduleSuggestionsEnabled,
               let date = appState.suggestedRescheduleDate(for: missedWorkout.session) {
                LiftCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Move this session?").font(LiftTypography.cardTitle)
                        Text("\(date.formatted(date: .abbreviated, time: .omitted)) is open in this program week. Other sessions will stay on their planned days.")
                            .font(.caption).foregroundStyle(Color.liftMuted)
                        Button("Move to \(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))") {
                            let day = Calendar.current.weekdayName(for: date)
                            if appState.rescheduleWorkoutSession(missedWorkout.session, day: day) {
                                rescheduleError = nil
                                movedWorkoutMessage = "\(missedWorkout.session.name) moved to \(date.formatted(date: .abbreviated, time: .omitted))."
                            } else {
                                rescheduleError = "This session could not move. Review its schedule in Plans."
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.liftAccentText)
                        if let rescheduleError {
                            Text(rescheduleError).font(.caption).foregroundStyle(Color.liftRed)
                        }
                    }
                }
            }
        } else if let todayWorkout = todayScheduledWorkout {
            LiftCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today’s session is recorded").font(LiftTypography.cardTitle)
                    Text("\(todayWorkout.session.name) is saved, skipped, or marked as a rest day.")
                        .font(.caption).foregroundStyle(Color.liftMuted)
                    if let workout = appState.completedWorkouts
                        .filter({ $0.sourceSessionID == todayWorkout.session.id })
                        .max(by: { $0.completedAt < $1.completedAt }) {
                        Button("Review completed workout") { selectedCompletedWorkout = workout }
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
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
                        .font(LiftTypography.cardTitle)
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
            VStack(alignment: .leading, spacing: 8) {
                let next = appState.nextScheduledWorkout()
                TrackerMessageCard(
                    title: next == nil ? "No upcoming sessions" : "Rest day",
                    message: next.map { "\(selectedPlanName) · Next: \($0.session.name), \($0.date.formatted(date: .abbreviated, time: .omitted))." }
                        ?? "\(selectedPlanName) has no future sessions scheduled. Review unfinished workouts or plan your next cycle."
                )
                Button(next == nil ? "Review unfinished workouts" : "View next scheduled workout") {
                    if let next { selectedWeekID = next.week.id }
                    else if let unfinished = appState.selectedPlanWeeks.first(where: { week in
                        appState.sessions(for: week).contains {
                            !appState.prescriptions(for: $0).isEmpty && !appState.isFullyCompletedPlanSession($0)
                        }
                    }) { selectedWeekID = unfinished.id }
                    planDetailTab = "Weeks"
                    segment = .plans
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liftAccentText)
                .frame(minHeight: LiftDesign.minimumTouchTarget)
                if let workout = appState.completedWorkouts
                    .filter({ Calendar.current.isDateInToday($0.completedAt) })
                    .max(by: { $0.completedAt < $1.completedAt }) {
                    Button("Review today’s completed workout") { selectedCompletedWorkout = workout }
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var visiblePlateauInsights: [PlateauInsight] {
        let dismissed = Set(dismissedPlateauInsightIDs.split(separator: "|").map(String.init))
        return appState.plateauInsights.filter { !dismissed.contains($0.id) }
    }

    private func dismissPlateauInsight(_ insight: PlateauInsight) {
        var dismissed = Set(dismissedPlateauInsightIDs.split(separator: "|").map(String.init))
        dismissed.insert(insight.id)
        dismissedPlateauInsightIDs = dismissed.sorted().joined(separator: "|")
        Haptics.light()
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appState.activeWorkout != nil {
                HStack {
                    Text("Workout active · plan editing paused").font(.caption).foregroundStyle(Color.liftMuted)
                    Spacer()
                    Button("Resume") { showingActiveWorkout = true }.frame(minHeight: 44)
                }
            }
            HStack(spacing: 12) {
                Button { showingPlanSwitcher = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ACTIVE PLAN").font(.caption2.weight(.bold))
                            Text(appState.selectedWorkoutPlan?.name ?? "Freestyle")
                                .font(.headline)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Label("Change", systemImage: "chevron.down")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(14)
                    .homePanelStyle()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.liftAccentText)
                .accessibilityIdentifier("tracker.plans.switch")
                .disabled(appState.activeWorkout != nil)
                Button { showingCreatePlan = true } label: {
                    Image(systemName: "plus").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Create plan")
                .disabled(appState.activeWorkout != nil)
            }
            if appState.selectedWorkoutPlan != nil && !isProgramLibraryExpanded {
                ProgramPlanDetailView(
                    selectedWeekID: $selectedWeekID,
                    detailTab: $planDetailTab,
                    selectedSessionForAdd: $selectedSessionForAdd,
                    selectedSessionToRun: $selectedSessionToRun,
                    onResume: { showingActiveWorkout = true }
                )
                .environmentObject(appState)
            }

            programLibrary.id("tracker-program-library")
            if appState.workoutSyncStore.planSyncState == .needsAttention {
                Button("Plans couldn’t sync · Retry") {
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
                    if appState.workoutSyncStore.planSyncState == .syncing || (appState.isLoadingInitialTrainingData && appState.workoutSyncStore.planSyncState == .local) {
                        ProgressView("Loading your plans…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("plans.loading")
                    } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(appState.workoutSyncStore.planSyncState == .needsAttention ? "Saved plans unavailable" : "No saved plans yet")
                            .font(LiftTypography.cardTitle)
                        Text(appState.workoutSyncStore.planSyncState == .needsAttention
                             ? "We couldn’t check whether you have saved plans. Retry sync to check your account."
                             : "Browse a ready-made program above or create your own plan.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        if appState.workoutSyncStore.planSyncState != .needsAttention {
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
                    }
                }
            }
        }
    }

    private var programLibrary: some View {
        let query = programLibrarySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasActiveFilters = !query.isEmpty || programLibraryCategory != "All" || programLibraryEquipment != "All" || programLibraryDays != 0
        let catalog = Dictionary(uniqueKeysWithValues: appState.trainingExerciseLibrary.map { ($0.id, $0.equipment) })
        let equipmentOptions = Set(appState.workoutProgramTemplates.flatMap { $0.sessions.flatMap { $0.exercises.compactMap { catalog[$0.exerciseID] } } }).sorted()
        let templates = appState.workoutProgramTemplates.filter { template in
            let equipment = Set(template.sessions.flatMap { $0.exercises.compactMap { catalog[$0.exerciseID] } })
            return (programLibraryEquipment == "All" || equipment.contains(programLibraryEquipment)) &&
            (programLibraryCategory == "All" || template.category.rawValue == programLibraryCategory) &&
            (programLibraryDays == 0 || WorkoutProgramCatalog.scheduleVariants(for: template).contains { $0.daysPerWeek == programLibraryDays }) &&
            (query.isEmpty || "\(template.name) \(template.category.rawValue) \(template.level.rawValue) \(equipment.sorted().joined(separator: " "))".localizedCaseInsensitiveContains(query))
        }
        return VStack(alignment: .leading, spacing: 9) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy) { isProgramLibraryExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.liftAccentText)
                        .frame(width: 30)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Workout programs")
                            .font(LiftTypography.rowEmphasis)
                            .foregroundStyle(Color.liftText)
                        Text("\(appState.workoutProgramTemplates.count) ready-made programs")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.liftMuted)
                        .rotationEffect(.degrees(isProgramLibraryExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 62)
                .liftSurface(radius: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Workout program library, \(appState.workoutProgramTemplates.count) programs")
            .accessibilityValue(isProgramLibraryExpanded ? "Expanded" : "Collapsed")

            if isProgramLibraryExpanded {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.liftMuted)
                        .accessibilityHidden(true)
                    TextField("Search programs", text: $programLibrarySearch)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .accessibilityLabel("Search programs by name or equipment")
                    if !programLibrarySearch.isEmpty {
                        Button { programLibrarySearch = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.liftMuted)
                                .frame(minWidth: LiftDesign.minimumTouchTarget, minHeight: LiftDesign.minimumTouchTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear program search")
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: LiftDesign.minimumTouchTarget)
                .foregroundStyle(Color.liftText)
                .background(Color.liftField)
                .clipShape(RoundedRectangle(cornerRadius: LiftDesign.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: LiftDesign.controlRadius).stroke(Color.liftOverlay, lineWidth: 1))

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        programLibraryFilterMenus(equipmentOptions: equipmentOptions)
                    }
                    .buttonStyle(.plain)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            programLibraryFilterMenus(equipmentOptions: equipmentOptions)
                        }
                        .buttonStyle(.plain)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("plans.filters")
                }
                HStack {
                    Text(hasActiveFilters ? "\(templates.count) of \(appState.workoutProgramTemplates.count) programs" : "\(templates.count) programs")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .accessibilityIdentifier("plans.programCount")
                    Spacer()
                    if hasActiveFilters {
                        Button("Clear all") {
                            programLibrarySearch = ""
                            programLibraryCategory = "All"
                            programLibraryDays = 0
                            programLibraryEquipment = "All"
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: LiftDesign.minimumTouchTarget)
                        .accessibilityLabel("Clear program search and filters")
                    }
                }
                .frame(minHeight: LiftDesign.minimumTouchTarget)
                if templates.isEmpty {
                    Text("No matching programs")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                }
                LazyVStack(spacing: 9) {
                    ForEach(templates) { template in
                        Button {
                            selectedProgramTemplate = template
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: template.category == .powerlifting ? "trophy.fill" : "figure.strengthtraining.traditional")
                                    .font(LiftTypography.rowEmphasis)
                                    .foregroundStyle(Color.liftAccentText)
                                    .frame(width: 42, height: 42)
                                    .background(Color.liftBlue.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(LiftTypography.rowEmphasis)
                                        .foregroundStyle(Color.liftText)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text("\(template.category.rawValue) · \(template.level.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                        .lineLimit(1)

                                    Text(appState.workoutPlanProgressionSettings.contains(where: { settings in
                                        WorkoutProgramCatalog.scheduleVariants(for: template).contains { $0.id == settings.sourceTemplateID }
                                    }) ? "Saved program · resume or start a new cycle" : template.defaultProgression.rawValue)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.liftAccentText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 8)

                                VStack(alignment: .trailing, spacing: 5) {
                                    Text(WorkoutProgramCatalog.scheduleVariants(for: template).count > 1 ? "2–6 DAYS" : "\(template.daysPerWeek) DAYS")
                                        .font(.caption2.weight(.bold))
                                        .tracking(0.4)
                                        .foregroundStyle(Color.liftAccentText)
                                        .padding(.horizontal, 8)
                                        .frame(minHeight: 24)
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
                        .accessibilityLabel("Preview \(template.name), \(template.category.rawValue), \(template.level.rawValue), \(WorkoutProgramCatalog.scheduleVariants(for: template).count > 1 ? "2 to 6" : String(template.daysPerWeek)) days per week")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func programLibraryFilterMenus(equipmentOptions: [String]) -> some View {
        Menu {
            Picker("Program category", selection: $programLibraryCategory) {
                Text("All categories").tag("All")
                ForEach(WorkoutProgramCategory.allCases) { category in
                    Text(category.rawValue).tag(category.rawValue)
                }
            }
        } label: {
            programFilterLabel(programLibraryCategory == "All" ? "Category" : programLibraryCategory,
                               isActive: programLibraryCategory != "All")
        }
        .accessibilityLabel("Program category")
        .accessibilityValue(programLibraryCategory == "All" ? "All categories" : programLibraryCategory)
        Menu {
            Picker("Includes equipment", selection: $programLibraryEquipment) {
                Text("Any equipment").tag("All")
                ForEach(equipmentOptions, id: \.self) { Text($0).tag($0) }
            }
        } label: {
            programFilterLabel(programLibraryEquipment == "All" ? "Equipment" : programLibraryEquipment,
                               isActive: programLibraryEquipment != "All")
        }
        .accessibilityLabel("Includes equipment")
        .accessibilityValue(programLibraryEquipment == "All" ? "Any equipment" : programLibraryEquipment)
        Menu {
            Picker("Training frequency", selection: $programLibraryDays) {
                Text("Any frequency").tag(0)
                ForEach(2...6, id: \.self) { days in Text("\(days) days per week").tag(days) }
            }
        } label: {
            programFilterLabel(programLibraryDays == 0 ? "Days/week" : "\(programLibraryDays) days/week",
                               isActive: programLibraryDays != 0)
        }
        .accessibilityLabel("Training frequency")
        .accessibilityValue(programLibraryDays == 0 ? "Any frequency" : "\(programLibraryDays) days per week")
    }

    private func programFilterLabel(_ title: String, isActive: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: dynamicTypeSize.isAccessibilitySize ? LiftDesign.controlRadius : 22,
                                     style: .continuous)
        return HStack(spacing: 6) {
            Text(title)
            if dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .accessibilityHidden(true)
        }
        .font(.subheadline.weight(.semibold))
        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: LiftDesign.minimumTouchTarget)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
        .foregroundStyle(isActive ? Color.liftOnAccent : Color.liftText)
        .background(isActive ? Color.liftBlue : Color.liftField)
        .clipShape(shape)
        .overlay(shape.stroke(Color.liftOverlay, lineWidth: 1))
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
