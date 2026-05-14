import SwiftUI

struct ExploreDetailView: View {
    let item: ModpackHeroItem
    let onDismiss: () -> Void
    @State private var projectDetail: ModrinthProjectDetail?
    @State private var versions: [ModrinthProjectDetailVersion] = []
    @State private var isLoading = true
    @State private var showInstallSheet = false
    @State private var selectedGameVersion = ""
    @State private var selectedVersion: ModrinthProjectDetailVersion?

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero header
                        heroHeader(width: geometry.size.width, height: geometry.size.height * 0.48)
                        // Content sections
                        detailSections
                    }
                }
            }
            .task {
                await loadDetail()
            }
            .sheet(isPresented: $showInstallSheet) {
                versionSelectionSheet
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: { onDismiss() }) {
                        Label("common.back".localized(), systemImage: "chevron.left")
                    }
                }
            }
        }
    }

    private var versionSelectionSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("resource.install.version_select".localized())
                    .font(.headline)
                Spacer()
                Button("common.cancel".localized()) {
                    showInstallSheet = false
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            Divider()
            if versions.isEmpty {
                Spacer()
                ProgressView().controlSize(.small)
                Spacer()
            } else {
                List(versions) { version in
                    Button {
                        selectedVersion = version
                        showInstallSheet = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(version.name)
                                    .font(.body.weight(.medium))
                                if !version.gameVersions.isEmpty {
                                    Text(version.gameVersions.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if let loader = version.loaders.first {
                                Text(loader)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 300)
            }
        }
        .frame(width: 420, height: 400)
    }

    // MARK: - Hero Header

    private func heroHeader(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Blurred background from icon
            blurredHeaderBackground(width: width, height: height)
            // Dark gradient for readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            // Content
            VStack(alignment: .leading, spacing: 16) {
                Spacer()
                // Bottom info
                VStack(alignment: .leading, spacing: 12) {
                    // App icon
                    if let iconUrl = item.iconUrl, let url = URL(string: iconUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                            default:
                                EmptyView()
                            }
                        }
                    }
                    Text(item.title)
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text(item.author)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                    HStack(spacing: 16) {
                        Label(downloadCountStr(item.downloads), systemImage: "arrow.down.to.line")
                        if let detail = projectDetail {
                            Label("\(detail.followers)", systemImage: "heart")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    // Install button
                    Button {
                        handleInstall()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 18))
                            Text("resource.install.title".localized())
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func blurredHeaderBackground(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let iconUrl = item.iconUrl, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .blur(radius: 80)
                            .clipped()
                            .overlay(Color.black.opacity(0.3))
                    default:
                        item.fallbackColor.frame(width: width, height: height)
                    }
                }
            } else {
                item.fallbackColor.frame(width: width, height: height)
            }
        }
    }

    // MARK: - Detail Sections

    @ViewBuilder
    private var detailSections: some View {
        if isLoading {
            VStack {
                ProgressView().controlSize(.large)
            }
            .frame(height: 200)
        } else if let detail = projectDetail {
            VStack(alignment: .leading, spacing: 0) {
                // Description
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("resource.detail.description".localized())
                            .font(.title3.bold())
                        Spacer()
                    }
                    Text(detail.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(5)
                    if !detail.categories.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(detail.categories, id: \.self) { cat in
                                Text(cat)
                                    .font(.caption2)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(24)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                // Info
                VStack(alignment: .leading, spacing: 14) {
                    Text("resource.detail.info".localized())
                        .font(.title3.bold())
                        .padding(.leading, 4)
                    infoRow(label: "resource.detail.license".localized(), value: detail.license?.name ?? "-")
                    infoRow(label: "resource.detail.client_side".localized(), value: detail.clientSide)
                    infoRow(label: "resource.detail.server_side".localized(), value: detail.serverSide)
                    if let sourceUrl = detail.sourceUrl, let url = URL(string: sourceUrl) {
                        Link(destination: url) {
                            Label("resource.detail.source".localized(), systemImage: "link")
                        }
                    }
                }
                .padding(24)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                .padding(.top, 16)
                // Links
                VStack(alignment: .leading, spacing: 12) {
                    if let wikiUrl = detail.wikiUrl, let url = URL(string: wikiUrl) {
                        Link(destination: url) {
                            Label("Wiki", systemImage: "book")
                        }
                    }
                    if let discordUrl = detail.discordUrl, let url = URL(string: discordUrl) {
                        Link(destination: url) {
                            Label("Discord", systemImage: "bubble.left.and.bubble.right")
                        }
                    }
                    if let issuesUrl = detail.issuesUrl, let url = URL(string: issuesUrl) {
                        Link(destination: url) {
                            Label("resource.detail.issues".localized(), systemImage: "exclamationmark.bubble")
                        }
                    }
                }
                .padding(24)
                .padding(.bottom, 40)
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .font(.subheadline)
    }

    // MARK: - Actions

    private func handleInstall() {
        showInstallSheet = true
    }

    // MARK: - Data

    private func loadDetail() async {
        do {
            let detail = await ModrinthService.fetchProjectDetails(id: item.id)
            let vers = await ModrinthService.fetchProjectVersions(id: item.id)
            await MainActor.run {
                projectDetail = detail
                versions = vers
                isLoading = false
            }
        }
    }

    private func downloadCountStr(_ count: Int) -> String {
        if count >= 1_000_000 {
            String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            "\(count)"
        }
    }
}
