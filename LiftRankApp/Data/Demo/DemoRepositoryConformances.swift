import Combine
import Foundation

extension DemoRepository: WorkoutRepository, WorkoutSyncRepository, WorkoutPRSubmissionRepository, ProgramRepository, ExerciseRepository, CompetitionRepository, AccountSocialRepository {}

extension DemoRepository: ProfileRepository {
    var profileChanges: AnyPublisher<Void, Never> {
        objectWillChange.eraseToAnyPublisher()
    }

    @discardableResult
    func joinGym(_ gym: Gym, maximumMemberships: Int) -> Bool {
        guard joinedGymIDs.contains(gym.id) || joinedGymIDs.count < maximumMemberships else { return false }
        if !gyms.contains(where: { $0.id == gym.id }) {
            gyms.append(gym)
        }
        joinedGymIDs.insert(gym.id)
        currentProfile.primaryGymID = gym.id
        currentProfile.primaryGymName = gym.name
        return true
    }

    func leaveGym(_ gym: Gym) {
        joinedGymIDs.remove(gym.id)
        if currentProfile.primaryGymID == gym.id {
            currentProfile.primaryGymID = joinedGymIDs.first ?? UUID()
            currentProfile.primaryGymName = gyms.first { $0.id == currentProfile.primaryGymID }?.name ?? ""
        }
    }

    func setChallengeJoined(_ challenge: Challenge, joined: Bool) {
        guard let index = challenges.firstIndex(where: { $0.id == challenge.id }),
              challenges[index].isJoined != joined else { return }
        challenges[index].isJoined = joined
        challenges[index].participantCount += joined ? 1 : -1
    }
}

extension DemoRepository: NotificationRepository {
    var notificationChanges: AnyPublisher<Void, Never> {
        objectWillChange.eraseToAnyPublisher()
    }
}
