import AppKit
import SwiftUI

struct ExploreDetailView: View {
    let item: ModpackHeroItem
    let onDismiss: () -> Void
    @EnvironmentObject private var gameRepository: GameRepository
    @State private var projectDetail: ModrinthProjectDetail?
    @State private var isLoading = true
    @State private var installSheetData: InstallSheetData?
    @State private var palette = ExploreDetailPalette.fallback

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    compactHeader
                    detailSections
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
                .scrollContentBackground(.hidden)
                .background(backgroundView.ignoresSafeArea())
            .task(id: item.iconUrl) {
                await updatePalette()
            }
            .task {
                await loadDetail()
            }
            .sheet(item: $installSheetData) { data in
                GlobalResourceSheet(
                    project: data.project,
                    resourceType: ResourceType.mod.rawValue,
                    isPresented: Binding(
                        get: { installSheetData != nil },
                        set: { isPresented in
                            if !isPresented {
                                installSheetData = nil
                            }
                        }
                    ),
                    preloadedDetail: data.detail,
                    preloadedCompatibleGames: data.compatibleGames
                )
                .environmentObject(gameRepository)
                .onDisappear {
                    installSheetData = nil
                }
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

    private var compactHeader: some View {
        VStack(alignment: .center, spacing: 14) {
            heroIcon

            VStack(alignment: .center, spacing: 10) {
                Text(item.author)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(secondaryHeaderColor)
                    .lineLimit(1)

                Text(item.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(primaryHeaderColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.body)
                        .foregroundColor(secondaryHeaderColor)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    metricChip(icon: "arrow.down.to.line", text: downloadCountStr(item.downloads))
                    if let detail = projectDetail {
                        metricChip(icon: "heart", text: "\(detail.followers)")
                    }
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    Button {
                        handleInstall()
                    } label: {
                        HStack(spacing: 8) {
                            Text("resource.install.title".localized())
                                .fontWeight(.semibold)
                                .foregroundColor(palette.start)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(buttonFillColor, in: Capsule())
                        .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)

                    if let detail = projectDetail, let sourceUrl = detail.sourceUrl, let url = URL(string: sourceUrl) {
                        Link(destination: url) {
                            Label("resource.detail.source".localized(), systemImage: "arrow.up.right")
                                .font(.headline)
                                .foregroundColor(primaryHeaderColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                if !detailCategories.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(detailCategories, id: \.self) { category in
                            Text(category)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(primaryHeaderColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(chipFillColor, in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 6)
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
            VStack(alignment: .leading, spacing: 16) {
                sectionCard(title: "resource.detail.description".localized()) {
                    Text(detail.description)
                        .font(.body)
                        .foregroundColor(secondaryHeaderColor)
                        .lineLimit(6)
                }

                sectionCard(title: "resource.detail.info".localized()) {
                    VStack(alignment: .leading, spacing: 14) {
                        infoRow(label: "resource.detail.license".localized(), value: detail.license?.name ?? "-")
                        infoRow(label: "resource.detail.client_side".localized(), value: detail.clientSide)
                        infoRow(label: "resource.detail.server_side".localized(), value: detail.serverSide)
                        infoRow(label: "project.info.details.published".localized(), value: relativeDateString(for: detail.published))
                        infoRow(label: "project.info.details.updated".localized(), value: relativeDateString(for: detail.updated))
                    }
                }

                sectionCard(title: "resource.detail.links".localized()) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let sourceUrl = detail.sourceUrl, let url = URL(string: sourceUrl) {
                            Link(destination: url) {
                                Label("resource.detail.source".localized(), systemImage: "link")
                                    .foregroundColor(primaryHeaderColor)
                            }
                        }
                        if let wikiUrl = detail.wikiUrl, let url = URL(string: wikiUrl) {
                            Link(destination: url) {
                                Label("Wiki", systemImage: "book")
                                    .foregroundColor(primaryHeaderColor)
                            }
                        }
                        if let discordUrl = detail.discordUrl, let url = URL(string: discordUrl) {
                            Link(destination: url) {
                                Label("Discord", systemImage: "bubble.left.and.bubble.right")
                                    .foregroundColor(primaryHeaderColor)
                            }
                        }
                        if let issuesUrl = detail.issuesUrl, let url = URL(string: issuesUrl) {
                            Link(destination: url) {
                                Label("resource.detail.issues".localized(), systemImage: "exclamationmark.bubble")
                                    .foregroundColor(primaryHeaderColor)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(secondaryHeaderColor)
            Spacer()
            Text(value)
                .foregroundColor(primaryHeaderColor)
        }
        .font(.subheadline)
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(primaryHeaderColor)
                .padding(.leading, 2)
            content()
        }
        .padding(24)
        .background(glassCardBackground)
    }

    private var glassCardBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.20),
                        Color.white.opacity(0.09)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: .white.opacity(0.16), radius: 1, x: 0, y: -1)
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    // MARK: - Actions

    private func handleInstall() {
        Task {
            await prepareInstallSheet()
        }
    }

    // MARK: - Data

    private func loadDetail() async {
        do {
            let detail = await ModrinthService.fetchProjectDetails(id: item.id)
            await MainActor.run {
                projectDetail = detail
                isLoading = false
            }
        }
    }

    private func prepareInstallSheet() async {
        guard let result = await ResourceDetailLoader.loadProjectDetail(
            projectId: item.id,
            gameRepository: gameRepository,
            resourceType: ResourceType.mod.rawValue
        ) else {
            return
        }

        await MainActor.run {
            projectDetail = result.detail
            installSheetData = InstallSheetData(
                project: ModrinthProject.from(detail: result.detail),
                detail: result.detail,
                compatibleGames: result.compatibleGames
            )
        }
    }

    private func updatePalette() async {
        let sampled = await ExploreDetailPaletteSampler.palette(from: item.iconUrl.flatMap(URL.init(string:)))
        await MainActor.run {
            palette = sampled ?? .fallback
        }
    }

    private func fallbackBackground(width: CGFloat, height: CGFloat) -> some View {
        LinearGradient(
            colors: [palette.start, palette.end],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: width, height: height)
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [palette.start, palette.end],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(palette.start.opacity(0.34))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: -120, y: -160)

            Circle()
                .fill(.black.opacity(0.22))
                .frame(width: 380, height: 380)
                .blur(radius: 110)
                .offset(x: 180, y: 240)
        }
    }

    private func metricChip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundColor(primaryHeaderColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(chipFillColor, in: Capsule())
    }

    private var heroIcon: some View {
        Group {
            if let iconUrl = item.iconUrl, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                    default:
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.white.opacity(0.12))
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.12))
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
    }

    private var detailCategories: [String] {
        guard let detail = projectDetail else { return [] }
        return detail.categories
    }

    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var primaryHeaderColor: Color {
        palette.isLight ? .black : .white
    }

    private var secondaryHeaderColor: Color {
        primaryHeaderColor.opacity(palette.isLight ? 0.7 : 0.8)
    }

    private var chipFillColor: Color {
        palette.isLight ? .black.opacity(0.08) : .white.opacity(0.12)
    }

    private var buttonFillColor: Color {
        .white
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

private struct InstallSheetData: Identifiable {
    let id = UUID()
    let project: ModrinthProject
    let detail: ModrinthProjectDetail
    let compatibleGames: [GameVersionInfo]
}

private struct ExploreDetailPalette {
    let start: Color
    let end: Color

    static let fallback = ExploreDetailPalette(
        start: Color(hue: 0.55, saturation: 0.55, brightness: 0.76),
        end: Color(hue: 0.55, saturation: 0.7, brightness: 0.42)
    )

    var isLight: Bool {
        start.isLight && end.isLight
    }
}

private enum ExploreDetailPaletteSampler {
    static func palette(from iconURL: URL?) async -> ExploreDetailPalette? {
        guard let iconURL else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: iconURL)
            guard let image = NSImage(data: data), let dominant = dominantColor(in: image) else {
                return nil
            }

            let start = dominant.withAlphaComponent(0.98)
            let end = dominant.darker(by: 0.55).withAlphaComponent(1)
            return ExploreDetailPalette(start: Color(nsColor: start), end: Color(nsColor: end))
        } catch {
            return nil
        }
    }

    private static func dominantColor(in image: NSImage) -> NSColor? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let sampleWidth = 64
        let sampleHeight = max(1, Int(round(CGFloat(cgImage.height) * CGFloat(sampleWidth) / CGFloat(cgImage.width))))
        let bytesPerRow = sampleWidth * 4
        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let drewImage = pixels.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: sampleWidth,
                    height: sampleHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }

            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
            return true
        }

        guard drewImage else { return nil }

        var buckets: [UInt32: (score: Double, count: Int)] = [:]

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = pixels[index]
            let green = pixels[index + 1]
            let blue = pixels[index + 2]
            let alpha = pixels[index + 3]

            guard alpha > 24 else { continue }

            let maxChannel = max(red, green, blue)
            let minChannel = min(red, green, blue)
            let brightness = Double(maxChannel) / 255.0
            let chroma = Double(maxChannel - minChannel) / 255.0

            guard brightness > 0.05 else { continue }
            guard !(brightness > 0.92 && chroma < 0.08) else { continue }

            let key = (UInt32(red >> 3) << 10) | (UInt32(green >> 3) << 5) | UInt32(blue >> 3)
            let weight = 1.0 + chroma

            if var bucket = buckets[key] {
                bucket.score += weight
                bucket.count += 1
                buckets[key] = bucket
            } else {
                buckets[key] = (score: weight, count: 1)
            }
        }

        guard let dominantBucket = buckets.max(by: { $0.value.score < $1.value.score }) else {
            return nil
        }

        let redBucket = CGFloat((dominantBucket.key >> 10) & 0x1F)
        let greenBucket = CGFloat((dominantBucket.key >> 5) & 0x1F)
        let blueBucket = CGFloat(dominantBucket.key & 0x1F)

        return NSColor(
            calibratedRed: (redBucket * 8 + 4) / 255.0,
            green: (greenBucket * 8 + 4) / 255.0,
            blue: (blueBucket * 8 + 4) / 255.0,
            alpha: 1
        )
    }
}

private extension NSColor {
    func darker(by amount: CGFloat) -> NSColor {
        guard let rgbColor = usingColorSpace(.deviceRGB) else { return self }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return NSColor(
            calibratedHue: hue,
            saturation: min(max(saturation, 0.18), 1),
            brightness: min(max(brightness * (1 - amount), 0.08), 1),
            alpha: alpha
        )
    }
}

private extension Color {
    var isLight: Bool {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            return false
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return brightness > 0.62
    }
}
