import Combine
import Foundation

@MainActor
final class PlayerSettingsViewModel: ObservableObject {
    @Published var isDownloadingAuthlibInjector: Bool = false
    @Published var authlibInjectorExists: Bool = false

    @Published private(set) var minecraftFriendAccountPreferences: MinecraftFriendsPreferencesPayload?
    @Published private(set) var isLoadingMinecraftFriendAccountPreferences = false
    @Published private(set) var isSavingMinecraftFriendAccountPreferences = false

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

    func refreshAuthlibInjectorExists() {
        let authlibInjectorJarURL = AppPaths.authDirectory.appendingPathComponent(
            AppConstants.AuthlibInjector.jarFileName
        )
        authlibInjectorExists = FileManager.default.fileExists(atPath: authlibInjectorJarURL.path)
    }

    func downloadAuthlibInjector() async {
        guard !isDownloadingAuthlibInjector else { return }
        isDownloadingAuthlibInjector = true
        defer { isDownloadingAuthlibInjector = false }

        let authlibInjectorJarURL = AppPaths.authDirectory.appendingPathComponent(
            AppConstants.AuthlibInjector.jarFileName
        )

        do {
            let downloadURL = URLConfig.API.AuthlibInjector.download
            _ = try await DownloadManager.downloadFile(
                urlString: downloadURL.absoluteString,
                destinationURL: authlibInjectorJarURL,
                expectedSha1: nil
            )
            authlibInjectorExists = true
        } catch {
            let globalError = GlobalError.download(
                chineseMessage: "下载 authlib-injector 失败: \(error.localizedDescription)",
                i18nKey: "error.download.authlib_injector_failed",
                level: .notification
            )
            errorHandler.handle(globalError)
        }
    }

    func clearMinecraftFriendAccountPreferences() {
        minecraftFriendAccountPreferences = nil
        isLoadingMinecraftFriendAccountPreferences = false
        isSavingMinecraftFriendAccountPreferences = false
    }

    func reloadMinecraftFriendAccountPreferences(currentPlayer: Player?) async {
        guard let player = currentPlayer, player.canUseMicrosoftMinecraftServices else {
            clearMinecraftFriendAccountPreferences()
            return
        }

        isLoadingMinecraftFriendAccountPreferences = true
        defer { isLoadingMinecraftFriendAccountPreferences = false }

        guard let tokenPlayer = await preparedTokenPlayer(for: player, onMissingCredential: reportMissingAccessToken) else {
            minecraftFriendAccountPreferences = nil
            return
        }

        do {
            minecraftFriendAccountPreferences = try await friendsService.fetchFriendAccountPreferences(
                accessToken: tokenPlayer.authAccessToken
            )
        } catch {
            minecraftFriendAccountPreferences = nil
            errorHandler.handle(GlobalError.from(error))
        }
    }

    func setMinecraftFriendListEnabled(_ enabled: Bool, currentPlayer: Player?) async {
        let invitesOn = minecraftFriendAccountPreferences?.acceptInvites == .enabled
        await persistMinecraftFriendAccountPreferences(
            currentPlayer: currentPlayer,
            enableFriendlist: enabled,
            enableFriendInvites: invitesOn
        )
    }

    func setMinecraftFriendAcceptInvitesEnabled(_ enabled: Bool, currentPlayer: Player?) async {
        let friendsOn = minecraftFriendAccountPreferences?.friends == .enabled
        await persistMinecraftFriendAccountPreferences(
            currentPlayer: currentPlayer,
            enableFriendlist: friendsOn,
            enableFriendInvites: enabled
        )
    }

    private func persistMinecraftFriendAccountPreferences(
        currentPlayer: Player?,
        enableFriendlist: Bool,
        enableFriendInvites: Bool
    ) async {
        guard let player = currentPlayer, player.canUseMicrosoftMinecraftServices else { return }
        guard let tokenPlayer = await preparedTokenPlayer(for: player, onMissingCredential: reportMissingAccessToken) else { return }

        isSavingMinecraftFriendAccountPreferences = true
        defer { isSavingMinecraftFriendAccountPreferences = false }

        do {
            try await friendsService.updateFriendSettings(
                accessToken: tokenPlayer.authAccessToken,
                enableFriendlist: enableFriendlist,
                enableFriendInvites: enableFriendInvites
            )
            minecraftFriendAccountPreferences = try await friendsService.fetchFriendAccountPreferences(
                accessToken: tokenPlayer.authAccessToken
            )
        } catch {
            errorHandler.handle(GlobalError.from(error))
            await reloadMinecraftFriendAccountPreferences(currentPlayer: currentPlayer)
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

    private func persistPlayerIfNeeded(_ updated: Player) {
        guard dataManager.updatePlayerSilently(updated) else { return }
        NotificationCenter.default.post(
            name: .playerUpdated,
            object: nil,
            userInfo: ["updatedPlayer": updated]
        )
    }
}
