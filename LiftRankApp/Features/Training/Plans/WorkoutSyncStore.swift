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
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var syncedUserID: UUID
    private let passiveSyncInterval: TimeInterval = 30
    private var lastPassiveHistorySyncAt: Date?
    private var lastPassivePlanSyncAt: Date?
    private var historySyncInFlight = false
    private var planSyncInFlight = false
    private var planSyncRequested = false
    @Published private(set) var planSyncState: WorkoutHistorySyncState = .local
    @Published private(set) var historySyncState: WorkoutHistorySyncState = .synced
    @Published private(set) var unreadableRemoteWorkoutCount = 0

    init(
        repository: any WorkoutSyncRepository,
        service: any WorkoutSyncService,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.repository = repository
        self.service = service
        self.encoder = encoder
        self.decoder = decoder
        self.syncedUserID = repository.currentProfile.id
    }

    var pendingCompletedWorkoutUploads: [CompletedWorkoutSnapshot] {
        repository.pendingCompletedWorkoutUploads
    }

    func enqueueCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot, persist: Bool = true) {
        repository.deletedCompletedWorkoutIDs.remove(snapshot.id)
        if let index = repository.pendingCompletedWorkoutUploads.firstIndex(where: { $0.id == snapshot.id }) {
            repository.pendingCompletedWorkoutUploads[index] = snapshot
        } else {
            repository.pendingCompletedWorkoutUploads.append(snapshot)
        }
        historySyncState = .local
        if persist { repository.persistWorkoutSnapshotWithoutBlockingUI() }
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
        unreadableRemoteWorkoutCount = 0
        let deletedWorkoutIDs = repository.deletedCompletedWorkoutIDs
        let pendingUploadIDs = Set(repository.pendingCompletedWorkoutUploads.map(\.id))
        var workoutIndexesByID = Dictionary(
            uniqueKeysWithValues: repository.completedWorkouts.enumerated().map { ($0.element.id, $0.offset) }
        )
        for snapshot in remote where snapshot.ownerID == userID
            && !deletedWorkoutIDs.contains(snapshot.id)
            && !pendingUploadIDs.contains(snapshot.id) {
            guard let workout = try? decoder.decode(CompletedWorkout.self, from: snapshot.payload) else {
                unreadableRemoteWorkoutCount += 1
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
        var syncFailed = false
        defer {
            if repository.currentProfile.id == userID {
                planSyncState = syncFailed ? .needsAttention : .synced
            }
            if planSyncRequested {
                planSyncRequested = false
                Task { await self.synchronizeWorkoutPlans() }
            }
            planSyncInFlight = false
            if repository.currentProfile.id == userID, !force {
                lastPassivePlanSyncAt = .now
            }
        }

        for planID in repository.pendingRemoteWorkoutPlanDeletions {
            guard repository.currentProfile.id == userID else { return }
            do {
                try await service.deletePlan(id: planID)
                guard repository.currentProfile.id == userID else { return }
                repository.pendingRemoteWorkoutPlanDeletions.remove(planID)
            } catch {
                syncFailed = true
                guard repository.currentProfile.id == userID else { return }
            }
        }
        guard repository.currentProfile.id == userID else { return }
        guard var remoteByID = try? await service.plans().reduce(
            into: [UUID: WorkoutPlanDocument](),
            { result, document in
                if document.ownerID == userID {
                    result[document.id] = document
                }
            }
        ) else {
            syncFailed = true
            return
        }
        guard repository.currentProfile.id == userID else { return }
        let localOnlyPlanIDs = Set([PersonalWorkoutPlanCatalog.planID])

        for plan in repository.workoutPlans where !localOnlyPlanIDs.contains(plan.id)
            && !repository.pendingRemoteWorkoutPlanDeletions.contains(plan.id) {
            guard var payload = payload(planID: plan.id) else { continue }
            let originalPayload = payload.canonicalized
            if payload.plan.name.hasSuffix(" (Conflict copy)"), payload.plan.name != payload.conflictCopyName {
                payload.plan.name = payload.conflictCopyName
                if let index = repository.workoutPlans.firstIndex(where: { $0.id == plan.id }) {
                    repository.workoutPlans[index].name = payload.plan.name
                }
            }
            let knownRevision = repository.workoutPlanSyncRevisions[plan.id]
            let baseline = repository.workoutPlanLastSyncedPayloads[plan.id].flatMap {
                try? decoder.decode(WorkoutPlanSyncPayload.self, from: $0).canonicalized
            }
            let local = payload.canonicalized
            let remote = remoteByID[plan.id]
            let expectedRevision: Int
            if let remote {
                guard let server = try? decoder.decode(WorkoutPlanSyncPayload.self, from: remote.payload),
                      server.plan.id == remote.id else { syncFailed = true; continue }
                if local == server.canonicalized {
                    remember(remote)
                    continue
                }
                if originalPayload == server.canonicalized {
                    expectedRevision = remote.revision
                } else if originalPayload == baseline {
                    apply(server, replacing: plan.id)
                    remember(remote)
                    if server.plan.name.hasSuffix(" (Conflict copy)"), server.plan.name != server.conflictCopyName {
                        planSyncRequested = true
                    }
                    continue
                } else {
                    // A revision-only server change is not a competing edit.
                    expectedRevision = server.canonicalized == baseline ? remote.revision : knownRevision ?? 0
                }
            } else {
                // Another device may already have cleaned up this unchanged copy.
                if knownRevision != nil, originalPayload == baseline,
                   plan.name.hasSuffix(" (Conflict copy)"), !isLocallyUsed(payload) {
                    removePlan(plan.id)
                    repository.workoutPlanSyncRevisions[plan.id] = nil
                    repository.workoutPlanLastSyncedPayloads[plan.id] = nil
                    continue
                }
                expectedRevision = 0
            }
            guard let data = try? encoder.encode(payload) else { syncFailed = true; continue }
            var document = remote ?? WorkoutPlanDocument(
                id: plan.id, ownerID: userID, revision: 0, name: payload.plan.name,
                payload: data, updatedAt: .now
            )
            document.name = payload.plan.name
            document.payload = data
            document.updatedAt = .now
            do {
                let result = try await service.savePlan(document, expectedRevision: expectedRevision)
                guard repository.currentProfile.id == userID else { return }
                if !apply(result, sentPayload: payload) { syncFailed = true }
                switch result {
                case .saved(let saved):
                    remoteByID[saved.id] = saved
                case .conflict(let server, let copy):
                    syncFailed = true
                    remoteByID[server.id] = server
                    remoteByID[copy.id] = copy
                }
            } catch {
                syncFailed = true
                guard repository.currentProfile.id == userID else { return }
            }
        }

        for document in remoteByID.values
        where !repository.pendingRemoteWorkoutPlanDeletions.contains(document.id)
            && !repository.workoutPlans.contains(where: { $0.id == document.id }) {
            guard let payload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: document.payload),
                  payload.plan.id == document.id else { syncFailed = true; continue }
            apply(payload, replacing: nil)
            remember(document)
            if payload.plan.name.hasSuffix(" (Conflict copy)"), payload.plan.name != payload.conflictCopyName {
                planSyncRequested = true
            }
        }
        if !syncFailed && !planSyncRequested {
            do { try await removeDuplicateConflictCopies(remoteByID, userID: userID) }
            catch { syncFailed = true }
            guard repository.currentProfile.id == userID else { return }
        }
        if repository.workoutPlans.filter(\.isActive).count > 1 { syncFailed = true }
        repository.persistWorkoutSnapshotWithoutBlockingUI()
    }

    private func isLocallyUsed(_ payload: WorkoutPlanSyncPayload) -> Bool {
        let sessionIDs = Set(payload.sessions.map(\.id))
        let prescriptionIDs = Set(payload.prescriptions.map(\.id))
        return payload.plan.isActive
            || repository.activeWorkout.map {
                $0.sourcePlanID == payload.plan.id || $0.sourceSessionID.map(sessionIDs.contains) == true
            } == true
            || repository.completedWorkouts.contains {
                $0.sourcePlanID == payload.plan.id || $0.sourceSessionID.map(sessionIDs.contains) == true
            }
            || repository.workoutSetLogs.contains { prescriptionIDs.contains($0.prescriptionID) }
            || repository.workoutFeedback.contains { sessionIDs.contains($0.sessionID) }
    }

    private func removeDuplicateConflictCopies(_ documents: [UUID: WorkoutPlanDocument], userID: UUID) async throws {
        var groups: [WorkoutPlanSyncPayload: [WorkoutPlanDocument]] = [:]
        for document in documents.values {
            guard let local = payload(planID: document.id),
                  let remote = try? decoder.decode(WorkoutPlanSyncPayload.self, from: document.payload),
                  local.canonicalized == remote.canonicalized,
                  let comparison = remote.duplicateComparisonPayload else { continue }
            groups[comparison, default: []].append(document)
        }
        let duplicates = groups.values.filter {
            $0.count > 1 && $0.contains { $0.name.hasSuffix(" (Conflict copy)") }
        }
        guard !duplicates.isEmpty else { return }
        let history = try await service.completedWorkouts(since: nil)
        guard repository.currentProfile.id == userID else { return }
        let workouts = try history.filter { $0.ownerID == userID }.map {
            try decoder.decode(CompletedWorkout.self, from: $0.payload)
        }
        for group in duplicates {
            let sorted = group.sorted { lhs, rhs in
                let leftActive = payload(planID: lhs.id)?.plan.isActive == true
                let rightActive = payload(planID: rhs.id)?.plan.isActive == true
                if leftActive != rightActive { return leftActive }
                let leftCopy = lhs.name.hasSuffix(" (Conflict copy)")
                let rightCopy = rhs.name.hasSuffix(" (Conflict copy)")
                if leftCopy != rightCopy { return !leftCopy }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            guard let keeper = sorted.first else { continue }
            for duplicate in sorted.dropFirst() where duplicate.name.hasSuffix(" (Conflict copy)") {
                guard repository.currentProfile.id == userID else { return }
                guard let local = payload(planID: duplicate.id), !isLocallyUsed(local),
                      local.canonicalized == (try decoder.decode(WorkoutPlanSyncPayload.self, from: duplicate.payload)).canonicalized,
                      let kept = payload(planID: keeper.id),
                      kept.canonicalized == (try decoder.decode(WorkoutPlanSyncPayload.self, from: keeper.payload)).canonicalized
                else { continue }
                let sessionIDs = Set(local.sessions.map(\.id))
                guard !workouts.contains(where: {
                    $0.sourcePlanID == duplicate.id || $0.sourceSessionID.map(sessionIDs.contains) == true
                }) else { continue }
                guard try await service.deleteDuplicatePlan(duplicate) else {
                    throw LiftRankServiceError.server("A plan changed during cleanup. Retry sync to keep its latest version.")
                }
                guard repository.currentProfile.id == userID else { return }
                // Editing or starting the copy while deletion was in flight wins:
                // keep the local plan and upload it again on the queued sync.
                if let latest = payload(planID: duplicate.id),
                   latest.canonicalized != local.canonicalized || isLocallyUsed(latest) {
                    planSyncRequested = true
                } else {
                    removePlan(duplicate.id)
                }
                repository.workoutPlanSyncRevisions[duplicate.id] = nil
                repository.workoutPlanLastSyncedPayloads[duplicate.id] = nil
            }
        }
    }

    private func resetAccountScopedDataIfNeeded() {
        guard syncedUserID != repository.currentProfile.id else { return }
        syncedUserID = repository.currentProfile.id
        unreadableRemoteWorkoutCount = 0
        lastPassiveHistorySyncAt = nil
        lastPassivePlanSyncAt = nil
        repository.completedWorkouts.removeAll()
        repository.pendingCompletedWorkoutUploads.removeAll()
        repository.deletedCompletedWorkoutIDs.removeAll()
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

    private func apply(_ result: WorkoutSyncResult, sentPayload: WorkoutPlanSyncPayload) -> Bool {
        let latest = payload(planID: sentPayload.plan.id)
        let changedDuringSave = latest?.canonicalized != sentPayload.canonicalized
        if changedDuringSave, latest != nil { planSyncRequested = true }
        switch result {
        case let .saved(saved):
            remember(saved)
        case let .conflict(server, localCopy):
            guard let serverPayload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: server.payload),
                  let copyPayload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: localCopy.payload),
                  serverPayload.plan.id == server.id, copyPayload.plan.id == localCopy.id else { return false }
            if !changedDuringSave {
                apply(serverPayload, replacing: server.id)
                remember(server)
            }
            let existingCopy = payload(planID: localCopy.id)?.canonicalized
            let copyBaseline = repository.workoutPlanLastSyncedPayloads[localCopy.id].flatMap {
                try? decoder.decode(WorkoutPlanSyncPayload.self, from: $0).canonicalized
            }
            if existingCopy == nil || existingCopy == copyBaseline || existingCopy == copyPayload.canonicalized {
                apply(copyPayload, replacing: localCopy.id)
                remember(localCopy)
            } else {
                planSyncRequested = true
            }
        }
        return true
    }

    private func remember(_ document: WorkoutPlanDocument) {
        repository.workoutPlanSyncRevisions[document.id] = document.revision
        repository.workoutPlanLastSyncedPayloads[document.id] = document.payload
    }

    private func removePlan(_ planID: UUID) {
        let weekIDs = Set(repository.workoutWeeks.filter { $0.planID == planID }.map(\.id))
        let sessionIDs = Set(repository.workoutSessions.filter { weekIDs.contains($0.weekID) }.map(\.id))
        repository.workoutPrescriptions.removeAll { sessionIDs.contains($0.sessionID) }
        repository.workoutSessions.removeAll { weekIDs.contains($0.weekID) }
        repository.workoutWeeks.removeAll { $0.planID == planID }
        repository.workoutPhases.removeAll { $0.planID == planID }
        repository.workoutPlanProgressionSettings.removeAll { $0.planID == planID }
        repository.workoutPlans.removeAll { $0.id == planID }
    }

    private func apply(_ payload: WorkoutPlanSyncPayload, replacing planID: UUID?) {
        if let planID { removePlan(planID) }
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
