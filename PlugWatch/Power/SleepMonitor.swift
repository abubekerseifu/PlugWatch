import AppKit
import Foundation

/// Observes system sleep/wake so unplugged accrual pauses during sleep.
final class SleepMonitor {
    var onWillSleep: (() -> Void)?
    var onDidWake: (() -> Void)?

    private var willSleepObserver: NSObjectProtocol?
    private var didWakeObserver: NSObjectProtocol?

    func start() {
        stop()
        let workspace = NSWorkspace.shared.notificationCenter

        willSleepObserver = workspace.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onWillSleep?()
        }

        didWakeObserver = workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onDidWake?()
        }
    }

    func stop() {
        let workspace = NSWorkspace.shared.notificationCenter
        if let willSleepObserver {
            workspace.removeObserver(willSleepObserver)
        }
        if let didWakeObserver {
            workspace.removeObserver(didWakeObserver)
        }
        willSleepObserver = nil
        didWakeObserver = nil
    }

    deinit {
        stop()
    }
}
