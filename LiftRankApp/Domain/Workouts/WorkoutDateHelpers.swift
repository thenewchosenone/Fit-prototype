import Foundation

extension Calendar {
    func weekdayName(for weekday: Int) -> String {
        let index = max(1, min(7, weekday))
        guard weekdaySymbols.indices.contains(index - 1) else { return "Monday" }
        return weekdaySymbols[index - 1]
    }

    func weekdayName(for date: Date = .now) -> String {
        let index = component(.weekday, from: date) - 1
        guard weekdaySymbols.indices.contains(index) else { return "Monday" }
        return weekdaySymbols[index]
    }
}
