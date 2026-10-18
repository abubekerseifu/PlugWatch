import Foundation

/// Tracks awake unplugged time with one-shot deadline timers (no polling ticks).
final class BatteryHabitController {
    private let queue = DispatchQueue(label: "com.plugwatch.habit")
    private var timer: DispatchSourceTimer?

    private(set) var state: HabitState = .pluggedIn
    private(set) var configuration: HabitConfiguration

    /// Awake time already accumulated in the current unplug cycle (excludes sleep).
    private var accumulatedAwake: TimeInterval = 0
    /// Start of the current awake tracking segment, if running.
    private var segmentStartedAt: Date?
    /// Remaining snooze when sleep interrupts a snooze countdown.
    private var snoozeRemaining: TimeInterval = 0
    private var snoozeSegmentStartedAt: Date?
    private var isSleeping = false

    var onStateChange: ((HabitState) -> Void)?
    var onAlert: (() -> Void)?

    init(configuration: HabitConfiguration = .default) {
        self.configuration = configuration
    }

    func updateConfiguration(_ configuration: HabitConfiguration) {
        queue.async { [weak self] in
            guard let self else { return }
            self.configuration = configuration
            if self.state == .unpluggedTracking, !self.isSleeping {
                self.rescheduleThresholdTimerLocked()
            }
        }
    }

    // MARK: - External events

    func handlePower(_ kind: PowerSourceKind) {
        queue.async { [weak self] in
            self?.handlePowerLocked(kind)
        }
    }

    func handleSleep() {
        queue.async { [weak self] in
            self?.handleSleepLocked()
        }
    }

    func handleWake(stillOnBattery: Bool) {
        queue.async { [weak self] in
            self?.handleWakeLocked(stillOnBattery: stillOnBattery)
        }
    }

    func dismiss() {
        queue.async { [weak self] in
            guard let self else { return }
            self.cancelTimerLocked()
            self.segmentStartedAt = nil
            self.snoozeSegmentStartedAt = nil
            self.snoozeRemaining = 0
            self.setStateLocked(.dismissedThisCycle)
        }
    }

    func snooze(interval: TimeInterval? = nil) {
        queue.async { [weak self] in
            guard let self else { return }
            let duration = interval ?? self.configuration.snoozeInterval
            self.cancelTimerLocked()
            self.segmentStartedAt = nil
            self.snoozeRemaining = duration
            self.snoozeSegmentStartedAt = Date()
            self.setStateLocked(.snoozed)
            if !self.isSleeping {
                self.scheduleLocked(after: duration) { [weak self] in
                    self?.snoozeElapsedLocked()
                }
            }
        }
    }

    /// Manual pause equivalent to dismiss for this unplug cycle.
    func pauseUntilPlug() {
        dismiss()
    }

    /// Awake unplugged duration for UI (safe to call from main).
    func currentAwakeUnpluggedDuration(at date: Date = Date()) -> TimeInterval {
        queue.sync {
            switch state {
            case .pluggedIn, .dismissedThisCycle:
                return 0
            case .unpluggedTracking, .alertPending, .snoozed:
                var total = accumulatedAwake
                if let started = segmentStartedAt, !isSleeping {
                    total += date.timeIntervalSince(started)
                }
                return max(0, total)
            }
        }
    }

    func snapshotState() -> HabitState {
        queue.sync { state }
    }

    // MARK: - Locked handlers

    private func handlePowerLocked(_ kind: PowerSourceKind) {
        if kind.isPluggedIn {
            resetToPluggedInLocked()
            return
        }

        guard kind.isOnBattery else { return }

        switch state {
        case .pluggedIn:
            accumulatedAwake = 0
            segmentStartedAt = isSleeping ? nil : Date()
            setStateLocked(.unpluggedTracking)
            if !isSleeping {
                rescheduleThresholdTimerLocked()
            }
        case .dismissedThisCycle, .unpluggedTracking, .alertPending, .snoozed:
            break
        }
    }

    private func handleSleepLocked() {
        guard !isSleeping else { return }
        isSleeping = true

        switch state {
        case .unpluggedTracking:
            if let started = segmentStartedAt {
                accumulatedAwake += Date().timeIntervalSince(started)
                segmentStartedAt = nil
            }
            cancelTimerLocked()
        case .snoozed:
            if let started = snoozeSegmentStartedAt {
                let elapsed = Date().timeIntervalSince(started)
                snoozeRemaining = max(0, snoozeRemaining - elapsed)
                snoozeSegmentStartedAt = nil
            }
            cancelTimerLocked()
        case .pluggedIn, .alertPending, .dismissedThisCycle:
            break
        }
    }

    private func handleWakeLocked(stillOnBattery: Bool) {
        isSleeping = false

        guard stillOnBattery else {
            resetToPluggedInLocked()
            return
        }

        switch state {
        case .unpluggedTracking:
            segmentStartedAt = Date()
            rescheduleThresholdTimerLocked()
        case .snoozed:
            if snoozeRemaining <= 0 {
                snoozeElapsedLocked()
            } else {
                snoozeSegmentStartedAt = Date()
                let remaining = snoozeRemaining
                scheduleLocked(after: remaining) { [weak self] in
                    self?.snoozeElapsedLocked()
                }
            }
        case .pluggedIn, .alertPending, .dismissedThisCycle:
            break
        }
    }

    private func thresholdReachedLocked() {
        guard state == .unpluggedTracking else { return }
        if let started = segmentStartedAt {
            accumulatedAwake += Date().timeIntervalSince(started)
            segmentStartedAt = nil
        }
        cancelTimerLocked()
        setStateLocked(.alertPending)
        DispatchQueue.main.async { [weak self] in
            self?.onAlert?()
        }
    }

    private func snoozeElapsedLocked() {
        guard state == .snoozed else { return }
        cancelTimerLocked()
        snoozeRemaining = 0
        snoozeSegmentStartedAt = nil
        setStateLocked(.alertPending)
        DispatchQueue.main.async { [weak self] in
            self?.onAlert?()
        }
    }

    private func resetToPluggedInLocked() {
        cancelTimerLocked()
        accumulatedAwake = 0
        segmentStartedAt = nil
        snoozeRemaining = 0
        snoozeSegmentStartedAt = nil
        setStateLocked(.pluggedIn)
    }

    private func rescheduleThresholdTimerLocked() {
        let remaining = max(0, configuration.alertThreshold - currentAccumulatedLocked())
        if remaining <= 0 {
            thresholdReachedLocked()
            return
        }
        scheduleLocked(after: remaining) { [weak self] in
            self?.thresholdReachedLocked()
        }
    }

    private func currentAccumulatedLocked(at date: Date = Date()) -> TimeInterval {
        var total = accumulatedAwake
        if let started = segmentStartedAt, !isSleeping {
            total += date.timeIntervalSince(started)
        }
        return total
    }

    private func scheduleLocked(after interval: TimeInterval, handler: @escaping () -> Void) {
        cancelTimerLocked()
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + interval, leeway: .seconds(2))
        source.setEventHandler(handler: handler)
        source.resume()
        timer = source
    }

    private func cancelTimerLocked() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    private func setStateLocked(_ newState: HabitState) {
        guard state != newState else { return }
        state = newState
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onStateChange?(newState)
        }
    }
}
