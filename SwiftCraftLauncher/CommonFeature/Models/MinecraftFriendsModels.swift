import Foundation

struct MinecraftFriendProfileDTO: Codable, Equatable, Sendable {
    let profileId: FlexibleUUIDString
    let name: String
}

struct MinecraftFriendsListResponse: Codable, Equatable, Sendable {
    var friends: [MinecraftFriendProfileDTO]
    var incomingRequests: [MinecraftFriendProfileDTO]
    var outgoingRequests: [MinecraftFriendProfileDTO]

    static let empty = Self(
        friends: [],
        incomingRequests: [],
        outgoingRequests: []
    )

    private enum CodingKeys: String, CodingKey {
        case friends
        case incomingRequests
        case outgoingRequests
    }

    init(friends: [MinecraftFriendProfileDTO], incomingRequests: [MinecraftFriendProfileDTO], outgoingRequests: [MinecraftFriendProfileDTO]) {
        self.friends = friends
        self.incomingRequests = incomingRequests
        self.outgoingRequests = outgoingRequests
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        friends = try c.decodeIfPresent([MinecraftFriendProfileDTO].self, forKey: .friends) ?? []
        incomingRequests = try c.decodeIfPresent([MinecraftFriendProfileDTO].self, forKey: .incomingRequests) ?? []
        outgoingRequests = try c.decodeIfPresent([MinecraftFriendProfileDTO].self, forKey: .outgoingRequests) ?? []
    }
}

// MARK: - Friend actions

struct MinecraftFriendActionRequest: Encodable {
    var name: String?
    var profileId: String?
    let updateType: String

    init(name: String? = nil, profileId: String? = nil, updateType: MinecraftFriendUpdateType) {
        self.name = name
        self.profileId = profileId
        self.updateType = updateType.rawValue
    }
}

enum MinecraftFriendUpdateType: String, Sendable {
    case add = "ADD"
    case remove = "REMOVE"
}

// MARK: - Player attributes

struct MinecraftUserAttributesRequest: Encodable {
    let friendsPreferences: MinecraftFriendsPreferencesPayload
}

struct MinecraftFriendsPreferencesPayload: Codable, Equatable, Sendable {
    let friends: MinecraftToggleWireValue
    let acceptInvites: MinecraftToggleWireValue
}

enum MinecraftToggleWireValue: String, Codable, Sendable {
    case enabled = "ENABLED"
    case disabled = "DISABLED"

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try c.decode(String.self)).uppercased()
        self = Self(rawValue: raw) ?? .disabled
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

// MARK: - Presence

struct MinecraftPresenceRequest: Encodable {
    let status: String
    var joinInfo: MinecraftJoinInfoUpdate?

    init(status: MinecraftPresenceWireStatus, joinInfo: MinecraftJoinInfoUpdate? = nil) {
        self.status = status.rawValue
        self.joinInfo = joinInfo
    }
}

struct MinecraftJoinInfoUpdate: Encodable, Sendable {
    let value: String
    var invites: [String]?
}

struct MinecraftPresenceResponse: Codable, Equatable, Sendable {
    var presence: [MinecraftPresenceStatusDTO]

    init(presence: [MinecraftPresenceStatusDTO]) {
        self.presence = presence
    }

    private enum CodingKeys: String, CodingKey {
        case presence
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        presence = try c.decodeIfPresent([MinecraftPresenceStatusDTO].self, forKey: .presence) ?? []
    }
}

struct MinecraftPresenceStatusDTO: Codable, Equatable, Sendable {
    let profileId: FlexibleUUIDString
    let pmid: String?
    let status: MinecraftPresenceWireStatus
    var joinInfo: MinecraftPresenceJoinInfoDTO?
    var lastUpdated: String?
}

struct MinecraftPresenceJoinInfoDTO: Codable, Equatable, Sendable {
    let value: String?
    let invited: Bool

    private enum CodingKeys: String, CodingKey {
        case value
        case invited
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = try c.decodeIfPresent(String.self, forKey: .value)
        invited = try c.decodeIfPresent(Bool.self, forKey: .invited) ?? false
    }
}

enum MinecraftPresenceWireStatus: String, Codable, Sendable, CaseIterable {
    case online = "ONLINE"
    case playingOffline = "PLAYING_OFFLINE"
    case playingRealms = "PLAYING_REALMS"
    case playingServer = "PLAYING_SERVER"
    case playingHostedServer = "PLAYING_HOSTED_SERVER"
    case offline = "OFFLINE"

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        self = Self(rawValue: s) ?? .offline
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

// MARK: - UI bundle

struct MinecraftFriendsUIData: Equatable, Sendable {
    var lists: MinecraftFriendsListResponse
    var presenceByProfileId: [String: MinecraftPresenceStatusDTO]

    static let empty = Self(lists: MinecraftFriendsListResponse.empty, presenceByProfileId: [:])
}

// MARK: - UUID string decoding

struct FlexibleUUIDString: Codable, Equatable, Hashable, Sendable {
    let normalized: String

    var dashedLowercase: String {
        guard normalized.count == 32 else { return normalized }
        let s = normalized
        let i = s.index(s.startIndex, offsetBy: 8)
        let j = s.index(i, offsetBy: 4)
        let k = s.index(j, offsetBy: 4)
        let l = s.index(k, offsetBy: 4)
        return "\(s[..<i])-\(s[i..<j])-\(s[j..<k])-\(s[k..<l])-\(s[l...])"
    }

    init(normalized: String) {
        self.normalized = Self.canonicalNoHyphens(normalized)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Empty profileId")
        }
        self.normalized = Self.canonicalNoHyphens(raw)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(normalized)
    }

    private static func canonicalNoHyphens(_ s: String) -> String {
        if let u = UUID(uuidString: s) {
            return u.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }
        let cleaned = s.replacingOccurrences(of: "-", with: "").lowercased()
        if cleaned.count == 32, cleaned.allSatisfy({ $0.isHexDigit }) {
            return cleaned
        }
        return cleaned
    }
}
