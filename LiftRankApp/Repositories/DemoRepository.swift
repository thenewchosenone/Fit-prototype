import Foundation
import Combine

@MainActor
final class DemoRepository: ObservableObject {
    @Published var currentProfile: UserProfile
    @Published var profiles: [UserProfile]
    @Published var gyms: [Gym]
    @Published var joinedGymIDs: Set<UUID>
    @Published var lifts: [LiftSubmission]
    @Published var challenges: [Challenge]
    @Published var achievements: [Achievement]
    @Published var activities: [ActivityItem]
    @Published var activityComments: [ActivityComment]
    @Published var notifications: [NotificationItem]
    @Published var workoutPlans: [WorkoutPlan]
    @Published var workoutPhases: [WorkoutPhase]
    @Published var workoutWeeks: [WorkoutWeek]
    @Published var workoutSessions: [WorkoutSession]
    @Published var workoutPrescriptions: [WorkoutExercisePrescription]
    @Published var workoutSetLogs: [WorkoutSetLog]
    @Published var workoutFeedback: [WorkoutFeedback]
    @Published var customTrainingExercises: [TrainingExerciseCatalogItem]
    @Published var workoutEntries: [WorkoutExerciseEntry]
    @Published var bodyweightEntries: [BodyweightEntry]
    @Published var communityThreads: [CommunityThread]
    @Published var communityThreadReplies: [CommunityThreadReply]
    @Published var likedCommunityThreadIDs: Set<UUID>
    @Published var gymRequests: [GymRequest]
    @Published var friendRequests: [FriendRequest]
    @Published var messageThreads: [DirectMessageThread]
    @Published var directMessages: [DirectMessage]
    @Published var messageReports: [MessageReport]

    init() {
        let seeded = MockData.community()
        let social = MockData.social(profiles: seeded.profiles)
        let seededThreads = MockData.communityThreads(for: MockData.challenges)
        currentProfile = MockData.demoProfile
        profiles = seeded.profiles
        gyms = MockData.gyms
        joinedGymIDs = [MockData.demoGymID]
        lifts = seeded.lifts
        challenges = MockData.challenges
        achievements = MockData.achievements
        activities = seeded.activities
        activityComments = Self.seedActivityComments(for: seeded.activities, profiles: seeded.profiles)
        workoutPlans = MockData.workoutPlans
        workoutPhases = []
        workoutWeeks = []
        workoutSessions = []
        workoutPrescriptions = []
        workoutSetLogs = []
        workoutFeedback = []
        customTrainingExercises = []
        workoutEntries = MockData.workoutEntries
        bodyweightEntries = MockData.bodyweightEntries
        communityThreads = seededThreads
        communityThreadReplies = Self.seedThreadReplies(for: seededThreads, profiles: seeded.profiles)
        likedCommunityThreadIDs = []
        gymRequests = []
        friendRequests = social.friendRequests
        messageThreads = social.messageThreads
        directMessages = social.messages
        messageReports = []
        notifications = [
            NotificationItem(id: UUID(), title: "Deadlift approved", message: "Your 495 lb deadlift is competition verified.", kind: "Lift approved", createdAt: .now, isRead: false),
            NotificationItem(id: UUID(), title: "Ranking increased", message: "You moved up three spots at Crunch Fitness - South Beach.", kind: "Ranking increased", createdAt: .now, isRead: false),
            NotificationItem(id: UUID(), title: "Achievement earned", message: "2x Bodyweight Deadlift unlocked.", kind: "Achievement earned", createdAt: .now, isRead: true)
        ]
        rebuildProgramBuilderDataFromEntries()
    }

    func reset() {
        let seeded = MockData.community()
        let social = MockData.social(profiles: seeded.profiles)
        let seededThreads = MockData.communityThreads(for: MockData.challenges)
        currentProfile = MockData.demoProfile
        profiles = seeded.profiles
        gyms = MockData.gyms
        joinedGymIDs = [MockData.demoGymID]
        lifts = seeded.lifts
        challenges = MockData.challenges
        achievements = MockData.achievements
        activities = seeded.activities
        activityComments = Self.seedActivityComments(for: seeded.activities, profiles: seeded.profiles)
        workoutPlans = MockData.workoutPlans
        workoutPhases = []
        workoutWeeks = []
        workoutSessions = []
        workoutPrescriptions = []
        workoutSetLogs = []
        workoutFeedback = []
        customTrainingExercises = []
        workoutEntries = MockData.workoutEntries
        bodyweightEntries = MockData.bodyweightEntries
        communityThreads = seededThreads
        communityThreadReplies = Self.seedThreadReplies(for: seededThreads, profiles: seeded.profiles)
        likedCommunityThreadIDs = []
        gymRequests = []
        friendRequests = social.friendRequests
        messageThreads = social.messageThreads
        directMessages = social.messages
        messageReports = []
        rebuildProgramBuilderDataFromEntries()
    }

