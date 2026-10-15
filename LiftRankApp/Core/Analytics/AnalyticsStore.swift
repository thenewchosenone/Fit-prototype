import Foundation

@MainActor
final class AnalyticsStore {
    private var service: any AnalyticsService
    private let makeID: () -> UUID
    private let now: () -> Date

    init(
        service: any AnalyticsService,
        makeID: @escaping () -> UUID = UUID.init,
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.makeID = makeID
        self.now = now
    }

    func updateService(_ service: any AnalyticsService) {
        self.service = service
    }

    func track(
        _ name: AnalyticsEventName,
        userID: UUID?,
        properties: [String: String] = [:]
    ) async {
        guard let userID else { return }
        await service.track(AnalyticsEventRecord(
            id: makeID(),
            userID: userID,
            name: name,
            occurredAt: now(),
            properties: properties
        ))
    }
}
