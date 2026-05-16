import SwiftUI

struct GameLibraryDetailView: View {
    let game: GameVersionInfo
    let onDismiss: () -> Void
    let onLaunch: () -> Void

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroHeader(width: geometry.size.width, height: geometry.size.height * 0.46)
                        detailSections
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button(action: onDismiss) {
                            Label("common.back".localized(), systemImage: "chevron.left")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func heroHeader(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            blurredHeaderBackground(width: width, height: height)
            LinearGradient(
                colors: [.clear, .black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 16) {
                Spacer()
                HStack(alignment: .bottom, spacing: 16) {
                    gameIcon
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(game.gameName)
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                            .lineLimit(2)
                        HStack(spacing: 10) {
                            infoChip(text: "MC \(game.gameVersion)")
                            if !game.modLoader.isEmpty && game.modLoader != "vanilla" {
                                infoChip(text: game.modLoader.capitalized)
                            }
                        }
                        HStack(spacing: 12) {
                            Label("\(game.xms == 0 ? 0 : game.xms) MB - \(game.xmx == 0 ? 0 : game.xmx) MB", systemImage: "memorychip")
                            Label(relativeDateString(for: game.lastPlayed) ?? "-", systemImage: "clock")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func blurredHeaderBackground(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let iconURL = iconURL, FileManager.default.fileExists(atPath: iconURL.path) {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .blur(radius: 70)
                            .clipped()
                            .overlay(Color.black.opacity(0.28))
                    default:
                        fallbackBackground(width: width, height: height)
                    }
                }
            } else {
                fallbackBackground(width: width, height: height)
            }
        }
    }

    private func fallbackBackground(width: CGFloat, height: CGFloat) -> some View {
        LinearGradient(
            colors: [baseFallbackColor.opacity(0.95), baseFallbackColor.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: width, height: height)
    }

    private var detailSections: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailCard(title: "游戏信息") {
                infoRow(label: "游戏版本", value: game.gameVersion)
                infoRow(label: "模组加载器", value: game.modLoader.isEmpty ? "-" : game.modLoader)
                infoRow(label: "最后游玩", value: relativeDateString(for: game.lastPlayed) ?? "-")
                infoRow(label: "Java 版本", value: "Java \(game.javaVersion)")
                infoRow(label: "内存", value: game.xms == 0 && game.xmx == 0 ? "-" : "\(game.xms) MB / \(game.xmx) MB")
            }
            detailCard(title: "启动") {
                Text("点击下方按钮直接启动这个游戏版本。")
                    .font(.body)
                    .foregroundColor(.secondary)
                Button(action: onLaunch) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("开始游戏")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 36)
    }

    private func detailCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.bold())
                .padding(.leading, 4)
            content()
        }
        .padding(24)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .font(.subheadline)
    }

    private func infoChip(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private var gameIcon: some View {
        Group {
            if let iconURL = iconURL, FileManager.default.fileExists(atPath: iconURL.path) {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.none)
                            .scaledToFill()
                    default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .clipped()
    }

    private var fallbackIcon: some View {
        ZStack {
            fallbackBackgroundView
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 34))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    private var fallbackBackgroundView: some View {
        LinearGradient(
            colors: [baseFallbackColor.opacity(0.95), baseFallbackColor.opacity(0.68)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var baseFallbackColor: Color {
        let hue = Double(abs(game.gameName.hashValue % 360)) / 360.0
        return Color(hue: hue, saturation: 0.45, brightness: 0.78)
    }

    private var iconURL: URL? {
        let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
        let candidate = profileDir.appendingPathComponent(game.gameIcon)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    private func relativeDateString(for date: Date) -> String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let str = formatter.localizedString(for: date, relativeTo: Date())
        if str.contains("0 sec") || str.contains("0 秒") {
            return nil
        }
        return str
    }
}
