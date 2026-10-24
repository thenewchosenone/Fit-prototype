import Combine
import Foundation

enum WorkoutHistorySyncState: Equatable {
    case local
    case syncing
    case synced
    case stale
    case needsAttention
}

@MainActor
final class WorkoutSyncStore: ObservableObject {
    private let repository: any WorkoutSyncRepository
    private let service: any WorkoutSyncService
    private let makeUUID: () -> UUID
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var syncedUserID: UUID
    private let passiveSyncInterval: TimeInterval = 30
    private var lastPassiveHistorySyncAt: Date?
    private var lastPassivePlanSyncAt: Date?
    private var historySyncInFlight = false
    private var historySyncWaiters: [CheckedContinuation<Void, Never>] = []
    private var planSyncInFlight = false
    private var planSyncRequested = false
    @Published private(set) var planSyncState: WorkoutHistorySyncState = .local
    @Published private(set) var planSyncFailureReason: String?
    @Published private(set) var historySyncState: WorkoutHistorySyncState = .synced

    init(
        repository: any WorkoutSyncRepository,
        service: any WorkoutSyncService,
        makeUUID: @escaping () -> UUID = UUID.init,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.repository = repository
        self.service = service
        self.makeUUID = makeUUID
        self.encoder = encoder
        self.decoder = decoder
        self.syncedUserID = repository.currentProfile.id
    }

    var pendingCompletedWorkoutUploads: [CompletedWorkoutSnapshot] {
        repository.pendingCompletedWorkoutUploads
    }

