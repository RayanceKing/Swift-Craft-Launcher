import SwiftUI

// MARK: - Unified Download Progress Window (supports multiple download rows)

struct DownloadProgressWindow: View {
    @ObservedObject var progressManager: DownloadProgressManager

    init(progressManager: DownloadProgressManager = DownloadProgressManager.shared) {
        self.progressManager = progressManager
    }

    var body: some View {
        VStack(spacing: 0) {
            if progressManager.tasks.isEmpty {
                emptyStateView
            } else {
                ForEach(Array(progressManager.tasks.enumerated()), id: \.element.id) { index, task in
                    DownloadItemView(
                        icon: task.icon,
                        title: task.title,
                        subtitle: task.subtitle,
                        progress: task.progress,
                        status: mapStatus(task.status, progress: task.progress),
                        onAction: { task.onAction?() }
                    )
                    if index < progressManager.tasks.count - 1 {
                        Divider()
                            .padding(.leading, 26)
                            .padding(.bottom, 4)
                    }
                }
            }
        }
        .padding(12)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("download.no.tasks".localized())
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func mapStatus(_ status: DownloadTaskStatus, progress: Double) -> DownloadStatus {
        switch status {
        case .downloading:
            return .downloading(progress: progress)
        case .completed:
            return .completed
        case .error:
            return .error
        }
    }
}

// MARK: - Legacy Java Download Progress Window (backward compat)

struct JavaDownloadProgressWindow: View {
    @ObservedObject var downloadState: JavaDownloadState
    @Environment(\.dismiss)
    private var dismiss
    private let javaDownloadManager: JavaDownloadManager

    init(
        downloadState: JavaDownloadState,
        javaDownloadManager: JavaDownloadManager = AppServices.javaDownloadManager
    ) {
        self.downloadState = downloadState
        self.javaDownloadManager = javaDownloadManager
    }

    var body: some View {
        VStack {
            if downloadState.hasError {
                DownloadItemView(
                    icon: "exclamationmark.triangle.fill",
                    title: downloadState.version,
                    subtitle: downloadState.errorMessage,
                    progress: downloadState.progress,
                    status: .error,
                    onAction: {
                        javaDownloadManager.retryDownload()
                    }
                )
            } else if downloadState.isDownloading {
                DownloadItemView(
                    icon: "cup.and.saucer.fill",
                    title: downloadState.version,
                    subtitle: downloadState.currentFile.isEmpty ? "Preparing..." : downloadState.currentFile,
                    progress: downloadState.progress,
                    status: .downloading(progress: downloadState.progress),
                    onAction: {
                        javaDownloadManager.cancelDownload()
                    }
                )
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("download.no.tasks".localized())
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .onAppear {
            javaDownloadManager.setDismissCallback {
                dismiss()
            }
        }
    }
}

// MARK: - Download Item View

struct DownloadItemView: View {
    let icon: String
    let title: String
    let subtitle: String
    let progress: Double
    let status: DownloadStatus
    let onAction: () -> Void

    @ViewBuilder
    var body: some View {
        switch status {
        case .completed:
            completedBody
        case .error:
            errorBody
        case .downloading where isPreparing:
            preparingBody
        case .downloading:
            downloadingBody
        case .cancelled:
            preparingBody
        }
    }

    // MARK: - Completed

    private var completedBody: some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                    .background(Circle().fill(Color.white).frame(width: 8, height: 8))
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(" ")
                    .font(.subheadline.weight(.semibold))
                    .hidden()

                HStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Spacer().frame(width: 14)
                }

                Text(" ")
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Error

    private var errorBody: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(displaySubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onAction) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Preparing

    private var preparingBody: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text("Preparing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onAction) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Downloading

    private var downloadingBody: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                HStack(alignment: .center, spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: .infinity)

                    Button(action: onAction) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Helpers

    private var isPreparing: Bool {
        subtitle == "Preparing..."
    }

    private var displaySubtitle: String {
        if subtitle.isEmpty || subtitle == "Preparing..." {
            return subtitle
        }
        return URL(fileURLWithPath: subtitle).lastPathComponent
    }
}

// MARK: - Download Status Enum

enum DownloadStatus {
    case downloading(progress: Double)
    case completed
    case error
    case cancelled
}
