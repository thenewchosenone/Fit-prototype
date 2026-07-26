import Foundation

extension AppState {
    var selectedTab: Int {
        get { router.selectedTab.rawValue }
        set { router.selectedTab = AppTab(rawValue: newValue) ?? .home }
    }

    var requestedTrackerSegment: String {
        get { router.trackerSection.rawValue }
        set { router.trackerSection = TrackerSection(rawValue: newValue) ?? .today }
    }

    var trainingTrackerStartOnProgress: Bool {
        get { router.trackerSection == .progress }
        set {
            if newValue {
                router.trackerSection = .progress
            } else if router.trackerSection == .progress {
                router.trackerSection = .today
            }
        }
    }

    var showingSubmitSheet: Bool {
        get { router.sheet == .submitLift }
        set { router.setSheet(.submitLift, isPresented: newValue) }
    }
    var showingLeaderboardFilters: Bool {
        get { router.sheet == .leaderboardFilters }
        set { router.setSheet(.leaderboardFilters, isPresented: newValue) }
    }
    var showingEditProfile: Bool {
        get { router.sheet == .editProfile }
        set { router.setSheet(.editProfile, isPresented: newValue) }
    }
    var showingModeratorReview: Bool {
        get { router.sheet == .moderatorReview }
        set { router.setSheet(.moderatorReview, isPresented: newValue) }
    }
    var showingSettings: Bool {
        get { router.sheet == .settings }
        set { router.setSheet(.settings, isPresented: newValue) }
    }
    var showingReportLift: Bool {
        get { router.sheet == .reportLift }
        set { router.setSheet(.reportLift, isPresented: newValue) }
    }
    var showingRequestGym: Bool {
        get { router.sheet == .requestGym }
        set { router.setSheet(.requestGym, isPresented: newValue) }
    }
    var showingAuthentication: Bool {
        get { router.cover == .authentication }
        set { router.setCover(.authentication, isPresented: newValue) }
    }
    var selectedProfile: UserProfile? {
        get { if case .profile(let value) = router.sheet { return value }; return nil }
        set { setSelectedSheet(newValue.map(AppSheet.profile), matching: { if case .profile = $0 { true } else { false } }) }
    }
    var selectedGym: Gym? {
        get { if case .gym(let value) = router.sheet { return value }; return nil }
        set { setSelectedSheet(newValue.map(AppSheet.gym), matching: { if case .gym = $0 { true } else { false } }) }
    }
    private func setSelectedSheet(_ destination: AppSheet?, matching: (AppSheet) -> Bool) {
        if let destination {
            router.sheet = destination
        } else if let current = router.sheet, matching(current) {
            router.sheet = nil
        }
    }

}
