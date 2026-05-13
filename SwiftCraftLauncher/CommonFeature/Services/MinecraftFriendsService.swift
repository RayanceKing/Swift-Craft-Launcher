import Foundation

final class MinecraftFriendsService: @unchecked Sendable {
    static let shared = MinecraftFriendsService()

    private let jsonDecoder: JSONDecoder
    fileprivate let jsonEncoder: JSONEncoder
    private let coordinator = MinecraftFriendsCoordinator()

    init() {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        self.jsonDecoder = decoder
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        self.jsonEncoder = encoder
    }

    // MARK: - Public

    func fetchFriendsAndPresence(accessToken: String, forceRefresh: Bool) async throws -> MinecraftFriendsUIData {
        try await coordinator.fetchBundle(
            accessToken: accessToken,
            forceRefresh: forceRefresh,
            service: self
        )
    }

    func performFriendAction(accessToken: String, request: MinecraftFriendActionRequest) async throws -> MinecraftFriendsListResponse {
        let urlRequest = Self.authenticatedJSONRequest(
            url: URLConfig.API.Authentication.minecraftFriends,
            method: "PUT",
            accessToken: accessToken,
            body: try jsonEncoder.encode(request)
        )
        let (data, http) = try await APIClient.performRequestWithResponse(request: urlRequest)
        try Self.throwIfFailedResponse(http: http, data: data)

        let lists = try jsonDecoder.decode(MinecraftFriendsListResponse.self, from: data)
        await coordinator.applyPutFriendsSuccess(lists: lists)
        return lists
    }

    func updateFriendSettings(
        accessToken: String,
        enableFriendlist: Bool,
        enableFriendInvites: Bool
    ) async throws {
        let body = MinecraftUserAttributesRequest(
            friendsPreferences: MinecraftFriendsPreferencesPayload(
                friends: enableFriendlist ? .enabled : .disabled,
                acceptInvites: enableFriendInvites ? .enabled : .disabled
            )
        )
        let urlRequest = Self.authenticatedJSONRequest(
            url: URLConfig.API.Authentication.minecraftPlayerAttributes,
            method: "POST",
            accessToken: accessToken,
            body: try jsonEncoder.encode(body)
        )
        let (data, http) = try await APIClient.performRequestWithResponse(request: urlRequest)
        try Self.throwIfFailedResponse(http: http, data: data)
    }

    // MARK: - Package-private HTTP（由 Coordinator 调用）

    fileprivate func executeGetFriends(accessToken: String, ifNoneMatch: String?) async throws -> (
        lists: MinecraftFriendsListResponse,
        status: Int,
        etag: String?
    ) {
        let urlRequest = Self.authenticatedJSONRequest(
            url: URLConfig.API.Authentication.minecraftFriends,
            method: "GET",
            accessToken: accessToken,
            ifNoneMatch: ifNoneMatch
        )
        let (data, http) = try await APIClient.performRequestWithResponse(request: urlRequest)
        let code = http.statusCode
        switch code {
        case 200:
            let lists = try jsonDecoder.decode(MinecraftFriendsListResponse.self, from: data)
            return (lists, code, Self.etag(from: http))
        case 304:
            return (.empty, code, Self.etag(from: http))
        default:
            try Self.throwIfFailedResponse(http: http, data: data)
            throw GlobalError.network(
                chineseMessage: "获取好友列表失败: HTTP \(code)",
                i18nKey: "error.network.api_request_failed",
                level: .notification
            )
        }
    }

    fileprivate func executePostPresence(accessToken: String, ifNoneMatch: String?, body: Data) async throws -> (
        presence: MinecraftPresenceResponse,
        status: Int,
        etag: String?
    ) {
        let urlRequest = Self.authenticatedJSONRequest(
            url: URLConfig.API.Authentication.minecraftPresence,
            method: "POST",
            accessToken: accessToken,
            body: body,
            ifNoneMatch: ifNoneMatch
        )
        let (data, http) = try await APIClient.performRequestWithResponse(request: urlRequest)
        let code = http.statusCode
        switch code {
        case 200:
            let pr = try jsonDecoder.decode(MinecraftPresenceResponse.self, from: data)
            return (pr, code, Self.etag(from: http))
        case 304:
            return (MinecraftPresenceResponse(presence: []), code, Self.etag(from: http))
        default:
            try Self.throwIfFailedResponse(http: http, data: data)
            throw GlobalError.network(
                chineseMessage: "获取在线状态失败: HTTP \(code)",
                i18nKey: "error.network.api_request_failed",
                level: .notification
            )
        }
    }

