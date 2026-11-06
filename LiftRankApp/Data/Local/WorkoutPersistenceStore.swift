import Foundation
import SwiftData

@MainActor
protocol WorkoutPersistenceStore: AnyObject {
    var loadError: String? { get }
    func loadSnapshot() -> WorkoutPersistenceSnapshot?
    func saveSnapshot(_ snapshot: WorkoutPersistenceSnapshot) throws
    func saveSnapshotWithoutBlockingUI(_ snapshot: WorkoutPersistenceSnapshot) async throws
    func legacyWorkoutRecords() -> [LegacyWorkoutRecordValue]
    func reset()
}

extension WorkoutPersistenceStore {
    func saveSnapshotWithoutBlockingUI(_ snapshot: WorkoutPersistenceSnapshot) async throws {
        try saveSnapshot(snapshot)
    }
}

@MainActor
final class InMemoryWorkoutPersistenceStore: WorkoutPersistenceStore {
    var loadError: String? { nil }
    private(set) var snapshot: WorkoutPersistenceSnapshot?
    private(set) var saveCount = 0
    var legacyRecords: [LegacyWorkoutRecordValue]

    init(snapshot: WorkoutPersistenceSnapshot? = nil, legacyRecords: [LegacyWorkoutRecordValue] = []) {
        self.snapshot = snapshot
        self.legacyRecords = legacyRecords
    }

    func loadSnapshot() -> WorkoutPersistenceSnapshot? { snapshot }
    func saveSnapshot(_ snapshot: WorkoutPersistenceSnapshot) throws {
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
    private(set) var loadError: String?

    init(context: ModelContext) {
        self.context = context
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        self.encoder = encoder
    }

    func loadSnapshot() -> WorkoutPersistenceSnapshot? {
        let record: PersistentWorkoutState
        do {
            guard let saved = try context.fetch(FetchDescriptor<PersistentWorkoutState>()).first else { return nil }
            record = saved
        } catch {
            loadError = "Could not read workout storage: \(error.localizedDescription)"
            return nil
        }
        snapshotRecord = record
        lastSavedPayload = record.payload
        if let snapshot = try? decoder.decode(WorkoutPersistenceSnapshot.self, from: record.payload) {
            loadError = nil
            return snapshot
        }
        if let snapshot = try? legacyDecoder.decode(WorkoutPersistenceSnapshot.self, from: record.payload) {
            loadError = nil
            return snapshot
        }
        loadError = "Saved workout history could not be decoded. The on-device record was kept for recovery."
        return nil
    }

    func saveSnapshot(_ snapshot: WorkoutPersistenceSnapshot) throws {
        let payload = try encoder.encode(snapshot)
        guard payload != lastSavedPayload else { return }
        try savePayload(payload, schemaVersion: snapshot.schemaVersion)
    }

    func saveSnapshotWithoutBlockingUI(_ snapshot: WorkoutPersistenceSnapshot) async throws {
        let payload = try await Task.detached(priority: .utility) {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            return try encoder.encode(snapshot)
        }.value
        try Task.checkCancellation()
        guard payload != lastSavedPayload else { return }
        try savePayload(payload, schemaVersion: snapshot.schemaVersion)
    }

    private func savePayload(_ payload: Data, schemaVersion: Int) throws {
        if let existing = try snapshotRecord ?? context.fetch(FetchDescriptor<PersistentWorkoutState>()).first {
            snapshotRecord = existing
            existing.schemaVersion = schemaVersion
            existing.updatedAt = .now
            existing.payload = payload
        } else {
            let record = PersistentWorkoutState(schemaVersion: schemaVersion, payload: payload)
            context.insert(record)
            snapshotRecord = record
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            snapshotRecord = nil
            throw error
        }
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
