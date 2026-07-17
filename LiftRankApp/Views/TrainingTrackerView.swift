import Charts
import PhotosUI
import SwiftData
import SwiftUI
import UserNotifications

struct TrainingTrackerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var segment: TrackerSegment
    @State private var selectedWeekID: UUID?
    @State private var selectedSessionForAdd: WorkoutSession?
    @State private var selectedSessionToRun: WorkoutSession?
    @State private var pendingSessionToStart: WorkoutSession?
    @State private var pendingFreestyleStart = false
    @State private var showingActiveWorkout = false
    @State private var showingWorkoutConflict = false
    @State private var showingCreatePlan = false
    @State private var showingRenamePlan = false
    @State private var renamePlanName = ""
    @State private var planDetailTab = "Weeks"
    @State private var librarySearch = ""
    @State private var libraryFilters = ExerciseLibraryFilterSelection()
    @State private var showingLibraryFilters = false
    @State private var selectedLibraryExercise: TrainingExerciseCatalogItem?
    @State private var selectedProgramTemplate: WorkoutProgramTemplate?
    @State private var isProgramLibraryExpanded = false
    @State private var showingProgressionEditor = false
    @State private var selectedBodyweightEntry: BodyweightEntry?
    @State private var selectedCompletedWorkout: CompletedWorkout?
    @State private var workoutHistoryMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedWorkoutHistoryDate: Date?
    @State private var selectedProgressExerciseID: String?
    let isEmbeddedInTab: Bool

    init(startOnProgress: Bool = false, isEmbeddedInTab: Bool = false) {
        _segment = State(initialValue: startOnProgress ? .progress : .today)
        self.isEmbeddedInTab = isEmbeddedInTab
    }

    private var selectedPlanName: String {
        appState.selectedWorkoutPlan?.name ?? "Workout Plan"
    }

    private var selectedProgramSettings: WorkoutPlanProgressionSettings? {
        appState.workoutPlanProgressionSettings.first { $0.planID == appState.selectedWorkoutPlanID }
    }

    private var selectedWeek: WorkoutWeek? {
        if let selectedWeekID, let week = appState.selectedPlanWeeks.first(where: { $0.id == selectedWeekID }) {
            return week
        }
        return appState.selectedPlanWeeks.first
    }

    private var filteredLibraryResults: [ExerciseSearchResult] {
        appState.searchExercises(query: librarySearch, filters: libraryFilters)
    }

    private var scheduledSessions: [WorkoutSession] {
        guard let selectedWeek else { return [] }
        return appState.sessions(for: selectedWeek)
    }

    private var primaryScheduledSession: WorkoutSession? {
        scheduledSessions.first { session in
            let planned = appState.prescriptions(for: session).count
            return planned == 0 || appState.completedPrescriptionCount(for: session) < planned
        } ?? scheduledSessions.first
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    controls
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if segment == .today {
                                today
                            } else if segment == .plans {
                                plans
                            } else if segment == .library {
                                library
                            } else {
                                progress
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, isEmbeddedInTab ? 132 : 36)
                    }
                    .id(segment)
                    .scrollIndicators(.hidden)
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
                    WorkoutRestNotificationScheduler.cancel()
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
                Text("LiftRank keeps one active workout at a time so sets and timers cannot be mixed between sessions.")
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
                            .foregroundStyle(.white)
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
                                .foregroundStyle(segment == option ? .white : Color.liftMuted)
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

            if let active = appState.activeWorkout {
                ActiveWorkoutResumeCard(workout: active) {
                    showingActiveWorkout = true
                }
                .environmentObject(appState)
            }

            if let week = selectedWeek, let session = primaryScheduledSession {
                TodayWorkoutLaunchCard(week: week, session: session) {
                    requestStart(session)
                }
                .environmentObject(appState)
            } else {
                TrackerMessageCard(title: "No scheduled workout", message: "Create a workout day inside Plans or start freestyle now.")
            }

            Button {
                startFreestyleWorkout()
            } label: {
                Label("Start empty workout", systemImage: "plus")
            }
            .buttonStyle(LiftSecondaryButtonStyle())

            TodayWorkoutStats(week: selectedWeek, sessions: scheduledSessions)
                .environmentObject(appState)
        }
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
                                        .foregroundStyle(.white)
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
                        Text("12-Week Program Library")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("5 ready-made strength and bodybuilding plans")
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
            .accessibilityLabel("12-week program library, 5 programs")
            .accessibilityValue(isProgramLibraryExpanded ? "Expanded" : "Collapsed")

            if isProgramLibraryExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(appState.workoutProgramTemplates) { template in
                            Button {
                                selectedProgramTemplate = template
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: template.category == .powerlifting ? "trophy.fill" : "figure.strengthtraining.traditional")
                                            .foregroundStyle(Color.liftBlue)
                                        Spacer()
                                        Text("\(template.daysPerWeek)d")
                                            .font(.caption2.weight(.black))
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                    Text(template.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text("\(template.level.rawValue) • \(template.defaultProgression.rawValue)")
                                        .font(.caption2)
                                        .foregroundStyle(Color.liftMuted)
                                        .lineLimit(2)
                                }
                                .padding(12)
                                .frame(width: 184, height: 112, alignment: .topLeading)
                                .background(Color.liftCard)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Preview \(template.name), \(template.daysPerWeek) days per week")
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.liftMuted)
                TextField("Search exercises", text: $librarySearch)
                    .textFieldStyle(.plain)
                if !librarySearch.isEmpty {
                    Button {
                        librarySearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.liftMuted)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear exercise search")
                }
                Button {
                    showingLibraryFilters = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(libraryFilters.isEmpty ? Color.liftMuted : Color.liftBlue)
                            .frame(width: 44, height: 44)
                        if libraryFilters.activeCategoryCount > 0 {
                            Text("\(libraryFilters.activeCategoryCount)")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.liftBlue)
                                .clipShape(Circle())
                                .offset(x: 2, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Filter exercise library")
                .accessibilityValue(libraryFilters.isEmpty ? "No filters applied" : "\(libraryFilters.activeCategoryCount) filter categories applied")
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(minHeight: 46)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }

            if !libraryFilters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(libraryFilters.activeChips) { chip in
                            Button {
                                libraryFilters.clear(category: chip.category)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(chip.title)
                                    Image(systemName: "xmark")
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.liftBlue)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 36)
                                .background(Color.liftBlue.opacity(0.14))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(chip.title) filter")
                        }

                        Button("Clear all") {
                            libraryFilters = ExerciseLibraryFilterSelection()
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                        .frame(minHeight: 36)
                    }
                }
            }

            Text("\(filteredLibraryResults.count) exercises")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)

            if filteredLibraryResults.isEmpty {
                LiftEmptyState(
                    title: "No exercises found",
                    message: "Try another search or clear the active filters.",
                    symbolName: "magnifyingglass"
                )
                Button("Clear filters") {
                    libraryFilters = ExerciseLibraryFilterSelection()
                    librarySearch = ""
                }
                .buttonStyle(LiftSecondaryButtonStyle())
            } else {

                VStack(spacing: 0) {
                    ForEach(Array(filteredLibraryResults.enumerated()), id: \.element.id) { index, result in
                        let exercise = result.exercise
                        Button {
                            selectedLibraryExercise = exercise
                        } label: {
                            HStack(spacing: 12) {
                                ExerciseCatalogIcon(exercise: exercise)
                                    .frame(width: 44, height: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.subheadline.weight(.semibold))
                                    if let reason = result.reasonLabel {
                                        Text(reason)
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(Color.liftBlue)
                                    }
                                    Text("\(exercise.resolvedMuscleProfile.primaryDescription) • \(exercise.equipment)")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("\(exercise.defaultSets) × \(exercise.defaultReps)")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Color.liftMuted)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 64)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens exercise anatomy and defaults")

                        if index < filteredLibraryResults.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.07))
                                .padding(.leading, 68)
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
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var progress: some View {
        let totals = appState.volumeByBodyPart()
        let maxVolume = max(1, totals.values.max() ?? 1)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Progress")
                .font(.title3.weight(.black))

            workoutHistorySection

            if !progressExerciseOptions.isEmpty {
                exerciseProgressSection
            }

            if let week = selectedWeek {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(week.title) completion")
                                .font(.subheadline.weight(.bold))
                            Text("\(Int(appState.weekCompletion(for: week) * 100))% of exercises completed")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        Text("\(Int(appState.weekCompletion(for: week) * 100))%")
                            .font(.headline.weight(.black).monospacedDigit())
                            .foregroundStyle(Color.liftGreen)
                    }
                    ProgressView(value: appState.weekCompletion(for: week))
                        .tint(Color.liftGreen)
                }
                .padding(14)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Weekly volume by body part")
                    .font(.subheadline.weight(.bold))

                if totals.values.allSatisfy({ $0 == 0 }) {
                    Text("Complete workout sets to build volume insights.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .padding(.vertical, 8)
                } else {
                    ForEach(totals.keys.sorted(), id: \.self) { bodyPart in
                        let value = totals[bodyPart] ?? 0
                        HStack(spacing: 10) {
                            Text(bodyPart)
                                .font(.caption.weight(.semibold))
                                .frame(width: 82, alignment: .leading)
                                .lineLimit(1)
                            ProgressView(value: value, total: maxVolume)
                                .tint(Color.liftBlue)
                            Text("\(Int(value))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.liftMuted)
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            Text("Bodyweight")
                .font(.title3.weight(.black))

            VStack(alignment: .leading, spacing: 8) {
                Chart(appState.bodyweightEntries) { row in
                    if let actual = row.actual {
                        LineMark(x: .value("Week", row.week), y: .value("Bodyweight", actual))
                            .foregroundStyle(Color.liftBlue)
                        PointMark(x: .value("Week", row.week), y: .value("Bodyweight", actual))
                            .foregroundStyle(Color.liftGreen)
                    }
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .trailing) {
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel().foregroundStyle(Color.liftMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks {
                        AxisValueLabel().foregroundStyle(Color.liftMuted)
                    }
                }
            }
            .padding(12)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }

            bodyweightTable
        }
        .onAppear {
            if selectedProgressExerciseID == nil {
                selectedProgressExerciseID = progressExerciseOptions.first?.id
            }
            syncWorkoutHistorySelection()
        }
        .onChange(of: appState.completedWorkouts.count) {
            syncWorkoutHistorySelection()
        }
    }

    private var workoutHistorySection: some View {
        WorkoutHistoryCalendar(
            workouts: appState.completedWorkouts,
            displayedMonth: $workoutHistoryMonth,
            selectedDate: $selectedWorkoutHistoryDate
        ) { workout in
            selectedCompletedWorkout = workout
        }
    }

    private var exerciseProgressSection: some View {
        let exerciseID = selectedProgressExerciseID ?? progressExerciseOptions.first?.id
        let exercise = progressExerciseOptions.first { $0.id == exerciseID }
        let points = exercise.map { exerciseProgressPoints(for: $0.id) } ?? []
        let prs = repSpecificPRs(points)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let exercise {
                    ExerciseCatalogIcon(exercise: exercise)
                        .frame(width: 42, height: 42)
                }
                Text("Exercise progress")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Menu {
                    ForEach(progressExerciseOptions) { option in
                        Button(option.name) { selectedProgressExerciseID = option.id }
                    }
                } label: {
                    Label(exercise?.name ?? "Exercise", systemImage: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                }
            }

            if points.isEmpty {
                Text("Complete sets for this exercise to build its trend.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(Color.liftBlue)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(Color.liftGreen)
                }
                .frame(height: 150)
                .chartYAxis { AxisMarks(position: .trailing) }

                if !prs.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(prs.prefix(4), id: \.reps) { pr in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(pr.reps)-rep PR")
                                    .font(.caption2)
                                    .foregroundStyle(Color.liftMuted)
                                Text("\(RankingCalculator.format(pr.weight)) \(pr.unit.shortLabel)")
                                    .font(.caption.weight(.black).monospacedDigit())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(9)
                            .background(Color.black.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var progressExerciseOptions: [TrainingExerciseCatalogItem] {
        let IDs = Set(appState.completedWorkouts.flatMap { $0.exercises.map(\.exerciseID) })
        return appState.trainingExerciseLibrary.filter { IDs.contains($0.id) }.sorted { $0.name < $1.name }
    }

    private func exerciseProgressPoints(for exerciseID: String) -> [ExerciseProgressPoint] {
        appState.completedWorkouts.flatMap { workout -> [ExerciseProgressPoint] in
            let matchingIDs = Set(workout.exercises.filter { $0.exerciseID == exerciseID }.map(\.id))
            return workout.sets.compactMap { set in
                guard matchingIDs.contains(set.prescriptionID),
                      set.isComplete,
                      !set.isWarmup,
                      let weight = set.weight,
                      let reps = set.reps else { return nil }
                let preferredUnit = appState.currentProfile.preferredUnit
                let normalizedWeight: Double
                if set.recordedUnit == preferredUnit {
                    normalizedWeight = weight
                } else if preferredUnit == .kilograms {
                    normalizedWeight = RankingCalculator.poundsToKilograms(weight)
                } else {
                    normalizedWeight = RankingCalculator.kilogramsToPounds(weight)
                }
                return ExerciseProgressPoint(
                    id: set.id,
                    date: workout.completedAt,
                    weight: normalizedWeight,
                    reps: reps,
                    unit: preferredUnit
                )
            }
        }
        .sorted { $0.date < $1.date }
    }

    private func repSpecificPRs(_ points: [ExerciseProgressPoint]) -> [(reps: Int, weight: Double, unit: UnitSystem)] {
        let grouped = Dictionary(grouping: points, by: \.reps)
        return grouped.compactMap { reps, values in
            guard let best = values.max(by: { lhs, rhs in
                let lhsKG = lhs.unit == .kilograms ? lhs.weight : RankingCalculator.poundsToKilograms(lhs.weight)
                let rhsKG = rhs.unit == .kilograms ? rhs.weight : RankingCalculator.poundsToKilograms(rhs.weight)
                return lhsKG < rhsKG
            }) else { return nil }
            return (reps, best.weight, best.unit)
        }
        .sorted { $0.reps < $1.reps }
    }

    private func syncWorkoutHistorySelection() {
        guard let mostRecent = appState.completedWorkouts.max(by: { $0.completedAt < $1.completedAt }) else {
            selectedWorkoutHistoryDate = nil
            workoutHistoryMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
            return
        }
        if selectedWorkoutHistoryDate == nil {
            selectedWorkoutHistoryDate = Calendar.current.startOfDay(for: mostRecent.completedAt)
            workoutHistoryMonth = Calendar.current.dateInterval(of: .month, for: mostRecent.completedAt)?.start ?? mostRecent.completedAt
        }
    }

    private var bodyweightTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Week").frame(width: 48, alignment: .leading)
                Text("Date").frame(maxWidth: .infinity, alignment: .leading)
                Text("Weight").frame(width: 76, alignment: .trailing)
                Text("").frame(width: 28)
            }
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(Color.liftMuted)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Color.liftCardRaised.opacity(0.7))

            ForEach(Array(appState.bodyweightEntries.enumerated()), id: \.element.id) { index, row in
                Button {
                    selectedBodyweightEntry = row
                } label: {
                    HStack(spacing: 8) {
                        Text("\(row.week)")
                            .frame(width: 48, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.targetDate, style: .date)
                                .lineLimit(1)
                            if !row.notes.isEmpty {
                                Text("Has notes")
                                    .font(.caption2)
                                    .foregroundStyle(Color.liftBlue)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.actual.map { "\(RankingCalculator.format($0)) lb" } ?? "—")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .frame(width: 76, alignment: .trailing)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftMuted)
                            .frame(width: 28)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Week \(row.week), \(row.actual.map { "\(RankingCalculator.format($0)) pounds" } ?? "no bodyweight"), edit")

                if index < appState.bodyweightEntries.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.07))
                        .padding(.leading, 68)
                }
            }
        }
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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

private enum TrackerSegment: String, CaseIterable, Hashable {
    case today = "Today"
    case plans = "Plans"
    case library = "Library"
    case progress = "Progress"

    var symbol: String {
        switch self {
        case .today: return "play.fill"
        case .plans: return "folder.fill"
        case .library: return "dumbbell.fill"
        case .progress: return "chart.bar.fill"
        }
    }
}

private struct ExerciseProgressPoint: Identifiable {
    let id: UUID
    let date: Date
    let weight: Double
    let reps: Int
    let unit: UnitSystem
}

struct TodayWorkoutLaunchCard: View {
    @EnvironmentObject private var appState: AppState
    let week: WorkoutWeek
    let session: WorkoutSession
    let onStart: () -> Void

    var body: some View {
        let prescriptions = appState.prescriptions(for: session)
        let completed = appState.completedPrescriptionCount(for: session)
        let progress = prescriptions.isEmpty ? 0 : Double(completed) / Double(prescriptions.count)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftBlue)
                    .frame(width: 44, height: 44)
                    .background(Color.liftBlue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("NEXT WORKOUT")
                        .font(.caption2.weight(.black))
                        .tracking(0.9)
                        .foregroundStyle(Color.liftBlue)
                    Text(session.name)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                    Text("\(session.day) • \(week.title)")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }

                Spacer()

                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.liftBackground)
                        .frame(width: 44, height: 44)
                        .background(Color.liftBlue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start \(session.name)")
            }

            if prescriptions.isEmpty {
                Text("No exercises yet. Build the workout as you train.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            } else {
                VStack(spacing: 6) {
                    HStack {
                        Text("\(prescriptions.count) exercises")
                        Spacer()
                        Text("\(completed) complete")
                            .foregroundStyle(completed > 0 ? Color.liftGreen : Color.liftMuted)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    ProgressView(value: progress)
                        .tint(completed == prescriptions.count ? Color.liftGreen : Color.liftBlue)
                }
            }

            Button(action: onStart) {
                HStack {
                    Text(completed > 0 ? "Continue workout" : "Start workout")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Color.liftBackground)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Color.liftBlue)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
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

struct WorkoutHistoryCalendarDay: Identifiable, Equatable {
    let id: Int
    let date: Date?
    let workoutCount: Int
}

enum WorkoutHistoryCalendarData {
    static func monthStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func days(
        in month: Date,
        workouts: [CompletedWorkout],
        calendar: Calendar = .current
    ) -> [WorkoutHistoryCalendarDay] {
        let monthStart = monthStart(for: month, calendar: calendar)
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingCount = (weekday - calendar.firstWeekday + 7) % 7
        let counts = Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.completedAt) }
            .mapValues(\.count)

        var result = (0..<leadingCount).map {
            WorkoutHistoryCalendarDay(id: $0, date: nil, workoutCount: 0)
        }
        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            result.append(
                WorkoutHistoryCalendarDay(
                    id: result.count,
                    date: date,
                    workoutCount: counts[calendar.startOfDay(for: date), default: 0]
                )
            )
        }
        let trailingCount = (7 - (result.count % 7)) % 7
        for _ in 0..<trailingCount {
            result.append(WorkoutHistoryCalendarDay(id: result.count, date: nil, workoutCount: 0))
        }
        return result
    }

    static func workouts(
        on date: Date?,
        from workouts: [CompletedWorkout],
        calendar: Calendar = .current
    ) -> [CompletedWorkout] {
        guard let date else { return [] }
        return workouts
            .filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
            .sorted { $0.completedAt > $1.completedAt }
    }

    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        let start = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }
}

struct WorkoutHistoryCalendar: View {
    let workouts: [CompletedWorkout]
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date?
    let onSelectWorkout: (CompletedWorkout) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var monthStart: Date {
        WorkoutHistoryCalendarData.monthStart(for: displayedMonth, calendar: calendar)
    }

    private var currentMonth: Date {
        WorkoutHistoryCalendarData.monthStart(for: .now, calendar: calendar)
    }

    private var earliestMonth: Date {
        workouts.map(\.completedAt).min().map {
            WorkoutHistoryCalendarData.monthStart(for: $0, calendar: calendar)
        } ?? currentMonth
    }

    private var latestMonth: Date {
        workouts.map(\.completedAt).max().map {
            WorkoutHistoryCalendarData.monthStart(for: $0, calendar: calendar)
        } ?? currentMonth
    }

    private var firstBrowsableMonth: Date { min(earliestMonth, currentMonth) }
    private var lastBrowsableMonth: Date { max(latestMonth, currentMonth) }

    private var calendarDays: [WorkoutHistoryCalendarDay] {
        WorkoutHistoryCalendarData.days(in: monthStart, workouts: workouts, calendar: calendar)
    }

    private var selectedWorkouts: [CompletedWorkout] {
        WorkoutHistoryCalendarData.workouts(on: selectedDate, from: workouts, calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout calendar")
                        .font(.subheadline.weight(.bold))
                    Text("\(workouts.count) completed")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                if monthStart != currentMonth {
                    Button("Today") {
                        displayedMonth = currentMonth
                        selectedDate = calendar.startOfDay(for: .now)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftBlue)
                    .frame(minHeight: 44)
                }
            }

            HStack(spacing: 8) {
                monthButton(symbol: "chevron.left", label: "Previous month", disabled: monthStart <= firstBrowsableMonth) {
                    moveMonth(by: -1)
                }
                Text(monthStart.formatted(.dateTime.month(.wide).year()))
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                monthButton(symbol: "chevron.right", label: "Next month", disabled: monthStart >= lastBrowsableMonth) {
                    moveMonth(by: 1)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(WorkoutHistoryCalendarData.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarDays) { day in
                    calendarDay(day)
                }
            }

            Divider().overlay(Color.white.opacity(0.07))

            selectedDayHistory
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

    private func calendarDay(_ day: WorkoutHistoryCalendarDay) -> some View {
        let isSelected: Bool
        if let date = day.date, let selectedDate {
            isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        } else {
            isSelected = false
        }
        let isToday = day.date.map(calendar.isDateInToday) ?? false
        return Button {
            selectedDate = day.date.map(calendar.startOfDay)
        } label: {
            VStack(spacing: 2) {
                Text(day.date.map { String(calendar.component(.day, from: $0)) } ?? "")
                    .font(.caption.weight(isSelected || day.workoutCount > 0 ? .bold : .medium).monospacedDigit())
                    .foregroundStyle(isSelected ? Color.white : day.date == nil ? Color.clear : Color.white)
                Circle()
                    .fill(day.workoutCount > 0 ? (isSelected ? Color.white : Color.liftBlue) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(isSelected ? Color.liftBlue : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.liftBlue.opacity(0.75), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(day.date == nil)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var selectedDayHistory: some View {
        if workouts.isEmpty {
            Text("Finish a workout to begin your training history.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
                .padding(.vertical, 4)
        } else if let selectedDate {
            VStack(alignment: .leading, spacing: 0) {
                Text(selectedDate.formatted(date: .complete, time: .omitted))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
                    .padding(.bottom, 4)

                if selectedWorkouts.isEmpty {
                    Text("No completed workouts")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(selectedWorkouts.enumerated()), id: \.element.id) { index, workout in
                        Button {
                            onSelectWorkout(workout)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(workout.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text("\(workout.completedWorkingSets.count) sets • \(workout.completedAt.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Spacer()
                                Text(formattedDuration(workout.duration))
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(Color.liftBlue)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens completed workout details")

                        if index < selectedWorkouts.count - 1 {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        } else {
            Text("Select a date to review past workouts.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
                .padding(.vertical, 4)
        }
    }

    private func moveMonth(by offset: Int) {
        guard let destination = calendar.date(byAdding: .month, value: offset, to: monthStart) else { return }
        let normalized = WorkoutHistoryCalendarData.monthStart(for: destination, calendar: calendar)
        guard normalized >= firstBrowsableMonth, normalized <= lastBrowsableMonth else { return }
        displayedMonth = normalized
        selectedDate = workouts
            .filter { calendar.isDate($0.completedAt, equalTo: normalized, toGranularity: .month) }
            .max(by: { $0.completedAt < $1.completedAt })
            .map { calendar.startOfDay(for: $0.completedAt) }
    }

    private func monthButton(
        symbol: String,
        label: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? Color.liftMuted.opacity(0.3) : Color.liftMuted)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    private func accessibilityLabel(for day: WorkoutHistoryCalendarDay) -> String {
        guard let date = day.date else { return "Empty calendar day" }
        let workoutText = day.workoutCount == 1 ? "1 completed workout" : "\(day.workoutCount) completed workouts"
        return "\(date.formatted(date: .complete, time: .omitted)), \(workoutText)"
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int(duration) / 60)
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
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
                        .foregroundStyle(Color.liftBackground)
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
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.liftBlue)
                }

                HStack {
                    Label("\(workout.exercises.count) exercises", systemImage: "dumbbell.fill")
                    Spacer()
                    Label("\(appState.activeWorkoutCompletedWorkingSets.count) sets logged", systemImage: "checkmark.circle.fill")
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

struct TodayWorkoutStats: View {
    @EnvironmentObject private var appState: AppState
    let week: WorkoutWeek?
    let sessions: [WorkoutSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This week")
                .font(.headline.weight(.black))

            HStack(spacing: 10) {
                metric("Week", week.map { "\($0.weekNumber)" } ?? "--", symbol: "calendar")
                divider
                metric("Planned", "\(sessions.count)", symbol: "figure.strengthtraining.traditional")
                divider
                metric("Finished", "\(finishedThisWeek)", symbol: "checkmark")
            }
            .padding(12)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }

            if let date = appState.lastCompletedWorkoutDate() {
                Label("Last workout \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftGreen)
            } else {
                Label("Complete your first workout to start a streak", systemImage: "flame")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(width: 1, height: 42)
    }

    private var finishedThisWeek: Int {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return appState.completedWorkouts.filter { interval.contains($0.completedAt) && !$0.completedWorkingSets.isEmpty }.count
    }

    private func metric(_ title: String, _ value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
                .lineLimit(1)
            Text(value)
                .font(.headline.weight(.black).monospacedDigit())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

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
                weekNavigator
                weekSessions
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
                        .foregroundStyle(.white)
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

    private var weekSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedWeek {
                let sessions = appState.sessions(for: selectedWeek)
                if sessions.isEmpty {
                    TrackerMessageCard(title: "No workout days yet", message: "Add workout days like Monday Push, Tuesday Pull, or Friday Legs.")
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
                .buttonStyle(.borderedProminent)
                .tint(Color.liftBlue)
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

struct ProgramSessionCard: View {
    @EnvironmentObject private var appState: AppState
    let session: WorkoutSession
    let week: WorkoutWeek
    let onStart: () -> Void
    let onAddExercise: () -> Void
    let onDelete: () -> Void

    var body: some View {
        LiftCard {
            let prescriptions = appState.prescriptions(for: session)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(session.day) · \(session.name)")
                            .font(.headline)
                        Text("\(prescriptions.count) exercises - \(appState.completedPrescriptionCount(for: session)) complete")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                    Menu {
                        Button(role: .destructive, action: onDelete) {
                            Text("Delete Workout Day")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.liftMuted)
                            .frame(width: 44, height: 44)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(Array(prescriptions.enumerated()), id: \.element.id) { index, prescription in
                        HStack(spacing: 11) {
                            ExerciseCatalogIcon(exercise: catalogExercise(for: prescription))
                                .frame(width: 38, height: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prescription.exerciseName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(prescription.sets) × \(prescription.reps) • \(prescription.bodyPart)")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 52)

                        if index < prescriptions.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.07))
                                .padding(.leading, 49)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button(action: onAddExercise) {
                        Label("Add Exercise", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.liftBlue)

                    Button(action: onStart) {
                        Label("Start", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liftBlue)
                }
            }
        }
    }

    private func catalogExercise(for prescription: WorkoutExercisePrescription) -> TrainingExerciseCatalogItem {
        appState.trainingExerciseLibrary.first { $0.id == prescription.exerciseID } ?? TrainingExerciseCatalogItem(
            id: prescription.exerciseID,
            name: prescription.exerciseName,
            bodyPart: prescription.bodyPart,
            workoutCategory: prescription.bodyPart,
            defaultSets: prescription.sets,
            defaultReps: prescription.reps,
            symbolName: "figure.strengthtraining.traditional",
            equipment: prescription.equipment,
            muscleProfile: prescription.muscleProfile
        )
    }
}

enum ExerciseLibraryBodyArea: String, CaseIterable, Hashable, Identifiable {
    case upperBody = "Upper body"
    case lowerBody = "Lower body"
    case core = "Core"
    case fullBody = "Full body"

    var id: String { rawValue }
}

struct WorkoutProgramTemplateDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutProgramTemplate
    @State private var method: WorkoutProgressionMethod
    @State private var startDate = Date.now
    @State private var scheduledWeekdays: [Int]
    @State private var trainingMaxInputs: [String: String] = [:]

    init(template: WorkoutProgramTemplate) {
        self.template = template
        _method = State(initialValue: template.defaultProgression)
        _scheduledWeekdays = State(initialValue: template.sessions.map(\.dayIndex))
    }

    private var canStart: Bool {
        method != .percentage || template.requiredTrainingMaxExerciseIDs.allSatisfy { parsedTrainingMaxKilograms[$0, default: 0] > 0 }
    }

    private var parsedTrainingMaxKilograms: [String: Double] {
        trainingMaxInputs.reduce(into: [:]) { result, pair in
            guard let value = Double(pair.value), value > 0 else { return }
            result[pair.key] = appState.currentProfile.preferredUnit == .pounds
                ? RankingCalculator.poundsToKilograms(value)
                : value
        }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        overview
                        setup
                        phaseSummary
                        sessionPreview
                    }
                    .padding(16)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    Button("Start 12-Week Program") {
                        if appState.startWorkoutProgram(
                            template: template,
                            startDate: startDate,
                            scheduledWeekdays: scheduledWeekdays,
                            method: method,
                            trainingMaxKilograms: parsedTrainingMaxKilograms
                        ) != nil {
                            dismiss()
                        }
                    }
                    .buttonStyle(LiftPrimaryButtonStyle())
                    .disabled(!canStart)
                    .padding(16)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Program Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { seedTrainingMaxesIfNeeded() }
            .onChange(of: method) { _, value in
                if value == .percentage { seedTrainingMaxesIfNeeded() }
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(template.name)
                .font(.title2.weight(.black))
            Text(template.summary)
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
            HStack(spacing: 8) {
                metadataChip(template.category.rawValue)
                metadataChip(template.level.rawValue)
                metadataChip("\(template.daysPerWeek) days/week")
            }
        }
    }

    private var setup: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Program setup").font(.headline)
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progression").font(.caption.weight(.bold)).foregroundStyle(Color.liftMuted)
                    ForEach(WorkoutProgressionMethod.allCases) { option in
                        ProgramChoiceRow(title: option.rawValue, isSelected: method == option) { method = option }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training days").font(.caption.weight(.bold)).foregroundStyle(Color.liftMuted)
                    ForEach(Array(template.sessions.enumerated()), id: \.offset) { index, session in
                        HStack {
                            Text(session.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Picker("Day for \(session.name)", selection: weekdayBinding(index)) {
                                ForEach(1...7, id: \.self) { weekday in
                                    Text(weekdayName(weekday)).tag(weekday)
                                }
                            }
                            .labelsHidden()
                        }
                        .frame(minHeight: 44)
                    }
                }
                if method == .percentage { trainingMaxFields }
            }
        }
    }

    private var trainingMaxFields: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Training maxes")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftMuted)
            Text("Suggested values use 90% of your best LiftRank 1RM or estimated 1RM. Review them before starting.")
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            ForEach(template.requiredTrainingMaxExerciseIDs, id: \.self) { exerciseID in
                HStack {
                    Text(exerciseName(exerciseID))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    TextField("Required", text: trainingMaxBinding(exerciseID))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 88)
                        .padding(9)
                        .background(Color.black.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text(appState.currentProfile.preferredUnit.shortLabel)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
            }
        }
    }

    private var phaseSummary: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("12-week structure").font(.headline)
            ForEach(["Weeks 1–3 · Foundation", "Week 4 · Deload", "Weeks 5–7 · Progressive overload", "Week 8 · Deload", "Weeks 9–11 · Intensification", "Week 12 · Recovery and optional performance check"], id: \.self) { title in
                Label(title, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
            }
        }
    }

    private var sessionPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly workouts").font(.headline)
            ForEach(Array(template.sessions.enumerated()), id: \.offset) { index, session in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(weekdayName(scheduledWeekdays[index])) · \(session.name)")
                        .font(.subheadline.weight(.bold))
                    ForEach(session.exercises, id: \.exerciseID) { prescription in
                        if let exercise = appState.trainingExerciseLibrary.first(where: { $0.id == prescription.exerciseID }) {
                            HStack(spacing: 10) {
                                ExerciseCatalogIcon(exercise: exercise)
                                    .frame(width: 42, height: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name).font(.caption.weight(.semibold))
                                    Text("\(prescription.sets) × \(prescription.reps) · \(exercise.resolvedMuscleProfile.primaryDescription)")
                                        .font(.caption2)
                                        .foregroundStyle(Color.liftMuted)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func seedTrainingMaxesIfNeeded() {
        guard trainingMaxInputs.isEmpty else { return }
        let suggestions = appState.suggestedTrainingMaxKilograms(for: template)
        for exerciseID in template.requiredTrainingMaxExerciseIDs {
            guard let kilograms = suggestions[exerciseID] else { continue }
            let displayed = appState.currentProfile.preferredUnit == .pounds
                ? RankingCalculator.kilogramsToPounds(kilograms)
                : kilograms
            trainingMaxInputs[exerciseID] = String(format: "%.1f", displayed)
        }
    }

    private func trainingMaxBinding(_ exerciseID: String) -> Binding<String> {
        Binding(get: { trainingMaxInputs[exerciseID, default: ""] }, set: { trainingMaxInputs[exerciseID] = $0 })
    }

    private func weekdayBinding(_ index: Int) -> Binding<Int> {
        Binding(get: { scheduledWeekdays[index] }, set: { scheduledWeekdays[index] = $0 })
    }

    private func exerciseName(_ id: String) -> String {
        appState.trainingExerciseLibrary.first { $0.id == id }?.name ?? id
    }

    private func weekdayName(_ value: Int) -> String {
        Calendar.current.weekdaySymbols[max(0, min(6, value - 1))]
    }

    private func metadataChip(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.liftBlue)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.liftBlue.opacity(0.13))
            .clipShape(Capsule())
    }
}

struct WorkoutProgramProgressionEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let settings: WorkoutPlanProgressionSettings
    let template: WorkoutProgramTemplate
    @State private var method: WorkoutProgressionMethod
    @State private var inputs: [String: String]

    init(settings: WorkoutPlanProgressionSettings, template: WorkoutProgramTemplate) {
        self.settings = settings
        self.template = template
        _method = State(initialValue: settings.method)
        _inputs = State(initialValue: settings.trainingMaxKilograms.mapValues { kilograms in
            let value = settings.preferredUnit == .pounds ? RankingCalculator.kilogramsToPounds(kilograms) : kilograms
            return String(format: "%.1f", value)
        })
    }

    private var parsed: [String: Double] {
        inputs.reduce(into: [:]) { result, pair in
            if let value = Double(pair.value), value > 0 {
                result[pair.key] = settings.preferredUnit == .pounds ? RankingCalculator.poundsToKilograms(value) : value
            }
        }
    }

    private var canSave: Bool {
        method != .percentage || template.requiredTrainingMaxExerciseIDs.allSatisfy { parsed[$0, default: 0] > 0 }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Changes apply only to uncompleted future weeks. Completed weeks, substitutions, exercise order, and the active workout stay unchanged.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                        ForEach(WorkoutProgressionMethod.allCases) { option in
                            ProgramChoiceRow(title: option.rawValue, isSelected: method == option) { method = option }
                        }
                        if method == .percentage {
                            LiftCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Training maxes · \(settings.preferredUnit.shortLabel)").font(.headline)
                                    ForEach(template.requiredTrainingMaxExerciseIDs, id: \.self) { id in
                                        HStack {
                                            Text(appState.trainingExerciseLibrary.first { $0.id == id }?.name ?? id)
                                                .font(.subheadline.weight(.semibold))
                                            Spacer()
                                            TextField("Required", text: Binding(
                                                get: { inputs[id, default: ""] },
                                                set: { inputs[id] = $0 }
                                            ))
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 88)
                                            .padding(9)
                                            .background(Color.black.opacity(0.18))
                                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Change Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if appState.changeProgression(for: settings.planID, method: method, trainingMaxKilograms: parsed) {
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

enum ExerciseLibraryFilterCategory: String, Hashable {
    case bodyAreas
    case primaryMuscles
    case equipment
    case movementTypes
    case trackingTypes
}

struct ExerciseLibraryFilterChip: Identifiable {
    let category: ExerciseLibraryFilterCategory
    let title: String
    var id: String { category.rawValue }
}

struct ExerciseLibraryFilterSelection: Equatable {
    var bodyAreas: Set<ExerciseLibraryBodyArea> = []
    var primaryMuscles: Set<ExerciseMuscleRegion> = []
    var equipment: Set<String> = []
    var movementTypes: Set<String> = []
    var trackingTypes: Set<String> = []

    var isEmpty: Bool { activeCategoryCount == 0 }
    var activeCategoryCount: Int {
        [!bodyAreas.isEmpty, !primaryMuscles.isEmpty, !equipment.isEmpty, !movementTypes.isEmpty, !trackingTypes.isEmpty]
            .filter { $0 }.count
    }

    var activeChips: [ExerciseLibraryFilterChip] {
        var chips: [ExerciseLibraryFilterChip] = []
        if !bodyAreas.isEmpty { chips.append(.init(category: .bodyAreas, title: summary("Area", values: bodyAreas.map(\.rawValue)))) }
        if !primaryMuscles.isEmpty { chips.append(.init(category: .primaryMuscles, title: summary("Muscle", values: primaryMuscles.map(\.displayName)))) }
        if !equipment.isEmpty { chips.append(.init(category: .equipment, title: summary("Equipment", values: Array(equipment)))) }
        if !movementTypes.isEmpty { chips.append(.init(category: .movementTypes, title: summary("Movement", values: Array(movementTypes)))) }
        if !trackingTypes.isEmpty { chips.append(.init(category: .trackingTypes, title: summary("Tracking", values: Array(trackingTypes)))) }
        return chips
    }

    func matches(_ exercise: TrainingExerciseCatalogItem) -> Bool {
        let primary = Set(exercise.resolvedMuscleProfile.primary)
        let areaMatch = bodyAreas.isEmpty || bodyAreas.contains { area in
            switch area {
            case .upperBody:
                return !primary.isDisjoint(with: [.neck, .upperChest, .chest, .lowerChest, .frontDelts, .sideDelts, .rearDelts, .biceps, .triceps, .forearms, .traps, .upperBack, .lats])
            case .lowerBody:
                return !primary.isDisjoint(with: [.glutes, .adductors, .quads, .hamstrings, .calves, .tibialis])
            case .core:
                return !primary.isDisjoint(with: [.abs, .obliques, .spinalErectors])
            case .fullBody:
                return primary.contains(.fullBody)
            }
        }
        return areaMatch &&
            (primaryMuscles.isEmpty || !primary.isDisjoint(with: primaryMuscles)) &&
            (equipment.isEmpty || equipment.contains(exercise.equipment)) &&
            (movementTypes.isEmpty || movementTypes.contains(exercise.movementType)) &&
            (trackingTypes.isEmpty || trackingTypes.contains(exercise.trackingType))
    }

    mutating func clear(category: ExerciseLibraryFilterCategory) {
        switch category {
        case .bodyAreas: bodyAreas.removeAll()
        case .primaryMuscles: primaryMuscles.removeAll()
        case .equipment: equipment.removeAll()
        case .movementTypes: movementTypes.removeAll()
        case .trackingTypes: trackingTypes.removeAll()
        }
    }

    private func summary(_ label: String, values: [String]) -> String {
        let sorted = values.sorted()
        guard let first = sorted.first else { return label }
        return sorted.count == 1 ? first : "\(label): \(first) +\(sorted.count - 1)"
    }
}

struct ExerciseLibraryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var applied: ExerciseLibraryFilterSelection
    let exercises: [TrainingExerciseCatalogItem]
    let searchText: String
    @State private var draft: ExerciseLibraryFilterSelection

    init(applied: Binding<ExerciseLibraryFilterSelection>, exercises: [TrainingExerciseCatalogItem], searchText: String) {
        _applied = applied
        self.exercises = exercises
        self.searchText = searchText
        _draft = State(initialValue: applied.wrappedValue)
    }

    private var equipmentOptions: [String] { Set(exercises.map(\.equipment)).sorted() }
    private var movementOptions: [String] { Set(exercises.map(\.movementType)).sorted() }
    private var trackingOptions: [String] { Set(exercises.map(\.trackingType)).sorted() }
    private var resultCount: Int {
        exercises.filter { $0.matchesSearch(searchText) && draft.matches($0) }.count
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            bodyAreaSection
                            muscleSection
                            stringSection("Equipment", options: equipmentOptions, selection: $draft.equipment)
                            stringSection("Movement type", options: movementOptions, selection: $draft.movementTypes)
                            stringSection("Tracking type", options: trackingOptions, selection: $draft.trackingTypes)
                        }
                        .padding(16)
                        .padding(.bottom, 90)
                    }
                    .scrollIndicators(.hidden)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 10) {
                        Button("Show \(resultCount) Exercises") {
                            applied = draft
                            dismiss()
                        }
                        .buttonStyle(LiftPrimaryButtonStyle())
                        Button("Reset filters") {
                            draft = ExerciseLibraryFilterSelection()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                        .frame(minHeight: 44)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Exercise Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applied = draft
                        dismiss()
                    }
                }
            }
        }
    }

    private var bodyAreaSection: some View {
        filterSectionTitle("Body area") {
            ForEach(ExerciseLibraryBodyArea.allCases) { area in
                filterToggle(area.rawValue, selected: draft.bodyAreas.contains(area)) {
                    toggle(area, in: &draft.bodyAreas)
                }
            }
        }
    }

    private var muscleSection: some View {
        filterSectionTitle("Primary muscle") {
            ForEach(ExerciseMuscleRegion.allCases.filter { $0 != .fullBody }) { muscle in
                filterToggle(muscle.displayName, selected: draft.primaryMuscles.contains(muscle)) {
                    toggle(muscle, in: &draft.primaryMuscles)
                }
            }
        }
    }

    private func stringSection(_ title: String, options: [String], selection: Binding<Set<String>>) -> some View {
        filterSectionTitle(title) {
            ForEach(options, id: \.self) { option in
                filterToggle(option, selected: selection.wrappedValue.contains(option)) {
                    var updated = selection.wrappedValue
                    if updated.contains(option) { updated.remove(option) } else { updated.insert(option) }
                    selection.wrappedValue = updated
                }
            }
        }
    }

    private func filterSectionTitle<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                content()
            }
        }
    }

    private func filterToggle(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).lineLimit(1)
                if selected { Image(systemName: "checkmark") }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(selected ? .white : Color.liftMuted)
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(selected ? Color.liftBlue : Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

struct ProgramFilterMenu: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) { selection = option }
            }
        } label: {
            HStack {
                Text(selection == "All" ? title : selection)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.liftBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.liftBlue.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct ExerciseCatalogIcon: View {
    let exercise: TrainingExerciseCatalogItem

    var body: some View {
        ExerciseMuscleMap(profile: exercise.resolvedMuscleProfile)
        .frame(width: 54, height: 54)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let profile = exercise.resolvedMuscleProfile
        let secondary = profile.secondary.isEmpty ? "" : "; assisting \(profile.secondaryDescription)"
        return "\(exercise.name); primary muscles \(profile.primaryDescription)\(secondary)"
    }
}

struct ExerciseLibraryDetailView: View {
    @EnvironmentObject private var appState: AppState
    let exercise: TrainingExerciseCatalogItem

    private var profile: ExerciseMuscleProfile { exercise.resolvedMuscleProfile }
    private var splitProfile: ExerciseMuscleProfile {
        ExerciseMuscleProfile(primary: profile.primary, secondary: profile.secondary, orientation: .split)
    }
    private var substitutes: [ExerciseSubstitutionRecommendation] {
        appState.substitutionRecommendations(for: exercise, limit: 5)
    }
    private var demoMediaID: String? {
        exercise.demonstrationMediaID
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let demoMediaID {
                        DemoMediaCard(
                            title: exercise.name,
                            subtitle: "\(exercise.equipment) • \(exercise.movementPattern.rawValue)",
                            mediaID: demoMediaID,
                            badge: "Exercise Demo"
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ExerciseMuscleMap(profile: splitProfile)
                            .frame(height: 270)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(anatomyAccessibilityLabel)

                        HStack(spacing: 8) {
                            anatomyLegend("Primary", color: Color.liftBlue)
                            if !profile.secondary.isEmpty {
                                anatomyLegend("Secondary", color: Color.liftBlue.opacity(0.38))
                            }
                            anatomyLegend("Unaffected", color: Color.liftMuted.opacity(0.45))
                        }
                    }
                    .padding(14)
                    .liftSurface()

                    VStack(alignment: .leading, spacing: 14) {
                        muscleList(title: "Primary muscles", muscles: profile.primary, color: Color.liftBlue)
                        if !profile.secondary.isEmpty {
                            Divider().overlay(Color.white.opacity(0.07))
                            muscleList(title: "Secondary muscles", muscles: profile.secondary, color: Color.liftBlue.opacity(0.58))
                        }
                    }
                    .padding(14)
                    .liftSurface()

                    VStack(spacing: 0) {
                        detailRow("Equipment", exercise.equipment)
                        Divider().overlay(Color.white.opacity(0.07))
                        detailRow("Movement", exercise.movementType)
                        Divider().overlay(Color.white.opacity(0.07))
                        detailRow("Pattern", exercise.movementPattern.rawValue)
                        Divider().overlay(Color.white.opacity(0.07))
                        detailRow("Difficulty", exercise.difficulty.title)
                        Divider().overlay(Color.white.opacity(0.07))
                        detailRow("Tracking", exercise.trackingType)
                        Divider().overlay(Color.white.opacity(0.07))
                        detailRow("Default prescription", "\(exercise.defaultSets) sets × \(exercise.defaultReps)")
                    }
                    .padding(.horizontal, 14)
                    .liftSurface()

                    if !substitutes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Find a substitute")
                                .font(.headline.weight(.bold))
                            ForEach(substitutes) { recommendation in
                                HStack(spacing: 12) {
                                    ExerciseCatalogIcon(exercise: recommendation.exercise)
                                        .frame(width: 40, height: 40)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(recommendation.exercise.name)
                                            .font(.subheadline.weight(.bold))
                                        Text(recommendation.reasons.joined(separator: " • "))
                                            .font(.caption)
                                            .foregroundStyle(Color.liftMuted)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(14)
                        .liftSurface()
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var anatomyAccessibilityLabel: String {
        let secondary = profile.secondary.isEmpty ? "" : "; secondary muscles \(profile.secondaryDescription)"
        return "Front and back muscle map. Primary muscles \(profile.primaryDescription)\(secondary)."
    }

    private func anatomyLegend(_ title: String, color: Color) -> some View {
        Label {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
        } icon: {
            Circle().fill(color).frame(width: 8, height: 8)
        }
    }

    private func muscleList(title: String, muscles: [ExerciseMuscleRegion], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.headline.weight(.bold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 7)], alignment: .leading, spacing: 7) {
                ForEach(muscles) { muscle in
                    Text(muscle.displayName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 50)
    }
}

struct ExerciseMuscleMap: View {
    let profile: ExerciseMuscleProfile

    var body: some View {
        GeometryReader { geometry in
            let showsLabels = geometry.size.width >= 150 && geometry.size.height >= 140
            let isCompact = geometry.size.width < 90 || geometry.size.height < 90
            ZStack {
                RoundedRectangle(cornerRadius: min(14, geometry.size.height * 0.22), style: .continuous)
                    .fill(Color.liftBlue.opacity(0.075))
                    .overlay {
                        RoundedRectangle(cornerRadius: min(14, geometry.size.height * 0.22), style: .continuous)
                            .stroke(Color.liftBlue.opacity(0.12), lineWidth: 1)
                    }

                VStack(spacing: showsLabels ? 5 : 0) {
                    HStack(spacing: geometry.size.width * 0.025) {
                        if isCompact && compactOrientation == .front {
                            AnatomicalMuscleFigure(profile: profile, side: .front)
                        } else if isCompact {
                            AnatomicalMuscleFigure(profile: profile, side: .back)
                        } else {
                            if profile.orientation == .front || profile.orientation == .split {
                                AnatomicalMuscleFigure(profile: profile, side: .front)
                            }
                            if profile.orientation == .back || profile.orientation == .split {
                                AnatomicalMuscleFigure(profile: profile, side: .back)
                            }
                        }
                    }
                    if showsLabels {
                        HStack(spacing: 4) {
                            if profile.orientation == .front || profile.orientation == .split {
                                orientationLabel("FRONT")
                            }
                            if profile.orientation == .back || profile.orientation == .split {
                                orientationLabel("BACK")
                            }
                        }
                    }
                }
                .padding(.horizontal, geometry.size.height * 0.065)
                .padding(.vertical, geometry.size.height * 0.045)
            }
        }
    }

    private var compactOrientation: ExerciseMuscleMapOrientation {
        guard profile.orientation == .split else { return profile.orientation }
        let active = profile.primary.filter { $0 != .fullBody }
        let backCount = active.filter(\.isBackFacing).count
        return backCount > active.count - backCount ? .back : .front
    }

    private func orientationLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(Color.liftMuted)
            .frame(maxWidth: .infinity)
    }
}

private struct AnatomicalMuscleFigure: View {
    enum Side { case front, back }
    let profile: ExerciseMuscleProfile
    let side: Side

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let wholeBody = profile.primary.contains(.fullBody)
            let bodyFill = Color(red: 0.27, green: 0.30, blue: 0.39)
            let bodyOutline = Color.white.opacity(0.16)
            let segmentFill = Color(red: 0.32, green: 0.35, blue: 0.45)
            let segmentOutline = Color.white.opacity(0.13)
            let lineWidth = max(0.45, min(size.width, size.height) * 0.018)

            for path in bodyPaths(in: size) {
                context.fill(path, with: .color(bodyFill))
                context.stroke(path, with: .color(bodyOutline), lineWidth: lineWidth)
            }

            // Establish the complete anatomy before applying exercise-specific color.
            // This keeps unworked muscles visible instead of leaving a flat silhouette.
            draw(
                visibleMuscleSegments,
                color: segmentFill,
                outline: segmentOutline,
                in: &context,
                size: size,
                lineWidth: lineWidth * 0.58
            )

            draw(
                profile.secondary.filter(isVisible),
                color: Color(red: 0.25, green: 0.49, blue: 0.95).opacity(0.62),
                outline: Color.liftBlue.opacity(0.45),
                in: &context,
                size: size,
                lineWidth: lineWidth * 0.65
            )
            draw(
                wholeBody ? visibleMuscleSegments : profile.primary.filter(isVisible),
                color: Color(red: 0.14, green: 0.38, blue: 1.0),
                outline: Color(red: 0.42, green: 0.64, blue: 1.0),
                in: &context,
                size: size,
                lineWidth: lineWidth * 0.85
            )

            // Redraw every boundary last so neutral and highlighted regions retain
            // the same anatomical segmentation at compact and expanded sizes.
            strokeMuscleSegments(
                visibleMuscleSegments,
                color: Color.white.opacity(0.13),
                in: &context,
                size: size,
                lineWidth: lineWidth * 0.48
            )

            let centerLine = centerAnatomyLine(in: size)
            context.stroke(centerLine, with: .color(Color.black.opacity(0.20)), lineWidth: lineWidth * 0.55)
            for landmark in anatomicalLandmarkPaths(in: size) {
                context.stroke(landmark, with: .color(Color.black.opacity(0.16)), lineWidth: lineWidth * 0.48)
            }
        }
        .aspectRatio(0.48, contentMode: .fit)
    }

    private var visibleMuscleSegments: [ExerciseMuscleRegion] {
        switch side {
        case .front:
            [
                .neck, .upperChest, .chest, .lowerChest,
                .frontDelts, .sideDelts, .biceps, .forearms,
                .abs, .obliques, .adductors, .quads, .tibialis
            ]
        case .back:
            [
                .neck, .traps, .rearDelts, .triceps, .forearms,
                .upperBack, .lats, .spinalErectors, .glutes,
                .hamstrings, .calves
            ]
        }
    }

    private func draw(
        _ regions: [ExerciseMuscleRegion],
        color: Color,
        outline: Color,
        in context: inout GraphicsContext,
        size: CGSize,
        lineWidth: CGFloat
    ) {
        for region in regions {
            for path in musclePaths(for: region, in: size) {
                context.fill(path, with: .color(color))
                context.stroke(path, with: .color(outline), lineWidth: lineWidth)
            }
        }
    }

    private func strokeMuscleSegments(
        _ regions: [ExerciseMuscleRegion],
        color: Color,
        in context: inout GraphicsContext,
        size: CGSize,
        lineWidth: CGFloat
    ) {
        for region in regions {
            for path in musclePaths(for: region, in: size) {
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }
        }
    }

    private func isVisible(_ region: ExerciseMuscleRegion) -> Bool {
        if region == .fullBody { return true }
        return side == .back ? region.isBackFacing : !region.isBackFacing
    }

    private func bodyPaths(in size: CGSize) -> [Path] {
        let leftArm: [(CGFloat, CGFloat)] = [
            (0.27, 0.23), (0.17, 0.25), (0.11, 0.36), (0.08, 0.51),
            (0.10, 0.60), (0.15, 0.61), (0.19, 0.53), (0.22, 0.39), (0.31, 0.29)
        ]
        let leftLeg: [(CGFloat, CGFloat)] = [
            (0.29, 0.56), (0.49, 0.58), (0.47, 0.75), (0.43, 0.96),
            (0.36, 0.99), (0.32, 0.94), (0.31, 0.78), (0.25, 0.64)
        ]

        var torso = Path()
        torso.move(to: point(0.42, 0.17, size))
        torso.addCurve(to: point(0.19, 0.25, size), control1: point(0.38, 0.20, size), control2: point(0.25, 0.20, size))
        torso.addCurve(to: point(0.29, 0.52, size), control1: point(0.22, 0.35, size), control2: point(0.25, 0.45, size))
        torso.addCurve(to: point(0.26, 0.62, size), control1: point(0.30, 0.56, size), control2: point(0.27, 0.59, size))
        torso.addCurve(to: point(0.50, 0.67, size), control1: point(0.34, 0.65, size), control2: point(0.42, 0.67, size))
        torso.addCurve(to: point(0.74, 0.62, size), control1: point(0.58, 0.67, size), control2: point(0.66, 0.65, size))
        torso.addCurve(to: point(0.71, 0.52, size), control1: point(0.73, 0.59, size), control2: point(0.70, 0.56, size))
        torso.addCurve(to: point(0.81, 0.25, size), control1: point(0.75, 0.45, size), control2: point(0.78, 0.35, size))
        torso.addCurve(to: point(0.58, 0.17, size), control1: point(0.75, 0.20, size), control2: point(0.62, 0.20, size))
        torso.closeSubpath()

        return [
            ellipse(0.36, 0.015, 0.28, 0.145, size),
            roundedRect(0.42, 0.145, 0.16, 0.10, radius: 0.035, size),
            torso,
            polygon(leftArm, size),
            polygon(mirrored(leftArm), size),
            polygon(leftLeg, size),
            polygon(mirrored(leftLeg), size)
        ]
    }

    private func musclePaths(for region: ExerciseMuscleRegion, in size: CGSize) -> [Path] {
        switch region {
        case .neck:
            return [roundedRect(0.435, 0.155, 0.13, 0.075, radius: 0.025, size)]
        case .upperChest:
            return pairedPolygons([(0.30, 0.265), (0.48, 0.245), (0.48, 0.305), (0.31, 0.32)], size)
        case .chest:
            return pairedPolygons([(0.28, 0.275), (0.48, 0.26), (0.48, 0.39), (0.31, 0.37)], size)
        case .lowerChest:
            return pairedPolygons([(0.31, 0.345), (0.48, 0.355), (0.48, 0.405), (0.33, 0.395)], size)
        case .frontDelts, .rearDelts:
            return [ellipse(0.185, 0.235, 0.155, 0.12, size), ellipse(0.66, 0.235, 0.155, 0.12, size)]
        case .sideDelts:
            return [ellipse(0.17, 0.245, 0.13, 0.13, size), ellipse(0.70, 0.245, 0.13, 0.13, size)]
        case .biceps, .triceps:
            return pairedPolygonGroups([
                [(0.16, 0.32), (0.23, 0.33), (0.205, 0.405), (0.14, 0.41), (0.12, 0.37)],
                [(0.14, 0.405), (0.205, 0.40), (0.20, 0.46), (0.13, 0.47), (0.115, 0.435)]
            ], size)
        case .forearms:
            return pairedPolygonGroups([
                [(0.13, 0.44), (0.17, 0.445), (0.145, 0.58), (0.10, 0.58)],
                [(0.17, 0.445), (0.20, 0.45), (0.16, 0.58), (0.145, 0.58)]
            ], size)
        case .traps:
            return [polygon([(0.40, 0.19), (0.50, 0.23), (0.60, 0.19), (0.68, 0.30), (0.32, 0.30)], size)]
        case .upperBack:
            return pairedPolygons([(0.27, 0.29), (0.48, 0.27), (0.48, 0.40), (0.31, 0.39)], size)
        case .lats:
            return pairedPolygons([(0.27, 0.34), (0.43, 0.38), (0.39, 0.54), (0.31, 0.50)], size)
        case .spinalErectors:
            return [
                roundedRect(0.44, 0.35, 0.045, 0.22, radius: 0.02, size),
                roundedRect(0.515, 0.35, 0.045, 0.22, radius: 0.02, size)
            ]
        case .abs:
            return abdominalPaths(in: size)
        case .obliques:
            return pairedPolygons([(0.30, 0.39), (0.39, 0.40), (0.40, 0.55), (0.32, 0.54)], size)
        case .glutes:
            return [ellipse(0.30, 0.55, 0.20, 0.13, size), ellipse(0.50, 0.55, 0.20, 0.13, size)]
        case .adductors:
            return pairedPolygons([(0.40, 0.64), (0.48, 0.63), (0.44, 0.80), (0.38, 0.79)], size)
        case .quads:
            return pairedPolygonGroups([
                [(0.285, 0.64), (0.355, 0.64), (0.36, 0.77), (0.335, 0.82), (0.30, 0.76)],
                [(0.355, 0.64), (0.41, 0.635), (0.405, 0.79), (0.36, 0.80)],
                [(0.41, 0.635), (0.455, 0.63), (0.435, 0.78), (0.405, 0.79)]
            ], size)
        case .hamstrings:
            return pairedPolygonGroups([
                [(0.29, 0.64), (0.37, 0.635), (0.375, 0.80), (0.34, 0.82), (0.30, 0.75)],
                [(0.37, 0.635), (0.455, 0.63), (0.43, 0.80), (0.375, 0.80)]
            ], size)
        case .calves:
            return pairedPolygonGroups([
                [(0.33, 0.80), (0.38, 0.80), (0.38, 0.92), (0.355, 0.95), (0.33, 0.91)],
                [(0.38, 0.80), (0.43, 0.80), (0.42, 0.94), (0.38, 0.92)]
            ], size)
        case .tibialis:
            return pairedPolygons([(0.35, 0.81), (0.40, 0.80), (0.40, 0.95), (0.36, 0.94)], size)
        case .fullBody:
            return []
        }
    }

    private func abdominalPaths(in size: CGSize) -> [Path] {
        var paths: [Path] = []
        for row in 0..<3 {
            let y = 0.385 + CGFloat(row) * 0.057
            paths.append(roundedRect(0.415, y, 0.075, 0.048, radius: 0.015, size))
            paths.append(roundedRect(0.510, y, 0.075, 0.048, radius: 0.015, size))
        }
        return paths
    }

    private func centerAnatomyLine(in size: CGSize) -> Path {
        var path = Path()
        path.move(to: point(0.50, side == .front ? 0.25 : 0.29, size))
        path.addLine(to: point(0.50, 0.61, size))
        return path
    }

    private func anatomicalLandmarkPaths(in size: CGSize) -> [Path] {
        var shoulderLine = Path()
        shoulderLine.move(to: point(0.31, 0.27, size))
        if side == .front {
            shoulderLine.addQuadCurve(to: point(0.50, 0.25, size), control: point(0.41, 0.24, size))
            shoulderLine.addQuadCurve(to: point(0.69, 0.27, size), control: point(0.59, 0.24, size))
        } else {
            shoulderLine.addQuadCurve(to: point(0.50, 0.34, size), control: point(0.40, 0.31, size))
            shoulderLine.addQuadCurve(to: point(0.69, 0.27, size), control: point(0.60, 0.31, size))
        }

        var pelvis = Path()
        pelvis.move(to: point(0.29, 0.58, size))
        pelvis.addQuadCurve(to: point(0.50, 0.63, size), control: point(0.39, 0.61, size))
        pelvis.addQuadCurve(to: point(0.71, 0.58, size), control: point(0.61, 0.61, size))

        var joints = Path()
        let jointLines: [(CGFloat, CGFloat, CGFloat)] = [
            (0.105, 0.195, 0.455), (0.805, 0.895, 0.455),
            (0.315, 0.445, 0.80), (0.555, 0.685, 0.80)
        ]
        for (x1, x2, y) in jointLines {
            joints.move(to: point(x1, y, size))
            joints.addLine(to: point(x2, y, size))
        }

        return [shoulderLine, pelvis, joints]
    }

    private func pairedPolygons(_ left: [(CGFloat, CGFloat)], _ size: CGSize) -> [Path] {
        [polygon(left, size), polygon(mirrored(left), size)]
    }

    private func pairedPolygonGroups(
        _ leftGroups: [[(CGFloat, CGFloat)]],
        _ size: CGSize
    ) -> [Path] {
        leftGroups.flatMap { pairedPolygons($0, size) }
    }

    private func mirrored(_ points: [(CGFloat, CGFloat)]) -> [(CGFloat, CGFloat)] {
        points.map { (1 - $0.0, $0.1) }
    }

    private func point(_ x: CGFloat, _ y: CGFloat, _ size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }

    private func polygon(_ points: [(CGFloat, CGFloat)], _ size: CGSize) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: point(first.0, first.1, size))
        for coordinate in points.dropFirst() {
            path.addLine(to: point(coordinate.0, coordinate.1, size))
        }
        path.closeSubpath()
        return path
    }

    private func ellipse(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ size: CGSize) -> Path {
        Path(ellipseIn: CGRect(x: x * size.width, y: y * size.height, width: width * size.width, height: height * size.height))
    }

    private func roundedRect(
        _ x: CGFloat,
        _ y: CGFloat,
        _ width: CGFloat,
        _ height: CGFloat,
        radius: CGFloat,
        _ size: CGSize
    ) -> Path {
        Path(
            roundedRect: CGRect(x: x * size.width, y: y * size.height, width: width * size.width, height: height * size.height),
            cornerRadius: radius * min(size.width, size.height)
        )
    }
}

struct CreateCustomExerciseView: View {
    @EnvironmentObject private var appState: AppState
    let session: WorkoutSession
    let onAdded: () -> Void
    @State private var name = ""
    @State private var muscleGroup = "Chest"
    @State private var equipment = "Dumbbell"
    @State private var trackingType = "Weight + Reps"
    @State private var createdExercise: TrainingExerciseCatalogItem?

    private let muscleGroups = ["Chest", "Back", "Shoulders", "Arms", "Quads", "Hamstrings", "Glutes", "Core", "Full Body"]
    private let equipmentOptions = ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Kettlebell", "Band"]
    private let trackingTypes = ["Weight + Reps", "Reps Only", "Time"]

    var body: some View {
        AppBackground {
            Form {
                Section("Exercise") {
                    TextField("Exercise name", text: $name)
                    Picker("Muscle group", selection: $muscleGroup) {
                        ForEach(muscleGroups, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(equipmentOptions, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Tracking") {
                    ForEach(trackingTypes, id: \.self) { option in
                        ProgramChoiceRow(title: option, isSelected: trackingType == option) {
                            trackingType = option
                        }
                    }
                }

                Section {
                    Button("Save Exercise") {
                        createdExercise = appState.saveCustomExercise(
                            name: name,
                            bodyPart: muscleGroup,
                            equipment: equipment,
                            trackingType: trackingType
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Create Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $createdExercise) { exercise in
            AddExerciseToWorkoutView(exercise: exercise, session: session, onAdded: onAdded)
                .environmentObject(appState)
        }
    }
}

struct AddExerciseToWorkoutView: View {
    @EnvironmentObject private var appState: AppState
    let exercise: TrainingExerciseCatalogItem
    let session: WorkoutSession
    let onAdded: () -> Void
    @State private var sets = 3
    @State private var repGoal = "8-12"
    @State private var restSeconds = 120

    private let repGoals = ["1-5", "6-8", "8-12", "12-15", "15-20"]
    private let restOptions = [60, 90, 120, 180]

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        ExerciseCatalogIcon(exercise: exercise)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name).font(.title3.bold())
                            Text("\(exercise.bodyPart) • \(exercise.equipment)")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                    .padding(14)
                    .liftSurface()

                    VStack(alignment: .leading, spacing: 16) {
                        IntegerInputField(title: "Sets", value: $sets, presentation: .inset)
                        Text("Rep goal").font(.headline)
                        FlowChipGroup(options: repGoals, selected: $repGoal)
                        Text("Rest time").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], spacing: 8) {
                            ForEach(restOptions, id: \.self) { seconds in
                                ProgramChoiceChip(title: "\(seconds) sec", isSelected: restSeconds == seconds) {
                                    restSeconds = seconds
                                }
                            }
                        }
                    }
                    .padding(14)
                    .liftSurface()

                    Button("Add to Workout") {
                        appState.addExercise(exercise, to: session, sets: sets, reps: repGoal, restSeconds: restSeconds)
                        onAdded()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liftBlue)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                }
                .padding(16)
            }
        }
        .navigationTitle("Configure Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sets = exercise.defaultSets
            if repGoals.contains(exercise.defaultReps) { repGoal = exercise.defaultReps }
            restSeconds = exercise.defaultRestSeconds
        }
    }
}

struct ProgramChoiceRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.headline).foregroundStyle(.white)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.liftBlue : Color.liftMuted)
            }
            .padding(13)
            .background(isSelected ? Color.liftBlue.opacity(0.18) : Color.black.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}

struct FlowChipGroup: View {
    let options: [String]
    @Binding var selected: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                ProgramChoiceChip(title: option, isSelected: selected == option) {
                    selected = option
                }
            }
        }
    }
}

struct ProgramChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Color.liftMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.liftBlue : Color.black.opacity(0.18))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ProgramAddExercisePickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    @State private var searchText = ""
    @State private var selectedBodyPart = "All"
    @State private var selectedEquipment = "All"
    @State private var selectedExerciseIDs: Set<String> = []
    @State private var previewExercise: TrainingExerciseCatalogItem?

    private let bodyPartFilters = ["All", "Chest", "Back", "Shoulders", "Arms", "Legs", "Glutes", "Core"]

    private var equipmentFilters: [String] {
        ["All"] + Array(Set(appState.trainingExerciseLibrary.map(\.equipment))).sorted()
    }

    private var existingExerciseIDs: Set<String> {
        Set(appState.prescriptions(for: session).map(\.exerciseID))
    }

    private var filteredExercises: [ExerciseSearchResult] {
        appState.searchExercises(query: searchText)
            .filter { selectedBodyPart == "All" || matchesBodyPart($0.exercise, filter: selectedBodyPart) }
            .filter { selectedEquipment == "All" || $0.exercise.equipment == selectedEquipment }
            .sorted { lhs, rhs in
                let lhsExists = existingExerciseIDs.contains(lhs.exercise.id)
                let rhsExists = existingExerciseIDs.contains(rhs.exercise.id)
                if lhsExists != rhsExists { return !lhsExists }
                if lhs.score == rhs.score { return lhs.exercise.name < rhs.exercise.name }
                return lhs.score > rhs.score
            }
    }

    private var selectedExercises: [TrainingExerciseCatalogItem] {
        appState.trainingExerciseLibrary
            .filter { selectedExerciseIDs.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        searchField
                        filterBar
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Text("\(filteredExercises.count) exercises")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                                Spacer()
                                if !selectedExerciseIDs.isEmpty {
                                    Text("\(selectedExerciseIDs.count) selected")
                                        .font(.caption.weight(.black))
                                        .foregroundStyle(Color.liftBlue)
                                }
                            }
                            .padding(.horizontal, 4)

                            if filteredExercises.isEmpty {
                                emptyResults
                            } else {
                                ForEach(filteredExercises) { result in
                                    exerciseRow(result)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 110)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollIndicators(.hidden)
                }
                .safeAreaInset(edge: .bottom) {
                    bottomActionBar
                }
            }
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink {
                        CreateCustomExerciseView(session: session) {
                            dismiss()
                        }
                        .environmentObject(appState)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create custom exercise")
                }
            }
            .navigationDestination(item: $previewExercise) { exercise in
                AddExerciseToWorkoutView(exercise: exercise, session: session) {
                    dismiss()
                }
                .environmentObject(appState)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.liftMuted)
            TextField("Search exercises", text: $searchText)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.liftMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 46)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(bodyPartFilters, id: \.self) { filter in
                    filterChip(filter, isSelected: selectedBodyPart == filter) {
                        selectedBodyPart = filter
                    }
                }

                Menu {
                    ForEach(equipmentFilters, id: \.self) { equipment in
                        Button(equipment) { selectedEquipment = equipment }
                    }
                } label: {
                    Label(selectedEquipment == "All" ? "Equipment" : selectedEquipment, systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(selectedEquipment == "All" ? Color.liftCard : Color.liftBlue.opacity(0.18))
                        .foregroundStyle(selectedEquipment == "All" ? Color.liftMuted : Color.liftBlue)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isSelected ? Color.liftBlue : Color.liftCard)
                .foregroundStyle(isSelected ? Color.liftBackground : Color.liftMuted)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func exerciseRow(_ result: ExerciseSearchResult) -> some View {
        let exercise = result.exercise
        let isExisting = existingExerciseIDs.contains(exercise.id)
        let isSelected = selectedExerciseIDs.contains(exercise.id)

        return HStack(spacing: 12) {
            ExerciseCatalogIcon(exercise: exercise)
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                if let reason = result.reasonLabel {
                    Text(reason)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                }
                Text("\(exercise.bodyPart) • \(exercise.equipment)")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                Text("\(exercise.defaultSets) sets × \(exercise.defaultReps)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.liftBlue)
            }
            Spacer()

            Button {
                previewExercise = exercise
            } label: {
                Image(systemName: "info.circle")
                    .font(.headline)
                    .foregroundStyle(Color.liftMuted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview and configure \(exercise.name)")

            Button {
                toggleSelection(exercise)
            } label: {
                Image(systemName: isExisting || isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(isExisting ? Color.liftGreen : isSelected ? Color.liftBlue : Color.liftMuted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isExisting)
            .accessibilityLabel(isExisting ? "Already in workout" : isSelected ? "Remove \(exercise.name) from selection" : "Select \(exercise.name)")
        }
        .padding(11)
        .background(isSelected ? Color.liftBlue.opacity(0.09) : Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(isSelected ? Color.liftBlue.opacity(0.45) : Color.white.opacity(0.05), lineWidth: 1)
        }
        .opacity(isExisting ? 0.62 : 1)
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            NavigationLink {
                CreateCustomExerciseView(session: session) {
                    dismiss()
                }
                .environmentObject(appState)
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 50, height: 50)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.liftBlue)
            .accessibilityLabel("Create custom exercise")

            Button {
                appState.addExercises(selectedExercises, to: session)
                dismiss()
            } label: {
                HStack {
                    Text(selectedExerciseIDs.isEmpty ? "Select exercises" : "Add \(selectedExerciseIDs.count) to workout")
                        .font(.headline.weight(.black))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(selectedExerciseIDs.isEmpty ? Color.liftMuted : Color.liftBackground)
                .padding(.horizontal, 17)
                .frame(height: 50)
                .background(selectedExerciseIDs.isEmpty ? Color.liftCard : Color.liftBlue)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedExerciseIDs.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var emptyResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(Color.liftBlue)
            Text("No exercises found")
                .font(.headline)
            Text("Try another search or clear a filter.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func toggleSelection(_ exercise: TrainingExerciseCatalogItem) {
        if selectedExerciseIDs.contains(exercise.id) {
            selectedExerciseIDs.remove(exercise.id)
        } else {
            selectedExerciseIDs.insert(exercise.id)
        }
        Haptics.light()
    }

    private func matchesBodyPart(_ exercise: TrainingExerciseCatalogItem, filter: String) -> Bool {
        let bodyPart = exercise.bodyPart.lowercased()
        switch filter {
        case "Back":
            return bodyPart.contains("back") || bodyPart.contains("lat") || bodyPart.contains("trap")
        case "Shoulders":
            return bodyPart.contains("shoulder") || bodyPart.contains("delt") || bodyPart.contains("rotator")
        case "Arms":
            return bodyPart.contains("bicep") || bodyPart.contains("tricep") || bodyPart.contains("arm") || bodyPart.contains("forearm")
        case "Legs":
            return bodyPart.contains("quad") || bodyPart.contains("hamstring") || bodyPart.contains("leg") || bodyPart.contains("calf") || bodyPart.contains("adductor") || bodyPart.contains("tibialis")
        case "Core":
            return bodyPart.contains("core") || bodyPart.contains("oblique")
        default: return bodyPart.contains(filter.lowercased())
        }
    }
}

struct ActiveWorkoutAddExercisePickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedIDs: Set<String> = []

    private var existingIDs: Set<String> {
        Set(appState.activeWorkout?.exercises.map(\.exerciseID) ?? [])
    }

    private var results: [ExerciseSearchResult] {
        appState.searchExercises(query: searchText)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.liftMuted)
                        TextField("Search exercises", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 46)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(16)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { result in
                                let exercise = result.exercise
                                let isExisting = existingIDs.contains(exercise.id)
                                let isSelected = selectedIDs.contains(exercise.id)
                                Button {
                                    guard !isExisting else { return }
                                    if isSelected { selectedIDs.remove(exercise.id) }
                                    else { selectedIDs.insert(exercise.id) }
                                } label: {
                                    HStack(spacing: 12) {
                                        ExerciseCatalogIcon(exercise: exercise)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(exercise.name)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.white)
                                            if let reason = result.reasonLabel {
                                                Text(reason)
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(Color.liftBlue)
                                            }
                                            Text("\(exercise.bodyPart) • \(exercise.equipment) • \(exercise.defaultSets) × \(exercise.defaultReps)")
                                                .font(.caption)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                        Spacer()
                                        Image(systemName: isExisting || isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(isExisting ? Color.liftGreen : isSelected ? Color.liftBlue : Color.liftMuted)
                                    }
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isExisting)

                                Divider().overlay(Color.white.opacity(0.06))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selectedIDs.isEmpty ? "Add" : "Add \(selectedIDs.count)") {
                        let selected = appState.trainingExerciseLibrary.filter { selectedIDs.contains($0.id) }
                        appState.addExercisesToActiveWorkout(selected)
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }
}

struct WorkoutSessionRunView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showingSummary = false
    @State private var showingAddExercise = false
    @State private var showingCancelConfirmation = false
    @State private var showingFinishConfirmation = false
    @State private var finishValidationMessage: String?
    @State private var isReorderingExercises = false

    private var workout: ActiveWorkoutState? { appState.activeWorkout }
    private var exercises: [WorkoutExerciseSnapshot] { workout?.exercises.sorted { $0.order < $1.order } ?? [] }
    private var completedSetCount: Int { appState.activeWorkoutCompletedWorkingSets.count }
    private var plannedSetCount: Int { exercises.reduce(0) { $0 + $1.targetSets } }

    var body: some View {
        NavigationStack {
            AppBackground {
                if let workout {
                    VStack(spacing: 0) {
                        activeHeader(workout)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if exercises.isEmpty {
                                    emptyCard
                                } else {
                                    HStack {
                                        Text("Exercises")
                                            .font(.title3.weight(.black))
                                        Spacer()
                                        if isReorderingExercises {
                                            Text("Reorder mode")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(Color.liftBlue)
                                        }
                                        Text("\(completedSetCount)/\(plannedSetCount) working sets")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.liftMuted)
                                    }

                                    ForEach(exercises) { exercise in
                                        NavigationLink {
                                            PrescriptionTrackView(exercise: exercise)
                                                .environmentObject(appState)
                                        } label: {
                                            exerciseCard(exercise)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button {
                                                _ = appState.moveActiveWorkoutExercise(exercise, direction: -1)
                                            } label: {
                                                Label("Move Up", systemImage: "arrow.up")
                                            }
                                            Button {
                                                _ = appState.moveActiveWorkoutExercise(exercise, direction: 1)
                                            } label: {
                                                Label("Move Down", systemImage: "arrow.down")
                                            }
                                            Button(role: .destructive) {
                                                if appState.activeWorkout?.restTimerExerciseID == exercise.id {
                                                    WorkoutRestNotificationScheduler.cancel()
                                                }
                                                appState.removeExerciseFromActiveWorkout(exercise)
                                            } label: {
                                                Label("Remove from this workout", systemImage: "trash")
                                            }
                                        }
                                    }
                                }

                                if let finishValidationMessage {
                                    Label(finishValidationMessage, systemImage: "exclamationmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.liftRed)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 18)
                            .padding(.bottom, 20)
                        }
                        .scrollIndicators(.hidden)
                        workoutControls
                    }
                } else {
                    LiftEmptyState(
                        title: "Workout saved",
                        message: "Your active workout is no longer available.",
                        symbolName: "checkmark.circle.fill",
                        actionTitle: "Return to Track"
                    ) { dismiss() }
                    .padding()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSummary) {
                if let summary = appState.activeWorkoutSummary() {
                    WorkoutSummaryView(
                        summary: summary,
                        prCandidates: appState.activeWorkoutPRCandidates(),
                        automaticSubmissionEnabled: appState.workoutPreferences.automaticallySubmitVideoBackedPRs,
                        didExplainAutomaticSubmission: appState.workoutPreferences.didExplainAutomaticPRs,
                        onAutomaticSubmissionChanged: appState.setAutomaticVideoPRSubmission,
                        onExplanationShown: appState.markAutomaticVideoPRExplanationShown
                    ) { effort, notes, videos in
                        guard let completed = appState.finishActiveWorkout(effort: effort, notes: notes) else { return }
                        WorkoutRestNotificationScheduler.cancel()
                        showingSummary = false
                        dismiss()
                        Task {
                            await appState.submitVideoBackedPRs(for: completed, videoURLsBySetID: videos)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                ActiveWorkoutAddExercisePickerView()
                    .environmentObject(appState)
                    .presentationDetents([.large])
            }
            .confirmationDialog("Discard this workout?", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
                Button("Discard Workout", role: .destructive) {
                    appState.discardActiveWorkout()
                    WorkoutRestNotificationScheduler.cancel()
                    dismiss()
                }
                Button("Keep Working Out", role: .cancel) {}
            } message: {
                Text("All sets in this active workout will be permanently discarded. Your plan is not changed.")
            }
            .confirmationDialog(
                completedSetCount < plannedSetCount ? "Finish with incomplete sets?" : "Finish this workout?",
                isPresented: $showingFinishConfirmation,
                titleVisibility: .visible
            ) {
                Button("Review & Finish") { showingSummary = true }
                Button("Keep Training", role: .cancel) {}
            } message: {
                Text("Review completed sets and any detected PRs before the workout is saved to history.")
            }
        }
    }

    private func elapsedText(_ workout: ActiveWorkoutState, at date: Date) -> String {
        let seconds = max(0, Int(workout.elapsedDuration(at: date)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }

    private func activeHeader(_ workout: ActiveWorkoutState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Minimize workout")

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.dayLabel.uppercased())
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(Color.liftBlue)
                    Text(workout.name)
                        .font(.headline.weight(.black))
                        .lineLimit(2)
                }

                Spacer()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsedText(workout, at: context.date))
                        .font(.subheadline.weight(.black).monospacedDigit())
                        .foregroundStyle(Color.liftBlue)
                }

                Menu {
                    Button {
                        workout.pausedAt == nil ? appState.pauseActiveWorkout() : appState.resumeActiveWorkout()
                    } label: {
                        Label(workout.pausedAt == nil ? "Pause Workout" : "Resume Workout", systemImage: workout.pausedAt == nil ? "pause.fill" : "play.fill")
                    }
                    Button {
                        isReorderingExercises.toggle()
                    } label: {
                        Label(isReorderingExercises ? "Done Reordering" : "Reorder Exercises", systemImage: "arrow.up.arrow.down")
                    }
                    Button { showingAddExercise = true } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                    if workout.sourceSessionID != nil {
                        Button {
                            _ = appState.updateSourcePlanFromActiveWorkout()
                        } label: {
                            Label("Update Plan from Workout", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    Button(role: .destructive) { showingCancelConfirmation = true } label: {
                        Label("Discard Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Workout options")
            }

            if workout.pausedAt != nil {
                Label("Workout paused", systemImage: "pause.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftGold)
            }

            ProgressView(value: Double(completedSetCount), total: Double(max(1, plannedSetCount)))
                .tint(Color.liftBlue)

            let summary = appState.activeWorkoutSummary()
            HStack(spacing: 14) {
                Label("\(summary?.completedExercises ?? 0)/\(summary?.totalExercises ?? 0) exercises", systemImage: "dumbbell.fill")
                Label("\(completedSetCount)/\(plannedSetCount) sets", systemImage: "checkmark.circle.fill")
                Toggle("Automatic Rest Timer", isOn: Binding(
                    get: { workout.automaticRestTimerEnabled },
                    set: { appState.setAutomaticRestTimerEnabledForActiveWorkout($0) }
                ))
                .labelsHidden()
                .tint(Color.liftBlue)
                .accessibilityLabel("Automatic rest timer")
                Spacer()
                Text("\(Int(summary?.totalVolume ?? 0)) \(workout.unit.shortLabel)")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.liftMuted)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.liftCardRaised)
        .overlay(alignment: .bottom) { Divider().overlay(Color.white.opacity(0.06)) }
    }

    private var emptyCard: some View {
        LiftEmptyState(
            title: "Build this workout",
            message: "Add exercises from the library, then log at least one working set.",
            symbolName: "dumbbell.fill",
            actionTitle: "Add first exercise"
        ) { showingAddExercise = true }
    }

    private func exerciseCard(_ exercise: WorkoutExerciseSnapshot) -> some View {
        let logs = appState.setLogs(for: exercise)
        let completed = logs.filter { $0.isComplete && !$0.isWarmup }.count
        let isComplete = completed >= exercise.targetSets

        return HStack(spacing: 12) {
            if isReorderingExercises {
                VStack(spacing: 6) {
                    Button {
                        _ = appState.moveActiveWorkoutExercise(exercise, direction: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.black))
                            .frame(width: 28, height: 20)
                    }
                    .buttonStyle(.plain)
                    Button {
                        _ = appState.moveActiveWorkoutExercise(exercise, direction: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.black))
                            .frame(width: 28, height: 20)
                    }
                    .buttonStyle(.plain)
                    Image(systemName: "line.3.horizontal")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.liftMuted)
                }
                .foregroundStyle(Color.liftBlue)
            }
            ExerciseCatalogIcon(exercise: catalogExercise(for: exercise))
                .frame(width: 48, height: 48)
                .overlay(alignment: .bottomTrailing) {
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.liftBackground)
                            .frame(width: 18, height: 18)
                            .background(Color.liftGreen)
                            .clipShape(Circle())
                    }
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.exerciseName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(exercise.targetSets) × \(exercise.targetReps) • \(exercise.restSeconds)s rest")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(isComplete ? "Done" : "\(completed)/\(exercise.targetSets)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(isComplete ? Color.liftGreen : Color.liftMuted)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
        }
        .padding(12)
        .background(isComplete ? Color.liftGreen.opacity(0.08) : Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isComplete ? Color.liftGreen.opacity(0.28) : Color.white.opacity(0.06), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    private var workoutControls: some View {
        HStack(spacing: 10) {
            Button { showingAddExercise = true } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 52, height: 52)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.liftBlue)
            .accessibilityLabel("Add exercise")

            Button {
                guard completedSetCount > 0 else {
                    finishValidationMessage = "Complete at least one non-warmup set before finishing."
                    Haptics.warning()
                    return
                }
                finishValidationMessage = nil
                showingFinishConfirmation = true
            } label: {
                HStack {
                    Text("Finish workout")
                        .font(.headline.weight(.black))
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                }
                .foregroundStyle(Color.liftBackground)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(Color.liftGreen)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func catalogExercise(for exercise: WorkoutExerciseSnapshot) -> TrainingExerciseCatalogItem {
        appState.trainingExerciseLibrary.first { $0.id == exercise.exerciseID } ?? TrainingExerciseCatalogItem(
            id: exercise.exerciseID,
            name: exercise.exerciseName,
            bodyPart: exercise.bodyPart,
            workoutCategory: exercise.bodyPart,
            defaultSets: exercise.targetSets,
            defaultReps: exercise.targetReps,
            symbolName: "figure.strengthtraining.traditional",
            equipment: exercise.equipment,
            muscleProfile: exercise.muscleProfile,
            rankingExerciseID: exercise.rankingExerciseID
        )
    }
}

enum WorkoutSetInputField: String, Hashable {
    case reps
    case weight
}

struct WorkoutSetInputFocus: Hashable {
    let logID: UUID
    let field: WorkoutSetInputField
}

enum WorkoutSetInputNavigator {
    static func orderedFocuses(for logs: [WorkoutSetLog]) -> [WorkoutSetInputFocus] {
        let sortedLogs = logs.sorted { $0.setNumber < $1.setNumber }
        return sortedLogs.map { WorkoutSetInputFocus(logID: $0.id, field: .reps) } +
            sortedLogs.map { WorkoutSetInputFocus(logID: $0.id, field: .weight) }
    }

    static func next(after current: WorkoutSetInputFocus, in logs: [WorkoutSetLog]) -> WorkoutSetInputFocus? {
        let focuses = orderedFocuses(for: logs)
        guard let index = focuses.firstIndex(of: current), focuses.indices.contains(index + 1) else {
            return nil
        }
        return focuses[index + 1]
    }
}

enum WorkoutRestNotificationScheduler {
    private static let identifier = "liftrank-active-rest-timer"

    static func schedule(endsAt: Date, exerciseName: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                addRequest(center: center, endsAt: endsAt, exerciseName: exerciseName)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { addRequest(center: center, endsAt: endsAt, exerciseName: exerciseName) }
                }
            default:
                break
            }
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private static func addRequest(center: UNUserNotificationCenter, endsAt: Date, exerciseName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Your next \(exerciseName) set is ready."
        content.sound = .default
        let interval = max(1, endsAt.timeIntervalSinceNow)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }
}

struct PrescriptionTrackView: View {
    @EnvironmentObject private var appState: AppState
    let exercise: WorkoutExerciseSnapshot
    @State private var restEndsAt: Date?
    @FocusState private var focusedInput: WorkoutSetInputFocus?

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                if let restEndsAt {
                    restTimerBanner(endsAt: restEndsAt)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ExerciseCatalogIcon(exercise: catalogExercise)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(exercise.exerciseName)
                                        .font(.title3.weight(.black))
                                    Text("Target: \(exercise.targetSets) × \(exercise.targetReps)")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Spacer()
                                Text("\(completedLogs.count)/\(exercise.targetSets)")
                                    .font(.headline.weight(.black).monospacedDigit())
                                    .foregroundStyle(completedLogs.count >= exercise.targetSets ? Color.liftGreen : Color.liftBlue)
                            }

                            HStack(spacing: 8) {
                                compactExerciseMetric("\(exercise.restSeconds)s", "timer")
                                compactExerciseMetric("\(Int(completedVolume)) \(appState.activeWorkout?.unit.shortLabel ?? "lb")", "scalemass")
                                if let previous = mostRecentCompletedLog {
                                    compactExerciseMetric("Last \(previous.reps ?? 0) × \(RankingCalculator.format(previous.weight ?? 0))", "clock.arrow.circlepath")
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        }

                        setColumnHeader

                            ForEach(activeLogs) { log in
                                WorkoutSetLogRow(
                                    log: log,
                                    previousLog: appState.previousSetLog(for: exercise, setNumber: log.setNumber),
                                    focusedInput: $focusedInput
                                ) {
                                    startRestTimer()
                                }
                                .environmentObject(appState)
                                .id(log.id)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 18)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollIndicators(.hidden)
                    .onChange(of: focusedInput) { _, focus in
                        guard let focus else { return }
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo(focus.logID, anchor: .center)
                            }
                        }
                    }
                }

                Button {
                    _ = appState.addSetLog(to: exercise)
                } label: {
                    Label("Add another set", systemImage: "plus")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.liftCard)
                        .foregroundStyle(Color.liftBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.liftBlue.opacity(0.40), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Track exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(keyboardActionTitle) {
                    advanceKeyboardFocus()
                }
                .font(.headline.weight(.bold))
            }
        }
        .onAppear {
            ensureTargetSetsExist()
            restoreRestTimer()
        }
    }

    private var activeLogs: [WorkoutSetLog] {
        appState.setLogs(for: exercise)
    }

    private var keyboardActionTitle: String {
        guard let focusedInput else { return "Next" }
        return WorkoutSetInputNavigator.next(after: focusedInput, in: activeLogs) == nil ? "Done" : "Next"
    }

    private func advanceKeyboardFocus() {
        guard let focusedInput else { return }
        self.focusedInput = WorkoutSetInputNavigator.next(after: focusedInput, in: activeLogs)
        Haptics.light()
    }

    private var completedLogs: [WorkoutSetLog] {
        appState.setLogs(for: exercise).filter(\.isComplete)
    }

    private var completedVolume: Double {
        completedLogs.reduce(0) { total, log in
            total + (log.weight ?? 0) * Double(log.reps ?? 0)
        }
    }

    private var mostRecentCompletedLog: WorkoutSetLog? {
        appState.previousSetLog(for: exercise, setNumber: 1)
    }

    private var catalogExercise: TrainingExerciseCatalogItem {
        appState.trainingExerciseLibrary.first { $0.id == exercise.exerciseID } ??
            TrainingExerciseCatalogItem(
                id: exercise.exerciseID,
                name: exercise.exerciseName,
                bodyPart: exercise.bodyPart,
                workoutCategory: exercise.bodyPart,
                defaultSets: exercise.targetSets,
                defaultReps: exercise.targetReps,
                symbolName: "dumbbell.fill",
                equipment: exercise.equipment,
                muscleProfile: exercise.muscleProfile,
                rankingExerciseID: exercise.rankingExerciseID
            )
    }

    private func compactExerciseMetric(_ value: String, _ symbol: String) -> some View {
        Label(value, systemImage: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.liftMuted)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.16))
            .clipShape(Capsule())
    }

    private var setColumnHeader: some View {
        HStack(spacing: 8) {
            Text("SET").frame(width: 34)
            Text("PREVIOUS").frame(maxWidth: .infinity)
            Text("REPS").frame(width: 64)
            Text((appState.activeWorkout?.unit.shortLabel ?? "lb").uppercased()).frame(width: 72)
            Color.clear.frame(width: 38, height: 1)
        }
        .font(.caption2.weight(.black))
        .tracking(0.7)
        .foregroundStyle(Color.liftMuted)
        .padding(.horizontal, 10)
    }

    private func restTimerBanner(endsAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(endsAt.timeIntervalSince(context.date)))
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftBackground)
                    .frame(width: 40, height: 40)
                    .background(Color.liftBlue)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("REST")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(Color.liftBlue)
                    Text(remaining > 0 ? "\(remaining / 60):\(String(format: "%02d", remaining % 60))" : "Ready")
                        .font(.title2.weight(.black).monospacedDigit())
                }

                Spacer()

                Button("Skip") {
                    restEndsAt = nil
                    appState.updateActiveRestTimer(endsAt: nil, exerciseID: nil)
                    WorkoutRestNotificationScheduler.cancel()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.liftBlue)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.liftCardRaised)
            .overlay(alignment: .bottom) {
                ProgressView(
                    value: Double(remaining),
                    total: Double(max(1, exercise.restSeconds))
                )
                .tint(Color.liftBlue)
            }
            .onChange(of: remaining) { _, value in
                if value == 0 {
                    restEndsAt = nil
                    appState.updateActiveRestTimer(endsAt: nil, exerciseID: nil)
                    WorkoutRestNotificationScheduler.cancel()
                    Haptics.success()
                }
            }
        }
    }

    private func ensureTargetSetsExist() {
        let existing = appState.setLogs(for: exercise).count
        guard existing < exercise.targetSets else { return }
        for _ in existing..<exercise.targetSets {
            _ = appState.addSetLog(to: exercise)
        }
    }

    private func startRestTimer() {
        guard appState.activeWorkout?.automaticRestTimerEnabled ?? appState.workoutPreferences.defaultRestTimerEnabled else { return }
        let end = Date.now.addingTimeInterval(TimeInterval(exercise.restSeconds))
        restEndsAt = end
        appState.updateActiveRestTimer(endsAt: end, exerciseID: exercise.id)
        WorkoutRestNotificationScheduler.schedule(endsAt: end, exerciseName: exercise.exerciseName)
    }

    private func restoreRestTimer() {
        guard let workout = appState.activeWorkout,
              workout.restTimerExerciseID == exercise.id,
              let end = workout.restTimerEndsAt else { return }
        if end > .now {
            restEndsAt = end
        } else {
            appState.updateActiveRestTimer(endsAt: nil, exerciseID: nil)
            WorkoutRestNotificationScheduler.cancel()
        }
    }
}

struct WorkoutSetLogRow: View {
    @EnvironmentObject private var appState: AppState
    @FocusState.Binding var focusedInput: WorkoutSetInputFocus?
    @State private var draft: WorkoutSetLog
    @State private var repsText: String
    @State private var weightText: String
    @State private var showValidation = false
    @State private var showingDetails = false
    let previousLog: WorkoutSetLog?
    var onCompleted: (() -> Void)?

    init(
        log: WorkoutSetLog,
        previousLog: WorkoutSetLog? = nil,
        focusedInput: FocusState<WorkoutSetInputFocus?>.Binding,
        onCompleted: (() -> Void)? = nil
    ) {
        _focusedInput = focusedInput
        _draft = State(initialValue: log)
        _repsText = State(initialValue: log.reps.map(String.init) ?? "")
        _weightText = State(initialValue: log.weight.map(Self.formatWeight) ?? "")
        self.previousLog = previousLog
        self.onCompleted = onCompleted
    }

    private var hasRequiredInputs: Bool {
        parsedReps != nil && parsedWeight != nil
    }

    private var parsedReps: Int? {
        let trimmed = repsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    private var parsedWeight: Double? {
        let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value >= 0 else { return nil }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(draft.setNumber)")
                    .font(.subheadline.weight(.black).monospacedDigit())
                    .foregroundStyle(draft.isComplete ? Color.liftBackground : .white)
                    .frame(width: 34, height: 38)
                    .background(draft.isComplete ? Color.liftGreen : Color.liftCardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    usePreviousValues()
                } label: {
                    Text(previousSummary)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(previousLog == nil ? Color.liftMuted : Color.liftBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.black.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(previousLog == nil)
                .accessibilityLabel("Use previous values for set \(draft.setNumber)")

                compactField("Reps", text: $repsText, width: 64, field: .reps)
                    .keyboardType(.numberPad)
                    .onChange(of: repsText) { _, _ in
                        draft.reps = parsedReps
                        appState.updateSetLog(draft)
                        if appState.attemptAutomaticCompletion(before: draft) {
                            onCompleted?()
                        }
                    }

                compactField(draft.recordedUnit.shortLabel.capitalized, text: $weightText, width: 72, field: .weight)
                    .keyboardType(.decimalPad)
                    .onChange(of: weightText) { _, _ in
                        draft.weight = parsedWeight
                        appState.updateSetLog(draft)
                        if appState.attemptAutomaticCompletion(before: draft) {
                            onCompleted?()
                        }
                    }

                Button {
                    toggleCompletion()
                } label: {
                    Image(systemName: draft.isComplete ? "checkmark" : "circle")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(draft.isComplete ? Color.liftBackground : Color.liftBlue)
                        .frame(width: 38, height: 38)
                        .background(draft.isComplete ? Color.liftGreen : Color.liftBlue.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .opacity(!draft.isComplete && !hasRequiredInputs ? 0.55 : 1)
                .accessibilityLabel(draft.isComplete ? "Mark set incomplete" : "Complete set")
            }

            if showingDetails {
                HStack(spacing: 10) {
                    Text("Optional details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                    Spacer()
                    OptionalIntegerInputField(title: "RPE", value: Binding(
                        get: { draft.rpe },
                        set: {
                            draft.rpe = $0
                            appState.updateSetLog(draft)
                        }
                    ), presentation: .inset)
                        .frame(maxWidth: 150)

                    Button {
                        draft.isWarmup.toggle()
                        appState.updateSetLog(draft)
                    } label: {
                        Image(systemName: draft.isWarmup ? "flame.fill" : "flame")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(draft.isWarmup ? Color.liftGold : Color.liftMuted)
                    .accessibilityLabel(draft.isWarmup ? "Mark as working set" : "Mark as warmup set")

                    Button(role: .destructive) {
                        appState.deleteSetLog(draft)
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.caption.weight(.bold))
                    }
                }
            }

            if showValidation && !hasRequiredInputs {
                Label("Enter reps and weight to complete this set.", systemImage: "exclamationmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftRed)
            }
        }
        .padding(10)
        .background(draft.isComplete ? Color.liftGreen.opacity(0.07) : Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(draft.isComplete ? Color.liftGreen.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
        }
        .contextMenu {
            Button {
                showingDetails.toggle()
            } label: {
                Label(showingDetails ? "Hide RPE" : "Add RPE", systemImage: "slider.horizontal.3")
            }
            Button {
                draft.isWarmup.toggle()
                appState.updateSetLog(draft)
            } label: {
                Label(draft.isWarmup ? "Mark Working Set" : "Mark Warmup Set", systemImage: "flame")
            }
            Button(role: .destructive) {
                appState.deleteSetLog(draft)
            } label: {
                Label("Delete Set", systemImage: "trash")
            }
        }
    }

    private var previousSummary: String {
        guard let previousLog else { return "—" }
        return "\(previousLog.reps ?? 0) × \(RankingCalculator.format(previousLog.weight ?? 0))"
    }

    private func compactField(_ placeholder: String, text: Binding<String>, width: CGFloat, field: WorkoutSetInputField) -> some View {
        TextField(placeholder, text: text)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .focused($focusedInput, equals: WorkoutSetInputFocus(logID: draft.id, field: field))
            .frame(width: width, height: 38)
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
    }

    private func usePreviousValues() {
        guard let previousLog else { return }
        if let reps = previousLog.reps {
            repsText = String(reps)
            draft.reps = reps
        }
        if let weight = previousLog.weight {
            weightText = Self.formatWeight(weight)
            draft.weight = weight
        }
        appState.updateSetLog(draft)
        Haptics.light()
    }

    private func toggleCompletion() {
        guard draft.isComplete || hasRequiredInputs else {
            showValidation = true
            return
        }
        showValidation = false
        let completing = !draft.isComplete
        let triggerTimer = appState.applyWorkoutSetCompletion(draft, isComplete: completing, source: .manual)
        draft.isComplete = completing
        draft.performedAt = .now
        draft.completionSource = completing ? .manual : nil
        if completing {
            Haptics.success()
            if triggerTimer { onCompleted?() }
        }
    }

    private static func formatWeight(_ value: Double) -> String {
        RankingCalculator.format(value)
    }
}

struct WorkoutSummaryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let summary: WorkoutSummary
    let prCandidates: [WorkoutPRCandidate]
    let didExplainAutomaticSubmission: Bool
    let onAutomaticSubmissionChanged: (Bool) -> Void
    let onExplanationShown: () -> Void
    let onComplete: (Int, String, [UUID: URL]) -> Void
    @State private var effort = 3
    @State private var notes = ""
    @State private var automaticSubmissionEnabled: Bool
    @State private var selectedVideoItems: [UUID: PhotosPickerItem] = [:]
    @State private var videoURLsBySetID: [UUID: URL] = [:]
    @State private var loadingVideoSetIDs: Set<UUID> = []
    @State private var videoError: String?
    @State private var showingAutomaticSubmissionExplanation = false

    init(
        summary: WorkoutSummary,
        prCandidates: [WorkoutPRCandidate],
        automaticSubmissionEnabled: Bool,
        didExplainAutomaticSubmission: Bool,
        onAutomaticSubmissionChanged: @escaping (Bool) -> Void,
        onExplanationShown: @escaping () -> Void,
        onComplete: @escaping (Int, String, [UUID: URL]) -> Void
    ) {
        self.summary = summary
        self.prCandidates = prCandidates
        self.didExplainAutomaticSubmission = didExplainAutomaticSubmission
        self.onAutomaticSubmissionChanged = onAutomaticSubmissionChanged
        self.onExplanationShown = onExplanationShown
        self.onComplete = onComplete
        _automaticSubmissionEnabled = State(initialValue: automaticSubmissionEnabled)
    }

    private var activeDuration: TimeInterval {
        appState.activeWorkout?.elapsedDuration() ?? 0
    }

    private var previousComparableWorkout: CompletedWorkout? {
        appState.completedWorkouts.first {
            $0.sourceSessionID == summary.sessionID || $0.name == summary.workoutName
        }
    }

    private var projectedWorkoutCount: Int {
        appState.competitiveStatistics.totalWorkouts + 1
    }

    private var projectedStreak: Int {
        max(appState.competitiveStatistics.currentStreak, 0) + 1
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 34, weight: .black))
                                .foregroundStyle(Color.liftBackground)
                                .frame(width: 72, height: 72)
                                .background(Color.liftGreen)
                                .clipShape(Circle())
                            Text("Workout complete")
                                .font(.largeTitle.weight(.black))
                            Text(summary.workoutName)
                                .font(.headline)
                                .foregroundStyle(Color.liftMuted)
                        }
                        .frame(maxWidth: .infinity)

                        HStack(spacing: 10) {
                            summaryMetric("Exercises", "\(summary.completedExercises)/\(summary.totalExercises)", "dumbbell.fill")
                            summaryMetric("Sets", "\(summary.totalSets)", "checkmark.circle.fill")
                            summaryMetric("Volume", "\(Int(summary.totalVolume))", "scalemass.fill")
                        }

                        HStack(spacing: 10) {
                            summaryMetric("Duration", durationText(activeDuration), "timer")
                            summaryMetric("Projected streak", "\(projectedStreak)d", "flame.fill")
                            summaryMetric("Lifetime workouts", "\(projectedWorkoutCount)", "calendar")
                        }

                        if let best = summary.bestSet {
                            HStack(spacing: 12) {
                                Image(systemName: "trophy.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.liftGold)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Best set")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.liftMuted)
                                    Text("\(best.weight.map { RankingCalculator.format($0) } ?? "--") \(best.recordedUnit.shortLabel) × \(best.reps ?? 0)")
                                        .font(.headline.weight(.black))
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.liftGold.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        if let previous = previousComparableWorkout {
                            comparisonSection(previous)
                        }

                        if !prCandidates.isEmpty {
                            prSubmissionSection
                        }

                        if !appState.achievementUnlocks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Unlocked achievements")
                                    .font(.headline.weight(.bold))
                                ForEach(appState.achievementUnlocks.prefix(3)) { unlock in
                                    HStack(spacing: 10) {
                                        Image(systemName: "medal.fill")
                                            .foregroundStyle(Color.liftGold)
                                        Text(unlock.title)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.liftCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("How hard did this workout feel?")
                                .font(.title3.weight(.black))
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { value in
                                    Button {
                                        effort = value
                                        Haptics.light()
                                    } label: {
                                        VStack(spacing: 5) {
                                            Text("\(value)")
                                                .font(.headline.weight(.black))
                                            Text(effortLabel(value))
                                                .font(.system(size: 9, weight: .bold))
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(effort == value ? Color.liftBlue : Color.liftCard)
                                        .foregroundStyle(effort == value ? Color.liftBackground : Color.liftMuted)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workout notes")
                                .font(.headline.weight(.bold))
                            TextEditor(text: $notes)
                                .frame(minHeight: 90)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .background(Color.liftCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(alignment: .topLeading) {
                                    if notes.isEmpty {
                                        Text("Anything to remember for next time?")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.liftMuted)
                                            .padding(.horizontal, 15)
                                            .padding(.vertical, 18)
                                            .allowsHitTesting(false)
                                    }
                                }
                        }

                        ShareLink(item: shareText) {
                            Label("Share summary", systemImage: "square.and.arrow.up")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.liftCard)
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.liftBlue)

                        PrimaryButton(title: "Save & finish", symbolName: "checkmark.circle.fill") {
                            onComplete(effort, notes, videoURLsBySetID)
                        }
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear {
                if !prCandidates.isEmpty && !didExplainAutomaticSubmission {
                    onExplanationShown()
                    showingAutomaticSubmissionExplanation = true
                }
            }
            .alert("Submit video-backed PRs automatically?", isPresented: $showingAutomaticSubmissionExplanation) {
                Button("Enable") {
                    automaticSubmissionEnabled = true
                    onAutomaticSubmissionChanged(true)
                }
                Button("Keep Private", role: .cancel) {
                    automaticSubmissionEnabled = false
                    onAutomaticSubmissionChanged(false)
                }
            } message: {
                Text("When enabled, only canonical lift PRs with an attached video are posted publicly as Video Submitted. PRs without video stay private.")
            }
        }
    }

    private var prSubmissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Personal records")
                        .font(.title3.weight(.black))
                    Text("Attach video now if you want an eligible PR to be submitted.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Color.liftGold)
            }

            Toggle(isOn: Binding(
                get: { automaticSubmissionEnabled },
                set: { enabled in
                    automaticSubmissionEnabled = enabled
                    onAutomaticSubmissionChanged(enabled)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Automatically submit video-backed PRs")
                        .font(.subheadline.weight(.bold))
                    Text("Public • Video Submitted • next daily ranking update")
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .tint(Color.liftBlue)

            ForEach(prCandidates) { candidate in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(candidate.exerciseName)
                                .font(.subheadline.weight(.bold))
                            Text("\(RankingCalculator.format(candidate.weight)) \(candidate.unit.shortLabel) × \(candidate.repetitions)")
                                .font(.headline.weight(.black).monospacedDigit())
                                .foregroundStyle(Color.liftGold)
                        }
                        Spacer()
                        Text("NEW PR")
                            .font(.caption2.weight(.black))
                            .tracking(0.7)
                            .foregroundStyle(Color.liftGold)
                    }

                    PhotosPicker(
                        selection: Binding(
                            get: { selectedVideoItems[candidate.setID] },
                            set: { item in
                                selectedVideoItems[candidate.setID] = item
                                guard let item else {
                                    videoURLsBySetID.removeValue(forKey: candidate.setID)
                                    return
                                }
                                loadVideo(item, for: candidate)
                            }
                        ),
                        matching: .videos
                    ) {
                        HStack {
                            if loadingVideoSetIDs.contains(candidate.setID) {
                                ProgressView()
                            } else {
                                Image(systemName: videoURLsBySetID[candidate.setID] == nil ? "video.badge.plus" : "checkmark.circle.fill")
                            }
                            Text(videoURLsBySetID[candidate.setID] == nil ? "Attach lift video" : "Video attached")
                            Spacer()
                            if videoURLsBySetID[candidate.setID] != nil {
                                Text("Ready")
                                    .foregroundStyle(Color.liftGreen)
                            }
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Color.liftBlue.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !automaticSubmissionEnabled {
                Label("These PRs will remain private even if a video is attached.", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
            }
            if let videoError {
                Label(videoError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftRed)
            }
        }
        .padding(14)
        .background(Color.liftGold.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.liftGold.opacity(0.25), lineWidth: 1)
        }
    }

    private func comparisonSection(_ previous: CompletedWorkout) -> some View {
        let previousVolume = previous.totalVolume
        let previousSets = previous.completedWorkingSets.count
        let volumeDelta = summary.totalVolume - previousVolume
        let setDelta = summary.totalSets - previousSets
        let durationDelta = activeDuration - previous.duration
        return VStack(alignment: .leading, spacing: 10) {
            Text("Compared with last \(previous.name)")
                .font(.headline.weight(.bold))
            HStack(spacing: 10) {
                summaryMetric("Volume", signedValue(volumeDelta), "chart.bar.fill")
                summaryMetric("Sets", signedValue(Double(setDelta)), "plusminus")
                summaryMetric("Time", signedDuration(durationDelta), "clock.arrow.circlepath")
            }
            Text("Previous: \(Int(previousVolume)) \(previous.unit.shortLabel) in \(previousSets) sets")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func signedValue(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded >= 0 ? "+\(rounded)" : "\(rounded)"
    }

    private func signedDuration(_ value: TimeInterval) -> String {
        let seconds = Int(value.rounded())
        let absSeconds = abs(seconds)
        let text = String(format: "%d:%02d", absSeconds / 60, absSeconds % 60)
        return seconds >= 0 ? "+\(text)" : "-\(text)"
    }

    private func loadVideo(_ item: PhotosPickerItem, for candidate: WorkoutPRCandidate) {
        loadingVideoSetIDs.insert(candidate.setID)
        videoError = nil
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw CocoaError(.fileReadUnknown)
                }
                let url = try appState.persistWorkoutVideo(data)
                await MainActor.run {
                    videoURLsBySetID[candidate.setID] = url
                    loadingVideoSetIDs.remove(candidate.setID)
                }
            } catch {
                await MainActor.run {
                    loadingVideoSetIDs.remove(candidate.setID)
                    videoError = "That video could not be prepared. Choose it again before saving."
                }
            }
        }
    }

    private var shareText: String {
        "Completed \(summary.workoutName): \(summary.totalSets) sets and \(Int(summary.totalVolume)) \(summary.bestSet?.recordedUnit.shortLabel ?? "lb") volume in LiftRank."
    }

    private func effortLabel(_ value: Int) -> String {
        ["Easy", "Light", "Solid", "Hard", "Max"][value - 1]
    }

    private func summaryMetric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftBlue)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            Text(value)
                .font(.headline.weight(.black).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct CompletedWorkoutDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let workout: CompletedWorkout
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(workout.name)
                                .font(.title2.weight(.black))
                            Text(workout.completedAt.formatted(date: .complete, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                            HStack(spacing: 8) {
                                detailMetric("Duration", durationText, "timer")
                                detailMetric("Sets", "\(workout.completedWorkingSets.count)", "checkmark.circle")
                                detailMetric("Volume", "\(Int(workout.totalVolume))", "scalemass")
                            }
                        }
                        .padding(14)
                        .liftSurface()

                        ForEach(workout.exercises.sorted { $0.order < $1.order }) { exercise in
                            let sets = workout.sets
                                .filter { $0.prescriptionID == exercise.id && $0.isComplete }
                                .sorted { $0.setNumber < $1.setNumber }
                            if !sets.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 10) {
                                        ExerciseMuscleMap(profile: exercise.muscleProfile ?? ExerciseMuscleProfileResolver.profile(name: exercise.exerciseName, bodyPart: exercise.bodyPart))
                                            .frame(width: 46, height: 46)
                                            .accessibilityHidden(true)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(exercise.exerciseName)
                                                .font(.headline.weight(.bold))
                                            Text((exercise.muscleProfile ?? ExerciseMuscleProfileResolver.profile(name: exercise.exerciseName, bodyPart: exercise.bodyPart)).primaryDescription)
                                                .font(.caption)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                        Spacer()
                                    }
                                    ForEach(sets) { set in
                                        HStack {
                                            Text(set.isWarmup ? "Warmup \(set.setNumber)" : "Set \(set.setNumber)")
                                                .foregroundStyle(set.isWarmup ? Color.liftGold : Color.liftMuted)
                                            Spacer()
                                            Text("\(RankingCalculator.format(set.weight ?? 0)) \(set.recordedUnit.shortLabel) × \(set.reps ?? 0)")
                                                .font(.subheadline.weight(.bold).monospacedDigit())
                                            if let rpe = set.rpe {
                                                Text("@ \(rpe)")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(Color.liftBlue)
                                            }
                                        }
                                        .font(.subheadline)
                                        if set.id != sets.last?.id {
                                            Divider().overlay(Color.white.opacity(0.06))
                                        }
                                    }
                                }
                                .padding(14)
                                .liftSurface()
                            }
                        }

                        if !workout.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes")
                                    .font(.headline.weight(.bold))
                                Text(workout.notes)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .padding(14)
                            .liftSurface()
                        }

                        if !workout.linkedSubmissionIDs.isEmpty {
                            Label("\(workout.linkedSubmissionIDs.count) public lift submission linked. Deleting this history entry will not delete it.", systemImage: "link")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.liftMuted)
                                .padding(14)
                                .liftSurface()
                        }

                        PrimaryButton(title: "Share to Community", symbolName: "person.3.fill") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                appState.beginForumComposer(workoutID: workout.id)
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Workout details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete workout history")
                }
            }
            .confirmationDialog("Delete this workout from history?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete History", role: .destructive) {
                    appState.deleteCompletedWorkout(workout)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The workout snapshot is removed. Any public lift submissions already created remain public.")
            }
        }
    }

    private var durationText: String {
        let minutes = max(0, Int(workout.duration) / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func detailMetric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            Text(value)
                .font(.subheadline.weight(.black).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CreateWorkoutPlanView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var planName = ""

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(alignment: .leading, spacing: 16) {
                    LiftCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Create Workout Plan")
                                .font(.title2.bold())
                            TextField("Plan name", text: $planName)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color.black.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("New Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        appState.createWorkoutPlan(name: planName)
                        dismiss()
                    }
                    .disabled(planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct BodyweightEntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BodyweightEntry
    let onSave: (BodyweightEntry) -> Void

    init(entry: BodyweightEntry, onSave: @escaping (BodyweightEntry) -> Void) {
        _draft = State(initialValue: entry)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(alignment: .leading, spacing: 16) {
                    LiftSheetHeader(
                        title: "Week \(draft.week)",
                        subtitle: draft.targetDate.formatted(date: .long, time: .omitted)
                    )

                    OptionalNumericInputField(
                        title: "Actual bodyweight",
                        value: $draft.actual,
                        unit: "lb"
                    )

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Notes")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                        TextField("Optional notes", text: $draft.notes, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.liftField)
                            .clipShape(RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous))
                    }

                    Spacer()
                }
                .padding(18)
            }
            .navigationTitle("Bodyweight Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color.liftBlue)
                }
            }
        }
    }
}
