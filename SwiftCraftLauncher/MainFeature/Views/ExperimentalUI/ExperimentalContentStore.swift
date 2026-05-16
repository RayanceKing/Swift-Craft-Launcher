import Foundation
import SwiftUI

@MainActor
final class ExperimentalContentStore: ObservableObject {
    @Published private(set) var homeModpackItems: [ModpackHeroItem] = []
    @Published private(set) var isHomeLoading = true

    @Published private(set) var heroItems: [ModpackHeroItem] = []
    @Published private(set) var topModpacks: [ModpackHeroItem] = []
    @Published private(set) var popularMods: [ModpackHeroItem] = []
    @Published private(set) var isExploreLoading = true

    private var homeLoadTask: Task<Void, Never>?
    private var exploreLoadTask: Task<Void, Never>?
    private var hasLoadedHome = false
    private var hasLoadedExplore = false

    deinit {
        homeLoadTask?.cancel()
        exploreLoadTask?.cancel()
    }

    func loadHomeIfNeeded() async {
        if hasLoadedHome {
            return
        }
        if let homeLoadTask {
            await homeLoadTask.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.fetchHomeData()
        }
        homeLoadTask = task
        await task.value
        homeLoadTask = nil
    }

    func loadExploreIfNeeded() async {
        if hasLoadedExplore {
            return
        }
        if let exploreLoadTask {
            await exploreLoadTask.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.fetchExploreData()
        }
        exploreLoadTask = task
        await task.value
        exploreLoadTask = nil
    }

    private func fetchHomeData() async {
        isHomeLoading = true

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

        homeModpackItems = items
        isHomeLoading = false
        hasLoadedHome = true
    }

    private func fetchExploreData() async {
        isExploreLoading = true

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.fetchHeroItems()
            }
            group.addTask { [weak self] in
                await self?.fetchTopModpacks()
            }
            group.addTask { [weak self] in
                await self?.fetchPopularMods()
            }
        }

        isExploreLoading = false
        hasLoadedExplore = true
    }

    private func fetchHeroItems() async {
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
        heroItems = items
    }

    private func fetchTopModpacks() async {
        let result = await ModrinthService.searchProjects(
            facets: [["project_type:modpack"]],
            offset: 0,
            limit: 15,
            query: nil
        )
        let sorted = result.hits.sorted(by: { $0.downloads > $1.downloads })
        let top10 = Array(sorted.prefix(10))
        topModpacks = top10.map { project in
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
    }

    private func fetchPopularMods() async {
        let result = await ModrinthService.searchProjects(
            facets: [["project_type:mod"]],
            offset: 0,
            limit: 15,
            query: nil
        )
        let sorted = result.hits.sorted(by: { $0.downloads > $1.downloads })
        let top10 = Array(sorted.prefix(10))
        popularMods = top10.map { project in
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