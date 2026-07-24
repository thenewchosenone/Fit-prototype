import Foundation


enum ExerciseLibraryBodyArea: String, CaseIterable, Hashable, Identifiable {
    case upperBody = "Upper body"
    case lowerBody = "Lower body"
    case core = "Core"
    case fullBody = "Full body"

    var id: String { rawValue }
}

enum ExerciseLibraryFilterCategory: String, Hashable {
    case bodyAreas
    case primaryMuscles
    case equipment
    case movementTypes
    case trackingTypes
}

struct ExerciseLibraryFilterChip: Identifiable {
    let category: ExerciseLibraryFilterCategory
    let title: String
    var id: String { category.rawValue }
}

struct ExerciseLibraryFilterSelection: Equatable {
    var bodyAreas: Set<ExerciseLibraryBodyArea> = []
    var primaryMuscles: Set<ExerciseMuscleRegion> = []
    var equipment: Set<String> = []
    var movementTypes: Set<String> = []
    var trackingTypes: Set<String> = []

    var isEmpty: Bool { activeCategoryCount == 0 }

    var activeCategoryCount: Int {
        [!bodyAreas.isEmpty, !primaryMuscles.isEmpty, !equipment.isEmpty, !movementTypes.isEmpty, !trackingTypes.isEmpty]
            .filter { $0 }
            .count
    }

    var activeChips: [ExerciseLibraryFilterChip] {
        var chips: [ExerciseLibraryFilterChip] = []
        if !bodyAreas.isEmpty {
            chips.append(.init(category: .bodyAreas, title: summary("Area", values: bodyAreas.map(\.rawValue))))
        }
        if !primaryMuscles.isEmpty {
            chips.append(.init(category: .primaryMuscles, title: summary("Muscle", values: primaryMuscles.map(\.displayName))))
        }
        if !equipment.isEmpty {
            chips.append(.init(category: .equipment, title: summary("Equipment", values: Array(equipment))))
        }
        if !movementTypes.isEmpty {
            chips.append(.init(category: .movementTypes, title: summary("Movement", values: Array(movementTypes))))
        }
        if !trackingTypes.isEmpty {
            chips.append(.init(category: .trackingTypes, title: summary("Tracking", values: Array(trackingTypes))))
        }
        return chips
    }

    func matches(_ exercise: TrainingExerciseCatalogItem) -> Bool {
        let primary = Set(exercise.resolvedMuscleProfile.primary)
        let areaMatch = bodyAreas.isEmpty || bodyAreas.contains { area in
            switch area {
            case .upperBody:
                return !primary.isDisjoint(with: [
                    .neck, .upperChest, .chest, .lowerChest, .frontDelts, .sideDelts,
                    .rearDelts, .biceps, .triceps, .forearms, .traps, .upperBack, .lats
                ])
            case .lowerBody:
                return !primary.isDisjoint(with: [.glutes, .adductors, .quads, .hamstrings, .calves, .tibialis])
            case .core:
                return !primary.isDisjoint(with: [.abs, .obliques, .spinalErectors])
            case .fullBody:
                return primary.contains(.fullBody)
            }
        }
        return areaMatch &&
            (primaryMuscles.isEmpty || !primary.isDisjoint(with: primaryMuscles)) &&
            (equipment.isEmpty || equipment.contains(exercise.equipment)) &&
            (movementTypes.isEmpty || movementTypes.contains(exercise.movementType)) &&
            (trackingTypes.isEmpty || trackingTypes.contains(exercise.trackingType))
    }

    mutating func clear(category: ExerciseLibraryFilterCategory) {
        switch category {
        case .bodyAreas: bodyAreas.removeAll()
        case .primaryMuscles: primaryMuscles.removeAll()
        case .equipment: equipment.removeAll()
        case .movementTypes: movementTypes.removeAll()
        case .trackingTypes: trackingTypes.removeAll()
        }
    }

    private func summary(_ label: String, values: [String]) -> String {
        let sorted = values.sorted()
        guard let first = sorted.first else { return label }
        return sorted.count == 1 ? first : "\(label): \(first) +\(sorted.count - 1)"
    }
}

