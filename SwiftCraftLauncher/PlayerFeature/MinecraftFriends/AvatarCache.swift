import Foundation
import AppKit
import CryptoKit

enum AvatarCache {
    private static let cacheFolderName = "swift-craft-launcher-avatar"
    private static let fileManager = FileManager.default
    private static var lastCleanup: Date?

    /// Return a cached processed avatar PNG URL for given avatar identifier (remote URL or local asset name).
    static func cachedAvatarURL(for avatar: String, size: CGSize = CGSize(width: 128, height: 128), cornerRadius: CGFloat = 20) async -> URL? {
        let cacheDir = cacheDirectory()
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        // periodic cleanup once per day
        if let last = lastCleanup {
            if Date().timeIntervalSince(last) > 60 * 60 * 24 {
                lastCleanup = Date()
                Task.detached {
                    cleanupExpiredFiles(olderThanDays: 7)
                }
            }
        } else {
            lastCleanup = Date()
            Task.detached { cleanupExpiredFiles(olderThanDays: 7) }
        }

        let key = sha256Hex(avatar)
        let filename = "avatar_\(key)_\(Int(size.width))x\(Int(size.height)).png"
        let fileURL = cacheDir.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        // produce image
        if avatar.hasPrefix("http://") || avatar.hasPrefix("https://") {
            guard let url = URL(string: avatar) else { return nil }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = NSImage(data: data) else { return nil }
                if let png = processImage(image: image, size: size, cornerRadius: cornerRadius) {
                    try png.write(to: fileURL)
                    return fileURL
                }
            } catch {
                Logger.shared.warning("AvatarCache: 下载头像失败: \(error.localizedDescription)")
                return nil
            }
        } else {
            if let image = NSImage(named: NSImage.Name(avatar)) {
                if let png = processImage(image: image, size: size, cornerRadius: cornerRadius) {
                    try? png.write(to: fileURL)
                    return fileURL
                }
            }
        }

        return nil
    }

    static func cleanupExpiredFiles(olderThanDays days: Int = 7) {
        let cacheDir = cacheDirectory()
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.contentModificationDateKey], options: []) else { return }
        let expiration = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        for f in files {
            if let attrs = try? f.resourceValues(forKeys: [.contentModificationDateKey]), let mod = attrs.contentModificationDate {
                if mod < expiration {
                    try? fileManager.removeItem(at: f)
                }
            }
        }
    }

    // MARK: - Helpers
    private static func cacheDirectory() -> URL {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        return base.appendingPathComponent(cacheFolderName, isDirectory: true)
    }

    private static func sha256Hex(_ s: String) -> String {
        let data = Data(s.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func processImage(image: NSImage, size: CGSize, cornerRadius: CGFloat) -> Data? {
        let targetRect = CGRect(origin: .zero, size: size)
        let img = NSImage(size: size)
        img.lockFocus()
        defer { img.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high

        let path = NSBezierPath(roundedRect: targetRect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.addClip()

        // Draw image preserving aspect fill
        let imageSize = image.size
        let scale = max(size.width / imageSize.width, size.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = (size.width - w) / 2.0
        let y = (size.height - h) / 2.0
        image.draw(in: CGRect(x: x, y: y, width: w, height: h), from: .zero, operation: .sourceOver, fraction: 1.0)

        guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        let png = rep.representation(using: .png, properties: [:])
        return png
    }
}
