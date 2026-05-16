//
//  AppWindowGroups.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import SwiftUI

/// 应用窗口组定义
extension SwiftCraftLauncherApp {
    /// 创建所有应用窗口组
    @SceneBuilder
    func appWindowGroups() -> some Scene {
        // 贡献者窗口
        Window("about.contributors".localized(), id: WindowID.contributors.rawValue) {
            AboutView(showingAcknowledgements: false)
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(nil)
                .windowStyleConfig(for: .contributors)
                .windowCleanup(for: .contributors)
        }
        .defaultSize(width: 280, height: 600)

        // 致谢窗口
        Window("about.acknowledgements".localized(), id: WindowID.acknowledgements.rawValue) {
            AboutView(showingAcknowledgements: true)
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(nil)
                .windowStyleConfig(for: .acknowledgements)
                .windowCleanup(for: .acknowledgements)
        }
        .defaultSize(width: 280, height: 600)

        // AI 聊天窗口
        Window("ai.assistant.title".localized(), id: WindowID.aiChat.rawValue) {
            AIChatWindowContent()
                .environmentObject(playerListViewModel)
                .environmentObject(gameRepository)
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(nil)
                .windowStyleConfig(for: .aiChat)
                .windowCleanup(for: .aiChat)
        }
        .defaultSize(width: 500, height: 600)

        // Java 下载窗口
        Window("global_resource.download".localized(), id: WindowID.javaDownload.rawValue) {
            JavaDownloadWindowContent()
                .preferredColorScheme(nil)
                .windowStyleConfig(for: .javaDownload)
                .windowCleanup(for: .javaDownload)
        }
        .defaultSize(width: 400, height: 100)

        // 游戏下载窗口
        Window("game.download.progress".localized(), id: WindowID.gameDownload.rawValue) {
            GameDownloadProgressWindowContent()
                .preferredColorScheme(nil)
                .windowStyleConfig(for: .gameDownload)
                .windowCleanup(for: .gameDownload)
        }
        .defaultSize(width: 400, height: 120)

        // 皮肤预览窗口
        Window("skin.preview".localized(), id: WindowID.skinPreview.rawValue) {
            SkinPreviewWindowContent()
                .preferredColorScheme(nil)
                .windowStyleConfig(for: .skinPreview)
                .windowCleanup(for: .skinPreview)
        }
        .defaultSize(width: 1200, height: 800)
    }
}

// MARK: - 窗口内容视图

private struct JavaDownloadWindowContent: View {
    @ObservedObject private var javaDownloadManager: JavaDownloadManager

    init(javaDownloadManager: JavaDownloadManager = AppServices.javaDownloadManager) {
        _javaDownloadManager = ObservedObject(wrappedValue: javaDownloadManager)
    }

    var body: some View {
        JavaDownloadProgressWindow(downloadState: javaDownloadManager.downloadState)
    }
}

/// 游戏下载进度窗口内容视图
private struct GameDownloadProgressWindowContent: View {
    @ObservedObject private var gameCreationManager: GameCreationManager

    init(gameCreationManager: GameCreationManager = AppServices.gameCreationManager) {
        _gameCreationManager = ObservedObject(wrappedValue: gameCreationManager)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let game = gameCreationManager.creatingGame {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(game.gameName)")
                            .font(.headline.weight(.semibold))
                        
                        if !gameCreationManager.currentDownloadFile.isEmpty {
                            Text(gameCreationManager.currentDownloadFile)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(Int(gameCreationManager.downloadProgress * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: gameCreationManager.downloadProgress)
                .progressViewStyle(.linear)
            
            HStack(spacing: 12) {
                Button("取消") {
                    gameCreationManager.cancelGameCreation()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("后台运行") {
                    // 不需要做什么，只是关闭窗口
                    // 下载会继续在后台进行
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(16)
    }
}

/// AI 聊天窗口内容视图（用于观察 WindowDataStore 变化）
private struct AIChatWindowContent: View {
    @ObservedObject private var windowDataStore: WindowDataStore
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var generalSettingsManager: GeneralSettingsManager

    init(windowDataStore: WindowDataStore = AppServices.windowDataStore) {
        _windowDataStore = ObservedObject(wrappedValue: windowDataStore)
    }

    var body: some View {
        Group {
            if let chatState = windowDataStore.aiChatState {
                AIChatWindowView(chatState: chatState)
            } else {
                EmptyView()
            }
        }
    }
}

/// 皮肤预览窗口内容视图（用于观察 WindowDataStore 变化）
private struct SkinPreviewWindowContent: View {
    @ObservedObject private var windowDataStore: WindowDataStore

    init(windowDataStore: WindowDataStore = AppServices.windowDataStore) {
        _windowDataStore = ObservedObject(wrappedValue: windowDataStore)
    }

    var body: some View {
        Group {
            if let data = windowDataStore.skinPreviewData {
                SkinPreviewWindowView(
                    skinImage: data.skinImage,
                    skinPath: data.skinPath,
                    capeImage: data.capeImage,
                    playerModel: data.playerModel
                )
            } else {
                EmptyView()
            }
        }
    }
}
