import Foundation

/// Java下载管理器
@MainActor
class JavaDownloadManager: ObservableObject {
    static let shared = JavaDownloadManager()

    @Published var downloadState = JavaDownloadState()
    @Published var isWindowVisible = false

    private let javaRuntimeService: JavaRuntimeService
    private let progressManager: DownloadProgressManager
    private var dismissCallback: (() -> Void)?
    private var currentDownloadTask: Task<Void, Error>?
    private var cancelRequested = false
    private var activeTaskItem: DownloadTaskItem?

    private init(
        javaRuntimeService: JavaRuntimeService = AppServices.javaRuntimeService,
        progressManager: DownloadProgressManager = DownloadProgressManager.shared
    ) {
        self.javaRuntimeService = javaRuntimeService
        self.progressManager = progressManager
    }

    /// 设置窗口关闭回调
    func setDismissCallback(_ callback: @escaping () -> Void) {
        dismissCallback = callback
    }

    /// 开始下载Java运行时
    func downloadJavaRuntime(version: String) async {
        defer {
            currentDownloadTask = nil
            cancelRequested = false
        }
        do {
            // 重置状态
            downloadState.reset()
            downloadState.startDownload(version: version)
            cancelRequested = false

            // 创建下载任务并注册到共享管理器
            let taskItem = DownloadTaskItem(
                icon: "cup.and.saucer.fill",
                title: version,
                subtitle: "Preparing...",
                progress: 0,
                status: .downloading,
                onAction: { [weak self] in
                    self?.cancelDownload()
                }
            )
            activeTaskItem = taskItem
            progressManager.addTask(taskItem)
            isWindowVisible = true

            // 设置进度回调
            javaRuntimeService.setProgressCallback { [weak self] fileName, completed, total in
                Task { @MainActor in
                    guard let self = self, !self.downloadState.isCancelled else { return }
                    let progress = total > 0 ? Double(completed) / Double(total) : 0.0
                    self.downloadState.updateProgress(fileName: fileName, progress: progress)
                    self.activeTaskItem?.subtitle = fileName
                    self.activeTaskItem?.progress = progress
                }
            }

            // 设置取消检查回调
            javaRuntimeService.setCancelCallback { [weak self] in
                return self?.cancelRequested ?? false
            }

            // 开始下载
            let task = Task { [javaRuntimeService] in
                try await javaRuntimeService.downloadJavaRuntime(for: version)
            }
            currentDownloadTask = task
            try await task.value

            // 检查是否被取消
            if downloadState.isCancelled || cancelRequested {
                Logger.shared.info("Java下载已被取消")
                cleanupCancelledDownload()
                return
            }

            // 下载完成 - 标记任务为已完成
            downloadState.isDownloading = false
            activeTaskItem?.status = .completed
            isWindowVisible = progressManager.hasActiveTasks
        } catch {
            if error is CancellationError || downloadState.isCancelled || cancelRequested {
                Logger.shared.info("Java下载任务已取消")
                cleanupCancelledDownload()
                return
            }
            // 下载失败
            if !downloadState.isCancelled {
                downloadState.setError(error.localizedDescription)
                activeTaskItem?.icon = "exclamationmark.triangle.fill"
                activeTaskItem?.subtitle = error.localizedDescription
                activeTaskItem?.status = .error(error.localizedDescription)
                activeTaskItem?.onAction = { [weak self] in
                    self?.retryDownload()
                }
            }
        }
    }

    /// 取消下载
    func cancelDownload() {
        guard downloadState.isDownloading else {
            removeActiveTask()
            return
        }
        cancelRequested = true
        downloadState.cancel()
        currentDownloadTask?.cancel()
    }

    /// 重试下载
    func retryDownload() {
        guard !downloadState.version.isEmpty else { return }
        removeActiveTask()
        Task {
            await downloadJavaRuntime(version: downloadState.version)
        }
    }

    /// 移除活跃任务
    private func removeActiveTask() {
        if let task = activeTaskItem {
            progressManager.removeTask(task)
            activeTaskItem = nil
        }
        isWindowVisible = progressManager.hasActiveTasks
        dismissCallback?()
    }

    /// 关闭窗口 (保留用于向后兼容)
    func closeWindow() {
        removeActiveTask()
        downloadState.reset()
    }

    /// 清理取消的下载数据
    func cleanupCancelledDownload() {
        Logger.shared.info("Cleaning up cancelled Java download for version: \(downloadState.version)")
        closeWindow()
    }
}
