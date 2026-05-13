import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: ExperimentalTab
    @EnvironmentObject var gameRepository: GameRepository
    @State private var currentCardIndex: Int = 0
    @State private var cardColors: [Color] = []

    var body: some View {
        VStack {
            if gameRepository.games.isEmpty {
                welcomeCard
            } else {
                GameCarousel(
                    games: gameRepository.games,
                    currentIndex: $currentCardIndex,
                    cardColors: cardColors
                )
                pageIndicator
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .onAppear { generateCardColors() }
        .onChange(of: gameRepository.games.count) { _, _ in generateCardColors() }
    }

    private var welcomeCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
            Text("experimental.home.welcome".localized())
                .font(.title.bold())
            Text("experimental.home.get_started".localized())
                .font(.body)
                .foregroundColor(.secondary)
            Button {
                selectedTab = .library
            } label: {
                Text("experimental.home.go_library".localized())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: 500, maxHeight: .infinity)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<gameRepository.games.count, id: \.self) { index in
                Circle()
                    .fill(index == currentCardIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentCardIndex)
            }
        }
        .padding(.top, 16)
    }

    private func generateCardColors() {
        cardColors = gameRepository.games.map { _ in
            Color(hue: Double.random(in: 0...1), saturation: 0.35, brightness: 0.85)
        }
    }
}
