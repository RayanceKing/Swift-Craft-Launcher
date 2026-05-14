import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: ExperimentalTab
    @EnvironmentObject var gameRepository: GameRepository
    @State private var modpackItems: [ModpackHeroItem] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading = true

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if isLoading {
                        loadingView(height: geometry.size.height)
                    } else if modpackItems.isEmpty {
                        fallbackView
                    } else {
                        heroSection(height: geometry.size.height * 0.72)
                        bottomStrip
                    }
                }
            }
        }
        .task {
            await loadModpackHeroItems()
        }
    }

    // MARK: - Loading

    private func loadingView(height: CGFloat) -> some View {
        VStack {
            Spacer()
            ProgressView().controlSize(.large)
            Spacer()
        }
        .frame(height: height)
    }

    // MARK: - Hero

    private func heroSection(height: CGFloat) -> some View {
        ModpackHeroCarousel(items: modpackItems, currentIndex: $currentIndex)
            .frame(height: height)
    }

    // MARK: - Bottom Strip

    private var bottomStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("experimental.home.popular_modpacks".localized())
                    .font(.title3.bold())
                    .padding(.leading, 24)
                Spacer()
            }
            .padding(.top, 24)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(modpackItems) { item in
                        miniCard(for: item)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 32)
    }

    private func miniCard(for item: ModpackHeroItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let iconUrl = item.iconUrl, let url = URL(string: iconUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            item.fallbackColor
                        }
                    }
                } else {
                    item.fallbackColor
                }
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            Text(item.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
            Text(item.author)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
        }
    }

    // MARK: - Fallback

    @ViewBuilder
    private var fallbackView: some View {
        if gameRepository.games.isEmpty {
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
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 16) {
                GameCarousel(
                    games: gameRepository.games,
                    currentIndex: $currentIndex,
                    cardColors: gameRepository.games.map { _ in
                        Color(hue: Double.random(in: 0...1), saturation: 0.35, brightness: 0.85)
                    }
                )
                pageIndicator(count: gameRepository.games.count)
            }
            .padding(32)
        }
    }

    private func pageIndicator(count: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
            }
        }
    }

    // MARK: - Data

    private func loadModpackHeroItems() async {
        let result = await ModrinthService.searchProjects(
            facets: [["project_type:modpack"]],
            offset: 0,
            limit: 20,
            query: nil
        )
        let sorted = result.hits.sorted(by: { $0.downloads > $1.downloads })
        let top10 = Array(sorted.prefix(10))
        let items: [ModpackHeroItem] = top10.map { project in
            let hue = Double(abs(project.slug.hashValue) % 360) / 360.0
            return ModpackHeroItem(
                id: project.projectId,
                title: project.title,
                author: project.author,
                description: project.description,
                downloads: project.downloads,
                iconUrl: project.iconUrl,
                fallbackColor: Color(hue: hue, saturation: 0.4, brightness: 0.8)
            )
        }
        await MainActor.run {
            modpackItems = items
            isLoading = false
        }
    }
}

struct ModpackHeroItem: Identifiable {
    let id: String
    let title: String
    let author: String
    let description: String
    let downloads: Int
    let iconUrl: String?
    let fallbackColor: Color
}
