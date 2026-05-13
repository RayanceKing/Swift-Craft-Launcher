import SwiftUI

struct ModpackHeroCarousel: View {
    let items: [ModpackHeroItem]
    @Binding var currentIndex: Int

    @State private var timer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()
    @State private var isHovering = false
    @State private var loadedImages: [String: Image] = [:]

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width
            let cardHeight = geometry.size.height

            ZStack {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                heroCard(for: item, width: cardWidth, height: cardHeight)
                                    .frame(width: cardWidth, height: cardHeight)
                                    .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .onReceive(timer) { _ in
                        guard !isHovering, items.count > 1 else { return }
                        let next = (currentIndex + 1) % items.count
                        withAnimation(.easeInOut(duration: 0.7)) {
                            proxy.scrollTo(next, anchor: .center)
                        }
                        currentIndex = next
                    }
                    .onChange(of: currentIndex) { _, newValue in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }

                // Always-visible navigation arrows
                if items.count > 1 {
                    HStack {
                        prevButton
                        Spacer()
                        nextButton
                    }
                }

                // Page dots
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<items.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: index == currentIndex ? 20 : 6, height: 6)
                                .animation(.easeInOut(duration: 0.3), value: currentIndex)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .onHover { hovering in isHovering = hovering }
    }

    // MARK: - Arrows

    private var prevButton: some View {
        Button {
            currentIndex = (currentIndex - 1 + items.count) % items.count
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.black.opacity(0.35)))
        }
        .buttonStyle(.plain)
        .padding(.leading, 12)
    }

    private var nextButton: some View {
        Button {
            currentIndex = (currentIndex + 1) % items.count
        } label: {
            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.black.opacity(0.35)))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 12)
    }

    // MARK: - Card

    @ViewBuilder
    private func heroCard(for item: ModpackHeroItem, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Blur-sampled color background from image
            blurredBackground(for: item, width: width, height: height)

            // Gradient over bottom for text readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: 10) {
                if let iconUrl = item.iconUrl, let url = URL(string: iconUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                        default:
                            EmptyView()
                        }
                    }
                }

                Text(item.title)
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(item.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(3)

                HStack(spacing: 20) {
                    Label(downloadCountString(item.downloads), systemImage: "arrow.down.to.line")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                    Label(item.author, systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 56)
        }
    }

    // MARK: - Blurred Background

    @ViewBuilder
    private func blurredBackground(for item: ModpackHeroItem, width: CGFloat, height: CGFloat) -> some View {
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
                        .overlay(Color.black.opacity(0.35))
                case .failure, .empty:
                    fallbackColor(item.fallbackColor, width: width, height: height)
                @unknown default:
                    fallbackColor(item.fallbackColor, width: width, height: height)
                }
            }
        } else {
            fallbackColor(item.fallbackColor, width: width, height: height)
        }
    }

    private func fallbackColor(_ color: Color, width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
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
