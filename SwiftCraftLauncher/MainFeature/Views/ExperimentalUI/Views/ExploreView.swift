import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var filterState: ResourceFilterState
    @State private var heroItems: [ModpackHeroItem] = []
    @State private var currentIndex: Int = 0
    @State private var topModpacks: [ModpackHeroItem] = []
    @State private var popularMods: [ModpackHeroItem] = []
    @State private var selectedTypeForFilter: ResourceType?
    @State private var selectedDetailItem: ModpackHeroItem?

    private let resourceTypes = ResourceType.allCases

    var body: some View {
        Group {
            if let detailItem = selectedDetailItem {
                ExploreDetailView(
                    item: detailItem,
                    onDismiss: { selectedDetailItem = nil }
                )
            } else if let filterType = selectedTypeForFilter {
                ExploreFilterView(
                    resourceType: filterType,
                    onDismiss: { selectedTypeForFilter = nil }
                )
                .transition(.move(edge: .trailing))
            } else {
                mainContent
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedTypeForFilter != nil)
        .animation(.easeInOut(duration: 0.3), value: selectedDetailItem != nil)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if !heroItems.isEmpty {
                        ModpackHeroCarousel(items: heroItems, currentIndex: $currentIndex)
                            .frame(height: geometry.size.height * 0.68)
                    }

                    classificationBar

                    sectionCards
                }
            }
        }
        .task {
            await loadAllData()
        }
    }

    // MARK: - Classification Bar

    private var classificationBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(resourceTypes, id: \.self) { type in
                    Button {
                        selectedTypeForFilter = type
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.systemImage)
                                .font(.system(size: 14, weight: .medium))
                            Text(type.localizedName)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Section Cards

    private var sectionCards: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !topModpacks.isEmpty {
                sectionView(
                    title: "explore.top_modpacks".localized(),
                    items: topModpacks
                )
            }

            if !popularMods.isEmpty {
                sectionView(
                    title: "explore.popular_mods".localized(),
                    items: popularMods
                )
            }

            Spacer().frame(height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func sectionView(title: String, items: [ModpackHeroItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.bold())
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        sectionCard(for: item)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func sectionCard(for item: ModpackHeroItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image
            ZStack {
                if let iconUrl = item.iconUrl, let url = URL(string: iconUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 200, height: 120)
                                .clipped()
                        default:
                            item.fallbackColor
                                .frame(width: 200, height: 120)
                        }
                    }
                } else {
                    item.fallbackColor
                        .frame(width: 200, height: 120)
                }
            }
            .frame(width: 200, height: 120)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 14,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 14
                )
            )

            // Info area
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Text(item.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(downloadCountString(item.downloads))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(width: 200, alignment: .leading)
            .background(Color(.controlBackgroundColor))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 14,
                    bottomTrailingRadius: 14,
                    topTrailingRadius: 0
                )
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDetailItem = item
        }
    }

    // MARK: - Data Loading

    private func loadAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadHeroItems() }
            group.addTask { await loadTopModpacks() }
            group.addTask { await loadPopularMods() }
        }
    }

    private func loadHeroItems() async {
        let types: [(ResourceType, String)] = [
            (.mod, "mod"),
            (.resourcepack, "resourcepack"),
            (.datapack, "datapack"),
            (.shader, "shader"),
            (.modpack, "modpack"),
            (.minecraftJavaServer, "minecraft_java_server"),
        ]

        var items: [ModpackHeroItem] = []
        for (resourceType, projectType) in types {
            let result = await ModrinthService.searchProjects(
                facets: [["project_type:\(projectType)"]],
                offset: 0,
                limit: 5,
                query: nil
            )
            let sorted = result.hits.sorted(by: { $0.downloads > $1.downloads })
            if let top = sorted.first {
                let hue = Double(abs(top.slug.hashValue) % 360) / 360.0
                items.append(ModpackHeroItem(
                    id: top.projectId,
                    title: top.title,
                    author: top.author,
                    description: resourceType.localizedName + " · " + top.description,
                    downloads: top.downloads,
                    iconUrl: top.iconUrl,
                    fallbackColor: Color(hue: hue, saturation: 0.4, brightness: 0.8)
                ))
            }
        }

        await MainActor.run { heroItems = items }
    }

    private func loadTopModpacks() async {
        let result = await ModrinthService.searchProjects(
            facets: [["project_type:modpack"]],
            offset: 0,
            limit: 15,
            query: nil
        )
        let sorted = result.hits.sorted(by: { $0.downloads > $1.downloads })
        let top10 = Array(sorted.prefix(10))

        let items = top10.map { project in
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

        await MainActor.run { topModpacks = items }
    }

    private func loadPopularMods() async {
        let result = await ModrinthService.searchProjects(
            facets: [["project_type:mod"]],
            offset: 0,
            limit: 15,
            query: nil
        )
        let sorted = result.hits.sorted(by: { $0.downloads > $1.downloads })
        let top10 = Array(sorted.prefix(10))

        let items = top10.map { project in
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

        await MainActor.run { popularMods = items }
    }

    private func downloadCountString(_ count: Int) -> String {
        if count >= 1_000_000 {
            String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            "\(count)"
        }
    }
}

// MARK: - Explore Filter View

struct ExploreFilterView: View {
    let resourceType: ResourceType
    let onDismiss: () -> Void
    @EnvironmentObject var filterState: ResourceFilterState
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    onDismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("common.back".localized())
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: resourceType.systemImage)
                    Text(resourceType.localizedName)
                        .font(.headline)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Filter content
            CategoryContentView(
                project: resourceType.rawValue,
                type: "resource",
                selectedCategories: filterState.selectedCategoriesBinding,
                selectedFeatures: filterState.selectedFeaturesBinding,
                selectedResolutions: filterState.selectedResolutionsBinding,
                selectedPerformanceImpacts: filterState.selectedPerformanceImpactBinding,
                selectedVersions: filterState.selectedVersionsBinding,
                selectedLoaders: filterState.selectedLoadersBinding,
                gameVersion: nil,
                gameLoader: nil,
                dataSource: filterState.dataSource
            )
            .id(resourceType)
        }
    }
}
