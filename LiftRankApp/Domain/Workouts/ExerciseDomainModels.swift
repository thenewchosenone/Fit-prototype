import Foundation

struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let symbolName: String
    let isPowerlift: Bool
}

struct TrainingExerciseCatalogItem: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var bodyPart: String
    var workoutCategory: String
    var defaultSets: Int
    var defaultReps: String
    var symbolName: String
    var secondaryMuscles: [String] = []
    var equipment: String = "Bodyweight"
    var movementType: String = "Strength"
    var trackingType: String = "Weight + Reps"
    var defaultRestSeconds: Int = 120
    var searchAliases: [String] = []
    var muscleProfile: ExerciseMuscleProfile? = nil
    var movementPattern: ExerciseMovementPattern = .other
    var difficulty: ExerciseDifficulty = .moderate
    var demonstrationMediaID: String? = nil
    /// Maps only canonical competition-style movements into the public ranking catalog.
    /// A nil value keeps the exercise private to workout progress.
    var rankingExerciseID: String? = nil

    var resolvedMuscleProfile: ExerciseMuscleProfile {
        muscleProfile ?? ExerciseMuscleProfileResolver.profile(name: name, bodyPart: bodyPart)
    }

    var guidance: ExerciseGuidance? {
        ExerciseGuidanceCatalog.guidance(for: self)
    }

    var rankingEligibilityLabel: String {
        rankingExerciseID == nil ? "Workout progress only" : "Counts toward rankings"
    }

    func matchesSearch(_ query: String) -> Bool {
        matchResult(for: query) != nil
    }

    func matchResult(for query: String) -> ExerciseSearchResult? {
        ExerciseCatalogSearch.match(exercise: self, query: query)
    }
}

struct ExerciseGuidance: Hashable {
    var summary: String
    var steps: [String]
    var cues: [String]
}

enum ExerciseTrackingKind: String, CaseIterable, Hashable {
    case weightReps = "Weight + Reps"
    case bodyweightReps = "Bodyweight Reps"
    case assistedBodyweight = "Assisted Bodyweight"
    case repsOnly = "Reps Only"
    case time = "Time"
    case weightTime = "Weight + Time"

    init(_ rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "bodyweight", "bodyweight reps":
            self = .bodyweightReps
        case "assisted", "assisted bodyweight":
            self = .assistedBodyweight
        case "reps only":
            self = .repsOnly
        case "duration", "time":
            self = .time
        case "weighted time", "weight + time":
            self = .weightTime
        default:
            self = .weightReps
        }
    }

    var requiresWeight: Bool {
        switch self {
        case .weightReps, .assistedBodyweight, .weightTime:
            return true
        case .bodyweightReps, .repsOnly, .time:
            return false
        }
    }

    var usesDuration: Bool { self == .time || self == .weightTime }
    var repsHeader: String { usesDuration ? "TIME" : "REPS" }
    var valueHint: String {
        switch self {
        case .weightReps: "Enter reps and weight."
        case .bodyweightReps, .repsOnly: "Enter reps."
        case .assistedBodyweight: "Enter reps and assistance."
        case .time: "Enter duration in seconds."
        case .weightTime: "Enter duration and weight."
        }
    }
}

enum ExerciseMovementPattern: String, Codable, CaseIterable, Hashable, Identifiable {
    case horizontalPress = "Horizontal press"
    case verticalPress = "Vertical press"
    case horizontalPull = "Horizontal pull"
    case verticalPull = "Vertical pull"
    case squat = "Squat"
    case hinge = "Hinge"
    case lunge = "Lunge"
    case curl = "Curl"
    case elbowExtension = "Extension"
    case shoulderIsolation = "Shoulder isolation"
    case calf = "Calf"
    case core = "Core"
    case carry = "Carry"
    case other = "Other"

    var id: String { rawValue }
}

enum ExerciseDifficulty: Int, Codable, CaseIterable, Hashable, Identifiable {
    case beginner = 0
    case moderate = 1
    case advanced = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .moderate: "Moderate"
        case .advanced: "Advanced"
        }
    }
}

enum ExerciseSearchMatchKind: String, Codable, Hashable {
    case canonicalExact
    case aliasExact
    case namePrefix
    case nameTokenSet
    case aliasTokenSet
    case equipmentPrimary
    case secondaryPartial
}

struct ExerciseSearchResult: Identifiable, Hashable {
    var id: String { exercise.id }
    let exercise: TrainingExerciseCatalogItem
    let score: Int
    let kind: ExerciseSearchMatchKind
    let matchedAlias: String?

