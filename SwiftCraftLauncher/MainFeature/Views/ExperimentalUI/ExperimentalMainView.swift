import SwiftUI

enum ExperimentalTab: String, CaseIterable {
    case home
    case explore
    case friends
    case library
    case search

    var iconName: String {
        switch self {
        case .home: return "house"
        case .explore: return "safari"
        case .friends: return "person.2"
        case .library: return "books.vertical"
        case .search: return "magnifyingglass"
        }
    }

    var displayName: String {
        switch self {
        case .home: return "tab.home".localized()
        case .explore: return "tab.explore".localized()
        case .friends: return "tab.friends".localized()
        case .library: return "tab.library".localized()
        case .search: return ""
        }
    }
}

struct ExperimentalMainView: View {
    @State private var selectedTab: ExperimentalTab = .home
    @State private var showingGameForm = false
    @State private var showNoPlayerAlert = false
    @StateObject private var filterState = ResourceFilterState()
    @StateObject private var detailState = ResourceDetailState()
    @StateObject private var contentStore = ExperimentalContentStore()
    @ObservedObject private var gameCreationManager = AppServices.gameCreationManager
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var gameLaunchUseCase: GameLaunchUseCase

    var body: some View {
        contentForTab
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all)
            .environmentObject(filterState)
            .environmentObject(detailState)
            .environmentObject(contentStore)
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    Picker(selection: $selectedTab) {
                        Text("tab.home".localized()).tag(ExperimentalTab.home)
                        Text("tab.explore".localized()).tag(ExperimentalTab.explore)
                        Text("tab.friends".localized()).tag(ExperimentalTab.friends)
                        Text("tab.library".localized()).tag(ExperimentalTab.library)
                        Image(systemName: "magnifyingglass")
                            .tag(ExperimentalTab.search)
                            .help("tab.search".localized())
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        if playerListViewModel.currentPlayer == nil {
                            showNoPlayerAlert = true
                        } else {
                            // 创建占位游戏对象
                            let placeholderGame = GameVersionInfo(
                                gameName: "New Game",
                                gameIcon: "",
                                gameVersion: "1.20.1",
                                assetIndex: "",
                                modLoader: "",
                                lastPlayed: Date()
                            )
                            gameCreationManager.startGameCreation(game: placeholderGame)
                            showingGameForm = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("game.form.title".localized())
                    .sheet(isPresented: $showingGameForm) {
                        GameFormView()
                            .environmentObject(gameRepository)
                            .environmentObject(playerListViewModel)
                    }

                    UserAvatarButton()
                }
            }
            .toolbarBackground(.hidden, for: .windowToolbar)
            .onAppear {
                playerListViewModel.loadPlayers()
                gameRepository.loadGames()
            }
            .alert(isPresented: $showNoPlayerAlert) {
                Alert(
                    title: Text("sidebar.alert.no_player.title".localized()),
                    message: Text("sidebar.alert.no_player.message".localized()),
                    dismissButton: .default(Text("common.confirm".localized()))
                )
            }
    }

    @ViewBuilder private var contentForTab: some View {
        switch selectedTab {
        case .home:
            HomeView(selectedTab: $selectedTab)
        case .explore:
            ExploreView()
        case .friends:
            FriendsView()
        case .library:
            LibraryView()
        case .search:
            SearchView()
        }
    }
}
