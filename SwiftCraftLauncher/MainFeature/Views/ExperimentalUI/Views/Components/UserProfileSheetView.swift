import SwiftUI

struct UserProfileSheetView: View {
    let player: Player
    @ObservedObject var friendsViewModel: MinecraftFriendsSheetViewModel
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @FocusState private var addFriendFieldFocused: Bool
    @State private var showingAddPlayerSheet = false
    @State private var newPlayerName = ""
    @State private var isPlayerNameValid = false

    private enum SheetPage {
        case profile
        case friends
        case addFriend
    }

    @State private var currentPage: SheetPage = .profile

    var body: some View {
        CommonSheetView(
            header: { sheetHeader },
            body: { sheetBody },
            footer: { sheetFooter }
        )
        .onAppear {
            if player.canUseMicrosoftMinecraftServices {
                Task {
                    await friendsViewModel.load(player: player, forceRefresh: false)
                }
            }
        }
        .onDisappear {
            friendsViewModel.clearLoadedData()
        }
        .sheet(isPresented: $showingAddPlayerSheet) {
            AddPlayerSheetView(
                playerName: $newPlayerName,
                isPlayerNameValid: $isPlayerNameValid,
                onAdd: {
                    if playerListViewModel.addPlayer(name: newPlayerName) {
                        Logger.shared.debug("player.add.success".localized())
                    }
                    isPlayerNameValid = true
                    showingAddPlayerSheet = false
                },
                onCancel: {
                    newPlayerName = ""
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

    // MARK: - Profile Header

    @ViewBuilder
    private var sheetHeader: some View {
        switch currentPage {
        case .profile:
            profileHeader
        case .friends:
            friendsPageHeader
        case .addFriend:
            addFriendPageHeader
        }
    }

    private var addFriendPageHeader: some View {
        HStack(spacing: 12) {
            Button {
                currentPage = .profile
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            Text("minecraft.friends.add.title".localized())
                .font(.title3.weight(.semibold))
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var friendsPageHeader: some View {
        HStack(spacing: 12) {
            Button {
                currentPage = .profile
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            Text("minecraft.friends.sheet.title".localized())
                .font(.title3.weight(.semibold))
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            MinecraftSkinUtils(
                type: player.isOnlineAccount ? .url : .asset,
                src: player.avatarName,
                size: 72
            )
            .id(player.id)
            .id(player.avatarName)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.title3.weight(.semibold))
                if player.isOnlineAccount {
                    Text("player.type.online".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("player.type.offline".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Body Content

    @ViewBuilder
    private var sheetBody: some View {
        switch currentPage {
        case .profile:
            bodyContent
        case .friends:
            friendsDetailsPage
        case .addFriend:
            addFriendPage
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                playerSwitchingSection
                if player.canUseMicrosoftMinecraftServices {
                    Divider()
                    friendsSection
                }
            }
        }
    }

    // MARK: - Player Switching

    private var playerSwitchingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("player.switch".localized())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(playerListViewModel.players) { p in
                HStack(spacing: 10) {
                    MinecraftSkinUtils(
                        type: p.isOnlineAccount ? .url : .asset,
                        src: p.avatarName,
                        size: 28
                    )
                    .id(p.id)
                    .id(p.avatarName)
                    Text(p.name)
                        .font(.body)
                        .lineLimit(1)
                        .foregroundColor(p.id == player.id ? .primary : .secondary)
                    if p.id == player.id {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(p.id == player.id ? Color.accentColor.opacity(0.08) : Color.clear)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if p.id != player.id {
                        playerListViewModel.setCurrentPlayer(byID: p.id)
                        dismiss()
                    }
                }
            }
            Button {
                newPlayerName = ""
                isPlayerNameValid = false
                showingAddPlayerSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("player.add".localized())
                        .font(.subheadline)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Friends Section

    @ViewBuilder
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("minecraft.friends.sheet.title".localized())
                .font(.title3.weight(.semibold))
            allFriendsCard
            quickActionsCard
        }
    }

    private var allFriendsCard: some View {
        Button {
            currentPage = .friends
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(primaryCardTextColor.opacity(0.9))
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("minecraft.friends.section.friends".localized())
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(primaryCardTextColor)
                    Text("共 \(friendsViewModel.uiData.lists.friends.count) 个")
                        .font(.headline)
                        .foregroundStyle(secondaryCardTextColor)
                }
                Spacer()
                friendAvatarStack
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(secondaryCardTextColor)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(glassCardBackground)
        }
        .buttonStyle(.plain)
    }

    private var primaryCardTextColor: Color {
        colorScheme == .light ? .black : .white
    }

    private var secondaryCardTextColor: Color {
        colorScheme == .light ? .black.opacity(0.68) : .white.opacity(0.75)
    }

    private var glassCardBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(colorScheme == .light ? Color.white.opacity(0.6) : Color.white.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        colorScheme == .light ? Color.black.opacity(0.12) : Color.white.opacity(0.16),
                        lineWidth: 1
                    )
            )
    }

    private var quickActionsCard: some View {
        VStack(spacing: 0) {
            Button {
                currentPage = .addFriend
            } label: {
                quickActionRow(
                    icon: "person.badge.plus",
                    title: "minecraft.friends.add.button".localized()
                )
            }
            .buttonStyle(.plain)
            .disabled(friendsViewModel.isLoading)
            Divider()
                .overlay(colorScheme == .light ? Color.black.opacity(0.12) : Color.white.opacity(0.14))
                .padding(.horizontal, 20)
            Button {
                currentPage = .friends
            } label: {
                quickActionRow(
                    icon: "person.crop.circle.badge.questionmark",
                    title: "minecraft.friends.section.incoming".localized(),
                    subtitle: "共 \(friendsViewModel.uiData.lists.incomingRequests.count) 个"
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassCardBackground)
    }

    private func quickActionRow(icon: String, title: String, subtitle: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(primaryCardTextColor.opacity(0.82))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(primaryCardTextColor)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(secondaryCardTextColor)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(secondaryCardTextColor)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var friendAvatarStack: some View {
        HStack(spacing: -11) {
            let previewFriends = Array(friendsViewModel.uiData.lists.friends.prefix(3))
            if previewFriends.isEmpty {
                Circle()
                    .fill(colorScheme == .light ? Color.black.opacity(0.12) : Color.white.opacity(0.2))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(primaryCardTextColor.opacity(0.85))
                    )
            } else {
                ForEach(previewFriends.indices, id: \.self) { idx in
                    let friend = previewFriends[idx]
                    let skinSrc = friendsViewModel.skinTextureURLString(forUUIDNormalized: friend.profileId.normalized)
                    Group {
                        if let skinSrc, !skinSrc.isEmpty {
                            MinecraftSkinUtils(type: .url, src: skinSrc, size: 56)
                                .id("friend-avatar-preview-\(friend.profileId.normalized)-\(skinSrc)")
                        } else {
                            Circle()
                                .fill(colorScheme == .light ? Color.black.opacity(0.12) : Color.white.opacity(0.2))
                                .overlay(
                                    Text(friend.name.prefix(1).uppercased())
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(primaryCardTextColor.opacity(0.9))
                                )
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(
                            colorScheme == .light ? Color.black.opacity(0.12) : Color(red: 0.18, green: 0.24, blue: 0.35),
                            lineWidth: 2
                        )
                    )
                }
            }
        }
    }

    private var friendsDetailsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if friendsViewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 72)
                } else if isFriendsEmptyState {
                    Text("minecraft.friends.empty".localized())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                } else {
                    friendsListSection(
                        sectionId: "friends",
                        title: "minecraft.friends.section.friends".localized(),
                        dtos: friendsViewModel.uiData.lists.friends,
                        rowActions: .confirmed
                    )
                    friendsListSection(
                        sectionId: "incoming",
                        title: "minecraft.friends.section.incoming".localized(),
                        dtos: friendsViewModel.uiData.lists.incomingRequests,
                        rowActions: .incoming
                    )
                    friendsListSection(
                        sectionId: "outgoing",
                        title: "minecraft.friends.section.outgoing".localized(),
                        dtos: friendsViewModel.uiData.lists.outgoingRequests,
                        rowActions: .outgoing
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var sheetFooter: some View {
        switch currentPage {
        case .profile:
            footerContent
        case .friends:
            friendsFooter
        case .addFriend:
            addFriendFooter
        }
    }

    private var addFriendFooter: some View {
        HStack {
            Button("common.cancel".localized()) {
                friendsViewModel.addFriendName = ""
                currentPage = .profile
            }
            Spacer()
            Button {
                submitAddFriend()
            } label: {
                Text("minecraft.friends.add.button".localized())
            }
            .keyboardShortcut(.defaultAction)
            .disabled(friendsViewModel.isLoading)
        }
    }

    private var friendsFooter: some View {
        HStack {
            Button {
                Task {
                    await friendsViewModel.load(player: player, forceRefresh: true)
                }
            } label: {
                Text("minecraft.friends.refresh".localized())
            }
            .disabled(friendsViewModel.isLoading)
            Spacer()
            Button("common.close".localized()) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private var footerContent: some View {
        HStack {
            if player.canUseMicrosoftMinecraftServices {
                Button {
                    Task {
                        await friendsViewModel.load(player: player, forceRefresh: true)
                    }
                } label: {
                    Text("minecraft.friends.refresh".localized())
                }
                .disabled(friendsViewModel.isLoading)
            }
            Spacer()
            Button("common.close".localized()) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    // MARK: - Add Friend Popover

    private var addFriendPage: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(primaryCardTextColor.opacity(0.7))
                    TextField("minecraft.friends.add.placeholder".localized(), text: $friendsViewModel.addFriendName)
                        .textFieldStyle(.roundedBorder)
                        .focused($addFriendFieldFocused)
                        .disabled(friendsViewModel.isLoading)
                        .onSubmit {
                            submitAddFriend()
                        }
                }
                .padding(.horizontal)
                Spacer(minLength: 20)
                VStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)
                    Text("与朋友一起玩，游戏更有趣")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("minecraft.friends.add.empty_hint".localized())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            }
            .padding()
            .onAppear {
                addFriendFieldFocused = true
            }
        }
    }

    private func submitAddFriend() {
        let trimmed = friendsViewModel.addFriendName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { @MainActor in
            await friendsViewModel.sendFriendRequest(player: player)
            currentPage = .friends
        }
    }

    // MARK: - Helpers

    private var isFriendsEmptyState: Bool {
        let l = friendsViewModel.uiData.lists
        return l.friends.isEmpty && l.incomingRequests.isEmpty && l.outgoingRequests.isEmpty
    }

    private enum RowActions: String {
        case confirmed
        case incoming
        case outgoing
    }

    @ViewBuilder
    private func friendsListSection(sectionId: String, title: String, dtos: [MinecraftFriendProfileDTO], rowActions: RowActions) -> some View {
        if !dtos.isEmpty {
            sectionHeader(title)
            ForEach(dtos, id: \.profileId.normalized) { dto in
                friendRow(dto: dto, rowActions: rowActions)
                    .id("\(sectionId)-\(rowActions.rawValue)-\(dto.profileId.normalized)")
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func friendRow(dto: MinecraftFriendProfileDTO, rowActions: RowActions) -> some View {
        let pid = dto.profileId.normalized
        let presence = friendsViewModel.uiData.presenceByProfileId[pid]
        let skinSrc = friendsViewModel.skinTextureURLString(forUUIDNormalized: pid)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                if let skinSrc, !skinSrc.isEmpty {
                    MinecraftSkinUtils(type: .url, src: skinSrc, size: 32)
                        .id("\(pid)-\(skinSrc)")
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 32, height: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(dto.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        presenceBadge(presence?.status)
                    }
                }
                actionButtons(for: dto, rowActions: rowActions)
            }
        }
    }

    @ViewBuilder
    private func actionButtons(for dto: MinecraftFriendProfileDTO, rowActions: RowActions) -> some View {
        let wireId = dto.profileId.dashedLowercase
        switch rowActions {
        case .confirmed:
            Button("minecraft.friends.action.remove".localized()) {
                Task {
                    await friendsViewModel.removeFriend(player: player, profileId: wireId)
                }
            }
            .disabled(friendsViewModel.isLoading)
            .controlSize(.small)
        case .incoming:
            HStack(spacing: 4) {
                Button("minecraft.friends.action.accept".localized()) {
                    Task {
                        await friendsViewModel.acceptIncoming(player: player, profileId: wireId)
                    }
                }
                .disabled(friendsViewModel.isLoading)
                .controlSize(.small)
                Button("minecraft.friends.action.decline".localized()) {
                    Task {
                        await friendsViewModel.declineIncoming(player: player, profileId: wireId)
                    }
                }
                .disabled(friendsViewModel.isLoading)
                .controlSize(.small)
            }
        case .outgoing:
            Button("minecraft.friends.action.revoke".localized()) {
                Task {
                    await friendsViewModel.revokeOutgoing(player: player, profileId: wireId)
                }
            }
            .disabled(friendsViewModel.isLoading)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func presenceBadge(_ status: MinecraftPresenceWireStatus?) -> some View {
        let s = status ?? .offline
        HStack(spacing: 4) {
            Circle()
                .fill(presenceColor(s))
                .frame(width: 6, height: 6)
            Text(presenceTitleKey(s).localized())
                .font(.caption2.weight(.medium))
                .foregroundStyle(presenceColor(s))
        }
    }

    private func presenceColor(_ s: MinecraftPresenceWireStatus) -> Color {
        switch s {
        case .online, .playingServer, .playingHostedServer, .playingRealms:
            return .green
        case .playingOffline:
            return .orange
        case .offline:
            return Color.secondary.opacity(0.45)
        }
    }

    private func presenceTitleKey(_ s: MinecraftPresenceWireStatus) -> String {
        switch s {
        case .online:
            return "minecraft.friends.presence.online"
        case .offline:
            return "minecraft.friends.presence.offline"
        case .playingOffline:
            return "minecraft.friends.presence.playing_offline"
        case .playingRealms:
            return "minecraft.friends.presence.playing_realms"
        case .playingServer:
            return "minecraft.friends.presence.playing_server"
        case .playingHostedServer:
            return "minecraft.friends.presence.playing_hosted_server"
        }
    }
}
