import SwiftUI

struct UserAvatarButton: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @State private var showingProfileSheet = false
    @State private var showingAddPlayerSheet = false
    @State private var playerName = ""
    @State private var isPlayerNameValid = false
    @StateObject private var friendsViewModel = MinecraftFriendsSheetViewModel()

    var body: some View {
        Button {
            if playerListViewModel.currentPlayer != nil {
                showingProfileSheet = true
            } else {
                playerName = ""
                isPlayerNameValid = false
                showingAddPlayerSheet = true
            }
        } label: {
            if let player = playerListViewModel.currentPlayer {
                MinecraftSkinUtils(
                    type: player.isOnlineAccount ? .url : .asset,
                    src: player.avatarName,
                    size: 28
                )
                .id(player.id)
                .id(player.avatarName)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
        //.buttonStyle(.plain)
        .sheet(isPresented: $showingProfileSheet) {
            if let player = playerListViewModel.currentPlayer {
                UserProfileSheetView(player: player, friendsViewModel: friendsViewModel)
                    .environmentObject(playerListViewModel)
            }
        }
        .sheet(isPresented: $showingAddPlayerSheet) {
            AddPlayerSheetView(
                playerName: $playerName,
                isPlayerNameValid: $isPlayerNameValid,
                onAdd: {
                    if playerListViewModel.addPlayer(name: playerName) {
                        Logger.shared.debug("player.add.success".localized())
                    }
                    isPlayerNameValid = true
                    showingAddPlayerSheet = false
                },
                onCancel: {
                    playerName = ""
                    isPlayerNameValid = false
                    showingAddPlayerSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        MinecraftAuthService.shared.clearAuthenticationData()
                    }
                },
                onLogin: { profile in
                    _ = playerListViewModel.addOnlinePlayer(profile: profile)
                    PremiumAccountFlagManager.shared.setPremiumAccountAdded()
                    showingAddPlayerSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        MinecraftAuthService.shared.clearAuthenticationData()
                    }
                },
                playerListViewModel: playerListViewModel
            )
        }
    }
}