    private static func seedActivityComments(for activities: [ActivityItem], profiles: [UserProfile]) -> [ActivityComment] {
        guard !activities.isEmpty else { return [] }
        let commenters = Array(profiles.dropFirst().prefix(5))
        guard !commenters.isEmpty else { return [] }
        let commentTemplates = [
            "Clean rep. What was your warmup progression?",
            "That moved fast for a max attempt.",
            "Strong lift. Depth and control looked solid.",
            "Nice work. Are you running this as part of a plan?",
            "That estimated max is climbing quick."
        ]

        return Array(activities.prefix(6)).enumerated().flatMap { activityIndex, activity in
            let count = activityIndex % 2 == 0 ? 2 : 1
            return (0..<count).map { offset in
                let commenter = commenters[(activityIndex + offset) % commenters.count]
                return ActivityComment(
                    id: UUID(),
                    activityID: activity.id,
                    authorID: commenter.id,
                    authorName: commenter.displayName,
                    body: commentTemplates[(activityIndex + offset) % commentTemplates.count],
                    createdAt: activity.createdAt.addingTimeInterval(TimeInterval((offset + 1) * 900))
                )
            }
        }
    }

    private static func seedThreadReplies(for threads: [CommunityThread], profiles: [UserProfile]) -> [CommunityThreadReply] {
        guard !threads.isEmpty else { return [] }
        let commenters = Array(profiles.dropFirst().prefix(6))
        guard !commenters.isEmpty else { return [] }
        let replyTemplates = [
            "Side angle plus the full lockout has worked best for me.",
            "I usually film from hip height so the plates and bar path are clear.",
            "I am training tonight around 7 if anyone wants to run deadlifts.",
            "Good thread. Would be useful to pin examples that got approved.",
            "For lift checks, I try to show the setup and the full rep."
        ]

        return threads.enumerated().flatMap { threadIndex, thread in
            let count = min(max(thread.replyCount, 1), 3)
            return (0..<count).map { offset in
                let commenter = commenters[(threadIndex + offset) % commenters.count]
                return CommunityThreadReply(
                    id: UUID(),
                    threadID: thread.id,
                    authorID: commenter.id,
                    authorName: commenter.displayName,
                    body: replyTemplates[(threadIndex + offset) % replyTemplates.count],
                    createdAt: thread.createdAt.addingTimeInterval(TimeInterval((offset + 1) * 1_200))
                )
            }
        }
    }

    func addLift(_ lift: LiftSubmission) {
        lifts.insert(lift, at: 0)
        activities.insert(ActivityItem(id: UUID(), profile: currentProfile, title: "\(currentProfile.displayName) logged \(lift.exerciseName)", detail: "\(RankingCalculator.format(lift.estimatedOneRepMax)) lb estimated max", liftID: lift.id, createdAt: .now, isLiked: false, isSaved: false), at: 0)
        notifications.insert(NotificationItem(id: UUID(), title: "Lift submitted", message: "Your lift is ready for moderator review.", kind: "Lift submitted", createdAt: .now, isRead: false), at: 0)
    }

    func updateWorkoutEntry(_ entry: WorkoutExerciseEntry) {
        guard let index = workoutEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        workoutEntries[index] = entry
    }

    func addWorkoutEntry(_ entry: WorkoutExerciseEntry) {
        workoutEntries.insert(entry, at: 0)
        activities.insert(ActivityItem(id: UUID(), profile: currentProfile, title: "\(currentProfile.displayName) added \(entry.exercise)", detail: entry.workout, createdAt: .now, isLiked: false, isSaved: false), at: 0)
    }

    func addWorkoutPlan(_ plan: WorkoutPlan) {
        workoutPlans.insert(plan, at: 0)
        createDefaultProgramScaffold(for: plan)
        activities.insert(ActivityItem(id: UUID(), profile: currentProfile, title: "\(currentProfile.displayName) created a workout plan", detail: plan.name, createdAt: plan.createdAt, isLiked: false, isSaved: false), at: 0)
    }

