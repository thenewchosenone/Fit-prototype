import Charts
import SwiftUI

extension TrainingTrackerView {
    var featureBody: some View {
        NavigationStack {
            AppBackground {
                trackerContent
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
            }
            .sheet(item: $selectedBodyweightEntry) { entry in
                BodyweightEntryEditor(entry: entry) { updatedEntry in
                    appState.updateBodyweight(updatedEntry)
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
            }
            .sheet(item: $selectedProgramTemplate) { template in
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
                CompletedWorkoutDetailView(workout: workout)
                    .environmentObject(appState)
                    .presentationDetents([.large])
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
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                syncSelectedWeek()
                applyRequestedSegment()
            }
            .onChange(of: appState.selectedWorkoutPlanID) {
                syncSelectedWeek()
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
                Button("Resume Active Workout") {
                    showingActiveWorkout = true
                }
                Button("Review & Finish Active Workout") {
                    showingActiveWorkout = true
                }
                Button("Discard Active & Start New", role: .destructive) {
                    appState.discardActiveWorkout()
                    SystemWorkoutRestNotificationScheduler.shared.cancel()
                    if let pendingSessionToStart {
                        _ = appState.startWorkout(pendingSessionToStart)
                    } else if pendingFreestyleStart {
                        _ = appState.startFreestyleWorkoutInstance()
                    }
                    clearPendingStart()
                    showingActiveWorkout = true
                }
                Button("Cancel", role: .cancel) { clearPendingStart() }
            } message: {
                Text("Lift Rivals keeps one active workout at a time so sets and timers cannot be mixed between sessions.")
            }
        }
    }

    private var trackerContent: some View {
        VStack(spacing: 0) {
            controls
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if segment == .today {
                            today
                        } else if segment == .plans {
                            plans
                        } else if segment == .library {
                            library(scrollProxy: scrollProxy)
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
                .overlay(alignment: .trailing) {
                    if segment == .library && librarySearch.isEmpty {
                        libraryAlphabetIndex(scrollProxy: scrollProxy)
                            .padding(.trailing, 2)
                    }
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Tracker")
                    .font(.title3.weight(.black))

                Menu {
                    Picker("Plan", selection: $appState.selectedWorkoutPlanID) {
                        ForEach(appState.workoutPlans) { plan in
                            Text(plan.name).tag(plan.id)
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "folder.fill")
                            .font(.caption)
                            .foregroundStyle(Color.liftBlue)
                        Text(selectedPlanName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftText)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.liftMuted)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 40)
                    .background(Color.liftCard)
                    .clipShape(Capsule())
                    .overlay { Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1) }
                }
                .accessibilityLabel("Active plan, \(selectedPlanName)")

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
                    Button {
                        renamePlanName = selectedPlanName
                        showingRenamePlan = true
                    } label: {
                        Label("Rename Plan", systemImage: "pencil")
                    }
                    Button {
                        appState.duplicateSelectedWorkoutPlan()
                        syncSelectedWeek()
                    } label: {
                        Label("Duplicate Plan", systemImage: "doc.on.doc")
                    }
                    Button {
                        showingProgressionEditor = true
                    } label: {
                        Label("Change Progression", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(selectedProgramSettings == nil)
                    Button(role: .destructive) {
                        appState.deleteSelectedWorkoutPlan()
                        syncSelectedWeek()
                    } label: {
                        Label("Delete Current Plan", systemImage: "trash")
                    }
                    .disabled(appState.workoutPlans.count < 2)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                        .overlay { Circle().stroke(Color.white.opacity(0.07), lineWidth: 1) }
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

            HStack(spacing: 0) {
                ForEach(TrackerSegment.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.snappy) { segment = option }
                    } label: {
                        VStack(spacing: 8) {
                            Text(option.rawValue)
                                .font(.subheadline.weight(segment == option ? .bold : .medium))
                                .foregroundStyle(segment == option ? Color.liftText : Color.liftMuted)
                                .lineLimit(1)
                            Rectangle()
                                .fill(segment == option ? Color.liftBlue : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(segment == option ? .isSelected : [])
                }
            }
            .padding(.horizontal, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background(Color.liftBackground)
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to train?")
                        .font(.title3.weight(.black))
                    Text("Log every set and keep your ranking current.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
            }

            Button {
                isProgramLibraryExpanded = true
                withAnimation(.snappy) { segment = .plans }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .font(.headline)
                        .foregroundStyle(Color.liftBlue)
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
                            .lineLimit(2)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                }
                .padding(12)
                .frame(minHeight: 72)
                .liftSurface(radius: 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Browse \(appState.workoutProgramTemplates.count) workout programs")
            .accessibilityHint("Opens the workout program catalog")

            if let insight = visiblePlateauInsights.first {
                PlateauAlertCard(insight: insight) {
                    selectedPlateauInsight = insight
                } dismiss: {
                    dismissPlateauInsight(insight)
                }
            }

            if let active = appState.activeWorkout {
                ActiveWorkoutResumeCard(workout: active) {
                    showingActiveWorkout = true
                }
                .environmentObject(appState)
            }

            if let week = selectedWeek, let session = primaryScheduledSession {
                TodayWorkoutLaunchCard(planName: selectedPlanName, week: week, session: session) {
                    requestStart(session)
                }
                .environmentObject(appState)
            } else {
                LiftCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.liftBlue)
                                .frame(width: 36, height: 36)
                                .background(Color.liftBlue.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("No scheduled workout")
                                    .font(.headline.weight(.bold))
                                Text("Add a workout day to this plan or train freestyle.")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }

                        Button {
                            withAnimation(.snappy) { segment = .plans }
                        } label: {
                            Label("Add workout day", systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LiftCompactProminentButtonStyle())
                    }
                }
            }

            Button {
                startFreestyleWorkout()
            } label: {
                Label("Start empty workout", systemImage: "plus")
            }
            .buttonStyle(LiftSecondaryButtonStyle())

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
            programLibrary

            if appState.workoutPlans.count > 1 {
                HStack {
                    Text("My Plans")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingCreatePlan = true
                    } label: {
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
                            appState.selectedWorkoutPlanID = plan.id
                            syncSelectedWeek()
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
                                Image(systemName: plan.id == appState.selectedWorkoutPlanID ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(plan.id == appState.selectedWorkoutPlanID ? Color.liftGreen : Color.liftMuted)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 58)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

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

            ProgramPlanDetailView(
                selectedWeekID: $selectedWeekID,
                detailTab: $planDetailTab,
                selectedSessionForAdd: $selectedSessionForAdd,
                selectedSessionToRun: $selectedSessionToRun
            )
            .environmentObject(appState)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                                    .foregroundStyle(Color.liftBlue)
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

    private func startFreestyleWorkout() {
        if appState.activeWorkout != nil {
            pendingSessionToStart = nil
            pendingFreestyleStart = true
            showingWorkoutConflict = true
            return
        }
        guard appState.startFreestyleWorkoutInstance() else { return }
        showingActiveWorkout = true
    }

    private func requestStart(_ session: WorkoutSession) {
        if appState.activeWorkout != nil {
            pendingSessionToStart = session
            pendingFreestyleStart = false
            showingWorkoutConflict = true
            return
        }
        guard appState.startWorkout(session) else { return }
        showingActiveWorkout = true
    }

    private func clearPendingStart() {
        pendingSessionToStart = nil
        pendingFreestyleStart = false
    }

    private func applyRequestedSegment() {
        guard let requested = TrackerSegment(rawValue: appState.requestedTrackerSegment) else { return }
        segment = requested
    }
}
