import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var gameLaunchUseCase: GameLaunchUseCase
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @State private var hoveredGameId: String?

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            if gameRepository.games.isEmpty {
                emptyLibrary
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(gameRepository.games) { game in
                        GameLibraryCard(
                            game: game,
                            isHovered: hoveredGameId == game.id
                        ) {
                            launchGame(game)
                        }
                        .onHover { hovering in
                            hoveredGameId = hovering ? game.id : nil
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyLibrary: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.4))
            Text("experimental.library.empty".localized())
                .font(.title2.weight(.medium))
                .foregroundColor(.secondary)
            Text("experimental.library.empty_hint".localized())
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func launchGame(_ game: GameVersionInfo) {
        guard let player = playerListViewModel.currentPlayer else { return }
        Task {
            await gameLaunchUseCase.launchGame(player: player, game: game)
        }
    }
}