    var reasonLabel: String? {
        guard let matchedAlias else { return nil }
        return "Matched \(matchedAlias)"
    }
}

struct ExerciseSubstitutionRecommendation: Identifiable, Hashable {
    var id: String { exercise.id }
    let exercise: TrainingExerciseCatalogItem
    let score: Double
    let reasons: [String]
}

enum ExerciseCatalogSearch {
    static func search(
        exercises: [TrainingExerciseCatalogItem],
        query: String
    ) -> [ExerciseSearchResult] {
        let cleanQuery = normalize(query)
        let results = exercises.compactMap { match(exercise: $0, query: cleanQuery) }
        return results.sorted {
            if $0.score == $1.score { return $0.exercise.name < $1.exercise.name }
            return $0.score > $1.score
        }
    }

    static func match(exercise: TrainingExerciseCatalogItem, query: String) -> ExerciseSearchResult? {
        let cleanQuery = normalize(query)
        guard !cleanQuery.isEmpty else {
            return ExerciseSearchResult(exercise: exercise, score: 0, kind: .secondaryPartial, matchedAlias: nil)
        }

        let normalizedName = normalize(exercise.name)
        let normalizedAliases = exercise.searchAliases.map(normalize)
        let queryTokens = tokens(from: cleanQuery)
        let nameTokens = tokens(from: normalizedName)
        let aliasTokens = normalizedAliases.map(tokens)
        let primaryMuscles = exercise.resolvedMuscleProfile.primary.map(\.displayName).map(normalize)
        let secondaryMuscles = exercise.resolvedMuscleProfile.secondary.map(\.displayName).map(normalize)
        let metadataTokens = tokens(from: normalize(exercise.equipment)) +
            tokens(from: normalize(exercise.bodyPart)) +
            tokens(from: normalize(exercise.movementPattern.rawValue))

        if normalizedName == cleanQuery {
            return ExerciseSearchResult(exercise: exercise, score: 700, kind: .canonicalExact, matchedAlias: nil)
        }

        if let alias = normalizedAliases.first(where: { $0 == cleanQuery }) {
            return ExerciseSearchResult(exercise: exercise, score: 640, kind: .aliasExact, matchedAlias: alias)
        }

        if normalizedName.hasPrefix(cleanQuery) {
            return ExerciseSearchResult(exercise: exercise, score: 560, kind: .namePrefix, matchedAlias: nil)
        }

        if queryTokens.allSatisfy(nameTokens.contains) {
            return ExerciseSearchResult(exercise: exercise, score: 480, kind: .nameTokenSet, matchedAlias: nil)
        }

        if let aliasIndex = aliasTokens.firstIndex(where: { tokens in
            let joined = tokens.joined(separator: " ")
            return joined.hasPrefix(cleanQuery) || queryTokens.allSatisfy(tokens.contains)
        }) {
            return ExerciseSearchResult(
                exercise: exercise,
                score: 420,
                kind: .aliasTokenSet,
                matchedAlias: normalizedAliases[aliasIndex]
            )
        }

        let primaryMatch = queryTokens.count == 1 && primaryMuscles.contains {
            tokens(from: $0).contains(queryTokens[0])
        }
        let equipmentMatch = queryTokens.count == 1 && metadataTokens.contains(queryTokens[0])
        if primaryMatch || equipmentMatch {
            return ExerciseSearchResult(
                exercise: exercise,
                score: primaryMatch ? 340 : 300,
                kind: .equipmentPrimary,
                matchedAlias: nil
            )
        }

        let secondaryMatch = secondaryMuscles.contains { muscle in
            queryTokens.allSatisfy { token in
                guard token.count >= 2 else { return false }
                return muscle.contains(token) || token.contains(muscle)
            }
        }
        let searchableValues = [normalizedName] + normalizedAliases
        let partialTokenMatch = queryTokens.allSatisfy { token in
            guard token.count >= 2 else { return false }
            return searchableValues.contains { $0.contains(token) }
        }
        if secondaryMatch || partialTokenMatch {
            return ExerciseSearchResult(exercise: exercise, score: 220, kind: .secondaryPartial, matchedAlias: nil)
        }

        return nil
    }

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func tokens(from value: String) -> [String] {
        normalize(value).split(separator: " ").map(String.init)
    }
}

