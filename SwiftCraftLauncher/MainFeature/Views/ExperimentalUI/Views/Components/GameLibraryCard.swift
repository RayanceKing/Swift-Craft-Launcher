import SwiftUI

struct GameLibraryCard: View {
    let game: GameVersionInfo
    let isHovered: Bool
    let onSelect: () -> Void
    let onLaunch: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                gameArtwork
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 8) {
                    if !game.modLoader.isEmpty && game.modLoader != "vanilla" {
                        Text(game.modLoader.capitalized)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                            .foregroundStyle(.secondary)
                    }

                    Text(game.gameName)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    Text("\("saveinfo.world.detail.label.last_played".localized())：\(relativeDateString(for: game.lastPlayed) ?? "-")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("MC \(game.gameVersion)")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.05)))

                        Spacer(minLength: 0)
                    }

                    Button(action: onLaunch) {
                        Text("开始游戏")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.white.opacity(0.16)))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: 148, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.controlBackgroundColor).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.16 : 0.08), radius: isHovered ? 14 : 8, y: isHovered ? 6 : 3)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(perform: onSelect)
    }

    @ViewBuilder private var gameArtwork: some View {
        let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
        let iconURL = profileDir.appendingPathComponent(game.gameIcon)
        ZStack {
            if FileManager.default.fileExists(atPath: iconURL.path) {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.none)
                            .scaledToFill()
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
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
