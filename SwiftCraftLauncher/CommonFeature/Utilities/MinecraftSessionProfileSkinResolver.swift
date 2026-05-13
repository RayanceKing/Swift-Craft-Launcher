import Foundation

enum MinecraftSessionProfileSkinResolver {
    private static let hitCache = NSCache<NSString, NSString>()

    static func resolveTextureURLString(uuidNoHyphens: String) async -> String? {
        let trimmed = uuidNoHyphens.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count == 32, trimmed.allSatisfy(\.isHexDigit) else { return nil }

        let cacheKey = trimmed as NSString
        if let cached = hitCache.object(forKey: cacheKey) {
            let s = cached as String
            return s.isEmpty ? nil : s
        }

        let url = URLConfig.API.Minecraft.mojangSessionProfileBase.appendingPathComponent(trimmed)

        do {
            let data = try await APIClient.get(url: url, headers: APIClient.DefaultHeaders.acceptJSON)
            guard let urlString = skinTextureURL(fromSessionProfileJSON: data), !urlString.isEmpty else {
                return nil
            }
            hitCache.setObject(urlString as NSString, forKey: cacheKey)
            return urlString
        } catch {
            Logger.shared.debug("[SessionSkin] fetch failed uuid=\(trimmed.prefix(8))… \(error.localizedDescription)")
            return nil
        }
    }

    static func skinTextureURL(fromSessionProfileJSON data: Data) -> String? {
        struct Prop: Codable { let name: String; let value: String }
        struct SessionProfile: Codable { let properties: [Prop]? }
        struct TexturesPayload: Codable { let textures: TexturesInner? }
        struct TexturesInner: Codable { let SKIN: SkinEntry? }
        struct SkinEntry: Codable { let url: String }

        guard let profile = try? JSONDecoder().decode(SessionProfile.self, from: data),
              let prop = profile.properties?.first(where: { $0.name == "textures" }),
              let decoded = Data(base64Encoded: prop.value),
              let payload = try? JSONDecoder().decode(TexturesPayload.self, from: decoded),
              let urlStr = payload.textures?.SKIN?.url
        else {
            return nil
        }
        return urlStr.httpToHttps()
    }
}
