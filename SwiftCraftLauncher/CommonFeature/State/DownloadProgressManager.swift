import SwiftUI
import Combine

// MARK: - Download Task Status

enum DownloadTaskStatus {
    case downloading
    case completed
    case error(String)
}

// MARK: - Download Task Item

class DownloadTaskItem: ObservableObject, Identifiable {
    let id = UUID()
    @Published var icon: String
    @Published var title: String
    @Published var subtitle: String
    @Published var progress: Double
    @Published var status: DownloadTaskStatus
    var onAction: (() -> Void)?

    init(
        icon: String,
        title: String,
        subtitle: String = "",
        progress: Double = 0,
        status: DownloadTaskStatus = .downloading,
        onAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.progress = progress
        self.status = status
        self.onAction = onAction
    }
}

// MARK: - Download Progress Manager

@MainActor
class DownloadProgressManager: ObservableObject {
    static let shared = DownloadProgressManager()

    @Published var tasks: [DownloadTaskItem] = []

    private let windowManager: WindowManager
    private var taskCancellables: [UUID: AnyCancellable] = [:]

    init(windowManager: WindowManager = AppServices.windowManager) {
        self.windowManager = windowManager
    }

    func addTask(_ task: DownloadTaskItem) {
        tasks.append(task)

        // 监听任务变更以触发 SwiftUI 更新
        taskCancellables[task.id] = task.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }

        if tasks.count == 1 {
            showWindow()
        }
    }

    func removeTask(_ task: DownloadTaskItem) {
        tasks.removeAll { $0.id == task.id }
        taskCancellables[task.id] = nil
        if tasks.isEmpty {
            closeWindow()
        }
    }

    var hasActiveTasks: Bool {
        !tasks.isEmpty
    }

    private func showWindow() {
        windowManager.openWindow(id: .javaDownload)
    }

    func closeWindow() {
        windowManager.closeWindow(id: .javaDownload)
    }
}
