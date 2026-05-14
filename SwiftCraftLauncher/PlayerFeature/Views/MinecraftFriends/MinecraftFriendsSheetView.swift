import SwiftUI

struct MinecraftFriendsSheetView: View {
    let player: Player
    @ObservedObject var viewModel: MinecraftFriendsSheetViewModel

    @Environment(\.dismiss)
    private var dismiss

    @State private var showAddFriendPopover = false
    @FocusState private var addFriendFieldFocused: Bool

    var body: some View {
        CommonSheetView(
            header: {
                HStack(alignment: .center, spacing: 12) {
                    Text("minecraft.friends.sheet.title".localized())
                        .font(.headline)
                    Spacer()
                    Button {
                        showAddFriendPopover = true
                    } label: {
                        Text("minecraft.friends.add.open".localized())
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoading)
                    .popover(isPresented: $showAddFriendPopover, arrowEdge: .bottom) {
                        addFriendPopoverContent
                            .presentationCompactAdaptation(.popover)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            body: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if isEmptyState {
                        Text("minecraft.friends.empty".localized())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                friendsListSection(
                                    sectionId: "friends",
                                    title: "minecraft.friends.section.friends".localized(),
                                    dtos: viewModel.uiData.lists.friends,
                                    rowActions: .confirmed
                                )
                                friendsListSection(
                                    sectionId: "incoming",
                                    title: "minecraft.friends.section.incoming".localized(),
                                    dtos: viewModel.uiData.lists.incomingRequests,
                                    rowActions: .incoming
                                )
                                friendsListSection(
                                    sectionId: "outgoing",
                                    title: "minecraft.friends.section.outgoing".localized(),
                                    dtos: viewModel.uiData.lists.outgoingRequests,
                                    rowActions: .outgoing
                                )
                            }
                        }
                        .frame(maxWidth: 400)
                    }
                }
            },
            footer: {
                HStack {
                    Button {
                        Task { await viewModel.load(player: player, forceRefresh: true) }
                    } label: {
                        Text("minecraft.friends.refresh".localized())
                    }
                    .disabled(viewModel.isLoading)

                    Spacer()

                    Button("common.close".localized()) {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
        )
        .onDisappear {
            viewModel.clearLoadedData()
        }
    }

    @ViewBuilder private var addFriendPopoverContent: some View {
        HStack {
            TextField("minecraft.friends.add.placeholder".localized(), text: $viewModel.addFriendName)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 240)
                .focused($addFriendFieldFocused)
                .disabled(viewModel.isLoading)
                .onSubmit { submitAddFriendFromPopover() }
            Button("minecraft.friends.add.button".localized()) {
                submitAddFriendFromPopover()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.isLoading)
        }
        .padding()
        .onAppear {
            addFriendFieldFocused = true
        }
    }

    private func submitAddFriendFromPopover() {
        let trimmed = viewModel.addFriendName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { @MainActor in
            await viewModel.sendFriendRequest(player: player)
            showAddFriendPopover = false
        }
    }

    private var isEmptyState: Bool {
        let l = viewModel.uiData.lists
        return l.friends.isEmpty && l.incomingRequests.isEmpty && l.outgoingRequests.isEmpty
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
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum RowActions: String {
        case confirmed
        case incoming
        case outgoing
    }

    private func friendRow(dto: MinecraftFriendProfileDTO, rowActions: RowActions) -> some View {
        let pid = dto.profileId.normalized
        let presence = viewModel.uiData.presenceByProfileId[pid]
        let skinSrc = viewModel.skinTextureURLString(forUUIDNormalized: pid)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if let skinSrc, !skinSrc.isEmpty {
                    MinecraftSkinUtils(type: .url, src: skinSrc, size: 40)
                        .id("\(pid)-\(skinSrc)")
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(dto.name)
                            .font(.body.weight(.medium))
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
                Task { await viewModel.removeFriend(player: player, profileId: wireId) }
            }
            .disabled(viewModel.isLoading)
            .controlSize(.small)
        case .incoming:
            HStack(spacing: 6) {
                Button("minecraft.friends.action.accept".localized()) {
                    Task { await viewModel.acceptIncoming(player: player, profileId: wireId) }
                }
                .disabled(viewModel.isLoading)
                .controlSize(.small)
                Button("minecraft.friends.action.decline".localized()) {
                    Task { await viewModel.declineIncoming(player: player, profileId: wireId) }
                }
                .disabled(viewModel.isLoading)
                .controlSize(.small)
            }
        case .outgoing:
            Button("minecraft.friends.action.revoke".localized()) {
                Task { await viewModel.revokeOutgoing(player: player, profileId: wireId) }
            }
            .disabled(viewModel.isLoading)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func presenceBadge(_ status: MinecraftPresenceWireStatus?) -> some View {
        let s = status ?? .offline
        HStack(spacing: 6) {
            Circle()
                .fill(presenceColor(s))
                .frame(width: 7, height: 7)
            Text(presenceTitleKey(s).localized())
                .font(.caption.weight(.medium))
                .foregroundStyle(presenceColor(s))
        }
        .accessibilityElement(children: .combine)
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
