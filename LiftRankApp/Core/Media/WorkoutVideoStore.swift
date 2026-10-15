import Foundation

protocol WorkoutVideoStoring: AnyObject {
    func save(_ data: Data, fileExtension: String) async throws -> URL
    func remove(_ url: URL)
    func prune(retaining URLs: Set<URL>, olderThan cutoff: Date)
}

final class LocalWorkoutVideoStore: WorkoutVideoStoring {
    private let fileManager: FileManager
    private let makeID: () -> UUID

    init(
        fileManager: FileManager = .default,
        makeID: @escaping () -> UUID = { UUID() }
    ) {
        self.fileManager = fileManager
        self.makeID = makeID
    }

    func save(_ data: Data, fileExtension: String) async throws -> URL {
        try await Task.detached(priority: .userInitiated) { [self] in
            try saveSynchronously(data, fileExtension: fileExtension)
        }.value
    }

    private func saveSynchronously(_ data: Data, fileExtension: String) throws -> URL {
        let root = try rootURL(create: true)
        let url = root.appendingPathComponent("\(makeID().uuidString).\(fileExtension)")
        try data.write(to: url, options: .atomic)
        try? (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        return url
    }

    func remove(_ url: URL) {
        let fileManager = fileManager
        Task.detached(priority: .utility) {
            guard let root = try? Self.rootURL(fileManager: fileManager, create: false),
                  url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/") else { return }
            try? fileManager.removeItem(at: url)
        }
    }

    func prune(retaining URLs: Set<URL>, olderThan cutoff: Date) {
        let fileManager = fileManager
        Task.detached(priority: .utility) {
            guard let root = try? Self.rootURL(fileManager: fileManager, create: false),
                  let files = try? fileManager.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles]
                  ) else { return }
            let retainedPaths = Set(URLs.map { $0.standardizedFileURL.path })
            for file in files where !retainedPaths.contains(file.standardizedFileURL.path) {
                let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                guard values?.isRegularFile == true,
                      (values?.contentModificationDate ?? .distantPast) < cutoff else { continue }
                try? fileManager.removeItem(at: file)
            }
        }
    }

    private func rootURL(create: Bool) throws -> URL {
        try Self.rootURL(fileManager: fileManager, create: create)
    }

    private static func rootURL(fileManager: FileManager, create: Bool) throws -> URL {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: create
        ).appendingPathComponent("WorkoutPRVideos", isDirectory: true)
        if create {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }
}
