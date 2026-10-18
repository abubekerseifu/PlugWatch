import Foundation

struct HabitConfiguration: Equatable, Sendable {
    /// Awake unplugged time before alerting.
    var alertThreshold: TimeInterval
    /// Postpone duration after Snooze.
    var snoozeInterval: TimeInterval
    /// Show floating NSPanel in addition to system notifications.
    var showFloatingAlert: Bool

    static let `default` = HabitConfiguration(
        alertThreshold: 15 * 60,
        snoozeInterval: 30 * 60,
        showFloatingAlert: true
    )

    #if DEBUG
    /// Short thresholds for local testing without waiting 15 minutes.
    static let debug = HabitConfiguration(
        alertThreshold: 30,
        snoozeInterval: 60,
        showFloatingAlert: true
    )
    #endif
}
