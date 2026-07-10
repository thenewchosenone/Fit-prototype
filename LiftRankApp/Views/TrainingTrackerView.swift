import Charts
import SwiftData
import SwiftUI

struct TrainingTrackerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var segment: TrackerSegment
    @State private var selectedWeekID: UUID?
    @State private var selectedSessionForAdd: WorkoutSession?
    @State private var selectedSessionToRun: WorkoutSession?
    @State private var showingCreatePlan = false
    @State private var showingRenamePlan = false
    @State private var renamePlanName = ""
    @State private var planDetailTab = "Weeks"
    @State private var librarySearch = ""
    @State private var libraryBodyPartFilter = "All"
    @State private var libraryEquipmentFilter = "All"
    @State private var selectedBodyweightEntry: BodyweightEntry?

    init(startOnProgress: Bool = false) {
        _segment = State(initialValue: startOnProgress ? .progress : .today)
    }

    private var selectedPlanName: String {
        appState.selectedWorkoutPlan?.name ?? "Workout Plan"
    }

    private var selectedWeek: WorkoutWeek? {
        if let selectedWeekID, let week = appState.selectedPlanWeeks.first(where: { $0.id == selectedWeekID }) {
            return week
        }
        return appState.selectedPlanWeeks.first
    }

    private var libraryBodyPartOptions: [String] {
        ["All", "Chest", "Back", "Shoulders", "Arms", "Quads", "Hamstrings", "Glutes", "Core", "Full Body"]
    }

    private var libraryEquipmentOptions: [String] {
        ["All"] + Set(appState.trainingExerciseLibrary.map(\.equipment)).sorted()
    }

    private var filteredLibraryExercises: [TrainingExerciseCatalogItem] {
        appState.trainingExerciseLibrary.filter { exercise in
            let query = librarySearch.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = exercise.matchesSearch(query)
            let matchesBody = libraryBodyPartFilter == "All" || exercise.bodyPart == libraryBodyPartFilter
            let matchesEquipment = libraryEquipmentFilter == "All" || exercise.equipment == libraryEquipmentFilter
            return matchesSearch && matchesBody && matchesEquipment
        }
        .sorted { $0.name < $1.name }
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
                        .padding(.bottom, 36)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedSessionForAdd) { session in
                ProgramAddExercisePickerView(session: session)
                    .environmentObject(appState)
                    .presentationDetents([.large])
            }
            .fullScreenCover(item: $selectedSessionToRun) { session in
                WorkoutSessionRunView(session: session)
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
            .alert("Rename Plan", isPresented: $showingRenamePlan) {
                TextField("Plan name", text: $renamePlanName)
                Button("Save") {
                    appState.renameSelectedWorkoutPlan(to: renamePlanName)
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                syncSelectedWeek()
            }
            .onChange(of: appState.selectedWorkoutPlanID) {
                syncSelectedWeek()
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Workout Tracker")
                    .font(.title3.weight(.black))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close training tracker")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                Menu {
                    Picker("Plan", selection: $appState.selectedWorkoutPlanID) {
                        ForEach(appState.workoutPlans) { plan in
                            Text(plan.name).tag(plan.id)
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color.liftBlue)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("ACTIVE PLAN")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(Color.liftMuted)
                            Text(selectedPlanName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftMuted)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .background(Color.liftCardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }

                Menu {
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
                        .frame(width: 48, height: 48)
                        .background(Color.liftCardRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .accessibilityLabel("Plan options")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

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
            .padding(.horizontal, 8)
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

            if let week = selectedWeek, let session = primaryScheduledSession {
                TodayWorkoutLaunchCard(week: week, session: session) {
                    selectedSessionToRun = session
                }
                .environmentObject(appState)
            } else {
                emptyPlanCard(title: "No scheduled workout", message: "Create a workout day inside Plans or start freestyle now.")
            }

            Button {
                startFreestyleWorkout()
            } label: {
                Label("Start empty workout", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.liftBlue.opacity(0.45), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.liftBlue)

            TodayWorkoutStats(week: selectedWeek, sessions: scheduledSessions)
                .environmentObject(appState)
        }
    }

    private var strengthBalanceCard: some View {
        let weekNumber = selectedWeek?.weekNumber ?? 1
        let balance = appState.strengthBalance(for: weekNumber)
        return LiftCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading) {
                        Text("Strength Balance")
                            .foregroundStyle(Color.liftMuted)
                        Text("\(balance.score)%")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                    }
                    Spacer()
                    Text(balance.label)
                        .font(.headline)
                        .foregroundStyle(balance.score >= 75 ? Color.liftGreen : Color.liftGold)
                }
                Text("\(balance.weakest) needs the most attention")
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                if let date = appState.lastCompletedWorkoutDate() {
                    Text("Last completed: \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftBlue)
                }
                ForEach(balance.volumes.keys.sorted(), id: \.self) { category in
                    let value = balance.volumes[category] ?? 0
                    HStack {
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .frame(width: 105, alignment: .leading)
                        ProgressView(value: value, total: max(1, balance.volumes.values.max() ?? 1))
                            .tint(Color.liftBlue)
                        Text("\(Int(value))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.liftMuted)
                    }
                }
            }
        }
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Plans")
                    .font(.title3.weight(.black))
                Spacer()
                Button {
                    showingCreatePlan = true
                } label: {
                    Label("New plan", systemImage: "plus")
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
                        .frame(minHeight: 62)
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

    private var library: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Exercise library")
                    .font(.title2.weight(.black))
                Text("\(filteredLibraryExercises.count) exercises available")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.liftMuted)
                TextField("Search exercises", text: $librarySearch)
                    .textFieldStyle(.plain)
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Color.liftBlue)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }

            HStack(spacing: 10) {
                ProgramFilterMenu(title: "Body Part", selection: $libraryBodyPartFilter, options: libraryBodyPartOptions)
                ProgramFilterMenu(title: "Equipment", selection: $libraryEquipmentFilter, options: libraryEquipmentOptions)
            }

            VStack(spacing: 0) {
                ForEach(Array(filteredLibraryExercises.enumerated()), id: \.element.id) { index, exercise in
                    HStack(spacing: 12) {
                        ExerciseCatalogIcon(exercise: exercise)
                            .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name)
                                .font(.subheadline.weight(.semibold))
                            Text("\(exercise.bodyPart) • \(exercise.equipment)")
                                .font(.caption)
                                .foregroundStyle(Color.liftBlue)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("\(exercise.defaultSets) × \(exercise.defaultReps)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.liftMuted)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 68)

                    if index < filteredLibraryExercises.count - 1 {
                        Divider()
                            .overlay(Color.white.opacity(0.07))
                            .padding(.leading, 70)
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
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var progress: some View {
        let totals = appState.volumeByBodyPart()
        let maxVolume = max(1, totals.values.max() ?? 1)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Progress")
                .font(.title3.weight(.black))

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

    private func emptyPlanCard(title: String, message: String) -> some View {
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

    private func syncSelectedWeek() {
        if let selectedWeekID, appState.selectedPlanWeeks.contains(where: { $0.id == selectedWeekID }) {
            return
        }
        selectedWeekID = appState.selectedPlanWeeks.first?.id
    }

    private func startFreestyleWorkout() {
        let session = appState.startFreestyleSession(in: selectedWeek)
        selectedWeekID = (selectedWeek ?? appState.selectedPlanWeeks.first)?.id
        selectedSessionToRun = session
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
                metric("Workouts", "\(sessions.count)", symbol: "figure.strengthtraining.traditional")
                divider
                metric("Complete", "\(Int((week.map { appState.weekCompletion(for: $0) } ?? 0) * 100))%", symbol: "checkmark")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Plan Detail")
            LiftCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(appState.selectedWorkoutPlan?.name ?? "Workout Plan")
                                .font(.title3.bold())
                            Text("\(appState.selectedPlanPhases.first?.name ?? "Base Phase") - \(selectedWeek?.title ?? "Week 1")")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        Menu {
                            if let selectedWeek {
                                Button {
                                    let clone = appState.cloneWeek(selectedWeek)
                                    selectedWeekID = clone.id
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
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.liftBlue)
                        }
                    }

                    HStack(spacing: 0) {
                        ForEach(["Weeks", "Overview", "Notes"], id: \.self) { tab in
                            Button {
                                detailTab = tab
                            } label: {
                                VStack(spacing: 7) {
                                    Text(tab)
                                        .font(.caption.weight(detailTab == tab ? .bold : .medium))
                                        .foregroundStyle(detailTab == tab ? .white : Color.liftMuted)
                                    Rectangle()
                                        .fill(detailTab == tab ? Color.liftBlue : Color.clear)
                                        .frame(height: 2)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if detailTab == "Weeks" {
                Button {
                    let week = appState.addWeekToSelectedPlan()
                    selectedWeekID = week.id
                } label: {
                    Label("Add Week", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.liftBlue)
                weekTabs
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

    private var weekTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.selectedPlanWeeks) { week in
                    Button {
                        selectedWeekID = week.id
                    } label: {
                        Text("Week \(week.weekNumber)")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(week.id == selectedWeek?.id ? Color.liftBlue : Color.liftCard)
                            .foregroundStyle(week.id == selectedWeek?.id ? .white : Color.liftMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var weekSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedWeek {
                let sessions = appState.sessions(for: selectedWeek)
                if sessions.isEmpty {
                    emptyPlanCard(title: "No workout days yet", message: "Add workout days like Monday Push, Tuesday Pull, or Friday Legs.")
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
        emptyPlanCard(title: "Plan notes", message: appState.selectedWorkoutPlan?.notes.isEmpty == false ? appState.selectedWorkoutPlan?.notes ?? "" : "Notes are ready for the next persistence pass.")
    }

    private func emptyPlanCard(title: String, message: String) -> some View {
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

struct ProgramSessionCard: View {
    @EnvironmentObject private var appState: AppState
    let session: WorkoutSession
    let week: WorkoutWeek
    let onStart: () -> Void
    let onAddExercise: () -> Void
    let onDelete: () -> Void

    var body: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(session.day) - \(session.name)")
                            .font(.headline)
                        let prescriptions = appState.prescriptions(for: session)
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
                    }
                }

                ForEach(appState.prescriptions(for: session)) { prescription in
                    HStack(spacing: 12) {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(Color.liftBlue)
                            .frame(width: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prescription.exerciseName)
                                .font(.subheadline.weight(.semibold))
                            Text("\(prescription.sets) sets x \(prescription.reps) - \(prescription.bodyPart)")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack {
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
                    .tint(Color.liftGreen)
                }
            }
        }
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

    private var regions: [ExerciseBodyRegion] {
        ExerciseBodyRegionResolver.regions(for: exercise.bodyPart)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.liftBlue.opacity(0.10))

                Image(systemName: "figure.stand")
                    .font(.system(size: geometry.size.height * 0.72, weight: .medium))
                    .foregroundStyle(regions.contains(.fullBody) ? Color.liftBlue : Color.liftMuted.opacity(0.55))

                if !regions.contains(.fullBody) {
                    ForEach(regions, id: \.self) { region in
                        ExerciseBodyRegionMarker(region: region, size: geometry.size)
                    }
                }
            }
        }
        .frame(width: 54, height: 54)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(exercise.bodyPart) exercise")
    }
}

private struct ExerciseBodyRegionMarker: View {
    let region: ExerciseBodyRegion
    let size: CGSize

    @ViewBuilder
    var body: some View {
        switch region {
        case .neck:
            marker(width: 0.11, height: 0.07, x: 0.50, y: 0.25)
        case .shoulders:
            marker(width: 0.43, height: 0.09, x: 0.50, y: 0.33)
        case .chest:
            marker(width: 0.29, height: 0.13, x: 0.50, y: 0.39)
        case .back:
            marker(width: 0.43, height: 0.15, x: 0.50, y: 0.42)
        case .arms:
            pairedMarker(width: 0.08, height: 0.25, xOffset: 0.18, y: 0.45)
        case .core:
            marker(width: 0.20, height: 0.15, x: 0.50, y: 0.52)
        case .glutes:
            marker(width: 0.25, height: 0.10, x: 0.50, y: 0.61)
        case .upperLegs:
            pairedMarker(width: 0.10, height: 0.24, xOffset: 0.08, y: 0.72)
        case .lowerLegs:
            pairedMarker(width: 0.075, height: 0.22, xOffset: 0.07, y: 0.88)
        case .fullBody:
            EmptyView()
        }
    }

    private func marker(width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Capsule()
            .fill(Color.liftBlue.opacity(0.92))
            .frame(width: size.width * width, height: size.height * height)
            .position(x: size.width * x, y: size.height * y)
    }

    private func pairedMarker(width: CGFloat, height: CGFloat, xOffset: CGFloat, y: CGFloat) -> some View {
        HStack(spacing: size.width * xOffset) {
            Capsule().fill(Color.liftBlue.opacity(0.92))
            Capsule().fill(Color.liftBlue.opacity(0.92))
        }
        .frame(width: size.width * (width * 2 + xOffset), height: size.height * height)
        .position(x: size.width * 0.50, y: size.height * y)
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

    private var filteredExercises: [TrainingExerciseCatalogItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return appState.trainingExerciseLibrary
            .filter { $0.matchesSearch(query) }
            .filter { selectedBodyPart == "All" || matchesBodyPart($0, filter: selectedBodyPart) }
            .filter { selectedEquipment == "All" || $0.equipment == selectedEquipment }
            .sorted { lhs, rhs in
                let lhsExists = existingExerciseIDs.contains(lhs.id)
                let rhsExists = existingExerciseIDs.contains(rhs.id)
                if lhsExists != rhsExists { return !lhsExists }
                return lhs.name < rhs.name
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
                                ForEach(filteredExercises) { exercise in
                                    exerciseRow(exercise)
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

    private func exerciseRow(_ exercise: TrainingExerciseCatalogItem) -> some View {
        let isExisting = existingExerciseIDs.contains(exercise.id)
        let isSelected = selectedExerciseIDs.contains(exercise.id)

        return HStack(spacing: 12) {
            ExerciseCatalogIcon(exercise: exercise)
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
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
                    .frame(width: 34, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview and configure \(exercise.name)")

            Button {
                toggleSelection(exercise)
            } label: {
                Image(systemName: isExisting || isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(isExisting ? Color.liftGreen : isSelected ? Color.liftBlue : Color.liftMuted)
                    .frame(width: 38, height: 40)
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

private struct LegacyProgramAddExercisePickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    @State private var searchText = ""
    @State private var selectedExercise: TrainingExerciseCatalogItem?

    private var filteredExercises: [TrainingExerciseCatalogItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return popularExercises
        }
        return appState.trainingExerciseLibrary.filter { exercise in
            exercise.matchesSearch(query)
        }
        .sorted { $0.name < $1.name }
    }

    private var popularExercises: [TrainingExerciseCatalogItem] {
        let popularIDs = ["barbell_bench_press", "incline_db_press", "machine_chest_press", "cable_fly", "pec_deck"]
        return popularIDs.compactMap { id in
            appState.trainingExerciseLibrary.first { $0.id == id }
        }
    }

    private var sectionTitle: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Popular Exercises" : "Search Results"
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("\(session.day) • \(session.name)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.liftMuted)

                            searchField

                            Text(sectionTitle)
                                .font(.headline)

                            VStack(spacing: 10) {
                                ForEach(filteredExercises) { exercise in
                                    exerciseRow(exercise)
                                }
                            }
                        }
                        .padding()
                    }
                    .scrollIndicators(.hidden)

                    NavigationLink {
                        CreateCustomExerciseView(session: session) {
                            dismiss()
                        }
                        .environmentObject(appState)
                    } label: {
                        Label("Create Custom Exercise", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liftBlue)
                    .padding()
                    .background(Color.liftBackground)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedExercise) { exercise in
                AddExerciseToWorkoutView(exercise: exercise, session: session) {
                    dismiss()
                }
                .environmentObject(appState)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.liftMuted)
            TextField("Search exercises...", text: $searchText)
                .textFieldStyle(.plain)
                .submitLabel(.search)
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func exerciseRow(_ exercise: TrainingExerciseCatalogItem) -> some View {
        HStack(spacing: 12) {
            ExerciseCatalogIcon(exercise: exercise)
            VStack(alignment: .leading, spacing: 4) {
                Text(popularDisplayName(for: exercise))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(exercise.bodyPart) • \(exercise.equipment)")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            Spacer()
            Button {
                selectedExercise = exercise
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.liftBlue)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Add \(exercise.name)")
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func popularDisplayName(for exercise: TrainingExerciseCatalogItem) -> String {
        switch exercise.id {
        case "barbell_bench_press":
            return "Bench Press"
        case "incline_db_press":
            return "Incline Bench Press"
        default:
            return exercise.name
        }
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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Exercise Name", text: $name)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(Color.black.opacity(0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Picker("Muscle Group", selection: $muscleGroup) {
                                    ForEach(muscleGroups, id: \.self) { Text($0).tag($0) }
                                }

                                Picker("Equipment", selection: $equipment) {
                                    ForEach(equipmentOptions, id: \.self) { Text($0).tag($0) }
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Tracking Type")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.liftMuted)
                                    ForEach(trackingTypes, id: \.self) { option in
                                        ProgramChoiceRow(title: option, isSelected: trackingType == option) {
                                            trackingType = option
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)

                Button {
                    if let exercise = appState.saveCustomExercise(name: name, bodyPart: muscleGroup, equipment: equipment, trackingType: trackingType) {
                        createdExercise = exercise
                    }
                } label: {
                    Text("Save Exercise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.liftBlue)
                .padding()
                .background(Color.liftBackground)
            }
        }
        .navigationTitle("Create Custom Exercise")
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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        LiftCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(exercise.name)
                                    .font(.title2.bold())
                                Text("\(exercise.bodyPart) • \(exercise.equipment) • \(exercise.trackingType)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }

                        LiftCard {
                            VStack(alignment: .leading, spacing: 16) {
                                IntegerInputField(title: "Sets", value: $sets, presentation: .inset)

                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Rep Goal")
                                        .font(.headline)
                                    FlowChipGroup(options: repGoals, selected: $repGoal)
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Rest Time")
                                        .font(.headline)
                                    HStack {
                                        ForEach(restOptions, id: \.self) { seconds in
                                            ProgramChoiceChip(title: "\(seconds) sec", isSelected: restSeconds == seconds) {
                                                restSeconds = seconds
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)

                Button {
                    appState.addExercise(exercise, to: session, sets: sets, reps: repGoal, restSeconds: restSeconds)
                    onAdded()
                } label: {
                    Text("Add to Workout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.liftBlue)
                .padding()
                .background(Color.liftBackground)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sets = exercise.defaultSets
            if repGoals.contains(exercise.defaultReps) {
                repGoal = exercise.defaultReps
            }
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
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.liftBlue : Color.liftMuted)
            }
            .padding(13)
            .background(isSelected ? Color.liftBlue.opacity(0.18) : Color.black.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.liftBlue : Color.black.opacity(0.18))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutSessionRunView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    @State private var startedAt = Date()
    @State private var showingSummary = false
    @State private var showingAddExercise = false
    @State private var showingCancelConfirmation = false
    @State private var showingFinishConfirmation = false

    private var prescriptions: [WorkoutExercisePrescription] {
        appState.prescriptions(for: session)
    }

    private var completedSetCount: Int {
        prescriptions.flatMap { appState.activeSetLogs(for: $0) }.filter(\.isComplete).count
    }

    private var plannedSetCount: Int {
        prescriptions.reduce(0) { $0 + $1.sets }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    activeHeader
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if prescriptions.isEmpty {
                                emptyCard
                            } else {
                                HStack {
                                    Text("Exercises")
                                        .font(.title3.weight(.black))
                                    Spacer()
                                    Text("\(completedSetCount)/\(plannedSetCount) sets")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.liftMuted)
                                }

                                ForEach(prescriptions) { prescription in
                                    NavigationLink {
                                        PrescriptionTrackView(prescription: prescription)
                                            .environmentObject(appState)
                                    } label: {
                                        prescriptionCard(prescription)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                    workoutControls
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSummary) {
                WorkoutSummaryView(summary: appState.workoutSummary(for: session)) { effort, notes in
                    appState.completeWorkout(session, effort: effort, notes: notes)
                    showingSummary = false
                    dismiss()
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                ProgramAddExercisePickerView(session: session)
                    .environmentObject(appState)
                    .presentationDetents([.large])
            }
            .confirmationDialog("Cancel this workout?", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
                Button("Cancel Workout", role: .destructive) {
                    appState.cancelWorkout(session)
                    dismiss()
                }
                Button("Keep Working Out", role: .cancel) {}
            } message: {
                Text("This discards today's logged sets. Freestyle workouts are removed from the plan.")
            }
            .confirmationDialog(
                completedSetCount < plannedSetCount ? "Finish with incomplete sets?" : "Finish this workout?",
                isPresented: $showingFinishConfirmation,
                titleVisibility: .visible
            ) {
                Button("Finish Workout") {
                    showingSummary = true
                }
                Button("Keep Training", role: .cancel) {}
            } message: {
                if completedSetCount < plannedSetCount {
                    Text("\(plannedSetCount - completedSetCount) planned sets are still incomplete. Your completed work will remain in the summary.")
                } else {
                    Text("Review your completed sets, volume, and best performance.")
                }
            }
        }
    }

    private func elapsedText(at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(startedAt)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var activeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.headline.weight(.bold))
                        .frame(width: 42, height: 42)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Minimize workout")

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.day.uppercased())
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(Color.liftBlue)
                    Text(session.name)
                        .font(.headline.weight(.black))
                        .lineLimit(2)
                }

                Spacer()

                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    Text(elapsedText(at: context.date))
                        .font(.title3.weight(.black).monospacedDigit())
                        .foregroundStyle(Color.liftBlue)
                }

                Menu {
                    Button {
                        showingAddExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                    Button(role: .destructive) {
                        showingCancelConfirmation = true
                    } label: {
                        Label("Cancel Workout", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.bold))
                        .frame(width: 42, height: 42)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                }
            }

            let summary = appState.workoutSummary(for: session)
            ProgressView(value: Double(completedSetCount), total: Double(max(1, plannedSetCount)))
                .tint(Color.liftBlue)

            HStack(spacing: 14) {
                Label("\(summary.completedExercises)/\(summary.totalExercises) exercises", systemImage: "dumbbell.fill")
                Label("\(completedSetCount)/\(plannedSetCount) sets", systemImage: "checkmark.circle.fill")
                Spacer()
                Text("\(Int(summary.totalVolume)) lb")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.liftMuted)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.liftCardRaised, Color.liftBackground],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.white.opacity(0.06))
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(Color.liftBlue)
                .frame(width: 90, height: 90)
                .background(Color.liftBlue.opacity(0.10))
                .clipShape(Circle())
            Text("Build this workout")
                .font(.title2.weight(.black))
            Text("Add an exercise or choose from your library to start logging sets.")
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
                .multilineTextAlignment(.center)
            Button {
                showingAddExercise = true
            } label: {
                Label("Add first exercise", systemImage: "plus")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.liftBlue)
                    .foregroundStyle(Color.liftBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func prescriptionCard(_ prescription: WorkoutExercisePrescription) -> some View {
        let logs = appState.activeSetLogs(for: prescription)
        let completed = logs.filter(\.isComplete).count
        let isComplete = completed >= prescription.sets

        return HStack(spacing: 12) {
            Image(systemName: isComplete ? "checkmark" : prescriptionSymbol(prescription.exerciseName))
                .font(.headline.weight(.bold))
                .foregroundStyle(isComplete ? Color.liftBackground : Color.liftBlue)
                .frame(width: 44, height: 44)
                .background(isComplete ? Color.liftGreen : Color.liftBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(prescription.exerciseName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                HStack(spacing: 7) {
                    Text("\(prescription.sets) × \(prescription.reps)")
                    Text("•")
                    Text("\(prescription.restSeconds)s rest")
                }
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(isComplete ? "Done" : "\(completed)/\(prescription.sets)")
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
            Button {
                showingAddExercise = true
            } label: {
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

    private func prescriptionSymbol(_ name: String) -> String {
        let value = name.lowercased()
        if value.contains("squat") || value.contains("leg") { return "figure.strengthtraining.functional" }
        if value.contains("bench") || value.contains("press") { return "figure.strengthtraining.traditional" }
        return "dumbbell.fill"
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

struct PrescriptionTrackView: View {
    @EnvironmentObject private var appState: AppState
    let prescription: WorkoutExercisePrescription
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
                                    Text(prescription.exerciseName)
                                        .font(.title3.weight(.black))
                                    Text("Target: \(prescription.sets) × \(prescription.reps)")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Spacer()
                                Text("\(completedLogs.count)/\(prescription.sets)")
                                    .font(.headline.weight(.black).monospacedDigit())
                                    .foregroundStyle(completedLogs.count >= prescription.sets ? Color.liftGreen : Color.liftBlue)
                            }

                            HStack(spacing: 8) {
                                compactExerciseMetric("\(prescription.restSeconds)s", "timer")
                                compactExerciseMetric("\(Int(completedVolume)) lb", "scalemass")
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
                                    previousLog: appState.previousSetLog(for: prescription, setNumber: log.setNumber),
                                    focusedInput: $focusedInput
                                ) {
                                    restEndsAt = .now.addingTimeInterval(TimeInterval(prescription.restSeconds))
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
                    _ = appState.addSetLog(to: prescription)
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
        }
    }

    private var activeLogs: [WorkoutSetLog] {
        appState.activeSetLogs(for: prescription)
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
        appState.activeSetLogs(for: prescription).filter(\.isComplete)
    }

    private var completedVolume: Double {
        completedLogs.reduce(0) { total, log in
            total + (log.weight ?? 0) * Double(log.reps ?? 0)
        }
    }

    private var mostRecentCompletedLog: WorkoutSetLog? {
        appState.setLogs(for: prescription)
            .filter { $0.isComplete && !Calendar.current.isDateInToday($0.performedAt) }
            .max { $0.performedAt < $1.performedAt }
    }

    private var catalogExercise: TrainingExerciseCatalogItem {
        appState.trainingExerciseLibrary.first { $0.name == prescription.exerciseName } ??
            TrainingExerciseCatalogItem(
                id: prescription.exerciseID,
                name: prescription.exerciseName,
                bodyPart: prescription.bodyPart,
                workoutCategory: prescription.bodyPart,
                defaultSets: prescription.sets,
                defaultReps: prescription.reps,
                symbolName: "dumbbell.fill",
                equipment: "Weights"
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
            Text("LBS").frame(width: 72)
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
                    total: Double(max(1, prescription.restSeconds))
                )
                .tint(Color.liftBlue)
            }
            .onChange(of: remaining) { _, value in
                if value == 0 {
                    restEndsAt = nil
                    Haptics.success()
                }
            }
        }
    }

    private func ensureTargetSetsExist() {
        let existing = appState.activeSetLogs(for: prescription).count
        guard existing < prescription.sets else { return }
        for _ in existing..<prescription.sets {
            _ = appState.addSetLog(to: prescription)
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
                    }

                compactField("Lbs", text: $weightText, width: 72, field: .weight)
                    .keyboardType(.decimalPad)
                    .onChange(of: weightText) { _, _ in
                        draft.weight = parsedWeight
                        appState.updateSetLog(draft)
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
        draft.isComplete.toggle()
        draft.performedAt = .now
        appState.updateSetLog(draft)
        if completing {
            Haptics.success()
            onCompleted?()
        }
    }

    private static func formatWeight(_ value: Double) -> String {
        RankingCalculator.format(value)
    }
}

struct WorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let summary: WorkoutSummary
    let onComplete: (Int, String) -> Void
    @State private var effort = 3
    @State private var notes = ""

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

                        if let best = summary.bestSet {
                            HStack(spacing: 12) {
                                Image(systemName: "trophy.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.liftGold)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Best set")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.liftMuted)
                                    Text("\(best.weight.map { RankingCalculator.format($0) } ?? "--") lb × \(best.reps ?? 0)")
                                        .font(.headline.weight(.black))
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.liftGold.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                            onComplete(effort, notes)
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
        }
    }

    private var shareText: String {
        "Completed \(summary.workoutName): \(summary.totalSets) sets and \(Int(summary.totalVolume)) lb volume in LiftRank."
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

struct WorkoutExerciseRow: View {
    let entry: WorkoutExerciseEntry

    var body: some View {
        LiftCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: entry.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(entry.isDone ? Color.liftGreen : Color.liftMuted)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.exercise)
                        .font(.headline)
                    Text("\(entry.targetSets) sets - \(entry.targetReps) reps - \(entry.muscleGroup)")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    if let best = entry.bestSet, let weight = best.weight, let reps = best.reps {
                        Text("Top set: \(RankingCalculator.format(weight)) x \(reps) @ RPE \(best.rpe ?? 0)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftBlue)
                    }
                    if !entry.notes.isEmpty {
                        Text(entry.notes)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.liftMuted)
            }
        }
    }
}

struct WorkoutExerciseInlineRow: View {
    let entry: WorkoutExerciseEntry

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.liftBlue.opacity(0.12))
                Image(systemName: symbol(for: entry.muscleGroup))
                    .font(.title3)
                    .foregroundStyle(Color.liftBlue)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.exercise)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(entry.targetSets) sets x \(entry.targetReps) reps")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.18))
                    .foregroundStyle(Color.liftMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                if let best = entry.bestSet, let weight = best.weight, let reps = best.reps {
                    Text("Top set: \(RankingCalculator.format(weight)) x \(reps)")
                        .font(.caption)
                        .foregroundStyle(Color.liftBlue)
                }
            }
            Spacer()
            Image(systemName: entry.isDone ? "checkmark.circle.fill" : "chevron.right")
                .foregroundStyle(entry.isDone ? Color.liftGreen : Color.liftMuted)
        }
        .padding(12)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func symbol(for muscle: String) -> String {
        let lower = muscle.lowercased()
        if lower.contains("quad") || lower.contains("hamstring") || lower.contains("glute") { return "figure.strengthtraining.functional" }
        if lower.contains("chest") { return "figure.strengthtraining.traditional" }
        if lower.contains("back") || lower.contains("lat") { return "arrow.down.to.line.compact" }
        if lower.contains("shoulder") { return "arrow.up.circle.fill" }
        if lower.contains("core") { return "figure.core.training" }
        return "dumbbell.fill"
    }
}

struct ExerciseLogView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: WorkoutExerciseEntry

    init(entry: WorkoutExerciseEntry) {
        var seeded = entry
        if seeded.sets.isEmpty {
            seeded.sets = (0..<max(1, seeded.targetSets)).map { _ in
                WorkoutSetEntry(id: UUID(), weight: nil, reps: nil, rpe: nil)
            }
        }
        _draft = State(initialValue: seeded)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        exerciseTrackHeader
                        ForEach(Array(draft.sets.indices), id: \.self) { index in
                            SetTrackRow(index: index, set: $draft.sets[index])
                        }
                        Button {
                            draft.sets.append(WorkoutSetEntry(id: UUID(), weight: nil, reps: nil, rpe: nil))
                        } label: {
                            Label("Add Set", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liftBlue)
                        Toggle("Completed", isOn: $draft.isDone)
                            .padding()
                            .background(Color.liftCard)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        TextField("Notes", text: $draft.notes, axis: .vertical)
                            .lineLimit(3...5)
                            .padding()
                            .background(Color.liftCard)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding()
                }
            }
            .navigationTitle("Log Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.updateWorkoutEntry(draft)
                        if let best = draft.bestSet, let weight = best.weight, let reps = best.reps {
                            modelContext.insert(PersistentWorkoutRecord(id: UUID(), exercise: draft.exercise, workout: draft.workout, weight: weight, reps: reps, rpe: best.rpe ?? 0, performedAt: draft.date))
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    private var exerciseTrackHeader: some View {
        LiftCard {
            VStack(alignment: .center, spacing: 16) {
                HStack {
                    Spacer()
                    Menu {
                        Button {
                            draft.sets.append(WorkoutSetEntry(id: UUID(), weight: nil, reps: nil, rpe: nil))
                        } label: {
                            Label("Add Set", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                Text(draft.exercise)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Reps: \(draft.targetReps)   Sets: \(draft.targetSets)")
                    .font(.headline)
                    .foregroundStyle(Color.liftMuted)
                HStack(spacing: 14) {
                    trackToolButton("arrow.counterclockwise")
                    trackToolButton("timer")
                    trackToolButton("function")
                    trackToolButton("plus.video.fill")
                }
            }
        }
    }

    private func trackToolButton(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.headline)
            .foregroundStyle(Color.liftBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.liftBlue.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SetTrackRow: View {
    let index: Int
    @Binding var set: WorkoutSetEntry

    var body: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Set \(index + 1)")
                        .font(.title2.bold())
                        .frame(width: 82, alignment: .leading)
                    SetValueField(title: "Reps", value: Binding(
                        get: { set.reps },
                        set: { set.reps = $0 }
                    ), unit: "reps")
                    SetValueField(title: "Weight", value: Binding(
                        get: { set.weight.map(Int.init) },
                        set: { set.weight = $0.map(Double.init) }
                    ), unit: "lbs")
                }
                HStack {
                    Spacer()
                    OptionalIntegerInputField(title: "RPE", value: Binding(
                        get: { set.rpe },
                        set: { set.rpe = $0 }
                    ), presentation: .inset)
                    .frame(maxWidth: 150)
                }
            }
        }
    }
}

struct SetValueField: View {
    let title: String
    @Binding var value: Int?
    let unit: String
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(title: String, value: Binding<Int?>, unit: String) {
        self.title = title
        self._value = value
        self.unit = unit
        self._text = State(initialValue: value.wrappedValue.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField(title, text: $text)
                    .focused($isFocused)
                    .keyboardType(.numberPad)
                    .font(.title2.weight(.black))
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 62)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(unit)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
            Text(value.map { "Last: \($0) \(unit)" } ?? "Last: -- \(unit)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
        }
        .padding(10)
        .background(Color.liftBlue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onChange(of: text) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            value = trimmed.isEmpty ? nil : Int(trimmed)
        }
        .onChange(of: value) { _, newValue in
            if !isFocused {
                text = newValue.map(String.init) ?? ""
            }
        }
    }
}

enum WorkoutEntryComposerMode {
    case planned
    case freestyle
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

struct AddExercisePickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let planID: UUID
    let week: Int
    let initialWorkoutName: String
    @State private var tab = "Library"
    @State private var searchText = ""
    @State private var bodyPartFilter = "All"
    @State private var categoryFilter = "All"
    @State private var selectedIDs = Set<String>()
    @State private var workoutName: String
    @State private var day: String
    @State private var customExerciseName = ""
    @State private var customBodyPart = "Chest"
    @State private var customSets = 3
    @State private var customReps = "8-12"

    private let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    init(planID: UUID, week: Int, initialWorkoutName: String) {
        self.planID = planID
        self.week = week
        self.initialWorkoutName = initialWorkoutName
        _workoutName = State(initialValue: initialWorkoutName)
        _day = State(initialValue: Self.currentWeekday())
    }

    private var bodyPartOptions: [String] {
        ["All"] + Set(MockData.trainingExerciseLibrary.map(\.bodyPart)).sorted()
    }

    private var categoryOptions: [String] {
        ["All"] + Set(MockData.trainingExerciseLibrary.map(\.workoutCategory)).sorted()
    }

    private var customBodyPartOptions: [String] {
        Array(Set(["Chest", "Back", "Quads", "Hamstrings", "Glutes", "Shoulders", "Arms", "Core", "Full Body"] + MockData.trainingExerciseLibrary.map(\.bodyPart))).sorted()
    }

    private var filteredExercises: [TrainingExerciseCatalogItem] {
        MockData.trainingExerciseLibrary.filter { exercise in
            let matchesSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.bodyPart.localizedCaseInsensitiveContains(searchText)
            let matchesBodyPart = bodyPartFilter == "All" || exercise.bodyPart == bodyPartFilter
            let matchesCategory = categoryFilter == "All" || exercise.workoutCategory == categoryFilter
            return matchesSearch && matchesBodyPart && matchesCategory
        }
        .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Picker("Add exercise mode", selection: $tab) {
                                Text("Library").tag("Library")
                                Text("Custom").tag("Custom")
                            }
                            .pickerStyle(.segmented)

                            workoutTargetCard

                            if tab == "Library" {
                                libraryPicker
                            } else {
                                customForm
                            }
                        }
                        .padding()
                    }

                    if tab == "Library" {
                        Button {
                            addSelectedExercises()
                        } label: {
                            Text("Add \(selectedIDs.count) Exercise\(selectedIDs.count == 1 ? "" : "s")")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liftRed)
                        .padding()
                        .disabled(selectedIDs.isEmpty)
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var workoutTargetCard: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add to Week \(week)")
                    .font(.headline)
                TextField("Workout name", text: $workoutName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.black.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Picker("Training day", selection: $day) {
                    ForEach(days, id: \.self) { day in
                        Text(day).tag(day)
                    }
                }
            }
        }
    }

    private var libraryPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.liftMuted)
                TextField("Search for an exercise", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(14)
            .background(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                filterMenu(title: "Muscle", selection: $bodyPartFilter, options: bodyPartOptions)
                filterMenu(title: "Type", selection: $categoryFilter, options: categoryOptions)
            }

            ForEach(filteredExercises) { exercise in
                Button {
                    toggle(exercise)
                } label: {
                    HStack(spacing: 12) {
                        exerciseIcon(for: exercise)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("\(exercise.bodyPart) - \(exercise.defaultSets) sets x \(exercise.defaultReps)")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        Image(systemName: selectedIDs.contains(exercise.id) ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(selectedIDs.contains(exercise.id) ? Color.liftGreen : Color.liftBlue)
                    }
                    .padding(14)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var customForm: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Exercise name", text: $customExerciseName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.black.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Picker("Muscle group", selection: $customBodyPart) {
                    ForEach(customBodyPartOptions, id: \.self) { bodyPart in
                        Text(bodyPart).tag(bodyPart)
                    }
                }
                IntegerInputField(title: "Sets", value: $customSets, presentation: .inset)
                TextField("Reps, e.g. 8-12", text: $customReps)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.black.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button {
                    addCustomExercise()
                } label: {
                    Label("Add Custom Exercise", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.liftBlue)
                .disabled(customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || customReps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func filterMenu(title: String, selection: Binding<String>, options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    selection.wrappedValue = option
                }
            }
        } label: {
            HStack {
                Text(selection.wrappedValue == "All" ? title : selection.wrappedValue)
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

    private func exerciseIcon(for exercise: TrainingExerciseCatalogItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.liftBlue.opacity(0.12))
            Image(systemName: exercise.symbolName)
                .font(.title3)
                .foregroundStyle(Color.liftBlue)
        }
        .frame(width: 54, height: 54)
    }

    private func toggle(_ exercise: TrainingExerciseCatalogItem) {
        if selectedIDs.contains(exercise.id) {
            selectedIDs.remove(exercise.id)
        } else {
            selectedIDs.insert(exercise.id)
        }
    }

    private func addSelectedExercises() {
        for exercise in MockData.trainingExerciseLibrary where selectedIDs.contains(exercise.id) {
            appState.addWorkoutEntry(entry(from: exercise))
        }
        dismiss()
    }

    private func addCustomExercise() {
        appState.addWorkoutEntry(
            WorkoutExerciseEntry(
                id: UUID(),
                planID: planID,
                week: week,
                date: Date(),
                day: day,
                workout: cleanWorkoutName,
                exercise: customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines),
                muscleGroup: customBodyPart,
                targetSets: customSets,
                targetReps: customReps.trimmingCharacters(in: .whitespacesAndNewlines),
                sets: [],
                isDone: false,
                notes: ""
            )
        )
        dismiss()
    }

    private func entry(from exercise: TrainingExerciseCatalogItem) -> WorkoutExerciseEntry {
        WorkoutExerciseEntry(
            id: UUID(),
            planID: planID,
            week: week,
            date: Date(),
            day: day,
            workout: cleanWorkoutName,
            exercise: exercise.name,
            muscleGroup: exercise.bodyPart,
            targetSets: exercise.defaultSets,
            targetReps: exercise.defaultReps,
            sets: [],
            isDone: false,
            notes: ""
        )
    }

    private var cleanWorkoutName: String {
        let trimmed = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? initialWorkoutName : trimmed
    }

    private static func currentWeekday() -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return Calendar.current.weekdaySymbols[max(0, min(Calendar.current.weekdaySymbols.count - 1, weekday - 1))]
    }
}

struct WorkoutEntryComposerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let mode: WorkoutEntryComposerMode
    let planID: UUID
    let week: Int
    @State private var workoutName: String
    @State private var exerciseName = ""
    @State private var muscleGroup = "Chest"
    @State private var day: String
    @State private var targetSets = 3
    @State private var targetReps = "8-12"
    @State private var sets: [WorkoutSetEntry]
    @State private var notes = ""

    private let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    private var muscleGroups: [String] {
        let base = ["Chest", "Back", "Quads", "Hamstrings", "Glutes", "Shoulders", "Arms", "Core", "Full Body"]
        return Array(Set(base + MockData.trainingExerciseLibrary.map(\.bodyPart))).sorted()
    }

    init(mode: WorkoutEntryComposerMode, planID: UUID, week: Int, template: TrainingExerciseCatalogItem? = nil) {
        self.mode = mode
        self.planID = planID
        self.week = week
        let isFreestyle = mode == .freestyle
        _workoutName = State(initialValue: isFreestyle ? "Freestyle Workout" : template?.workoutCategory ?? "My Workout")
        _exerciseName = State(initialValue: template?.name ?? "")
        _muscleGroup = State(initialValue: template?.bodyPart ?? "Chest")
        _day = State(initialValue: Self.currentWeekday())
        _targetSets = State(initialValue: template?.defaultSets ?? 3)
        _targetReps = State(initialValue: template?.defaultReps ?? "8-12")
        _sets = State(initialValue: isFreestyle ? [WorkoutSetEntry(id: UUID(), weight: nil, reps: nil, rpe: nil)] : [])
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(mode == .freestyle ? "Freestyle Workout" : "Add to Plan")
                                    .font(.title2.bold())
                                TextField("Workout name", text: $workoutName)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(Color.black.opacity(0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                TextField("Exercise name", text: $exerciseName)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(Color.black.opacity(0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Picker("Muscle group", selection: $muscleGroup) {
                                    ForEach(muscleGroups, id: \.self) { muscle in
                                        Text(muscle).tag(muscle)
                                    }
                                }
                                Picker("Training day", selection: $day) {
                                    ForEach(days, id: \.self) { day in
                                        Text(day).tag(day)
                                    }
                                }
                                IntegerInputField(title: "Target sets", value: $targetSets, presentation: .inset)
                                TextField("Target reps, e.g. 8-12", text: $targetReps)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(Color.black.opacity(0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        if mode == .freestyle {
                            freestyleSets
                        }
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...5)
                            .padding()
                            .background(Color.liftCard)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding()
                }
            }
            .navigationTitle(mode == .freestyle ? "Freestyle" : "New Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var freestyleSets: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sets")
            ForEach($sets) { $set in
                LiftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        OptionalNumericInputField(title: "Weight", value: Binding(
                            get: { set.weight },
                            set: { set.weight = $0 }
                        ), unit: "lb")
                        OptionalIntegerInputField(title: "Reps", value: Binding(
                            get: { set.reps },
                            set: { set.reps = $0 }
                        ))
                        OptionalIntegerInputField(title: "RPE", value: Binding(
                            get: { set.rpe },
                            set: { set.rpe = $0 }
                        ))
                    }
                }
            }
            Button {
                sets.append(WorkoutSetEntry(id: UUID(), weight: nil, reps: nil, rpe: nil))
            } label: {
                Label("Add Set", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.liftBlue)
        }
    }

    private var canSave: Bool {
        !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        targetSets > 0 &&
        !targetReps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let entry = WorkoutExerciseEntry(
            id: UUID(),
            planID: planID,
            week: week,
            date: Date(),
            day: day,
            workout: workoutName.trimmingCharacters(in: .whitespacesAndNewlines),
            exercise: exerciseName.trimmingCharacters(in: .whitespacesAndNewlines),
            muscleGroup: muscleGroup,
            targetSets: targetSets,
            targetReps: targetReps.trimmingCharacters(in: .whitespacesAndNewlines),
            sets: mode == .freestyle ? sets : [],
            isDone: mode == .freestyle,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        appState.addWorkoutEntry(entry)
        dismiss()
    }

    private static func currentWeekday() -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return Calendar.current.weekdaySymbols[max(0, min(Calendar.current.weekdaySymbols.count - 1, weekday - 1))]
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
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Week \(draft.week)")
                                .font(.title3.weight(.black))
                            Text(draft.targetDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                    }

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
                            .background(Color.liftCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
