import Combine
import Foundation

extension DemoRepository: WorkoutRepository, WorkoutSyncRepository, WorkoutPRSubmissionRepository, ProgramRepository, ExerciseRepository, CompetitionRepository, CommunityRepository, AccountSocialRepository {}

extension DemoRepository: SocialMessagingRepository {
    var socialMessagingChanges: AnyPublisher<Void, Never> {
        objectWillChange.eraseToAnyPublisher()
    }
}

extension DemoRepository: ProfileRepository {
    var profileChanges: AnyPublisher<Void, Never> {
        objectWillChange.eraseToAnyPublisher()
    }
}

extension DemoRepository: NotificationRepository {
    var notificationChanges: AnyPublisher<Void, Never> {
        objectWillChange.eraseToAnyPublisher()
    }
}
