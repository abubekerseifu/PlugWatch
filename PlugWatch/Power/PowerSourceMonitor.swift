import Foundation
import IOKit.ps

/// Event-driven AC/battery observer via IOKit. No polling.
final class PowerSourceMonitor {
    private var runLoopSource: CFRunLoopSource?
    var onChange: ((PowerSourceKind) -> Void)?

    func start() {
        stop()

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let unmanaged = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.emit()
        }, context) else {
            return
        }

        let source = unmanaged.takeRetainedValue()
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        emit()
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        runLoopSource = nil
    }

    func currentKind() -> PowerSourceKind {
        Self.readCurrentKind()
    }

    private func emit() {
        onChange?(Self.readCurrentKind())
    }

    static func readCurrentKind() -> PowerSourceKind {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return .unknown
        }

        let type = IOPSGetProvidingPowerSourceType(blob).takeUnretainedValue() as String
        switch type {
        case kIOPSACPowerValue:
            return .ac
        case kIOPSBatteryPowerValue:
            return .battery
        default:
            return .unknown
        }
    }

    deinit {
        stop()
    }
}