@MainActor
final class ExerciseLibraryStore {
    private let repository: any ExerciseRepository
    private let bundledExercises: [TrainingExerciseCatalogItem]
    private let makeID: () -> UUID

    init(
        repository: any ExerciseRepository,
        bundledExercises: [TrainingExerciseCatalogItem] = MockData.trainingExerciseLibrary,
        makeID: @escaping () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.bundledExercises = bundledExercises
        self.makeID = makeID
    }

    var customExercises: [TrainingExerciseCatalogItem] {
        repository.customTrainingExercises
    }

    var exercises: [TrainingExerciseCatalogItem] {
        bundledExercises + repository.customTrainingExercises
    }

    func search(
        query: String,
        filters: ExerciseLibraryFilterSelection? = nil,
        excludingIDs: Set<String> = []
    ) -> [ExerciseSearchResult] {
        ExerciseCatalogSearch.search(exercises: exercises, query: query)
            .filter { !excludingIDs.contains($0.exercise.id) }
            .filter { filters?.matches($0.exercise) ?? true }
    }

    func substitutionRecommendations(
        for exercise: TrainingExerciseCatalogItem,
        equipmentFilter: Set<String> = [],
        limit: Int = 8
    ) -> [ExerciseSubstitutionRecommendation] {
        exercises
            .filter { $0.id != exercise.id }
            .filter { equipmentFilter.isEmpty || equipmentFilter.contains($0.equipment) }
            .compactMap { candidate in
                let primaryOverlap = overlapScore(
                    exercise.resolvedMuscleProfile.primary,
                    candidate.resolvedMuscleProfile.primary
                )
                let secondaryOverlap = overlapScore(
                    exercise.resolvedMuscleProfile.secondary,
                    candidate.resolvedMuscleProfile.secondary
                )
                let movementMatch = exercise.movementPattern == candidate.movementPattern ? 1.0 : 0.0
                let equipmentMatch = exercise.equipment == candidate.equipment ? 1.0 : 0.0
                let trackingMatch = trackingCompatibility(base: exercise.trackingType, candidate: candidate.trackingType)
                let rankingMatch = rankingCompatibility(base: exercise.rankingExerciseID, candidate: candidate.rankingExerciseID)
                let difficultyDistance = Double(abs(exercise.difficulty.rawValue - candidate.difficulty.rawValue))
                let difficultyScore = max(0, 1 - (difficultyDistance / 2))
                let score = (primaryOverlap * 0.34) +
                    (movementMatch * 0.25) +
                    (secondaryOverlap * 0.12) +
                    (equipmentMatch * 0.09) +
                    (trackingMatch * 0.10) +
                    (rankingMatch * 0.05) +
                    (difficultyScore * 0.05)
                guard score >= 0.35 else { return nil }
                let reasons = substitutionReasons(
                    base: exercise,
                    candidate: candidate,
                    movementMatch: movementMatch > 0,
                    equipmentMatch: equipmentMatch > 0,
                    trackingMatch: trackingMatch >= 0.75,
                    rankingMatch: rankingMatch > 0
                )
                guard !reasons.isEmpty else { return nil }
                return ExerciseSubstitutionRecommendation(exercise: candidate, score: score, reasons: reasons)
            }
            .sorted {
                if $0.score == $1.score { return $0.exercise.name < $1.exercise.name }
                return $0.score > $1.score
            }
            .prefix(limit)
            .map { $0 }
    }