enum ExerciseMuscleRegion: String, CaseIterable, Codable, Hashable, Identifiable {
    case neck
    case upperChest
    case chest
    case lowerChest
    case frontDelts
    case sideDelts
    case rearDelts
    case biceps
    case triceps
    case forearms
    case traps
    case upperBack
    case lats
    case spinalErectors
    case abs
    case obliques
    case glutes
    case adductors
    case quads
    case hamstrings
    case calves
    case tibialis
    case fullBody

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upperChest: "Upper chest"
        case .lowerChest: "Lower chest"
        case .frontDelts: "Front delts"
        case .sideDelts: "Side delts"
        case .rearDelts: "Rear delts"
        case .upperBack: "Upper back"
        case .spinalErectors: "Spinal erectors"
        case .fullBody: "Full body"
        default: rawValue.capitalized
        }
    }

    var isBackFacing: Bool {
        switch self {
        case .rearDelts, .triceps, .traps, .upperBack, .lats, .spinalErectors, .glutes, .hamstrings, .calves:
            true
        default:
            false
        }
    }
}

enum ExerciseMuscleMapOrientation: String, Codable, Hashable {
    case front
    case back
    case split
}

struct ExerciseMuscleProfile: Codable, Hashable {
    var primary: [ExerciseMuscleRegion]
    var secondary: [ExerciseMuscleRegion]
    var orientation: ExerciseMuscleMapOrientation

    var primaryDescription: String {
        primary.map(\.displayName).joined(separator: ", ")
    }

    var secondaryDescription: String {
        secondary.map(\.displayName).joined(separator: ", ")
    }
}

enum ExerciseMuscleProfileResolver {
    static func profile(name: String, bodyPart: String) -> ExerciseMuscleProfile {
        let body = bodyPart.lowercased()
        let movement = name.lowercased()

        if let curated = curatedProfile(movement: movement, body: body) {
            return curated
        }

        var primary: [ExerciseMuscleRegion] = []
        var secondary: [ExerciseMuscleRegion] = []

        func include(_ region: ExerciseMuscleRegion, in list: inout [ExerciseMuscleRegion], when condition: Bool) {
            if condition && !list.contains(region) { list.append(region) }
        }

        include(.neck, in: &primary, when: body.contains("neck"))
        include(.upperChest, in: &primary, when: body.contains("upper chest"))
        include(.lowerChest, in: &primary, when: body.contains("lower chest"))
        include(.chest, in: &primary, when: (body.contains("chest") || body.contains("pec")) && !body.contains("upper chest") && !body.contains("lower chest"))
        include(.rearDelts, in: &primary, when: body.contains("rear delt"))
        include(.sideDelts, in: &primary, when: (body.contains("shoulder") || body.contains("delt")) && (movement.contains("lateral") || movement.contains("upright") || movement.contains("y raise")))
        include(.frontDelts, in: &primary, when: (body.contains("shoulder") || body.contains("delt")) && !body.contains("rear delt") && !primary.contains(.sideDelts))
        include(.biceps, in: &primary, when: body.contains("bicep"))
        include(.triceps, in: &primary, when: body.contains("tricep"))
        include(.forearms, in: &primary, when: body.contains("forearm") || body.contains("grip"))
        include(.traps, in: &primary, when: body.contains("trap"))
        include(.lats, in: &primary, when: body.contains("lat"))
        include(.upperBack, in: &primary, when: (body.contains("back") || body.contains("row")) && !body.contains("lower back") && !body.contains("hamstrings/back") && !primary.contains(.lats))
        include(.spinalErectors, in: &primary, when: body.contains("lower back"))
        include(.abs, in: &primary, when: body.contains("core") || body.contains("abdominal"))
        include(.obliques, in: &primary, when: body.contains("oblique"))
        include(.glutes, in: &primary, when: body.contains("glute"))
        include(.adductors, in: &primary, when: body.contains("adductor"))
        include(.quads, in: &primary, when: body.contains("quad"))
        include(.hamstrings, in: &primary, when: body.contains("hamstring"))
        include(.calves, in: &primary, when: body.contains("calf") || body.contains("calves"))
        include(.tibialis, in: &primary, when: body.contains("tibialis"))
        include(.fullBody, in: &primary, when: body.contains("full body"))

        if movement.contains("deadlift") {
            include(.hamstrings, in: &primary, when: true)
            include(.glutes, in: &primary, when: true)
            include(.spinalErectors, in: &secondary, when: true)
            include(.upperBack, in: &secondary, when: true)
        }
        if movement.contains("squat") || movement.contains("leg press") || movement.contains("lunge") || movement.contains("step-up") {
            include(.quads, in: &primary, when: true)
            include(.glutes, in: &secondary, when: true)
            include(.adductors, in: &secondary, when: true)
        }
        let isLowerBodyPress = movement.contains("leg press") || movement.contains("calf press")
        if (movement.contains("press") && !isLowerBodyPress) || movement.contains("dip") {
            include(.triceps, in: &secondary, when: !primary.contains(.triceps))
            include(.frontDelts, in: &secondary, when: !primary.contains(.frontDelts))
        }
        if movement.contains("row") || movement.contains("pulldown") || movement.contains("pull-up") || movement.contains("pullover") {
            include(.lats, in: &primary, when: !primary.contains(.upperBack))
            include(.biceps, in: &secondary, when: true)
            include(.rearDelts, in: &secondary, when: movement.contains("row"))
        }
        if movement.contains("curl") && !movement.contains("leg curl") {
            include(.biceps, in: &primary, when: true)
            include(.forearms, in: &secondary, when: true)
        }
        if movement.contains("leg curl") || movement.contains("nordic") {
            include(.hamstrings, in: &primary, when: true)
        }
        if movement.contains("hip thrust") || movement.contains("glute") || movement.contains("kickback") {
            include(.glutes, in: &primary, when: true)
            include(.hamstrings, in: &secondary, when: true)
        }
        if movement.contains("carry") {
            primary = [.fullBody]
            secondary = [.forearms, .traps, .abs]
        }

        if primary.isEmpty { primary = [.fullBody] }
        secondary.removeAll { primary.contains($0) }
        let hasFront = primary.contains { !$0.isBackFacing && $0 != .fullBody }
        let hasBack = primary.contains { $0.isBackFacing }
        let orientation: ExerciseMuscleMapOrientation = primary.contains(.fullBody) || (hasFront && hasBack)
            ? .split
            : (hasBack ? .back : .front)
        return ExerciseMuscleProfile(primary: primary, secondary: secondary, orientation: orientation)
    }

