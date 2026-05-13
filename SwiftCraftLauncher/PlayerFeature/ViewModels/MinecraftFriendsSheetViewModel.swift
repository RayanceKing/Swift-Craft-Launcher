import Foundation
import SwiftUI

@MainActor
final class MinecraftFriendsSheetViewModel: ObservableObject {
    @Published private(set) var uiData: MinecraftFriendsUIData = .empty
    @Published private(set) var skinTextureURLByUUID: [String: String] = [:]
    @Published private(set) var isLoading = false
    @Published var addFriendName: String = ""

    private let friendsService: MinecraftFriendsService
    private let authService: MinecraftAuthService
    private let dataManager: PlayerDataManager
    private let errorHandler: GlobalErrorHandler

    init(
        friendsService: MinecraftFriendsService = .shared,
        authService: MinecraftAuthService = .shared,
        dataManager: PlayerDataManager = PlayerDataManager(),
        errorHandler: GlobalErrorHandler = AppServices.errorHandler
    ) {
        self.friendsService = friendsService
        self.authService = authService
        self.dataManager = dataManager
        self.errorHandler = errorHandler
    }

    func load(player: Player, forceRefresh: Bool) async {
        isLoading = true
        defer { isLoading = false }

        guard let tokenPlayer = await preparedTokenPlayer(
            for: player,
            onMissingCredential: {
                uiData = .empty
                skinTextureURLByUUID = [:]
                reportMissingAccessToken()
            }
        ) else { return }

        do {
            uiData = try await friendsService.fetchFriendsAndPresence(
                accessToken: tokenPlayer.authAccessToken,
                forceRefresh: forceRefresh
            )
            await prefetchSkinTextureURLs(for: uiData)
        } catch {
            errorHandler.handle(GlobalError.from(error))
        }
    }

    func skinTextureURLString(forUUIDNormalized id: String) -> String? {
        skinTextureURLByUUID[id]
    }

    func sendFriendRequest(player: Player) async {
        let name = addFriendName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        await runFriendMutation(
            player: player,
            request: MinecraftFriendActionRequest(name: name, profileId: nil, updateType: .add)
        )
        addFriendName = ""
    }

    func acceptIncoming(player: Player, profileId: String) async {
        await runFriendMutation(
            player: player,
            request: MinecraftFriendActionRequest(name: nil, profileId: profileId, updateType: .add)
        )
    }

    func declineIncoming(player: Player, profileId: String) async {
        await runFriendMutation(
            player: player,
            request: MinecraftFriendActionRequest(name: nil, profileId: profileId, updateType: .remove)
        )
    }

    func revokeOutgoing(player: Player, profileId: String) async {
        await runFriendMutation(
            player: player,
            request: MinecraftFriendActionRequest(name: nil, profileId: profileId, updateType: .remove)
        )
    }

    func removeFriend(player: Player, profileId: String) async {
        await runFriendMutation(
            player: player,
            request: MinecraftFriendActionRequest(name: nil, profileId: profileId, updateType: .remove)
        )
    }

    private func runFriendMutation(player: Player, request: MinecraftFriendActionRequest) async {
        await mutate(player: player) { token in
            _ = try await friendsService.performFriendAction(accessToken: token, request: request)
        }
    }

    private func mutate(player: Player, action: (String) async throws -> Void) async {
        guard let tokenPlayer = await preparedTokenPlayer(for: player, onMissingCredential: reportMissingAccessToken) else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await action(tokenPlayer.authAccessToken)
            uiData = try await friendsService.fetchFriendsAndPresence(
                accessToken: tokenPlayer.authAccessToken,
                forceRefresh: true
            )
            await prefetchSkinTextureURLs(for: uiData)
        } catch {
            errorHandler.handle(GlobalError.from(error))
        }
    }

    private func preparedTokenPlayer(for player: Player, onMissingCredential: () -> Void) async -> Player? {
        var resolved = player
        if resolved.credential == nil {
            resolved.credential = dataManager.loadCredential(userId: resolved.id)
        }
        guard !resolved.authAccessToken.isEmpty else {
            onMissingCredential()
            return nil
        }

        do {
            let tokenPlayer = try await authService.validateAndRefreshPlayerTokenThrowing(for: resolved)
            if tokenPlayer.authAccessToken != resolved.authAccessToken {
                persistPlayerIfNeeded(tokenPlayer)
            }
            return tokenPlayer
        } catch {
            errorHandler.handle(GlobalError.from(error))
            return nil
        }
    }

    private func reportMissingAccessToken() {
        errorHandler.handle(
            GlobalError.authentication(
                chineseMessage: "缺少 Minecraft 访问令牌，请重新登录该正版账号",
                i18nKey: "error.authentication.missing_token",
                level: .notification
            )
        )
    }

    private func prefetchSkinTextureURLs(for data: MinecraftFriendsUIData) async {
        let ids = collectNormalizedUUIDs(from: data)
        guard !ids.isEmpty else {
            skinTextureURLByUUID = [:]
            return
        }

        let batchSize = 4
        var built: [String: String] = [:]
        var start = 0
        while start < ids.count {
            let end = min(start + batchSize, ids.count)
            let batch = Array(ids[start..<end])
            await withTaskGroup(of: (String, String?).self) { group in
                for id in batch {
                    group.addTask {
                        let url = await MinecraftSessionProfileSkinResolver.resolveTextureURLString(uuidNoHyphens: id)
                        return (id, url)
                    }
                }
                for await (id, url) in group {
                    if let url, !url.isEmpty {
                        built[id] = url
                    }
                }
            }
            start = end
        }
        skinTextureURLByUUID = built
    }

    private func collectNormalizedUUIDs(from data: MinecraftFriendsUIData) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        func appendUnique(_ list: [MinecraftFriendProfileDTO]) {
            for dto in list {
                let id = dto.profileId.normalized
                if seen.insert(id).inserted {
                    ordered.append(id)
                }
            }
        }
        appendUnique(data.lists.friends)
        appendUnique(data.lists.incomingRequests)
        appendUnique(data.lists.outgoingRequests)
        return ordered
    }

    private func persistPlayerIfNeeded(_ updated: Player) {
        guard dataManager.updatePlayerSilently(updated) else { return }
        NotificationCenter.default.post(
            name: .playerUpdated,
            object: nil,
            userInfo: ["updatedPlayer": updated]
        )
    }
}
