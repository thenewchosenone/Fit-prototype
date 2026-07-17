import Foundation
import Supabase

@MainActor
struct AppServiceContainer {
    let authentication: any AuthenticationService
    let profile: any ProfileService
    let gyms: any GymService
    let gymMemberships: any GymMembershipService
    let friendships: any FriendRelationshipService
    let exercises: any ExerciseCatalogService

    static func make(repository: DemoRepository) -> AppServiceContainer {
        guard let configuration = SupabaseConfiguration.load() else {
            return AppServiceContainer(
                authentication: UnconfiguredAuthenticationService(repository: repository),
                profile: MockProfileService(repository: repository),
                gyms: MockGymService(repository: repository),
                gymMemberships: MockGymMembershipService(repository: repository),
                friendships: MockFriendRelationshipService(repository: repository),
                exercises: MockExerciseCatalogService()
            )
        }

        let client = SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.publicKey)
        return AppServiceContainer(
            authentication: SupabaseAuthenticationService(client: client),
            profile: SupabaseProfileService(client: client),
            gyms: SupabaseGymService(client: client),
            gymMemberships: SupabaseGymMembershipService(client: client),
            friendships: SupabaseFriendRelationshipService(client: client),
            exercises: SupabaseExerciseCatalogService(client: client)
        )
    }

    static func demo(repository: DemoRepository) -> AppServiceContainer {
        AppServiceContainer(
            authentication: MockAuthenticationService(repository: repository),
            profile: MockProfileService(repository: repository),
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            friendships: MockFriendRelationshipService(repository: repository),
            exercises: MockExerciseCatalogService()
        )
    }
}

@MainActor
final class UnconfiguredAuthenticationService: AuthenticationService {
    private let repository: DemoRepository
    var isConfigured: Bool { false }
    var isDemoMode: Bool { false }
    init(repository: DemoRepository) { self.repository = repository }
    func restoreSession() async throws -> AccountSession? { nil }
    func signUp(email: String, password: String) async throws -> AccountSession { throw LiftRankServiceError.configurationMissing }
    func signIn(email: String, password: String) async throws -> AccountSession { throw LiftRankServiceError.configurationMissing }
    func requestPasswordReset(email: String) async throws { throw LiftRankServiceError.configurationMissing }
    func signInDemo() async throws -> UserProfile { repository.currentProfile }
    func signOut() async throws {}
}

