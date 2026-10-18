import Foundation

enum HabitState: Equatable, Sendable {
    case pluggedIn
    case unpluggedTracking
    case alertPending
    case snoozed
    case dismissedThisCycle

    var displayName: String {
        switch self {
        case .pluggedIn: return "Plugged In"
        case .unpluggedTracking: return "Tracking Unplugged Time"
        case .alertPending: return "Alert Pending"
        case .snoozed: return "Snoozed"
        case .dismissedThisCycle: return "Dismissed (this cycle)"
        }
    }
}
