import Foundation
import SwiftData

@MainActor
protocol WorkoutPersistenceStore: AnyObject {
    func loadSnapshot() -> WorkoutPersistenceSnapshot?
    func saveSnapshot(_ snapshot: WorkoutPersistenceSnapshot)
    func saveSnapshotWithoutBlockingUI(_ snapshot: WorkoutPersistenceSnapshot) async
    func legacyWorkoutRecords() -> [LegacyWorkoutRecordValue]
    func reset()
}

extension WorkoutPersistenceStore {
    func saveSnapshotWithoutBlockingUI(_ snapshot: WorkoutPersistenceSnapshot) async {
        saveSnapshot(snapshot)
    }
}

@MainActor
final class InMemoryWorkoutPersistenceStore: WorkoutPersistenceStore {
    private(set) var snapshot: WorkoutPersistenceSnapshot?
    private(set) var saveCount = 0
    var legacyRecords: [LegacyWorkoutRecordValue]

    init(snapshot: WorkoutPersistenceSnapshot? = nil, legacyRecords: [LegacyWorkoutRecordValue] = []) {
        self.snapshot = snapshot
        self.legacyRecords = legacyRecords
    }

    func loadSnapshot() -> WorkoutPersistenceSnapshot? { snapshot }
    func saveSnapshot(_ snapshot: WorkoutPersistenceSnapshot) {
        saveCount += 1
        self.snapshot = snapshot
    }
    func legacyWorkoutRecords() -> [LegacyWorkoutRecordValue] { legacyRecords }

    func reset() {
        snapshot = nil
        saveCount = 0
        legacyRecords = []
    }
}

@MainActor
final class SwiftDataWorkoutPersistenceStore: WorkoutPersistenceStore {
    private let context: ModelContext
    private let encoder: PropertyListEncoder
    private let decoder = PropertyListDecoder()
    private let legacyDecoder = JSONDecoder()
    private var snapshotRecord: PersistentWorkoutState?
    private var lastSavedPayload: Data?

    init(context: ModelContext) {
        self.context = context
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        self.encoder = encoder
    }

    func loadSnapshot() -> WorkoutPersistenceSnapshot? {
        guard let record = try? context.fetch(FetchDescriptor<PersistentWorkoutState>()).first else { return nil }
        snapshotRecord = record
        lastSavedPayload = record.payload
        return (try? decoder.decode(WorkoutPersistenceSnapshot.self, from: record.payload)) ??
            (try? legacyDecoder.decode(WorkoutPersistenceSnapshot.self, from: record.payload))
    }

    func saveSnapshot(_ snapshot: WorkoutPersistenceSnapshot) {
        guard let payload = try? encoder.encode(snapshot), payload != lastSavedPayload else { return }
        savePayload(payload, schemaVersion: snapshot.schemaVersion)
    }

    func saveSnapshotWithoutBlockingUI(_ snapshot: WorkoutPersistenceSnapshot) async {
        let payload = await Task.detached(priority: .utility) {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            return try? encoder.encode(snapshot)
        }.value
        guard !Task.isCancelled, let payload, payload != lastSavedPayload else { return }
        savePayload(payload, schemaVersion: snapshot.schemaVersion)
    }

    private func savePayload(_ payload: Data, schemaVersion: Int) {
        if let existing = snapshotRecord ?? (try? context.fetch(FetchDescriptor<PersistentWorkoutState>()).first) {
            snapshotRecord = existing
            existing.schemaVersion = schemaVersion
            existing.updatedAt = .now
            existing.payload = payload
        } else {
            let record = PersistentWorkoutState(schemaVersion: schemaVersion, payload: payload)
            context.insert(record)
            snapshotRecord = record
        }
        guard (try? context.save()) != nil else { return }
        lastSavedPayload = payload
    }

    func legacyWorkoutRecords() -> [LegacyWorkoutRecordValue] {
        let records = (try? context.fetch(FetchDescriptor<PersistentWorkoutRecord>())) ?? []
        return records.map {
            LegacyWorkoutRecordValue(
                id: $0.id,
                exercise: $0.exercise,
                workout: $0.workout,
                weight: $0.weight,
                reps: $0.reps,
                rpe: $0.rpe,
                performedAt: $0.performedAt
            )
        }
    }

    func reset() {
        let liftRecords = (try? context.fetch(FetchDescriptor<PersistentLiftRecord>())) ?? []
        liftRecords.forEach(context.delete)
        let settings = (try? context.fetch(FetchDescriptor<PersistentSettings>())) ?? []
        settings.forEach(context.delete)
        let snapshots = (try? context.fetch(FetchDescriptor<PersistentWorkoutState>())) ?? []
        snapshots.forEach(context.delete)
        let legacyRecords = (try? context.fetch(FetchDescriptor<PersistentWorkoutRecord>())) ?? []
        legacyRecords.forEach(context.delete)
        try? context.save()
        snapshotRecord = nil
        lastSavedPayload = nil
    }
}
