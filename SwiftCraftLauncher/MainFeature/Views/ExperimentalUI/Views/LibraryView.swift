import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var filterState: ResourceFilterState
    @EnvironmentObject var detailState: ResourceDetailState
    @EnvironmentObject var gameLaunchUseCase: GameLaunchUseCase
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @ObservedObject private var gameCreationManager = AppServices.gameCreationManager
    @State private var hoveredGameId: String?
    @State private var selectedGameForDetail: GameVersionInfo?

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 20, alignment: .top)
    ]

    var body: some View {
        Group {
            if let game = selectedGameForDetail {
                GameLibraryDetailView(
                    game: game,
                    onDismiss: {
                        selectedGameForDetail = nil
                        resetDetailState()
                    },
                    onLaunch: { launchGame(game) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerView

                        if gameRepository.games.isEmpty {
                            emptyLibrary
                        } else {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(gameRepository.games) { game in
                                    GameLibraryCard(
                                        game: game,
                                        isHovered: hoveredGameId == game.id,
                                        onSelect: {
                                            openGameDetail(game)
                                        },
                                        onLaunch: {
                                            launchGame(game)
                                        }
                                    )
                                    .onHover { hovering in
                                        hoveredGameId = hovering ? game.id : nil
                                    }
                                }
                                if gameCreationManager.isCreatingGame, let creatingGame = gameCreationManager.creatingGame {
                                    gameCreationPlaceholder(creatingGame)
                                }
                            }
                            .padding(.bottom, 12)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 36)
                    .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: gameRepository.games.count) { _, _ in
            // 当游戏列表变化时，检查占位游戏是否已被添加（按名称匹配）
            if gameCreationManager.isCreatingGame,
               let creatingGame = gameCreationManager.creatingGame,
               gameRepository.games.contains(where: { $0.gameName == creatingGame.gameName }) {
                // 游戏已添加，移除占位卡片但保持下载状态
                gameCreationManager.clearPlaceholder()
            }
        }
    }

    private var headerView: some View {
        HStack(alignment: .center) {
            Text("你的游戏")
                .font(.title.bold())
                .foregroundStyle(.primary)

            Spacer()

            Button {
                gameRepository.loadGames()
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }

    private var emptyLibrary: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 56, weight: .regular))
                .foregroundColor(.secondary.opacity(0.35))
            Text("experimental.library.empty".localized())
                .font(.title2.bold())
                .foregroundColor(.secondary)
            Text("experimental.library.empty_hint".localized())
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openGameDetail(_ game: GameVersionInfo) {
        detailState.selectedItem = .game(game.id)
        detailState.gameId = game.id
        detailState.gameType = false
        detailState.selectedProjectId = nil
        detailState.gameResourcesType = game.modLoader == GameLoader.vanilla.displayName
            ? ResourceType.datapack.rawValue
            : ResourceType.mod.rawValue
        AppServices.selectedGameManager.setSelectedGame(game.id)
        selectedGameForDetail = game
    }

    private func launchGame(_ game: GameVersionInfo) {
        let player = playerListViewModel.currentPlayer
        Task {
            await gameLaunchUseCase.launchGame(player: player, game: game)
        }
    }

    private func resetDetailState() {
        detailState.selectedItem = .resource(.mod)
        detailState.gameId = nil
        detailState.gameType = true
        detailState.selectedProjectId = nil
    }

    private func gameCreationPlaceholder(_ game: GameVersionInfo) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.controlBackgroundColor).opacity(0.5))
                    ProgressView()
                        .controlSize(.large)
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(game.gameName)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    Text("正在创建中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: 148, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
