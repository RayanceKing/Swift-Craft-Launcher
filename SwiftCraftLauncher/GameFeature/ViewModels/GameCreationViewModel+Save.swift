import Foundation

extension GameCreationViewModel {
    // MARK: - Game Save Methods

    func saveGame(
        gameVersion: String,
        modLoader: String,
        loaderVersion: String,
        pendingIconData: Data?
    ) async {
        guard let gameRepository = gameRepository,
              let playerListViewModel = playerListViewModel else {
            Logger.shared.error("GameRepository 或 PlayerListViewModel 未设置")
            return
        }

        var finalGameName = gameNameValidator.gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalGameName.isEmpty {
            finalGameName = GameNameGenerator.generateGameName(
                gameVersion: gameVersion,
                loaderVersion: loaderVersion,
                modLoader: modLoader
            )
            gameNameValidator.gameName = finalGameName
        }

        await gameSetupService.saveGame(
            gameName: finalGameName,
            selectedGameVersion: gameVersion,
            selectedModLoader: modLoader,
            specifiedLoaderVersion: loaderVersion,
            pendingIconData: pendingIconData,
            playerListViewModel: playerListViewModel,
            gameRepository: gameRepository,
            onSuccess: {
                Task { @MainActor in
                    AppServices.gameCreationManager.completeGameCreation()
                    self.configuration.actions.onCancel()
                }
            },
            onError: { error, message in
                Task { @MainActor in
                    AppServices.gameCreationManager.cancelGameCreation()
                    self.handleNonCriticalError(error, message: message)
                }
            }
        )
    }
}
