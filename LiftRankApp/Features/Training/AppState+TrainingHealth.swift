import Foundation

@MainActor
extension AppState {
    var strainEntriesSorted: [StrainEntry] {
        trainingProgressStore.strainEntries.sorted { lhs, rhs in
            lhs.occurredAt > rhs.occurredAt
        }
    }

    var injuryEntriesSorted: [InjuryEntry] {
        trainingProgressStore.injuryEntries.sorted { lhs, rhs in
            lhs.occurredAt > rhs.occurredAt
        }
    }

    var activeInjuries: [InjuryEntry] {
        injuryEntriesSorted.filter { $0.status != .resolved }
    }

    var latestStrainEntry: StrainEntry? {
        strainEntriesSorted.first
    }

    func upsertStrainEntry(_ entry: StrainEntry) {
        let sanitized = StrainEntry(
            id: entry.id,
            occurredAt: entry.occurredAt,
            strain: min(10, max(1, entry.strain)),
            notes: entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        trainingProgressStore.updateStrainEntry(sanitized)
        Haptics.light()
    }

    func deleteStrainEntry(_ entry: StrainEntry) {
        trainingProgressStore.removeStrainEntry(entry.id)
        Haptics.warning()
    }

    func upsertInjuryEntry(_ entry: InjuryEntry) {
        let normalized = InjuryEntry(
            id: entry.id,
            occurredAt: entry.occurredAt,
            area: entry.area.trimmingCharacters(in: .whitespacesAndNewlines),
            description: entry.description.trimmingCharacters(in: .whitespacesAndNewlines),
            intensity: min(10, max(1, entry.intensity)),
            status: entry.status
        )
        trainingProgressStore.updateInjuryEntry(normalized)
        Haptics.light()
    }

    func deleteInjuryEntry(_ entry: InjuryEntry) {
        trainingProgressStore.removeInjuryEntry(entry.id)
        Haptics.warning()
    }

    func markInjuryResolved(_ entry: InjuryEntry) {
        var updated = entry
        updated.status = .resolved
        upsertInjuryEntry(updated)
        Haptics.success()
    }
}
