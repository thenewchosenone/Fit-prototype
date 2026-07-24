import Foundation

protocol WorkoutVideoStoring: AnyObject {
    func save(_ data: Data, fileExtension: String) throws -> URL
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
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("WorkoutPRVideos", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("\(makeID().uuidString).\(fileExtension)")
        try data.write(to: url, options: .atomic)
        return url
    }
}