    func deleteWorkoutPlan(_ plan: WorkoutPlan) {
        let phaseIDs = workoutPhases.filter { $0.planID == plan.id }.map(\.id)
        let weekIDs = workoutWeeks.filter { $0.planID == plan.id || phaseIDs.contains($0.phaseID) }.map(\.id)
        let sessionIDs = workoutSessions.filter { weekIDs.contains($0.weekID) }.map(\.id)
        let prescriptionIDs = workoutPrescriptions.filter { sessionIDs.contains($0.sessionID) }.map(\.id)
        workoutPlans.removeAll { $0.id == plan.id }
        workoutPhases.removeAll { $0.planID == plan.id }
        workoutWeeks.removeAll { $0.planID == plan.id }
        workoutSessions.removeAll { weekIDs.contains($0.weekID) }
        workoutPrescriptions.removeAll { sessionIDs.contains($0.sessionID) }
        workoutSetLogs.removeAll { prescriptionIDs.contains($0.prescriptionID) }
        workoutEntries.removeAll { $0.planID == plan.id }
    }

    func updateWorkoutPlan(_ plan: WorkoutPlan) {
        guard let index = workoutPlans.firstIndex(where: { $0.id == plan.id }) else { return }
        workoutPlans[index] = plan
    }

    func duplicateWorkoutPlan(_ plan: WorkoutPlan) -> WorkoutPlan {
        let copy = WorkoutPlan(
            id: UUID(),
            name: "\(plan.name) Copy",
            createdAt: .now,
            goal: plan.goal,
            notes: plan.notes,
            isActive: false
        )
        workoutPlans.insert(copy, at: 0)

        let phases = workoutPhases.filter { $0.planID == plan.id }.sorted { $0.order < $1.order }
        var phaseMap: [UUID: UUID] = [:]
        for phase in phases {
            let newID = UUID()
            phaseMap[phase.id] = newID
            workoutPhases.append(WorkoutPhase(id: newID, planID: copy.id, name: phase.name, order: phase.order, goal: phase.goal, durationWeeks: phase.durationWeeks))
        }

        let weeks = workoutWeeks.filter { $0.planID == plan.id }.sorted { $0.weekNumber < $1.weekNumber }
        var weekMap: [UUID: UUID] = [:]
        for week in weeks {
            guard let newPhaseID = phaseMap[week.phaseID] else { continue }
            let newID = UUID()
            weekMap[week.id] = newID
            workoutWeeks.append(WorkoutWeek(id: newID, planID: copy.id, phaseID: newPhaseID, weekNumber: week.weekNumber, title: week.title, notes: week.notes))
        }

        let sessions = workoutSessions.filter { weekMap.keys.contains($0.weekID) }.sorted { $0.order < $1.order }
        var sessionMap: [UUID: UUID] = [:]
        for session in sessions {
            guard let newWeekID = weekMap[session.weekID] else { continue }
            let newID = UUID()
            sessionMap[session.id] = newID
            workoutSessions.append(WorkoutSession(id: newID, weekID: newWeekID, day: session.day, name: session.name, order: session.order, notes: session.notes))
        }

        let prescriptions = workoutPrescriptions.filter { sessionMap.keys.contains($0.sessionID) }.sorted { $0.order < $1.order }
        for prescription in prescriptions {
            guard let newSessionID = sessionMap[prescription.sessionID] else { continue }
            workoutPrescriptions.append(WorkoutExercisePrescription(
                id: UUID(),
                sessionID: newSessionID,
                exerciseID: prescription.exerciseID,
                exerciseName: prescription.exerciseName,
                bodyPart: prescription.bodyPart,
                equipment: prescription.equipment,
                sets: prescription.sets,
                reps: prescription.reps,
                restSeconds: prescription.restSeconds,
                order: prescription.order,
                notes: prescription.notes
            ))
        }

        activities.insert(ActivityItem(id: UUID(), profile: currentProfile, title: "\(currentProfile.displayName) duplicated a workout plan", detail: copy.name, createdAt: copy.createdAt, isLiked: false, isSaved: false), at: 0)
        return copy
    }

