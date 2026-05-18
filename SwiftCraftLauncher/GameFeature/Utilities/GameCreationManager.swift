import Foundation

/// 游戏创建管理器 - 管理游戏创建流程和下载进度
@MainActor
class GameCreationManager: ObservableObject {
    static let shared = GameCreationManager()

    @Published var isCreatingGame = false
    @Published var creatingGame: GameVersionInfo?
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var currentDownloadFile: String = ""
    @Published var isWindowVisible = false

    private let progressManager: DownloadProgressManager

    // 下载任务项（用于统一下载窗口）
    private var gameTaskItem: DownloadTaskItem?

    private init(
        progressManager: DownloadProgressManager = DownloadProgressManager.shared
    ) {
        self.progressManager = progressManager
    }

    /// 开始游戏创建 - 显示占位卡片
    func startGameCreation(game: GameVersionInfo) {
        creatingGame = game
        isCreatingGame = true
    }

    /// 开始游戏下载 - 创建统一的游戏下载任务并显示进度窗口
    func startGameDownload(game: GameVersionInfo, modLoader: String? = nil) {
        creatingGame = game
        isDownloading = true
        downloadProgress = 0.0
        currentDownloadFile = ""
        isWindowVisible = true

        // 创建统一的游戏下载任务
        let gameTask = DownloadTaskItem(
            icon: "gamecontroller.fill",
            title: game.gameName,
            subtitle: "Preparing...",
            progress: 0,
            status: .downloading,
            onAction: { [weak self] in
                self?.cancelGameCreation()
            }
        )
        gameTaskItem = gameTask
        progressManager.addTask(gameTask)
    }

    /// 更新游戏下载进度（统一核心+资源+加载器）
    func updateGameProgress(fileName: String, progress: Double) {
        gameTaskItem?.subtitle = fileName
        gameTaskItem?.progress = progress
        downloadProgress = progress
        currentDownloadFile = fileName
    }

    /// 完成游戏创建 - 标记任务为已完成
    func completeGameCreation() {
        gameTaskItem?.status = .completed
        gameTaskItem?.progress = 1.0
        isCreatingGame = false
        isDownloading = false
        creatingGame = nil
    }

    /// 取消游戏创建
    func cancelGameCreation() {
        removeAllTasks()
        isCreatingGame = false
        isDownloading = false
        creatingGame = nil
    }

    /// 更新下载进度 (保留用于向后兼容)
    func updateDownloadProgress(fileName: String, progress: Double) {
        currentDownloadFile = fileName
        downloadProgress = progress
        gameTaskItem?.subtitle = fileName
        gameTaskItem?.progress = progress
    }

    private func removeAllTasks() {
        if let task = gameTaskItem { progressManager.removeTask(task); gameTaskItem = nil }
        isWindowVisible = progressManager.hasActiveTasks
    }

    /// 关闭窗口并清理状态
    func closeWindow() {
        removeAllTasks()
        isDownloading = false
        downloadProgress = 0.0
        currentDownloadFile = ""
    }

    /// 清除占位卡片
    func clearPlaceholder() {
        isCreatingGame = false
    }
}
