import Foundation

enum WeightClassCatalog {
    static let male: [WeightClass] = classes(
        sex: .male,
        prefix: "usapl-m",
        limits: [52, 56, 60, 67.5, 75, 82.5, 90, 100, 110, 125, 140]
    )

    static let female: [WeightClass] = classes(
        sex: .female,
        prefix: "usapl-f",
        limits: [44, 48, 52, 56, 60, 65, 70, 75, 82.5, 90, 100]
    )

    static let all = male + female

    private static func classes(
        sex: SexCategory,
        prefix: String,
        limits: [Double]
    ) -> [WeightClass] {
        var previous: Double?
        var result = limits.map { limit in
            defer { previous = limit }
            return WeightClass(
                id: "\(prefix)-\(RankingCalculator.format(limit))",
                sexCategory: sex,
                name: "\(RankingCalculator.format(limit)) kg",
                minKilograms: previous,
                maxKilograms: limit
            )
        }
        if let finalLimit = limits.last {
            result.append(WeightClass(
                id: "\(prefix)-\(RankingCalculator.format(finalLimit))-plus",
                sexCategory: sex,
                name: "\(RankingCalculator.format(finalLimit))+ kg",
                minKilograms: finalLimit,
                maxKilograms: nil
            ))
        }
        return result
    }
}
