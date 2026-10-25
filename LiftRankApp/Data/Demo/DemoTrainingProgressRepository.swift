import Foundation

extension DemoRepository {
    func clearTrainingHealthEntries() {
        bodyweightEntries.removeAll()
        strainEntries.removeAll()
        injuryEntries.removeAll()
        scheduleWorkoutSnapshotPersistence()
    }

    func updateBodyweight(_ entry: BodyweightEntry) {
        if let index = bodyweightEntries.firstIndex(where: { $0.id == entry.id }) {
            bodyweightEntries[index] = entry
        } else {
            bodyweightEntries.append(entry)
        }
        bodyweightEntries.sort { $0.targetDate < $1.targetDate }
        scheduleWorkoutSnapshotPersistence()
    }

}
