import SwiftUI

struct SearchView: View {
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var filterState: ResourceFilterState
    @State private var searchQuery: String = ""
    @State private var searchResults: [ModrinthProject] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                TextField("experimental.search.placeholder".localized(), text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                        searchTask?.cancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.controlBackgroundColor)))
            .padding(24)
            .onChange(of: searchQuery) { _, newValue in
                performSearch(query: newValue)
            }

            if searchQuery.isEmpty {
                emptyPrompt
            } else if isSearching {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            } else if filteredGames.isEmpty && searchResults.isEmpty {
                noResults
            } else {
                searchResultsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredGames: [GameVersionInfo] {
        guard !searchQuery.isEmpty else { return [] }
        let lower = searchQuery.lowercased()
        return gameRepository.games.filter { $0.gameName.lowercased().contains(lower) }
    }

    private var emptyPrompt: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 52))
                .foregroundColor(.secondary.opacity(0.35))
            Text("experimental.search.prompt".localized())
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var noResults: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.35))
            Text(String(format: "experimental.search.no_results".localized(), searchQuery))
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if !filteredGames.isEmpty {
                    Section {
                        ForEach(filteredGames) { game in
                            gameResultRow(game)
                        }
                    } header: {
                        Text("sidebar.games.title".localized())
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                if !searchResults.isEmpty {
                    Section {
                        ForEach(searchResults, id: \.projectId) { project in
                            modrinthResultRow(project)
                        }
                    } header: {
                        Text("Modrinth")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func gameResultRow(_ game: GameVersionInfo) -> some View {
        HStack(spacing: 12) {
            gameThumbnail(for: game)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(game.gameName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("MC \(game.gameVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func gameThumbnail(for game: GameVersionInfo) -> some View {
        let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
        let iconURL = profileDir.appendingPathComponent(game.gameIcon)
        if FileManager.default.fileExists(atPath: iconURL.path) {
            AsyncImage(url: iconURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().interpolation(.none).scaledToFit()
                default:
                    Color.secondary.opacity(0.15)
                }
            }
        } else {
            Color.secondary.opacity(0.15)
        }
    }

    @ViewBuilder
    private func modrinthResultRow(_ project: ModrinthProject) -> some View {
        HStack(spacing: 12) {
            if let iconURL = project.iconUrl, let url = URL(string: iconURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        Color.secondary.opacity(0.15)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(project.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func performSearch(query: String) {
        searchTask?.cancel()

        guard query.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard !Task.isCancelled else { return }

            let result = await ModrinthService.searchProjects(
                offset: 0,
                limit: 10,
                query: query
            )
            await MainActor.run {
                guard !Task.isCancelled else { return }
                searchResults = result.hits
                isSearching = false
            }
        }
    }
}
