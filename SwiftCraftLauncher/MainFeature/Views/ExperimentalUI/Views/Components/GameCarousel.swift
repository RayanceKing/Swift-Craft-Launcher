import SwiftUI

struct GameCarousel: View {
    let games: [GameVersionInfo]
    @Binding var currentIndex: Int
    let cardColors: [Color]

    @State private var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State private var isHovering = false

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                            carouselCard(for: game, color: cardColors[safe: index] ?? Color.gray)
                                .frame(width: 700)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onReceive(timer) { _ in
                    guard !isHovering, games.count > 1 else { return }
                    let next = (currentIndex + 1) % games.count
                    withAnimation(.easeInOut(duration: 0.6)) {
                        proxy.scrollTo(next, anchor: .center)
                    }
                    currentIndex = next
                }
                .onChange(of: currentIndex) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }

            if isHovering, games.count > 1 {
                HStack {
                    Button {
                        let prev = (currentIndex - 1 + games.count) % games.count
                        currentIndex = prev
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)

                    Spacer()

                    Button {
                        let next = (currentIndex + 1) % games.count
                        currentIndex = next
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
            }
        }
        .onHover { hovering in isHovering = hovering }
    }

    @ViewBuilder
    private func carouselCard(for game: GameVersionInfo, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(color.gradient)

            HStack(spacing: 24) {
                gameIconView(for: game)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 10) {
                    Text(game.gameName)
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if !game.modLoader.isEmpty && game.modLoader != "vanilla" {
                            Text(game.modLoader.capitalized)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.25))
                                .clipShape(Capsule())
                                .foregroundColor(.white)
                        }
                        Text("MC \(game.gameVersion)")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.25))
                            .clipShape(Capsule())
                            .foregroundColor(.white)
                    }

                    if let formatted = relativeDateString(for: game.lastPlayed) {
                        Text(formatted)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()
            }
            .padding(28)
        }
    }

    @ViewBuilder
    private func gameIconView(for game: GameVersionInfo) -> some View {
        let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
        let iconURL = profileDir.appendingPathComponent(game.gameIcon)
        if FileManager.default.fileExists(atPath: iconURL.path) {
            AsyncImage(url: iconURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().interpolation(.none).scaledToFit()
                case .failure, .empty:
                    fallbackIcon
                @unknown default:
                    fallbackIcon
                }
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        ZStack {
            Color.white.opacity(0.15)
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func relativeDateString(for date: Date) -> String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let str = formatter.localizedString(for: date, relativeTo: Date())
        if str.contains("0 sec") || str.contains("0秒") { return nil }
        return str
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