    private static func curatedProfile(movement: String, body: String) -> ExerciseMuscleProfile? {
        func profile(
            primary: [ExerciseMuscleRegion],
            secondary: [ExerciseMuscleRegion] = [],
            orientation: ExerciseMuscleMapOrientation? = nil
        ) -> ExerciseMuscleProfile {
            let cleanedSecondary = secondary.filter { !primary.contains($0) }
            let resolvedOrientation = orientation ?? mapOrientation(primary: primary)
            return ExerciseMuscleProfile(primary: primary, secondary: cleanedSecondary, orientation: resolvedOrientation)
        }

        if movement.contains("triceps dip") {
            return profile(primary: [.triceps], secondary: [.chest, .frontDelts], orientation: .split)
        }
        if movement.contains("dip") {
            return profile(primary: [.chest, .triceps], secondary: [.frontDelts], orientation: .split)
        }
        if movement.contains("fly") || movement.contains("pec deck") {
            let primary: [ExerciseMuscleRegion] = movement.contains("incline") ? [.upperChest] : [.chest]
            return profile(primary: primary, secondary: [.frontDelts], orientation: .front)
        }
        if movement.contains("bench") || movement.contains("chest press") || (movement.contains("press") && (body.contains("chest") || movement.contains("push-up"))) {
            let primary: [ExerciseMuscleRegion] = movement.contains("incline") ? [.upperChest] : [.chest]
            return profile(primary: primary, secondary: [.frontDelts, .triceps], orientation: .split)
        }
        if movement.contains("shoulder press") || movement.contains("overhead press") || movement.contains("military press") {
            return profile(primary: [.frontDelts, .sideDelts], secondary: [.triceps, .traps], orientation: .split)
        }
        if movement.contains("lateral raise") {
            return profile(primary: [.sideDelts], secondary: [.traps], orientation: .split)
        }
        if movement.contains("rear delt") || movement.contains("reverse pec deck") || movement.contains("face pull") {
            return profile(primary: [.rearDelts], secondary: [.upperBack, .traps], orientation: .back)
        }
        if movement.contains("upright row") {
            return profile(primary: [.sideDelts, .traps], secondary: [.biceps], orientation: .split)
        }
        if movement.contains("row") {
            return profile(primary: [.upperBack, .lats], secondary: [.rearDelts, .biceps], orientation: .split)
        }
        if movement.contains("pulldown") || movement.contains("pull-up") || movement.contains("chin-up") {
            return profile(primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts], orientation: .split)
        }
        if movement.contains("pullover") {
            return profile(primary: [.lats], secondary: [.chest, .triceps], orientation: .split)
        }
        if movement.contains("hack squat") || movement.contains("leg press") || movement.contains("squat") || movement.contains("lunge") || movement.contains("step-up") {
            return profile(primary: [.quads], secondary: [.glutes, .adductors, .hamstrings], orientation: .split)
        }
        if movement.contains("deadlift") || movement.contains("romanian") || movement.contains("good morning") {
            return profile(primary: [.hamstrings, .glutes], secondary: [.spinalErectors, .upperBack], orientation: .split)
        }
        if movement.contains("back extension") || movement.contains("hyperextension") {
            return profile(primary: [.spinalErectors, .glutes], secondary: [.hamstrings], orientation: .back)
        }
        if movement.contains("hip thrust") || movement.contains("glute bridge") || movement.contains("kickback") {
            return profile(primary: [.glutes], secondary: [.hamstrings], orientation: .back)
        }
        if movement.contains("leg curl") || movement.contains("nordic") {
            return profile(primary: [.hamstrings], secondary: [.glutes], orientation: .back)
        }
        if movement.contains("leg extension") || movement.contains("sissy squat") {
            return profile(primary: [.quads], orientation: .front)
        }
        if movement.contains("calf raise") || movement.contains("calf press") {
            return profile(primary: [.calves], orientation: .back)
        }
        if movement.contains("tibialis") {
            return profile(primary: [.tibialis], orientation: .front)
        }
        if movement.contains("curl") && !movement.contains("leg curl") {
            return profile(primary: [.biceps], secondary: [.forearms], orientation: .front)
        }
        if movement.contains("pressdown") || movement.contains("pushdown") || movement.contains("skullcrusher") || movement.contains("skull crusher") || movement.contains("triceps extension") {
            return profile(primary: [.triceps], secondary: [.forearms], orientation: .back)
        }
        if movement.contains("crunch") || movement.contains("sit-up") || movement.contains("leg raise") || movement.contains("plank") || movement.contains("pallof") {
            return profile(primary: [.abs], secondary: [.obliques], orientation: .front)
        }
        if movement.contains("russian twist") || movement.contains("woodchop") || movement.contains("side bend") {
            return profile(primary: [.obliques], secondary: [.abs], orientation: .front)
        }
        if movement.contains("shrug") {
            return profile(primary: [.traps], secondary: [.forearms], orientation: .back)
        }
        if movement.contains("carry") {
            return profile(primary: [.fullBody], secondary: [.forearms, .traps, .abs], orientation: .split)
        }

