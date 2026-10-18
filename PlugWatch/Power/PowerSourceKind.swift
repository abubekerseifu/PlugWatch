import Foundation

enum PowerSourceKind: String, Equatable, Sendable, Codable {
    case ac
    case battery
    case unknown

    var isOnBattery: Bool { self == .battery }
    var isPluggedIn: Bool { self == .ac }

    var isTrackable: Bool { self == .ac || self == .battery }

    var displayName: String {
        switch self {
        case .ac: return "AC Power"
        case .battery: return "Battery"
        case .unknown: return "Unknown"
        }
    }

    var csvValue: String {
        switch self {
        case .ac: return "ac"
        case .battery: return "battery"
        case .unknown: return "unknown"
        }
    }
}
