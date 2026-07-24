import Foundation
import SwiftData

@MainActor
protocol ForumPersistenceStore: AnyObject {
    func loadSnapshot() -> ForumPersistenceSnapshot?
    func saveSnapshot(_ snapshot: ForumPersistenceSnapshot)
    func reset()
}

@MainActor
final class InMemoryForumPersistenceStore: ForumPersistenceStore {
    private(set) var snapshot: ForumPersistenceSnapshot?

    init(snapshot: ForumPersistenceSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func loadSnapshot() -> ForumPersistenceSnapshot? { snapshot }
    func saveSnapshot(_ snapshot: ForumPersistenceSnapshot) { self.snapshot = snapshot }
    func reset() { snapshot = nil }
}

@MainActor
final class SwiftDataForumPersistenceStore: ForumPersistenceStore {
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(context: ModelContext) {
        self.context = context
    }

    func loadSnapshot() -> ForumPersistenceSnapshot? {
        guard let record = try? context.fetch(FetchDescriptor<PersistentForumState>()).first else { return nil }
        return try? decoder.decode(ForumPersistenceSnapshot.self, from: record.payload)
    }

    func saveSnapshot(_ snapshot: ForumPersistenceSnapshot) {
        guard let payload = try? encoder.encode(snapshot) else { return }
        let descriptor = FetchDescriptor<PersistentForumState>()
        if let existing = try? context.fetch(descriptor).first {
            existing.schemaVersion = snapshot.schemaVersion
            existing.updatedAt = .now
            existing.payload = payload
        } else {
            context.insert(PersistentForumState(schemaVersion: snapshot.schemaVersion, payload: payload))
        }
        try? context.save()
    }

    func reset() {
        let records = (try? context.fetch(FetchDescriptor<PersistentForumState>())) ?? []
        records.forEach(context.delete)
        try? context.save()
    }
}