    @discardableResult
    func addWorkoutWeek(planID: UUID, phaseID: UUID? = nil, title: String? = nil) -> WorkoutWeek {
        let phase = phaseID.flatMap { id in workoutPhases.first { $0.id == id } } ?? firstPhase(for: planID)
        let resolvedPhase = phase ?? createDefaultPhase(for: planID)
        let nextNumber = (workoutWeeks.filter { $0.planID == planID }.map(\.weekNumber).max() ?? 0) + 1
        let week = WorkoutWeek(id: UUID(), planID: planID, phaseID: resolvedPhase.id, weekNumber: nextNumber, title: title ?? "Week \(nextNumber)", notes: "")
        workoutWeeks.append(week)
        return week
    }

    @discardableResult
    func cloneWorkoutWeek(_ week: WorkoutWeek) -> WorkoutWeek {
        let newWeek = addWorkoutWeek(planID: week.planID, phaseID: week.phaseID, title: "Week \(nextWeekNumber(for: week.planID))")
        let sessions = workoutSessions.filter { $0.weekID == week.id }.sorted { $0.order < $1.order }
        var sessionMap: [UUID: UUID] = [:]
        for session in sessions {
            let clone = WorkoutSession(id: UUID(), weekID: newWeek.id, day: session.day, name: session.name, order: session.order, notes: session.notes)
            workoutSessions.append(clone)
            sessionMap[session.id] = clone.id
        }
        for prescription in workoutPrescriptions.filter({ sessionMap.keys.contains($0.sessionID) }) {
            guard let newSessionID = sessionMap[prescription.sessionID] else { continue }
            workoutPrescriptions.append(WorkoutExercisePrescription(
                id: UUID(),
                sessionID: newSessionID,
                exerciseID: prescription.exerciseID,
                exerciseName: prescription.exerciseName,
                bodyPart: prescription.bodyPart,
                equipment: prescription.equipment,
                sets: prescription.sets,
                reps: prescription.reps,
                restSeconds: prescription.restSeconds,
                order: prescription.order,
                notes: prescription.notes
            ))
        }
        return newWeek
    }

    func deleteWorkoutWeek(_ week: WorkoutWeek) {
        let sessionIDs = workoutSessions.filter { $0.weekID == week.id }.map(\.id)
        let prescriptionIDs = workoutPrescriptions.filter { sessionIDs.contains($0.sessionID) }.map(\.id)
        workoutWeeks.removeAll { $0.id == week.id }
        workoutSessions.removeAll { $0.weekID == week.id }
        workoutPrescriptions.removeAll { sessionIDs.contains($0.sessionID) }
        workoutSetLogs.removeAll { prescriptionIDs.contains($0.prescriptionID) }
        workoutEntries.removeAll { $0.planID == week.planID && $0.week == week.weekNumber }
    }

    @discardableResult
    func addWorkoutSession(weekID: UUID, day: String, name: String) -> WorkoutSession {
        let nextOrder = (workoutSessions.filter { $0.weekID == weekID }.map(\.order).max() ?? -1) + 1
        let session = WorkoutSession(id: UUID(), weekID: weekID, day: day, name: name, order: nextOrder, notes: "")
        workoutSessions.append(session)
        return session
    }

    func deleteWorkoutSession(_ session: WorkoutSession) {
        guard let week = workoutWeeks.first(where: { $0.id == session.weekID }) else { return }
        let prescriptionIDs = workoutPrescriptions.filter { $0.sessionID == session.id }.map(\.id)
        workoutSessions.removeAll { $0.id == session.id }
        workoutPrescriptions.removeAll { $0.sessionID == session.id }
        workoutSetLogs.removeAll { prescriptionIDs.contains($0.prescriptionID) }
        workoutEntries.removeAll { $0.planID == week.planID && $0.week == week.weekNumber && $0.workout == session.name }
    }

    func cancelWorkoutSession(_ session: WorkoutSession) {
        if session.name.localizedCaseInsensitiveContains("freestyle") {
            deleteWorkoutSession(session)
            return
        }

        let prescriptionIDs = Set(workoutPrescriptions.filter { $0.sessionID == session.id }.map(\.id))
        workoutSetLogs.removeAll { log in
            prescriptionIDs.contains(log.prescriptionID) && Calendar.current.isDateInToday(log.performedAt)
        }
    }