    func enqueueCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) {
        repository.deletedCompletedWorkoutIDs.remove(snapshot.id)
        if let index = repository.pendingCompletedWorkoutUploads.firstIndex(where: { $0.id == snapshot.id }) {
            repository.pendingCompletedWorkoutUploads[index] = snapshot
        } else {
            repository.pendingCompletedWorkoutUploads.append(snapshot)
        }
        historySyncState = .local
        repository.persistWorkoutSnapshotWithoutBlockingUI()
    }

    func synchronizeCompletedWorkoutHistory(force: Bool = true) async {
        resetAccountScopedDataIfNeeded()
        let userID = repository.currentProfile.id
        guard !historySyncInFlight else { return }
        if !force {
            if let lastPassiveHistorySyncAt,
               Date.now.timeIntervalSince(lastPassiveHistorySyncAt) < passiveSyncInterval {
                return
            }
            historySyncState = .stale
        }
        historySyncInFlight = true
        historySyncState = .syncing
        var syncFailed = false
        defer {
            historySyncInFlight = false
            let waiters = historySyncWaiters
            historySyncWaiters.removeAll()
            waiters.forEach { $0.resume() }
            if repository.currentProfile.id == userID, !force {
                lastPassiveHistorySyncAt = .now
            }
        }

        let deletedIDs = repository.deletedCompletedWorkoutIDs
        for deletedID in deletedIDs {
            guard repository.currentProfile.id == userID else { return }
            do {
                try await service.deleteCompletedWorkout(id: deletedID)
                guard repository.currentProfile.id == userID else { return }
                repository.deletedCompletedWorkoutIDs.remove(deletedID)
            } catch {
                syncFailed = true
                guard repository.currentProfile.id == userID else { return }
            }
        }

        let pendingUploads = repository.pendingCompletedWorkoutUploads
        for snapshot in pendingUploads {
            guard repository.currentProfile.id == userID else { return }
            do {
                try await service.uploadCompletedWorkout(snapshot)
                guard repository.currentProfile.id == userID else { return }
                if let index = repository.pendingCompletedWorkoutUploads.firstIndex(where: { $0.id == snapshot.id }),
                   repository.pendingCompletedWorkoutUploads[index] == snapshot {
                    repository.pendingCompletedWorkoutUploads.remove(at: index)
                }
                if snapshot.ownerID == userID {
                    repository.syncedCompletedWorkoutIDs.insert(snapshot.id)
                }
            } catch {
                syncFailed = true
                guard repository.currentProfile.id == userID else { return }
            }
        }

        guard let remote = try? await service.completedWorkouts(since: nil) else {
            guard repository.currentProfile.id == userID else { return }
            historySyncState = .needsAttention
            repository.persistWorkoutSnapshotWithoutBlockingUI()
            return
        }
        guard repository.currentProfile.id == userID else { return }
        let deletedWorkoutIDs = repository.deletedCompletedWorkoutIDs
        let pendingUploadIDs = Set(repository.pendingCompletedWorkoutUploads.map(\.id))
        let remoteWorkoutIDs = Set(remote.filter { $0.ownerID == userID }.map(\.id))
        repository.syncedCompletedWorkoutIDs.formUnion(remoteWorkoutIDs)
        let remotelyDeletedWorkoutIDs = repository.syncedCompletedWorkoutIDs
            .subtracting(remoteWorkoutIDs)
            .subtracting(pendingUploadIDs)
            .subtracting(deletedWorkoutIDs)
        repository.completedWorkouts.removeAll { remotelyDeletedWorkoutIDs.contains($0.id) }
        repository.syncedCompletedWorkoutIDs.subtract(remotelyDeletedWorkoutIDs)
        var workoutIndexesByID = Dictionary(
            uniqueKeysWithValues: repository.completedWorkouts.enumerated().map { ($0.element.id, $0.offset) }
        )
        for snapshot in remote where snapshot.ownerID == userID
            && !deletedWorkoutIDs.contains(snapshot.id)
            && !pendingUploadIDs.contains(snapshot.id) {
            guard let workout = try? decoder.decode(CompletedWorkout.self, from: snapshot.payload) else {
                syncFailed = true
                continue
            }
            if let index = workoutIndexesByID[snapshot.id] {
                repository.completedWorkouts[index] = workout
            } else {
                workoutIndexesByID[snapshot.id] = repository.completedWorkouts.count
                repository.completedWorkouts.append(workout)
            }
        }
        repository.rebuildWorkoutHistoryDerivedState()
        if syncFailed {
            historySyncState = .needsAttention
        } else if repository.pendingCompletedWorkoutUploads.isEmpty,
                  repository.deletedCompletedWorkoutIDs.isEmpty {
            historySyncState = .synced
        } else {
            historySyncState = .local
        }
        repository.persistWorkoutSnapshotWithoutBlockingUI()
    }

    func saveCompletedWorkoutVisibility(_ snapshot: CompletedWorkoutSnapshot) async throws {
        // Finish any older upload before sending the new privacy decision.
        while historySyncInFlight {
            await withCheckedContinuation { historySyncWaiters.append($0) }
        }
        try Task.checkCancellation()
        guard repository.currentProfile.id == snapshot.ownerID else { throw LiftRankServiceError.sessionExpired }
        enqueueCompletedWorkout(snapshot)
        await synchronizeCompletedWorkoutHistory()
        guard repository.currentProfile.id == snapshot.ownerID else { throw LiftRankServiceError.sessionExpired }
        guard !repository.pendingCompletedWorkoutUploads.contains(where: { $0.id == snapshot.id }) else {
            throw LiftRankServiceError.server("Workout visibility wasn't saved. Check your connection and retry.")
        }
    }

    func synchronizeDeletedCompletedWorkout(id: UUID) async {
        resetAccountScopedDataIfNeeded()
        let userID = repository.currentProfile.id
        guard repository.deletedCompletedWorkoutIDs.contains(id) else { return }
        do {
            try await service.deleteCompletedWorkout(id: id)
            guard repository.currentProfile.id == userID else { return }
            repository.deletedCompletedWorkoutIDs.remove(id)
        } catch {
            guard repository.currentProfile.id == userID else { return }
        }
        repository.persistWorkoutSnapshotWithoutBlockingUI()
    }

    func synchronizeWorkoutPlans(force: Bool = true) async {
        resetAccountScopedDataIfNeeded()
        let userID = repository.currentProfile.id
        guard !planSyncInFlight else {
            planSyncRequested = planSyncRequested || force
            return
        }
        if !force,
           let lastPassivePlanSyncAt,
           Date.now.timeIntervalSince(lastPassivePlanSyncAt) < passiveSyncInterval {
            return
        }
        planSyncInFlight = true
        planSyncState = .syncing
        planSyncFailureReason = nil
        var syncFailed = false
        var failureReason: String?
        func recordFailure(_ reason: String) {
            syncFailed = true
            failureReason = failureReason ?? reason
        }
        defer {
            if repository.currentProfile.id == userID {
                planSyncState = syncFailed ? .needsAttention : .synced
                planSyncFailureReason = failureReason
            }
            let shouldRetry = planSyncRequested
            planSyncRequested = false
            planSyncInFlight = false
            if repository.currentProfile.id == userID, !force {
                lastPassivePlanSyncAt = .now
            }
            if shouldRetry { Task { await self.synchronizeWorkoutPlans() } }
        }

        guard let remotelyDeletedPlanIDs = try? await service.deletedWorkoutPlanIDs() else {
            recordFailure("Could not check deleted plans.")
            return
        }
        guard repository.currentProfile.id == userID else { return }
        let deletedPlanIDs = remotelyDeletedPlanIDs.union(repository.pendingRemoteWorkoutPlanDeletions)
        repository.pendingRemoteWorkoutPlanDeletions.formUnion(remotelyDeletedPlanIDs)

        for planID in deletedPlanIDs {
            guard repository.currentProfile.id == userID else { return }
            if let plan = repository.workoutPlans.first(where: { $0.id == planID }) {
                repository.deleteWorkoutPlan(plan)
                forgetPlan(planID)
            }
        }

        for planID in Set(repository.pendingRemoteWorkoutPlanDeletions) {
            guard repository.currentProfile.id == userID else { return }
            do {
                try await service.deletePlan(id: planID)
                guard repository.currentProfile.id == userID else { return }
                repository.pendingRemoteWorkoutPlanDeletions.remove(planID)
            } catch {
                recordFailure("Could not delete a plan from the server.")
                guard repository.currentProfile.id == userID else { return }
            }
        }
        guard repository.currentProfile.id == userID else { return }
        let remoteDocuments: [WorkoutPlanDocument]
        do {
            remoteDocuments = try await service.plans()
        } catch {
            recordFailure("Could not load saved plans from the server. \(error.localizedDescription)")
            return
        }
        var remoteByID = remoteDocuments.reduce(into: [UUID: WorkoutPlanDocument]()) { result, document in
            if document.ownerID == userID && !deletedPlanIDs.contains(document.id) {
                result[document.id] = document
            }
        }
        guard repository.currentProfile.id == userID else { return }
        let localOnlyPlanIDs = Set([PersonalWorkoutPlanCatalog.planID])

        for plan in repository.workoutPlans where !localOnlyPlanIDs.contains(plan.id)
            && !deletedPlanIDs.contains(plan.id)
            && !repository.pendingRemoteWorkoutPlanDeletions.contains(plan.id) {
            guard let payload = payload(planID: plan.id), let data = try? encoder.encode(payload) else {
                recordFailure("Could not prepare a plan for syncing.")
                continue
            }
            let knownRevision = repository.workoutPlanSyncRevisions[plan.id]
            let lastPayload = repository.workoutPlanLastSyncedPayloads[plan.id]

            if let remote = remoteByID[plan.id] {
                if knownRevision == nil {
                    if payloadsMatch(remote.payload, data) {
                        remember(remote)
                    } else if let serverPayload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: remote.payload) {
                        let conflict = payload.conflictCopy(documentID: makeUUID(), makeUUID: makeUUID)
                        apply(serverPayload, replacing: plan.id)
                        apply(conflict, replacing: nil)
                        remember(remote)
                        recordFailure("A plan conflict was preserved. Review the conflict copy.")
                    } else {
                        recordFailure("A saved plan on the server could not be read.")
                    }
                    continue
                }

                if payloadsMatch(lastPayload, data) {
                    if !payloadsMatch(remote.payload, data) {
                        guard let serverPayload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: remote.payload) else {
                            recordFailure("A saved plan on the server could not be read.")
                            continue
                        }
                        apply(serverPayload, replacing: plan.id)
                    }
                    remember(remote)
                    continue
                }

                let document = WorkoutPlanDocument(
                    id: plan.id,
                    ownerID: repository.currentProfile.id,
                    revision: knownRevision ?? remote.revision,
                    name: plan.name,
                    payload: data,
                    updatedAt: .now
                )
                let result = try? await service.savePlan(
                    document,
                    expectedRevision: knownRevision ?? remote.revision
                )
                guard repository.currentProfile.id == userID else { return }
                if let result {
                    if case .conflict = result { recordFailure("A plan conflict was preserved. Review the conflict copy.") }
                    if !apply(result) { recordFailure("A plan conflict could not be applied locally.") }
                    if case let .saved(saved) = result { remoteByID[saved.id] = saved }
                } else { recordFailure("Could not save a plan to the server.") }
            } else {
                let document = WorkoutPlanDocument(
                    id: plan.id,
                    ownerID: repository.currentProfile.id,
                    revision: 0,
                    name: plan.name,
                    payload: data,
                    updatedAt: .now
                )
                let result = try? await service.savePlan(document, expectedRevision: 0)
                guard repository.currentProfile.id == userID else { return }
                if let result {
                    if case .conflict = result { recordFailure("A plan conflict was preserved. Review the conflict copy.") }
                    if !apply(result) { recordFailure("A plan conflict could not be applied locally.") }
                } else { recordFailure("Could not save a plan to the server.") }
            }
        }

        for document in remoteByID.values
        where !repository.pendingRemoteWorkoutPlanDeletions.contains(document.id)
            && !repository.workoutPlans.contains(where: { $0.id == document.id }) {
            guard let payload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: document.payload) else {
                recordFailure("A saved plan on the server could not be read.")
                continue
            }
            apply(payload, replacing: nil)
            remember(document)
        }
        if repository.workoutPlans.filter(\.isActive).count > 1 {
            recordFailure("More than one workout plan is marked active.")
        }
        repository.persistWorkoutSnapshotWithoutBlockingUI()
    }

    private func resetAccountScopedDataIfNeeded() {
        guard syncedUserID != repository.currentProfile.id else { return }
        syncedUserID = repository.currentProfile.id
        lastPassiveHistorySyncAt = nil
        lastPassivePlanSyncAt = nil
        repository.completedWorkouts.removeAll()
        repository.pendingCompletedWorkoutUploads.removeAll()
        repository.deletedCompletedWorkoutIDs.removeAll()
        repository.syncedCompletedWorkoutIDs.removeAll()
        repository.clearAccountScopedWorkoutHistory()

        let localOnlyPlanIDs = Set([PersonalWorkoutPlanCatalog.planID])
        let removedPlanIDs = Set(repository.workoutPlans.map(\.id).filter { !localOnlyPlanIDs.contains($0) })
        let removedWeekIDs = Set(repository.workoutWeeks.filter { removedPlanIDs.contains($0.planID) }.map(\.id))
        let removedSessionIDs = Set(repository.workoutSessions.filter { removedWeekIDs.contains($0.weekID) }.map(\.id))
        repository.workoutPlans.removeAll { removedPlanIDs.contains($0.id) }
        repository.workoutPhases.removeAll { removedPlanIDs.contains($0.planID) }
        repository.workoutWeeks.removeAll { removedPlanIDs.contains($0.planID) }
        repository.workoutSessions.removeAll { removedWeekIDs.contains($0.weekID) }
        repository.workoutPrescriptions.removeAll { removedSessionIDs.contains($0.sessionID) }
        repository.workoutPlanProgressionSettings.removeAll { removedPlanIDs.contains($0.planID) }
        repository.workoutPlanSyncRevisions.removeAll()
        repository.workoutPlanLastSyncedPayloads.removeAll()
        repository.pendingRemoteWorkoutPlanDeletions.removeAll()
        repository.persistWorkoutSnapshotWithoutBlockingUI()
    }

    func forgetPlan(_ planID: UUID) {
        repository.workoutPlanSyncRevisions[planID] = nil
        repository.workoutPlanLastSyncedPayloads[planID] = nil
        repository.persistWorkoutSnapshotWithoutBlockingUI()
    }

    func deleteRemotePlan(_ planID: UUID) async {
        let userID = repository.currentProfile.id
        repository.pendingRemoteWorkoutPlanDeletions.insert(planID)
        repository.persistWorkoutSnapshot()
        do {
            try await service.deletePlan(id: planID)
            guard repository.currentProfile.id == userID else { return }
            repository.pendingRemoteWorkoutPlanDeletions.remove(planID)
        } catch {
            guard repository.currentProfile.id == userID else { return }
            planSyncState = .needsAttention
            planSyncFailureReason = "Could not delete a plan from the server."
        }
        repository.persistWorkoutSnapshot()
    }

    func payload(planID: UUID) -> WorkoutPlanSyncPayload? {
        guard let plan = repository.workoutPlans.first(where: { $0.id == planID }) else { return nil }
        let phases = repository.workoutPhases.filter { $0.planID == planID }
        let weeks = repository.workoutWeeks.filter { $0.planID == planID }
        let weekIDs = Set(weeks.map(\.id))
        let sessions = repository.workoutSessions.filter { weekIDs.contains($0.weekID) }
        let sessionIDs = Set(sessions.map(\.id))
        return WorkoutPlanSyncPayload(
            plan: plan,
            phases: phases,
            weeks: weeks,
            sessions: sessions,
            prescriptions: repository.workoutPrescriptions.filter { sessionIDs.contains($0.sessionID) },
            progression: repository.workoutPlanProgressionSettings.first { $0.planID == planID }
        )
    }

    private func apply(_ result: WorkoutSyncResult) -> Bool {
        switch result {
        case let .saved(saved):
            remember(saved)
            return true
        case let .conflict(server, localCopy):
            guard let serverPayload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: server.payload),
                  let localPayload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: localCopy.payload) else {
                return false
            }
            apply(serverPayload, replacing: server.id)
            apply(
                localPayload.plan.id == localCopy.id
                    ? localPayload
                    : localPayload.conflictCopy(documentID: localCopy.id, makeUUID: makeUUID),
                replacing: nil
            )
            remember(server)
            repository.workoutPlanSyncRevisions[localCopy.id] = localCopy.revision
            return true
        }
    }

    private func remember(_ document: WorkoutPlanDocument) {
        repository.workoutPlanSyncRevisions[document.id] = document.revision
        repository.workoutPlanLastSyncedPayloads[document.id] = document.payload
    }

    private func payloadsMatch(_ lhs: Data?, _ rhs: Data) -> Bool {
        guard let lhs,
              let left = try? decoder.decode(WorkoutPlanSyncPayload.self, from: lhs),
              let right = try? decoder.decode(WorkoutPlanSyncPayload.self, from: rhs) else { return false }
        return left == right
    }

    private func apply(_ payload: WorkoutPlanSyncPayload, replacing planID: UUID?) {
        if let planID {
            let weekIDs = Set(repository.workoutWeeks.filter { $0.planID == planID }.map(\.id))
            let sessionIDs = Set(repository.workoutSessions.filter { weekIDs.contains($0.weekID) }.map(\.id))
            repository.workoutPrescriptions.removeAll { sessionIDs.contains($0.sessionID) }
            repository.workoutSessions.removeAll { weekIDs.contains($0.weekID) }
            repository.workoutWeeks.removeAll { $0.planID == planID }
            repository.workoutPhases.removeAll { $0.planID == planID }
            repository.workoutPlanProgressionSettings.removeAll { $0.planID == planID }
            repository.workoutPlans.removeAll { $0.id == planID }
        }
        repository.workoutPlans.append(payload.plan)
        repository.workoutPhases.append(contentsOf: payload.phases)
        repository.workoutWeeks.append(contentsOf: payload.weeks)
        repository.workoutSessions.append(contentsOf: payload.sessions)
        repository.workoutPrescriptions.append(contentsOf: payload.prescriptions)
        if let progression = payload.progression {
            repository.workoutPlanProgressionSettings.append(progression)
        }
    }

}