        return nil
    }

    private static func mapOrientation(primary: [ExerciseMuscleRegion]) -> ExerciseMuscleMapOrientation {
        let hasFront = primary.contains { !$0.isBackFacing && $0 != .fullBody }
        let hasBack = primary.contains { $0.isBackFacing }
        return primary.contains(.fullBody) || (hasFront && hasBack)
            ? .split
            : (hasBack ? .back : .front)
    }
}

enum ExerciseBodyRegion: String, CaseIterable, Hashable {
    case neck
    case shoulders
    case chest
    case back
    case arms
    case core
    case glutes
    case upperLegs
    case lowerLegs
    case fullBody
}

enum ExerciseBodyRegionResolver {
    static func regions(for bodyPart: String) -> [ExerciseBodyRegion] {
        let value = bodyPart.lowercased()
        var regions: [ExerciseBodyRegion] = []

        func include(_ region: ExerciseBodyRegion, when condition: Bool) {
            if condition && !regions.contains(region) {
                regions.append(region)
            }
        }

        include(.neck, when: value.contains("neck"))
        include(.shoulders, when: value.contains("shoulder") || value.contains("delt") || value.contains("rotator"))
        include(.chest, when: value.contains("chest") || value.contains("pec"))
        include(.back, when: value.contains("back") || value.contains("lat") || value.contains("trap"))
        include(.arms, when: value.contains("bicep") || value.contains("tricep") || value.contains("arm") || value.contains("forearm") || value.contains("grip"))
        include(.core, when: value.contains("core") || value.contains("abdominal") || value.contains("oblique"))
        include(.glutes, when: value.contains("glute"))
        include(.upperLegs, when: value.contains("quad") || value.contains("hamstring") || value.contains("adductor") || value.contains("upper leg"))
        include(.lowerLegs, when: value.contains("calf") || value.contains("calves") || value.contains("tibialis") || value.contains("lower leg"))
        include(.fullBody, when: value.contains("full body"))

        return regions.isEmpty ? [.fullBody] : regions
    }
}
