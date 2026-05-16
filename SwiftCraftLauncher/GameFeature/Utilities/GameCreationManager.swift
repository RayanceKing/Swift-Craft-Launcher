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

    private let windowManager: WindowManager

    private init(
        windowManager: WindowManager = AppServices.windowManager
    ) {
        self.windowManager = windowManager
    }

    /// 开始游戏创建 - 显示占位卡片
    func startGameCreation(game: GameVersionInfo) {
        creatingGame = game
        isCreatingGame = true
    }

    /// 开始游戏下载 - 显示进度窗口（在表单确认后调用）
    func startGameDownload(game: GameVersionInfo) {
        creatingGame = game
        isDownloading = true
        downloadProgress = 0.0
        currentDownloadFile = ""
        showDownloadWindow()
    }

    /// 完成游戏创建
    func completeGameCreation() {
        isCreatingGame = false
        isDownloading = false
        creatingGame = nil
        closeWindow()
    }

    /// 取消游戏创建
    func cancelGameCreation() {
        isCreatingGame = false
        isDownloading = false
        creatingGame = nil
        closeWindow()
    }

    /// 更新下载进度
    func updateDownloadProgress(fileName: String, progress: Double) {
        currentDownloadFile = fileName
        downloadProgress = progress
    }

    /// 显示下载窗口
    private func showDownloadWindow() {
        windowManager.openWindow(id: .gameDownload)
        isWindowVisible = true
    }

    /// 关闭下载窗口并清理状态
    func closeWindow() {
        windowManager.closeWindow(id: .gameDownload)
        isWindowVisible = false
        isDownloading = false
        downloadProgress = 0.0
        currentDownloadFile = ""
    }

    /// 清除占位卡片
    func clearPlaceholder() {
        isCreatingGame = false
    }
}