    private static func authenticatedJSONRequest(
        url: URL,
        method: String,
        accessToken: String,
        body: Data? = nil,
        ifNoneMatch: String? = nil
    ) -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        r.setValue(APIClient.MimeType.json, forHTTPHeaderField: APIClient.Header.accept)
        if let body {
            r.setValue(APIClient.MimeType.json, forHTTPHeaderField: APIClient.Header.contentType)
            r.httpBody = body
        }
        if let ifNoneMatch, !ifNoneMatch.isEmpty {
            r.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match")
        }
        return r
    }

    private static func etag(from response: HTTPURLResponse) -> String? {
        if let v = response.value(forHTTPHeaderField: "ETag") { return v }
        return response.value(forHTTPHeaderField: "Etag")
    }

    private static func throwIfFailedResponse(http: HTTPURLResponse, data: Data) throws {
        let code = http.statusCode
        if (200 ... 299).contains(code) { return }

        switch code {
        case 401:
            throw GlobalError.authentication(
                chineseMessage: "Minecraft 访问令牌无效或已过期，请重新登录",
                i18nKey: "error.authentication.token_expired",
                level: .popup
            )
        case 403:
            throw GlobalError.authentication(
                chineseMessage: "没有权限访问好友服务 (403)",
                i18nKey: "error.network.api_request_failed",
                level: .notification
            )
        case 400:
            let detail = parseFriendsErrorDetail(from: data)
            throw GlobalError.validation(
                chineseMessage: detail?.chineseMessage ?? "无效的请求参数",
                i18nKey: detail?.i18nKey ?? "error.validation.invalid_request",
                level: .notification
            )
        case 429:
            throw GlobalError.network(
                chineseMessage: "请求过于频繁，请稍后再试",
                i18nKey: "error.network.rate_limited",
                level: .notification
            )
        case 500 ... 599:
            throw GlobalError.network(
                chineseMessage: "好友服务暂时不可用 (HTTP \(code))",
                i18nKey: "error.network.api_request_failed",
                level: .notification
            )
        default:
            let snippet = String(data: data.prefix(256), encoding: .utf8) ?? ""
            throw GlobalError.network(
                chineseMessage: "好友接口错误 HTTP \(code): \(snippet)",
                i18nKey: "error.network.api_request_failed",
                level: .notification
            )
        }
    }

    private static func parseFriendsErrorDetail(from data: Data) -> (chineseMessage: String, i18nKey: String)? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let details = obj["details"] as? [String: Any] ?? obj["Details"] as? [String: Any]
        let status = details?["status"] as? String ?? details?["Status"] as? String
        switch status {
        case "UNKNOWN_PROFILE":
            return ("找不到该玩家名称或档案", "minecraft.friends.error.unknown_profile")
        case "CANNOT_ADD_SELF":
            return ("不能添加自己为好友", "minecraft.friends.error.cannot_add_self")
        case "DUPLICATED_PROFILES":
            return ("重复的玩家档案", "minecraft.friends.error.duplicated_profiles")
        default:
            return nil
        }
    }
}

// MARK: - Coordinator

private actor MinecraftFriendsCoordinator {
    private static let friendsCooldown: TimeInterval = 10

    private var friendsETag: String?
    private var presenceETag: String?
    private var lastLists: MinecraftFriendsListResponse?
    private var lastPresenceById: [String: MinecraftPresenceStatusDTO] = [:]
    private var lastFriendsFetchAt: Date?
    private var inflight: Task<MinecraftFriendsUIData, Error>?

    func applyPutFriendsSuccess(lists: MinecraftFriendsListResponse) {
        lastLists = lists
        friendsETag = nil
    }

    func fetchBundle(accessToken: String, forceRefresh: Bool, service: MinecraftFriendsService) async throws -> MinecraftFriendsUIData {
        if let inflight {
            return try await inflight.value
        }
        let task = Task {
            try await self.fetchBundleInner(accessToken: accessToken, forceRefresh: forceRefresh, service: service)
        }
        inflight = task
        let value = try await task.value
        inflight = nil
        return value
    }

    private func fetchBundleInner(accessToken: String, forceRefresh: Bool, service: MinecraftFriendsService) async throws -> MinecraftFriendsUIData {
        let now = Date()
        let lists: MinecraftFriendsListResponse

        if !forceRefresh,
           let at = lastFriendsFetchAt,
           now.timeIntervalSince(at) < Self.friendsCooldown,
           let cached = lastLists {
            lists = cached
        } else {
            let getResult = try await service.executeGetFriends(accessToken: accessToken, ifNoneMatch: friendsETag)
            if getResult.status == 304 {
                lists = lastLists ?? .empty
            } else {
                lists = getResult.lists
                lastLists = lists
                if let e = getResult.etag, !e.isEmpty {
                    friendsETag = e
                }
            }
            lastFriendsFetchAt = Date()
        }

        let presenceBody = try service.jsonEncoder.encode(MinecraftPresenceRequest(status: .offline, joinInfo: nil))
        let pres = try await service.executePostPresence(accessToken: accessToken, ifNoneMatch: presenceETag, body: presenceBody)

        if pres.status == 200 {
            var map: [String: MinecraftPresenceStatusDTO] = [:]
            for row in pres.presence.presence {
                map[row.profileId.normalized] = row
            }
            lastPresenceById = map
            if let e = pres.etag, !e.isEmpty {
                presenceETag = e
            }
        }

        return MinecraftFriendsUIData(lists: lists, presenceByProfileId: lastPresenceById)
    }
}
