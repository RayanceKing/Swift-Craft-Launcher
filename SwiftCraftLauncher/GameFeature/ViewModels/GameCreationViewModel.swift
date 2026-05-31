//
//  GameCreationViewModel.swift
//  SwiftCraftLauncher
//
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Game Creation View Model
@MainActor
class GameCreationViewModel: BaseGameFormViewModel {
    // MARK: - Published Properties
    @Published var gameIcon = AppConstants.defaultGameIcon
    @Published var iconImage: Image?
    @Published var selectedGameVersion = ""
    @Published var versionTime = ""
    @Published var selectedModLoader = GameLoader.vanilla.displayName {
        didSet {
            updateParentState()
        }
    }
    @Published var selectedLoaderVersion = "" {
        didSet {
            updateDefaultGameName()
        }
    }
    @Published var availableLoaderVersions: [String] = []
    @Published var availableVersions: [String] = []

    // MARK: - Private Properties
    var pendingIconData: Data?
    var pendingIconURL: URL?
    var didInit = false
    let gameSettingsManager: GameSettingsManager
    private var downloadStateCancellable: AnyCancellable?

    // MARK: - Environment Objects (to be set from view)
    var gameRepository: GameRepository?
    var playerListViewModel: PlayerListViewModel?

    // MARK: - Initialization
    override init(
        configuration: GameFormConfiguration,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler
    ) {
        self.gameSettingsManager = AppServices.gameSettingsManager
        super.init(configuration: configuration, errorHandler: errorHandler)
    }

    init(
        configuration: GameFormConfiguration,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
        gameSettingsManager: GameSettingsManager
    ) {
        self.gameSettingsManager = gameSettingsManager
        super.init(configuration: configuration, errorHandler: errorHandler)
    }

    // MARK: - Setup Methods
    func setup(gameRepository: GameRepository, playerListViewModel: PlayerListViewModel) {
        self.gameRepository = gameRepository
        self.playerListViewModel = playerListViewModel

        if !didInit {
            didInit = true
            Task {
                await initializeVersionPicker()
            }
        }
        updateParentState()

        // 监听下载状态变化并转发到 GameCreationManager，用于更新统一下载窗口
        downloadStateCancellable = gameSetupService.downloadState.objectWillChange.sink { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                let ds = self.gameSetupService.downloadState
                let progress = max(ds.coreProgress, ds.resourcesProgress)
                let file = ds.currentCoreFile.isEmpty ? ds.currentResourceFile : ds.currentCoreFile
                AppServices.gameCreationManager.updateGameProgress(fileName: file, progress: progress)
            }
        }
    }

    // MARK: - Override Methods
    override func performConfirmAction() async {
        // 构建临时占位游戏信息用于在下载窗口展示
        let tempGame = GameVersionInfo(
            gameName: gameNameValidator.gameName.isEmpty ? "New Game" : gameNameValidator.gameName,
            gameIcon: gameIcon,
            gameVersion: selectedGameVersion,
            assetIndex: "",
            modLoader: selectedModLoader,
            lastPlayed: Date()
        )

        // 立即关闭表单（由父视图传入的 onConfirm 将处理 dismiss）
        configuration.actions.onConfirm()

        // 捕获值（onConfirm 会触发 onDisappear 清空这些属性）
        let capturedGameVersion = selectedGameVersion
        let capturedModLoader = selectedModLoader
        let capturedLoaderVersion = selectedModLoader == GameLoader.vanilla.displayName ? selectedModLoader : selectedLoaderVersion
        let capturedPendingIconData = pendingIconData

        // 打开下载窗口并展示占位信息
        AppServices.gameCreationManager.startGameDownload(game: tempGame)

        // 开始实际的保存与下载流程
        startDownloadTask {
            await self.saveGame(
                gameVersion: capturedGameVersion,
                modLoader: capturedModLoader,
                loaderVersion: capturedLoaderVersion,
                pendingIconData: capturedPendingIconData
            )
        }
    }

    override func handleCancel() {
        if isDownloading {
            // 停止下载任务
            downloadTask?.cancel()
            downloadTask = nil

            // 取消下载状态
            gameSetupService.downloadState.cancel()

            // 执行取消后的清理工作
            Task {
                await performCancelCleanup()
            }
        } else {
            configuration.actions.onCancel()
        }
    }

    override func performCancelCleanup() async {
        // 如果正在下载时取消，需要删除已创建的游戏文件夹
        let gameName = gameNameValidator.gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !gameName.isEmpty {
            // 检查游戏是否已经保存到仓库中
            // 如果已经保存，说明游戏创建成功，不应该删除文件夹
            let isGameSaved = await MainActor.run {
                guard let gameRepository = gameRepository else { return false }
                return gameRepository.games.contains { $0.gameName == gameName }
            }

            if !isGameSaved {
                do {
                    let profileDir = AppPaths.profileDirectory(gameName: gameName)

                    if FileManager.default.fileExists(atPath: profileDir.path) {
                        try FileManager.default.removeItem(at: profileDir)
                        Logger.shared.info("已删除取消创建的游戏文件夹: \(profileDir.path)")
                    }
                } catch {
                    Logger.shared.error("删除游戏文件夹失败: \(error.localizedDescription)")
                }
            } else {
                Logger.shared.info("游戏已成功保存，跳过删除文件夹: \(gameName)")
            }
        }

        // 重置下载状态并关闭窗口
        await MainActor.run {
            gameSetupService.downloadState.reset()
            configuration.actions.onCancel()
        }
    }

    override func computeIsDownloading() -> Bool {
        return gameSetupService.downloadState.isDownloading
    }

    override func computeIsFormValid() -> Bool {
        let isLoaderVersionValid = selectedModLoader == GameLoader.vanilla.displayName || !selectedLoaderVersion.isEmpty
        return gameNameValidator.isFormValid && isLoaderVersionValid
    }

    var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading
    }

    var pendingIconURLForDisplay: URL? {
        pendingIconURL ?? URLConfig.API.GitHub.gameIcon(selectedModLoader)
    }

    /// 添加游戏窗口关闭时，清理已加载的版本列表
    func clearLoadedVersionsOnClose() {
        availableVersions = []
        availableLoaderVersions = []
        selectedGameVersion = ""
        selectedLoaderVersion = ""
        versionTime = ""
        didInit = false
    }
}
