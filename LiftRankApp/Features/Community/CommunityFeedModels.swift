import SwiftUI

enum CommunityTopic: String, CaseIterable, Identifiable {
    case all = "All"
    case bench = "Bench"
    case squat = "Squat"
    case deadlift = "Deadlift"
    case personalRecords = "PRs"
    case gym = "Gym"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .all: return "line.3.horizontal"
        case .bench: return "figure.strengthtraining.traditional"
        case .squat: return "figure.strengthtraining.functional"
        case .deadlift: return "dumbbell.fill"
        case .personalRecords: return "trophy.fill"
        case .gym: return "building.2.fill"
        }
    }
}

enum CommunityFeedItem: Identifiable {
    case thread(CommunityThread)
    case activity(ActivityItem)

    var id: String {
        switch self {
        case .thread(let thread): return "thread-\(thread.id.uuidString)"
        case .activity(let activity): return "activity-\(activity.id.uuidString)"
        }
    }

    var createdAt: Date {
        switch self {
        case .thread(let thread): return thread.createdAt
        case .activity(let activity): return activity.createdAt
        }
    }
}

enum CommunityFeedBuilder {
    static func items(
        threads: [CommunityThread],
        activities: [ActivityItem],
        lifts: [LiftSubmission],
        topic: CommunityTopic
    ) -> [CommunityFeedItem] {
        let liftByID = Dictionary(uniqueKeysWithValues: lifts.map { ($0.id, $0) })
        let threadItems = threads
            .filter { ($0.kind == .general || $0.kind == .gym) && $0.removedAt == nil }
            .filter { matches(thread: $0, topic: topic) }
            .map(CommunityFeedItem.thread)
        let activityItems = activities
            .filter { !$0.title.localizedCaseInsensitiveContains("started a thread") && !$0.title.localizedCaseInsensitiveContains("replied to") }
            .filter { matches(activity: $0, lift: $0.liftID.flatMap { liftByID[$0] }, topic: topic) }
            .map(CommunityFeedItem.activity)
        return (threadItems + activityItems).sorted { $0.createdAt > $1.createdAt }
    }

    private static func matches(thread: CommunityThread, topic: CommunityTopic) -> Bool {
        let text = "\(thread.title) \(thread.body)".lowercased()
        switch topic {
        case .all: return true
        case .bench: return text.contains("bench")
        case .squat: return text.contains("squat")
        case .deadlift: return text.contains("deadlift") || text.contains("pull")
        case .personalRecords: return text.contains(" pr") || text.contains("record")
        case .gym: return thread.kind == .gym
        }
    }

    private static func matches(activity: ActivityItem, lift: LiftSubmission?, topic: CommunityTopic) -> Bool {
        switch topic {
        case .all: return true
        case .bench: return lift?.exerciseID == "bench"
        case .squat: return lift?.exerciseID == "squat"
        case .deadlift: return lift?.exerciseID == "deadlift"
        case .personalRecords: return lift?.isActualOneRepMax == true
        case .gym: return lift != nil
        }
    }
}

extension View {
    func communityPostStyle() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liftSurface()
    }

    func compactSocialCardStyle() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liftSurface(radius: 14)
    }
}

struct CommunityReportDraft: Identifiable {
    var id: UUID
    var type: CommunityReportTargetType
    var title: String
}
