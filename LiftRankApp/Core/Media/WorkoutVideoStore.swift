import Foundation

protocol WorkoutVideoStoring: AnyObject {
    func save(_ data: Data, fileExtension: String) throws -> URL
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

    func save(_ data: Data, fileExtension: String) throws -> URL {
        let root = try rootURL(create: true)
        let url = root.appendingPathComponent("\(makeID().uuidString).\(fileExtension)")
        try data.write(to: url, options: .atomic)
        try? (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        return url
    }

    func remove(_ url: URL) {
        guard isManaged(url) else { return }
        try? fileManager.removeItem(at: url)
    }

    func prune(retaining URLs: Set<URL>, olderThan cutoff: Date) {
        guard let root = try? rootURL(create: false),
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

    private func isManaged(_ url: URL) -> Bool {
        guard let root = try? rootURL(create: false) else { return false }
        return url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/")
    }

    private func rootURL(create: Bool) throws -> URL {
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