    @discardableResult
    func createCustomExercise(
        name: String,
        bodyPart: String,
        equipment: String,
        trackingType: String,
        primaryMuscles: [ExerciseMuscleRegion] = [],
        secondaryMuscles: [ExerciseMuscleRegion] = []
    ) -> TrainingExerciseCatalogItem? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }

        let fallbackProfile = ExerciseMuscleProfileResolver.profile(name: cleanName, bodyPart: bodyPart)
        let selectedPrimary = primaryMuscles.isEmpty ? fallbackProfile.primary : primaryMuscles
        let selectedSecondary = secondaryMuscles.filter { !selectedPrimary.contains($0) }
        let hasFront = selectedPrimary.contains { !$0.isBackFacing && $0 != .fullBody }
        let hasBack = selectedPrimary.contains { $0.isBackFacing }
        let orientation: ExerciseMuscleMapOrientation = selectedPrimary.contains(.fullBody) || (hasFront && hasBack)
            ? .split
            : (hasBack ? .back : .front)
        let exercise = TrainingExerciseCatalogItem(
            id: "custom_\(makeID().uuidString)",
            name: cleanName,
            bodyPart: bodyPart,
            workoutCategory: "Custom",
            defaultSets: 3,
            defaultReps: "8-12",
            symbolName: "dumbbell.fill",
            secondaryMuscles: [],
            equipment: equipment,
            movementType: "Custom",
            trackingType: normalizedTrackingType(trackingType),
            defaultRestSeconds: 120,
            muscleProfile: ExerciseMuscleProfile(
                primary: selectedPrimary,
                secondary: selectedSecondary,
                orientation: orientation
            )
        )
        repository.addCustomTrainingExercise(exercise)
        return exercise
    }

    private func overlapScore<T: Hashable>(_ lhs: [T], _ rhs: [T]) -> Double {
        let left = Set(lhs)
        let right = Set(rhs)
        guard !left.isEmpty || !right.isEmpty else { return 0 }
        let union = Double(left.union(right).count)
        return union == 0 ? 0 : Double(left.intersection(right).count) / union
    }

    private func trackingCompatibility(base: String, candidate: String) -> Double {
        let base = normalizedTrackingType(base)
        let candidate = normalizedTrackingType(candidate)
        if base == candidate { return 1.0 }
        if Set([base, candidate]) == Set(["Weight + Reps", "Bodyweight Reps"]) { return 0.55 }
        if Set([base, candidate]) == Set(["Bodyweight Reps", "Assisted Bodyweight"]) { return 0.70 }
        if base.contains("Time") && candidate.contains("Time") { return 0.75 }
        return 0.0
    }

    private func rankingCompatibility(base: String?, candidate: String?) -> Double {
        switch (base, candidate) {
        case let (lhs?, rhs?) where lhs == rhs:
            return 1.0
        case (nil, nil):
            return 0.5
        default:
            return 0.0
        }
    }

    private func normalizedTrackingType(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch clean.lowercased() {
        case "weight", "weighted", "weight and reps", "weight + reps":
            return "Weight + Reps"
        case "bodyweight", "bodyweight reps", "reps only":
            return "Bodyweight Reps"
        case "assisted", "assisted bodyweight":
            return "Assisted Bodyweight"
        case "duration", "time":
            return "Time"
        case "weighted time", "weight + time":
            return "Weight + Time"
        default:
            return clean.isEmpty ? "Weight + Reps" : clean
        }
    }

    private func substitutionReasons(
        base: TrainingExerciseCatalogItem,
        candidate: TrainingExerciseCatalogItem,
        movementMatch: Bool,
        equipmentMatch: Bool,
        trackingMatch: Bool,
        rankingMatch: Bool
    ) -> [String] {
        var reasons: [String] = []
        let primaryOverlap = Set(base.resolvedMuscleProfile.primary)
            .intersection(candidate.resolvedMuscleProfile.primary)
        let secondaryOverlap = Set(base.resolvedMuscleProfile.secondary)
            .intersection(candidate.resolvedMuscleProfile.secondary)
        if !primaryOverlap.isEmpty { reasons.append("same primary muscles") }
        if movementMatch { reasons.append("same \(base.movementPattern.rawValue.lowercased()) pattern") }
        if equipmentMatch { reasons.append("same equipment") }
        if trackingMatch { reasons.append("same tracking") }
        if rankingMatch { reasons.append("same ranking movement") }
        if !secondaryOverlap.isEmpty { reasons.append("similar assisting muscles") }
        if reasons.isEmpty && abs(base.difficulty.rawValue - candidate.difficulty.rawValue) <= 1 {
            reasons.append("similar difficulty")
        }
        return Array(reasons.prefix(3))
    }
}
