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

}
