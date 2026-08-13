import Foundation

extension DemoRepository {
    func clearTrainingHealthEntries() {
        bodyweightEntries.removeAll()
        strainEntries.removeAll()
        injuryEntries.removeAll()
        persistWorkoutSnapshot()
    }

    func updateBodyweight(_ entry: BodyweightEntry) {
        if let index = bodyweightEntries.firstIndex(where: { $0.id == entry.id }) {
            bodyweightEntries[index] = entry
        } else {
            bodyweightEntries.append(entry)
        }
        bodyweightEntries.sort { $0.targetDate < $1.targetDate }
        persistWorkoutSnapshot()
    }

    func updateStrainEntry(_ entry: StrainEntry) {
        if let index = strainEntries.firstIndex(where: { $0.id == entry.id }) {
            strainEntries[index] = entry
        } else {
            strainEntries.append(entry)
        }
        strainEntries.sort { $0.occurredAt > $1.occurredAt }
        persistWorkoutSnapshot()
    }

    func deleteStrainEntry(_ entryID: UUID) {
        strainEntries.removeAll { $0.id == entryID }
        persistWorkoutSnapshot()
    }

    func updateInjuryEntry(_ entry: InjuryEntry) {
        if let index = injuryEntries.firstIndex(where: { $0.id == entry.id }) {
            injuryEntries[index] = entry
        } else {
            injuryEntries.append(entry)
        }
        injuryEntries.sort { $0.occurredAt > $1.occurredAt }
        persistWorkoutSnapshot()
    }

    func deleteInjuryEntry(_ entryID: UUID) {
        injuryEntries.removeAll { $0.id == entryID }
        persistWorkoutSnapshot()
    }
}