    @discardableResult
    func addWorkoutPrescription(_ prescription: WorkoutExercisePrescription) -> WorkoutExercisePrescription {
        workoutPrescriptions.append(prescription)
        bridgePrescriptionToWorkoutEntry(prescription)
        return prescription
    }

    func deleteWorkoutPrescription(_ prescription: WorkoutExercisePrescription) {
        workoutPrescriptions.removeAll { $0.id == prescription.id }
        workoutSetLogs.removeAll { $0.prescriptionID == prescription.id }
        workoutEntries.removeAll { $0.exercise == prescription.exerciseName && $0.workout == session(for: prescription)?.name }
    }

    func updateWorkoutSetLog(_ log: WorkoutSetLog) {
        if let index = workoutSetLogs.firstIndex(where: { $0.id == log.id }) {
            workoutSetLogs[index] = log
        } else {
            workoutSetLogs.append(log)
        }
    }

    @discardableResult
    func addWorkoutSetLog(prescriptionID: UUID, setNumber: Int? = nil) -> WorkoutSetLog {
        let nextNumber = setNumber ?? ((workoutSetLogs.filter { $0.prescriptionID == prescriptionID }.map(\.setNumber).max() ?? 0) + 1)
        let log = WorkoutSetLog(id: UUID(), prescriptionID: prescriptionID, performedAt: .now, setNumber: nextNumber, weight: nil, reps: nil, rpe: nil, isWarmup: false, isComplete: false)
        workoutSetLogs.append(log)
        return log
    }

    func deleteWorkoutSetLog(_ log: WorkoutSetLog) {
        workoutSetLogs.removeAll { $0.id == log.id }
    }

    func addCustomTrainingExercise(_ exercise: TrainingExerciseCatalogItem) {
        customTrainingExercises.insert(exercise, at: 0)
    }

    func workoutSummary(for session: WorkoutSession) -> WorkoutSummary {
        let prescriptions = workoutPrescriptions.filter { $0.sessionID == session.id }
        let prescriptionIDs = Set(prescriptions.map(\.id))
        let completedLogs = workoutSetLogs.filter { log in
            prescriptionIDs.contains(log.prescriptionID) &&
            log.isComplete &&
            Calendar.current.isDateInToday(log.performedAt)
        }
        let completedExerciseIDs = Set(completedLogs.map(\.prescriptionID))
        let best = completedLogs.max { lhs, rhs in
            (lhs.weight ?? 0) < (rhs.weight ?? 0)
        }
        return WorkoutSummary(
            id: UUID(),
            sessionID: session.id,
            workoutName: session.name,
            completedExercises: completedExerciseIDs.count,
            totalExercises: prescriptions.count,
            totalSets: completedLogs.count,
            totalVolume: completedLogs.reduce(0) { $0 + $1.volume },
            bestSet: best
        )
    }

