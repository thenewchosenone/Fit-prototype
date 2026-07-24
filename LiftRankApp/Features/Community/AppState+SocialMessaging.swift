import Foundation

@MainActor
extension AppState {
    func profile(id: UUID) -> UserProfile? {
        socialMessagingStore.profile(id: id)
    }

    func friendRequest(with profile: UserProfile) -> FriendRequest? {
        socialMessagingStore.friendRequest(with: profile)
    }

    func friendActionTitle(for profile: UserProfile) -> String {
        socialMessagingStore.friendActionTitle(for: profile)
    }

    func canSendFriendRequest(to profile: UserProfile) -> Bool {
        socialMessagingStore.canSendFriendRequest(to: profile)
    }

    func sendFriendRequest(to profile: UserProfile) {
        guard canSendFriendRequest(to: profile) else {
            Haptics.warning()
            return
        }
        if isAuthenticated {
            Task {
                do {
                    try await accountSocialStore.requestFriend(userID: profile.id)
                    Haptics.success()
                } catch {
                    accountMessage = userMessage(error)
                    Haptics.warning()
                }
            }
        } else {
            socialMessagingStore.sendLocalFriendRequest(to: profile)
            Haptics.success()
        }
    }

    func acceptFriendRequest(_ request: FriendRequest) {
        respondToFriendRequest(request, accept: true)
    }

    func declineFriendRequest(_ request: FriendRequest) {
        respondToFriendRequest(request, accept: false)
    }

    func cancelFriendRequest(_ request: FriendRequest) {
        if isAuthenticated {
            Task {
                do {
                    try await accountSocialStore.cancelFriendRequest(relationshipID: request.id)
                    Haptics.warning()
                } catch { accountMessage = userMessage(error) }
            }
        } else {
            socialMessagingStore.cancelLocalFriendRequest(request)
            Haptics.warning()
        }
    }

    private func respondToFriendRequest(_ request: FriendRequest, accept: Bool) {
        if isAuthenticated {
            Task {
                do {
                    try await accountSocialStore.respondToFriendRequest(
                        relationshipID: request.id,
                        accept: accept
                    )
                    accept ? Haptics.success() : Haptics.warning()
                } catch { accountMessage = userMessage(error) }
            }
        } else {
            socialMessagingStore.respondToLocalFriendRequest(request, accept: accept)
            accept ? Haptics.success() : Haptics.warning()
        }
    }

    func openMessageThread(with profile: UserProfile) {
        guard socialMessagingStore.canOpenMessageThread(with: profile, friends: friends) else {
            Haptics.warning()
            return
        }
        if isAuthenticated, !isDemoMode {
            Task {
                do {
                    selectedMessageThread = try await socialMessagingStore.openRemoteMessageThread(with: profile)
                } catch { accountMessage = userMessage(error) }
            }
        } else {
            selectedMessageThread = socialMessagingStore.openLocalMessageThread(with: profile)
        }
        Haptics.light()
    }

    func messages(for thread: DirectMessageThread) -> [DirectMessage] {
        socialMessagingStore.messages(for: thread)
    }

    func otherParticipant(in thread: DirectMessageThread) -> UserProfile? {
        socialMessagingStore.otherParticipant(in: thread)
    }

    func lastMessage(in thread: DirectMessageThread) -> DirectMessage? {
        socialMessagingStore.lastMessage(in: thread)
    }

    func sendMessage(in thread: DirectMessageThread, body: String) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else {
            Haptics.warning()
            return
        }
        if isAuthenticated, !isDemoMode {
            Task {
                do {
                    if let updatedThread = try await socialMessagingStore.sendRemoteMessage(
                        in: thread,
                        body: cleanBody
                    ) {
                        selectedMessageThread = updatedThread
                    }
                } catch { accountMessage = userMessage(error) }
            }
        } else {
            selectedMessageThread = socialMessagingStore.sendLocalMessage(in: thread, body: cleanBody)
        }
        Haptics.success()
    }

    func deleteMessage(_ message: DirectMessage) {
        socialMessagingStore.deleteLocalMessage(message)
        if isAuthenticated, !isDemoMode {
            Task { try? await socialMessagingStore.deleteRemoteMessage(message) }
        }
        Haptics.warning()
    }

    func deleteMessageThread(_ thread: DirectMessageThread) {
        socialMessagingStore.deleteLocalThread(thread)
        if isAuthenticated, !isDemoMode {
            Task { try? await socialMessagingStore.deleteRemoteThread(thread) }
        }
        if selectedMessageThread?.id == thread.id {
            selectedMessageThread = nil
        }
        Haptics.warning()
    }

    func reportMessage(_ message: DirectMessage, reason: MessageReportReason, note: String) {
        socialMessagingStore.reportLocalMessage(
            message,
            reason: reason,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if isAuthenticated, !isDemoMode {
            Task {
                try? await socialMessagingStore.reportRemoteMessage(
                    message,
                    reason: reason,
                    note: note
                )
            }
        }
        Haptics.warning()
    }

}
