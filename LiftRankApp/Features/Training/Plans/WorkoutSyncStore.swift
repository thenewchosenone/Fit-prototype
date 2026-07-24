import Foundation

@MainActor
final class WorkoutSyncStore {
    private let repository: any WorkoutSyncRepository
    private let service: any WorkoutSyncService
    private let makeUUID: () -> UUID
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

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
    }

    var pendingCompletedWorkoutUploads: [CompletedWorkoutSnapshot] {
        repository.pendingCompletedWorkoutUploads
    }

    func enqueueCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) {
        guard !repository.pendingCompletedWorkoutUploads.contains(where: { $0.id == snapshot.id }) else { return }
        repository.pendingCompletedWorkoutUploads.append(snapshot)
        repository.persistWorkoutSnapshot()
    }

    func synchronizeCompletedWorkoutHistory() async {
        var remaining: [CompletedWorkoutSnapshot] = []
        for snapshot in repository.pendingCompletedWorkoutUploads {
            do { try await service.uploadCompletedWorkout(snapshot) }
            catch { remaining.append(snapshot) }
        }
        repository.pendingCompletedWorkoutUploads = remaining

        guard let remote = try? await service.completedWorkouts(since: nil) else {
            repository.persistWorkoutSnapshot()
            return
        }
        for snapshot in remote where !repository.completedWorkouts.contains(where: { $0.id == snapshot.id }) {
            guard let workout = try? decoder.decode(CompletedWorkout.self, from: snapshot.payload) else { continue }
            repository.completedWorkouts.append(workout)
        }
        repository.persistWorkoutSnapshot()
    }

    func synchronizeWorkoutPlans() async {
        guard var remoteByID = try? await service.plans().reduce(
            into: [UUID: WorkoutPlanDocument](),
            { $0[$1.id] = $1 }
        ) else { return }
        let seededIDs = Set(MockData.workoutPlans.map(\.id)).union([PersonalWorkoutPlanCatalog.planID])

        for plan in repository.workoutPlans where !seededIDs.contains(plan.id) {
            guard let payload = payload(planID: plan.id), let data = try? encoder.encode(payload) else { continue }
            let knownRevision = repository.workoutPlanSyncRevisions[plan.id]
            let lastPayload = repository.workoutPlanLastSyncedPayloads[plan.id]

            if let remote = remoteByID[plan.id] {
                if knownRevision == nil {
                    if remote.payload == data {
                        remember(remote)
                    } else if let serverPayload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: remote.payload) {
                        let conflict = remappedConflictPayload(payload, documentID: makeUUID())
                        apply(serverPayload, replacing: plan.id)
                        apply(conflict, replacing: nil)
                    }
                    continue
                }

                if data == lastPayload {
                    if remote.payload != data,
                       let serverPayload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: remote.payload) {
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
                if let result = try? await service.savePlan(
                    document,
                    expectedRevision: knownRevision ?? remote.revision
                ) {
                    apply(result)
                    if case let .saved(saved) = result { remoteByID[saved.id] = saved }
                }
            } else {
                let document = WorkoutPlanDocument(
                    id: plan.id,
                    ownerID: repository.currentProfile.id,
                    revision: 0,
                    name: plan.name,
                    payload: data,
                    updatedAt: .now
                )
                if let result = try? await service.savePlan(document, expectedRevision: 0) {
                    apply(result)
                }
            }
        }

        for document in remoteByID.values where !repository.workoutPlans.contains(where: { $0.id == document.id }) {
            guard let payload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: document.payload) else { continue }
            apply(payload, replacing: nil)
            remember(document)
        }
        repository.persistWorkoutSnapshot()
    }

    func forgetPlan(_ planID: UUID) {
        repository.workoutPlanSyncRevisions[planID] = nil
        repository.workoutPlanLastSyncedPayloads[planID] = nil
        repository.persistWorkoutSnapshot()
    }

    func deleteRemotePlan(_ planID: UUID) async {
        try? await service.deletePlan(id: planID)
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

    private func apply(_ result: WorkoutSyncResult) {
        switch result {
        case let .saved(saved):
            remember(saved)
        case let .conflict(server, localCopy):
            if let payload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: server.payload) {
                apply(payload, replacing: server.id)
            }
            if let payload = try? decoder.decode(WorkoutPlanSyncPayload.self, from: localCopy.payload) {
                apply(remappedConflictPayload(payload, documentID: localCopy.id), replacing: nil)
            }
            remember(server)
            repository.workoutPlanSyncRevisions[localCopy.id] = localCopy.revision
        }
    }

    private func remember(_ document: WorkoutPlanDocument) {
        repository.workoutPlanSyncRevisions[document.id] = document.revision
        repository.workoutPlanLastSyncedPayloads[document.id] = document.payload
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

    private func remappedConflictPayload(
        _ payload: WorkoutPlanSyncPayload,
        documentID: UUID
    ) -> WorkoutPlanSyncPayload {
        let phaseIDs = Dictionary(uniqueKeysWithValues: payload.phases.map { ($0.id, makeUUID()) })
        let weekIDs = Dictionary(uniqueKeysWithValues: payload.weeks.map { ($0.id, makeUUID()) })
        let sessionIDs = Dictionary(uniqueKeysWithValues: payload.sessions.map { ($0.id, makeUUID()) })
        var plan = payload.plan
        plan.id = documentID
        plan.name += " (Conflict copy)"
        let phases = payload.phases.map { value -> WorkoutPhase in
            var copy = value
            copy.id = phaseIDs[value.id]!
            copy.planID = documentID
            return copy
        }
        let weeks = payload.weeks.map { value -> WorkoutWeek in
            var copy = value
            copy.id = weekIDs[value.id]!
            copy.planID = documentID
            copy.phaseID = phaseIDs[value.phaseID] ?? value.phaseID
            return copy
        }
        let sessions = payload.sessions.map { value -> WorkoutSession in
            var copy = value
            copy.id = sessionIDs[value.id]!
            copy.weekID = weekIDs[value.weekID] ?? value.weekID
            return copy
        }
        let prescriptions = payload.prescriptions.map { value -> WorkoutExercisePrescription in
            var copy = value
            copy.id = makeUUID()
            copy.sessionID = sessionIDs[value.sessionID] ?? value.sessionID
            return copy
        }
        var progression = payload.progression
        progression?.planID = documentID
        return WorkoutPlanSyncPayload(
            plan: plan,
            phases: phases,
            weeks: weeks,
            sessions: sessions,
            prescriptions: prescriptions,
            progression: progression
        )
    }
}