    func saveWorkoutFeedback(sessionID: UUID, effort: Int, notes: String) {
        let feedback = WorkoutFeedback(
            id: UUID(),
            sessionID: sessionID,
            completedAt: .now,
            effort: min(max(effort, 1), 5),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        workoutFeedback.removeAll { $0.sessionID == sessionID && Calendar.current.isDateInToday($0.completedAt) }
        workoutFeedback.append(feedback)
    }

    private func rebuildProgramBuilderDataFromEntries() {
        workoutPhases.removeAll()
        workoutWeeks.removeAll()
        workoutSessions.removeAll()
        workoutPrescriptions.removeAll()
        workoutSetLogs.removeAll()

        for plan in workoutPlans {
            let entries = workoutEntries.filter { $0.planID == plan.id }
            let maxWeek = max(1, entries.map(\.week).max() ?? 1)
            let phase = WorkoutPhase(id: UUID(), planID: plan.id, name: "Base Phase", order: 0, goal: plan.goal, durationWeeks: maxWeek)
            workoutPhases.append(phase)

            let weekNumbers = Set(entries.map(\.week)).union([1]).sorted()
            for weekNumber in weekNumbers {
                let week = WorkoutWeek(id: UUID(), planID: plan.id, phaseID: phase.id, weekNumber: weekNumber, title: "Week \(weekNumber)", notes: "")
                workoutWeeks.append(week)

                let weekEntries = entries.filter { $0.week == weekNumber }
                let groups = Dictionary(grouping: weekEntries) { $0.workout }
                for (sessionIndex, group) in groups.sorted(by: { lhs, rhs in
                    let lhsDay = lhs.value.first?.day ?? ""
                    let rhsDay = rhs.value.first?.day ?? ""
                    return dayOrder(lhsDay) < dayOrder(rhsDay)
                }).enumerated() {
                    let session = WorkoutSession(
                        id: UUID(),
                        weekID: week.id,
                        day: group.value.first?.day ?? "Any day",
                        name: group.key,
                        order: sessionIndex,
                        notes: ""
                    )
                    workoutSessions.append(session)

                    for (exerciseIndex, entry) in group.value.sorted(by: { $0.exercise < $1.exercise }).enumerated() {
                        let catalog = (MockData.trainingExerciseLibrary + customTrainingExercises).first { $0.name == entry.exercise }
                        let prescription = WorkoutExercisePrescription(
                            id: UUID(),
                            sessionID: session.id,
                            exerciseID: catalog?.id ?? entry.exercise.lowercased().replacingOccurrences(of: " ", with: "_"),
                            exerciseName: entry.exercise,
                            bodyPart: entry.muscleGroup,
                            equipment: catalog?.equipment ?? "Mixed",
                            sets: entry.targetSets,
                            reps: entry.targetReps,
                            restSeconds: catalog?.defaultRestSeconds ?? 120,
                            order: exerciseIndex,
                            notes: entry.notes
                        )
                        workoutPrescriptions.append(prescription)

                        for (setIndex, set) in entry.sets.enumerated() {
                            workoutSetLogs.append(WorkoutSetLog(
                                id: set.id,
                                prescriptionID: prescription.id,
                                performedAt: entry.date,
                                setNumber: setIndex + 1,
                                weight: set.weight,
                                reps: set.reps,
                                rpe: set.rpe,
                                isWarmup: false,
                                isComplete: entry.isDone
                            ))
                        }
                    }
                }
            }
        }
    }

    private func createDefaultProgramScaffold(for plan: WorkoutPlan) {
        let phase = createDefaultPhase(for: plan.id)
        let week = WorkoutWeek(id: UUID(), planID: plan.id, phaseID: phase.id, weekNumber: 1, title: "Week 1", notes: "")
        workoutWeeks.append(week)
        workoutSessions.append(WorkoutSession(id: UUID(), weekID: week.id, day: "Monday", name: "Freestyle Workout", order: 0, notes: ""))
    }

    private func createDefaultPhase(for planID: UUID) -> WorkoutPhase {
        let phase = WorkoutPhase(id: UUID(), planID: planID, name: "Base Phase", order: 0, goal: "Build strength and muscle", durationWeeks: 1)
        workoutPhases.append(phase)
        return phase
    }

    private func firstPhase(for planID: UUID) -> WorkoutPhase? {
        workoutPhases
            .filter { $0.planID == planID }
            .sorted { $0.order < $1.order }
            .first
    }

    private func nextWeekNumber(for planID: UUID) -> Int {
        (workoutWeeks.filter { $0.planID == planID }.map(\.weekNumber).max() ?? 0) + 1
    }

    private func bridgePrescriptionToWorkoutEntry(_ prescription: WorkoutExercisePrescription) {
        guard let session = session(for: prescription),
              let week = workoutWeeks.first(where: { $0.id == session.weekID }) else { return }
        let exists = workoutEntries.contains { entry in
            entry.planID == week.planID &&
            entry.week == week.weekNumber &&
            entry.workout == session.name &&
            entry.exercise == prescription.exerciseName
        }
        guard !exists else { return }
        workoutEntries.insert(
            WorkoutExerciseEntry(
                id: UUID(),
                planID: week.planID,
                week: week.weekNumber,
                date: .now,
                day: session.day,
                workout: session.name,
                exercise: prescription.exerciseName,
                muscleGroup: prescription.bodyPart,
                targetSets: prescription.sets,
                targetReps: prescription.reps,
                sets: [],
                isDone: false,
                notes: prescription.notes
            ),
            at: 0
        )
    }

    private func session(for prescription: WorkoutExercisePrescription) -> WorkoutSession? {
        workoutSessions.first { $0.id == prescription.sessionID }
    }

    private func dayOrder(_ day: String) -> Int {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].firstIndex(of: day) ?? 99
    }

    func updateBodyweight(_ entry: BodyweightEntry) {
        guard let index = bodyweightEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        bodyweightEntries[index] = entry
    }

