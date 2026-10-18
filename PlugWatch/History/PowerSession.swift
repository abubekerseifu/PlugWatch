import Foundation

struct PowerSession: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: PowerSourceKind
    let startedAt: Date
    var endedAt: Date?
    /// Awake time only (excludes system sleep).
    var awakeDuration: TimeInterval

    var isOpen: Bool { endedAt == nil }

    init(
        id: UUID = UUID(),
        kind: PowerSourceKind,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        awakeDuration: TimeInterval = 0
    ) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.awakeDuration = awakeDuration
    }
}

struct PowerHistoryDocument: Codable, Equatable, Sendable {
    var sessions: [PowerSession]

    static let empty = PowerHistoryDocument(sessions: [])
}

struct PowerUsageSummary: Equatable, Sendable {
    var batteryAwake: TimeInterval
    var acAwake: TimeInterval

    var totalAwake: TimeInterval { batteryAwake + acAwake }

    var batteryPercent: Double {
        guard totalAwake > 0 else { return 0 }
        return (batteryAwake / totalAwake) * 100
    }

    var acPercent: Double {
        guard totalAwake > 0 else { return 0 }
        return (acAwake / totalAwake) * 100
    }
}
