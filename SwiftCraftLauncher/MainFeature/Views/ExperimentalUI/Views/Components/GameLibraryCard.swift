import SwiftUI

struct GameLibraryCard: View {
    let game: GameVersionInfo
    let isHovered: Bool
    let onLaunch: () -> Void

    var body: some View {
        Button(action: onLaunch) {
            VStack(spacing: 0) {
                gameArtwork
                    .frame(height: 140)
                    .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    Text(game.gameName)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        if !game.modLoader.isEmpty && game.modLoader != "vanilla" {
                            Text(game.modLoader.capitalized)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                .foregroundColor(.accentColor)
                        }
                        Text("MC \(game.gameVersion)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        if let formatted = relativeDateString(for: game.lastPlayed) {
                            Text(formatted)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.controlBackgroundColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isHovered ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(isHovered ? 0.12 : 0.05), radius: isHovered ? 10 : 4, y: isHovered ? 4 : 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
    }

    @ViewBuilder private var gameArtwork: some View {
        let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
        let iconURL = profileDir.appendingPathComponent(game.gameIcon)
        if FileManager.default.fileExists(atPath: iconURL.path) {
            AsyncImage(url: iconURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().interpolation(.none).scaledToFill()
                case .failure, .empty:
                    artworkPlaceholder
                @unknown default:
                    artworkPlaceholder
                }
            }
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: Double(game.gameName.hashValue % 360) / 360.0, saturation: 0.4, brightness: 0.75),
                    Color(hue: Double((game.gameName.hashValue + 40) % 360) / 360.0, saturation: 0.5, brightness: 0.65),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.45))
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