    func addThread(_ thread: CommunityThread) {
        communityThreads.insert(thread, at: 0)
        activities.insert(ActivityItem(id: UUID(), profile: currentProfile, title: "\(currentProfile.displayName) started a thread", detail: thread.title, createdAt: thread.createdAt, isLiked: false, isSaved: false), at: 0)
    }

    func addReply(to thread: CommunityThread, body: String, author: UserProfile) {
        guard let index = communityThreads.firstIndex(where: { $0.id == thread.id }) else { return }
        communityThreads[index].replyCount += 1
        communityThreadReplies.append(
            CommunityThreadReply(
                id: UUID(),
                threadID: thread.id,
                authorID: author.id,
                authorName: author.displayName,
                body: body,
                createdAt: .now
            )
        )
        activities.insert(ActivityItem(id: UUID(), profile: author, title: "\(author.displayName) replied to \(thread.title)", detail: body, createdAt: .now, isLiked: false, isSaved: false), at: 0)
    }

    func toggleThreadLike(_ thread: CommunityThread) {
        guard let index = communityThreads.firstIndex(where: { $0.id == thread.id }) else { return }
        if likedCommunityThreadIDs.contains(thread.id) {
            likedCommunityThreadIDs.remove(thread.id)
            communityThreads[index].likeCount = max(0, communityThreads[index].likeCount - 1)
        } else {
            likedCommunityThreadIDs.insert(thread.id)
            communityThreads[index].likeCount += 1
        }
    }

    func toggleActivityLike(_ activity: ActivityItem) {
        guard let index = activities.firstIndex(where: { $0.id == activity.id }) else { return }
        activities[index].isLiked.toggle()
    }

    func toggleActivitySave(_ activity: ActivityItem) {
        guard let index = activities.firstIndex(where: { $0.id == activity.id }) else { return }
        activities[index].isSaved.toggle()
    }

    func addComment(to activity: ActivityItem, body: String) {
        activityComments.append(
            ActivityComment(
                id: UUID(),
                activityID: activity.id,
                authorID: currentProfile.id,
                authorName: currentProfile.displayName,
                body: body,
                createdAt: .now
            )
        )
    }

    func requestGym(_ request: GymRequest) {
        gymRequests.insert(request, at: 0)
        let demoGym = Gym(id: UUID(), name: request.name, city: request.city, state: request.state, memberCount: 1, verifiedLiftCount: 0)
        gyms.insert(demoGym, at: 0)
        communityThreads.insert(CommunityThread(id: UUID(), title: "\(request.name) members thread", body: "Use this thread for lift checks, meetups, and gym-specific questions.", authorID: currentProfile.id, authorName: currentProfile.displayName, kind: .gym, challengeID: nil, gymID: demoGym.id, replyCount: 0, likeCount: 0, createdAt: .now), at: 0)
        notifications.insert(NotificationItem(id: UUID(), title: "Gym request submitted", message: "\(request.name) is now available as a demo gym.", kind: "Gym request", createdAt: .now, isRead: false), at: 0)
    }

    @discardableResult
    func joinGym(_ gym: Gym, maximumMemberships: Int) -> Bool {
        guard !joinedGymIDs.contains(gym.id), joinedGymIDs.count < maximumMemberships else {
            return joinedGymIDs.contains(gym.id)
        }
        joinedGymIDs.insert(gym.id)
        if let index = gyms.firstIndex(where: { $0.id == gym.id }) {
            gyms[index].memberCount += 1
        }
        return true
    }

    func leaveGym(_ gym: Gym) {
        guard gym.id != currentProfile.primaryGymID, joinedGymIDs.remove(gym.id) != nil else { return }
        if let index = gyms.firstIndex(where: { $0.id == gym.id }) {
            gyms[index].memberCount = max(0, gyms[index].memberCount - 1)
        }
    }

    func setChallengeJoined(_ challenge: Challenge, joined: Bool) {
        guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        let wasJoined = challenges[index].isJoined
        guard wasJoined != joined else { return }
        challenges[index].isJoined = joined
        challenges[index].participantCount += joined ? 1 : -1
        challenges[index].participantCount = max(0, challenges[index].participantCount)
    }

