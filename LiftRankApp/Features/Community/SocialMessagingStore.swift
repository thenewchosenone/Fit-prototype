import Combine
import Foundation

@MainActor
final class SocialMessagingStore: ObservableObject {
    private let repository: any SocialMessagingRepository
    private var messagingService: (any MessagingService)?
    private var cancellable: AnyCancellable?

    init(
        repository: any SocialMessagingRepository,
        messagingService: (any MessagingService)? = nil
    ) {
        self.repository = repository
        self.messagingService = messagingService
        cancellable = repository.socialMessagingChanges.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func updateService(_ messagingService: any MessagingService) {
        self.messagingService = messagingService
    }

    func refreshProductionData() async {
        repository.messageThreads = []
        repository.directMessages = []
        guard let messagingService else { return }
        repository.messageThreads = (try? await messagingService.threads()) ?? []
        for thread in repository.messageThreads {
            repository.directMessages.append(
                contentsOf: (try? await messagingService.messages(for: thread)) ?? []
            )
        }
    }

    var friendRequests: [FriendRequest] { repository.friendRequests }
    var messageThreads: [DirectMessageThread] { repository.messageThreads }
    var directMessages: [DirectMessage] { repository.directMessages }

    func profile(id: UUID) -> UserProfile? {
        repository.profiles.first { $0.id == id }
    }

    func friendRequest(with profile: UserProfile) -> FriendRequest? {
        repository.friendRequests.first { request in
            (request.fromUserID == repository.currentProfile.id && request.toUserID == profile.id) ||
            (request.fromUserID == profile.id && request.toUserID == repository.currentProfile.id)
        }
    }

    func friendActionTitle(for profile: UserProfile) -> String {
        guard let request = friendRequest(with: profile) else { return "Connect" }
        switch request.status {
        case .accepted:
            return "Connected"
        case .declined:
            return "Connect"
        case .pending:
            return request.fromUserID == repository.currentProfile.id ? "Request Sent" : "Accept Request"
        }
    }

    func canSendFriendRequest(to profile: UserProfile) -> Bool {
        guard profile.id != repository.currentProfile.id else { return false }
        guard let request = friendRequest(with: profile) else { return true }
        return request.status == .declined
    }

    func sendLocalFriendRequest(to profile: UserProfile) {
        repository.sendFriendRequest(to: profile)
    }

    func cancelLocalFriendRequest(_ request: FriendRequest) {
        repository.cancelFriendRequest(request)
    }

    func respondToLocalFriendRequest(_ request: FriendRequest, accept: Bool) {
        repository.respondToFriendRequest(request, status: accept ? .accepted : .declined)
    }

    func canOpenMessageThread(with profile: UserProfile, friends: [UserProfile]) -> Bool {
        friends.contains(where: { $0.id == profile.id }) || profile.id == repository.currentProfile.id
    }

    func openLocalMessageThread(with profile: UserProfile) -> DirectMessageThread {
        repository.messageThread(with: profile)
    }

    func openRemoteMessageThread(with profile: UserProfile) async throws -> DirectMessageThread {
        guard let messagingService else { throw LiftRankServiceError.configurationMissing }
        return upsertRemoteThread(try await messagingService.createOrGetThread(with: profile.id))
    }

    @discardableResult
    func upsertRemoteThread(_ thread: DirectMessageThread) -> DirectMessageThread {
        if let index = repository.messageThreads.firstIndex(where: { $0.id == thread.id }) {
            repository.messageThreads[index] = thread
        } else {
            repository.messageThreads.append(thread)
        }
        return thread
    }

    func messages(for thread: DirectMessageThread) -> [DirectMessage] {
        repository.directMessages
            .filter { $0.threadID == thread.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func otherParticipant(in thread: DirectMessageThread) -> UserProfile? {
        guard let otherID = thread.participantIDs.first(where: { $0 != repository.currentProfile.id }) else { return nil }
        return profile(id: otherID)
    }

    func lastMessage(in thread: DirectMessageThread) -> DirectMessage? {
        messages(for: thread).last
    }

    @discardableResult
    func appendRemoteMessage(_ message: DirectMessage, in thread: DirectMessageThread) -> DirectMessageThread {
        if !repository.directMessages.contains(where: { $0.id == message.id }) {
            repository.directMessages.append(message)
        }
        if let index = repository.messageThreads.firstIndex(where: { $0.id == thread.id }) {
            repository.messageThreads[index].updatedAt = message.createdAt
            return repository.messageThreads[index]
        }
        var inserted = thread
        inserted.updatedAt = message.createdAt
        repository.messageThreads.append(inserted)
        return inserted
    }

    @discardableResult
    func sendLocalMessage(in thread: DirectMessageThread, body: String) -> DirectMessageThread? {
        repository.addMessage(to: thread, body: body)
        return repository.messageThreads.first { $0.id == thread.id }
    }

    func sendRemoteMessage(in thread: DirectMessageThread, body: String) async throws -> DirectMessageThread? {
        guard let messagingService else { throw LiftRankServiceError.configurationMissing }
        guard let message = try await messagingService.sendMessage(in: thread, body: body) else { return nil }
        return appendRemoteMessage(message, in: thread)
    }

    func deleteLocalMessage(_ message: DirectMessage) {
        repository.deleteMessage(message)
    }

    func deleteRemoteMessage(_ message: DirectMessage) async throws {
        guard let messagingService else { throw LiftRankServiceError.configurationMissing }
        try await messagingService.deleteMessage(message)
    }

    func deleteLocalThread(_ thread: DirectMessageThread) {
        repository.deleteMessageThread(thread)
    }

    func deleteRemoteThread(_ thread: DirectMessageThread) async throws {
        guard let messagingService else { throw LiftRankServiceError.configurationMissing }
        try await messagingService.deleteThread(thread)
    }

    func reportLocalMessage(_ message: DirectMessage, reason: MessageReportReason, note: String) {
        repository.reportMessage(message, reason: reason, note: note)
    }

    func reportRemoteMessage(_ message: DirectMessage, reason: MessageReportReason, note: String) async throws {
        guard let messagingService else { throw LiftRankServiceError.configurationMissing }
        try await messagingService.reportMessage(message, reason: reason, note: note)
    }
}
