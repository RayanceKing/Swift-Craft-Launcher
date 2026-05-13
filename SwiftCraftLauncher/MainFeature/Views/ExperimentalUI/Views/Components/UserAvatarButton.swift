import SwiftUI

struct UserAvatarButton: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @State private var showingPopover = false
    @State private var playerToDelete: Player?
    @State private var showDeleteAlert = false
    @State private var showingAddPlayerSheet = false
    @State private var playerName = ""
    @State private var isPlayerNameValid = false

    var body: some View {
        Button {
            showingPopover.toggle()
        } label: {
            if let player = playerListViewModel.currentPlayer {
                HStack(spacing: 8) {
                    MinecraftSkinUtils(
                        type: player.isOnlineAccount ? .url : .asset,
                        src: player.avatarName,
                        size: 28
                    )
                    .id(player.id)
                    .id(player.avatarName)
                    Text(player.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    Text("experimental.no_player".localized())
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(playerListViewModel.players) { player in
                    PlayerPopoverRow(
                        player: player,
                        onSelect: {
                            playerListViewModel.setCurrentPlayer(byID: player.id)
                            showingPopover = false
                        },
                        onDelete: {
                            playerToDelete = player
                            showDeleteAlert = true
                        }
                    )
                }
                Divider()
                Button {
                    showingPopover = false
                    playerName = ""
                    isPlayerNameValid = false
                    showingAddPlayerSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("player.add".localized())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
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
        .confirmationDialog(
            "player.remove".localized(),
            isPresented: $showDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("player.remove".localized(), role: .destructive) {
                if let player = playerToDelete {
                    _ = playerListViewModel.deletePlayer(byID: player.id)
                }
                playerToDelete = nil
            }
            Button("common.cancel".localized(), role: .cancel) {
                playerToDelete = nil
            }
        } message: {
            Text(String(format: "player.remove.confirm".localized(), playerToDelete?.name ?? ""))
        }
    }
}

private struct PlayerPopoverRow: View {
    let player: Player
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button {
                onSelect()
            } label: {
                MinecraftSkinUtils(
                    type: player.isOnlineAccount ? .url : .asset,
                    src: player.avatarName,
                    size: 32
                )
                .id(player.id)
                .id(player.avatarName)
                Text(player.name)
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 64)
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .help("player.remove".localized())
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