    func sendFriendRequest(to profile: UserProfile) {
        guard profile.id != currentProfile.id else { return }
        if let index = friendRequests.firstIndex(where: { request in
            (request.fromUserID == currentProfile.id && request.toUserID == profile.id) ||
            (request.fromUserID == profile.id && request.toUserID == currentProfile.id)
        }) {
            if friendRequests[index].status == .declined {
                friendRequests[index].fromUserID = currentProfile.id
                friendRequests[index].toUserID = profile.id
                friendRequests[index].status = .pending
                friendRequests[index].createdAt = .now
                friendRequests[index].respondedAt = nil
            }
            return
        }
        friendRequests.insert(
            FriendRequest(id: UUID(), fromUserID: currentProfile.id, toUserID: profile.id, status: .pending, createdAt: .now, respondedAt: nil),
            at: 0
        )
        notifications.insert(NotificationItem(id: UUID(), title: "Friend request sent", message: "Request sent to \(profile.displayName).", kind: "Friend request", createdAt: .now, isRead: false), at: 0)
    }

    func respondToFriendRequest(_ request: FriendRequest, status: FriendRequestStatus) {
        guard let index = friendRequests.firstIndex(where: { $0.id == request.id }) else { return }
        friendRequests[index].status = status
        friendRequests[index].respondedAt = .now
        let otherID = request.fromUserID == currentProfile.id ? request.toUserID : request.fromUserID
        let otherName = profiles.first { $0.id == otherID }?.displayName ?? "Lifter"
        notifications.insert(NotificationItem(id: UUID(), title: status == .accepted ? "Friend request accepted" : "Friend request declined", message: "\(otherName) was updated.", kind: "Friend request", createdAt: .now, isRead: false), at: 0)
    }

    func cancelFriendRequest(_ request: FriendRequest) {
        guard request.fromUserID == currentProfile.id, request.status == .pending else { return }
        friendRequests.removeAll { $0.id == request.id }
        let otherName = profiles.first { $0.id == request.toUserID }?.displayName ?? "Lifter"
        notifications.insert(NotificationItem(id: UUID(), title: "Friend request canceled", message: "Request to \(otherName) was canceled.", kind: "Friend request", createdAt: .now, isRead: false), at: 0)
    }

    func messageThread(with profile: UserProfile) -> DirectMessageThread {
        if let thread = messageThreads.first(where: { Set($0.participantIDs) == Set([currentProfile.id, profile.id]) }) {
            return thread
        }
        let thread = DirectMessageThread(id: UUID(), participantIDs: [currentProfile.id, profile.id], createdAt: .now, updatedAt: .now)
        messageThreads.insert(thread, at: 0)
        return thread
    }

    func addMessage(to thread: DirectMessageThread, body: String) {
        guard !body.isEmpty else { return }
        let message = DirectMessage(id: UUID(), threadID: thread.id, senderID: currentProfile.id, body: body, createdAt: .now, isRead: true, isReported: false)
        directMessages.append(message)
        if let index = messageThreads.firstIndex(where: { $0.id == thread.id }) {
            messageThreads[index].updatedAt = message.createdAt
        }
    }

    func deleteMessage(_ message: DirectMessage) {
        directMessages.removeAll { $0.id == message.id }
        messageReports.removeAll { $0.messageID == message.id }
        if let latest = directMessages
            .filter({ $0.threadID == message.threadID })
            .max(by: { $0.createdAt < $1.createdAt }),
           let index = messageThreads.firstIndex(where: { $0.id == message.threadID }) {
            messageThreads[index].updatedAt = latest.createdAt
        }
    }

    func deleteMessageThread(_ thread: DirectMessageThread) {
        let messageIDs = Set(directMessages.filter { $0.threadID == thread.id }.map(\.id))
        directMessages.removeAll { $0.threadID == thread.id }
        messageReports.removeAll { messageIDs.contains($0.messageID) }
        messageThreads.removeAll { $0.id == thread.id }
    }

    func reportMessage(_ message: DirectMessage, reason: MessageReportReason, note: String) {
        if let index = directMessages.firstIndex(where: { $0.id == message.id }) {
            directMessages[index].isReported = true
        }
        messageReports.insert(
            MessageReport(id: UUID(), messageID: message.id, reporterID: currentProfile.id, reason: reason, note: note, createdAt: .now),
            at: 0
        )
        notifications.insert(NotificationItem(id: UUID(), title: "Message reported", message: "Thanks. We flagged the message for review.", kind: "Message report", createdAt: .now, isRead: false), at: 0)
    }
}
