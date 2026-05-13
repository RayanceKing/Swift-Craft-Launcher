import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var filterState: ResourceFilterState
    @State private var selectedResourceType: ResourceType = .mod
    @State private var heroItems: [ModpackHeroItem] = []
    @State private var currentIndex: Int = 0

    private let resourceTypes = ResourceType.allCases

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero carousel
                    if !heroItems.isEmpty {
                        ModpackHeroCarousel(items: heroItems, currentIndex: $currentIndex)
                            .frame(height: geometry.size.height * 0.68)
                    }

                    // Classification bar
                    classificationBar

                    // Content
                    CategoryContentView(
                        project: selectedResourceType.rawValue,
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
                    .id(selectedResourceType)
                    .frame(minHeight: geometry.size.height * 0.45)
                }
            }
        }
        .task {
            await loadHeroItems()
        }
    }

    // MARK: - Classification Bar

    private var classificationBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(resourceTypes, id: \.self) { type in
                    Button {
                        guard selectedResourceType != type else { return }
                        selectedResourceType = type
                        filterState.clearFiltersAndPagination()
                        filterState.selectedTab = 0
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.systemImage)
                                .font(.system(size: 14, weight: .medium))
                            Text(type.localizedName)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedResourceType == type
                                ? Color.accentColor
                                : Color.secondary.opacity(0.12)
                        )
                        .foregroundColor(
                            selectedResourceType == type ? .white : .primary
                        )
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

    // MARK: - Hero Data

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

        await MainActor.run {
            heroItems = items
        }
    }
}
