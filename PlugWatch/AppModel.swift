import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject, NotificationActionHandling {
    @Published private(set) var powerKind: PowerSourceKind = .unknown
    @Published private(set) var habitState: HabitState = .pluggedIn
    @Published var showFloatingAlert: Bool {
        didSet {
            guard isConfigured else { return }
            UserDefaults.standard.set(showFloatingAlert, forKey: Keys.showFloatingAlert)
            applyConfiguration()
        }
    }
    @Published var alertThresholdMinutes: Double {
        didSet {
            guard isConfigured else { return }
            UserDefaults.standard.set(alertThresholdMinutes, forKey: Keys.alertThresholdMinutes)
            applyConfiguration()
        }
    }
    @Published var snoozeMinutes: Double {
        didSet {
            guard isConfigured else { return }
            UserDefaults.standard.set(snoozeMinutes, forKey: Keys.snoozeMinutes)
            applyConfiguration()
        }
    }
    @Published var launchAtLogin: Bool = false

    private var isConfigured = false
    private let powerMonitor = PowerSourceMonitor()
    private let sleepMonitor = SleepMonitor()
    private let habitController: BatteryHabitController
    private let notifications = NotificationService()
    private let floatingPanel = FloatingAlertPanelController()
    private let settingsWindow = SettingsWindowController()
    private let historyWindow = HistoryWindowController()
    let usageRecorder = PowerUsageRecorder()

    private var recorderCancellable: AnyCancellable?

    var menuBarSymbol: String {
        switch powerKind {
        case .ac: return "bolt.fill"
        case .battery: return "battery.50"
        case .unknown: return "questionmark.circle"
        }
    }

    init() {
        let storedThreshold = UserDefaults.standard.object(forKey: Keys.alertThresholdMinutes) as? Double
        let storedSnooze = UserDefaults.standard.object(forKey: Keys.snoozeMinutes) as? Double
        let storedPanel = UserDefaults.standard.object(forKey: Keys.showFloatingAlert) as? Bool

        #if DEBUG
        let defaultThreshold = 0.5 // 30 seconds for debug builds
        #else
        let defaultThreshold = 15.0
        #endif

        let threshold = storedThreshold ?? defaultThreshold
        let snooze = storedSnooze ?? 30.0
        let floating = storedPanel ?? true

        alertThresholdMinutes = threshold
        snoozeMinutes = snooze
        showFloatingAlert = floating

        let config = HabitConfiguration(
            alertThreshold: threshold * 60,
            snoozeInterval: snooze * 60,
            showFloatingAlert: floating
        )
        habitController = BatteryHabitController(configuration: config)

        notifications.actionHandler = self
        notifications.configure()
        notifications.requestAuthorizationIfNeeded()

        floatingPanel.onDismiss = { [weak self] in self?.dismissAlert() }
        floatingPanel.onSnooze = { [weak self] in self?.snoozeAlert() }

        habitController.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.habitState = state
                if state == .pluggedIn {
                    self?.floatingPanel.close()
                    self?.notifications.removeDeliveredAlerts()
                }
            }
        }

        habitController.onAlert = { [weak self] in
            Task { @MainActor in
                self?.presentAlert()
            }
        }

        recorderCancellable = usageRecorder.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        refreshLaunchAtLogin()
        startMonitors()
        isConfigured = true
        UserDefaults.standard.set(threshold, forKey: Keys.alertThresholdMinutes)
        UserDefaults.standard.set(snooze, forKey: Keys.snoozeMinutes)
        UserDefaults.standard.set(floating, forKey: Keys.showFloatingAlert)
    }

    func awakeUnpluggedDurationText(at date: Date = Date()) -> String {
        let seconds = habitController.currentAwakeUnpluggedDuration(at: date)
        return Self.formatDuration(seconds)
    }

    func snoozeAlert() {
        floatingPanel.close()
        habitController.snooze()
    }

    func dismissAlert() {
        floatingPanel.close()
        habitController.dismiss()
    }

    func pauseUntilPlug() {
        floatingPanel.close()
        habitController.pauseUntilPlug()
    }

    func quit() {
        usageRecorder.finalizeForQuit()
        powerMonitor.stop()
        sleepMonitor.stop()
        NSApp.terminate(nil)
    }

    func openSettingsWindow() {
        settingsWindow.show(model: self)
    }

    func openHistoryWindow() {
        historyWindow.show(model: self)
    }

    func powerSessions(at date: Date = Date()) -> [PowerSession] {
        usageRecorder.sessionsIncludingLive(at: date)
    }

    func powerSummary(from start: Date?, to end: Date = Date()) -> PowerUsageSummary {
        usageRecorder.summary(from: start, to: end)
    }

    func liveAwakeDuration(for session: PowerSession, at date: Date = Date()) -> TimeInterval {
        usageRecorder.awakeDuration(for: session, at: date)
    }

    func clearPowerHistory() {
        usageRecorder.clearHistory()
        usageRecorder.handlePower(powerKind)
    }

    func exportHistoryCSV() {
        let csv = usageRecorder.exportCSV()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "PlugWatch-power-history.csv"
        panel.canCreateDirectories = true
        panel.title = "Export Power History"

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
            _ = self
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Status below remains source of truth.
        }
        refreshLaunchAtLogin()
    }

    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - NotificationActionHandling

    func handleNotificationDismiss() {
        dismissAlert()
    }

    func handleNotificationSnooze() {
        snoozeAlert()
    }

    // MARK: - Private

    private func startMonitors() {
        powerMonitor.onChange = { [weak self] kind in
            Task { @MainActor in
                guard let self else { return }
                self.powerKind = kind
                self.habitController.handlePower(kind)
                self.usageRecorder.handlePower(kind)
            }
        }
        powerMonitor.start()

        sleepMonitor.onWillSleep = { [weak self] in
            self?.habitController.handleSleep()
            self?.usageRecorder.handleSleep()
        }
        sleepMonitor.onDidWake = { [weak self] in
            guard let self else { return }
            let kind = self.powerMonitor.currentKind()
            Task { @MainActor in
                self.powerKind = kind
                self.habitController.handleWake(stillOnBattery: kind.isOnBattery)
                self.usageRecorder.handleWake(currentKind: kind)
            }
        }
        sleepMonitor.start()
    }

    private func applyConfiguration() {
        let config = HabitConfiguration(
            alertThreshold: alertThresholdMinutes * 60,
            snoozeInterval: snoozeMinutes * 60,
            showFloatingAlert: showFloatingAlert
        )
        habitController.updateConfiguration(config)
    }

    private func presentAlert() {
        notifications.postUnpluggedAlert()
        if showFloatingAlert {
            floatingPanel.show()
        }
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%dh %02dm", h, m)
        }
        if m > 0 {
            return String(format: "%dm %02ds", m, s)
        }
        return String(format: "%ds", s)
    }

    private enum Keys {
        static let alertThresholdMinutes = "alertThresholdMinutes"
        static let snoozeMinutes = "snoozeMinutes"
        static let showFloatingAlert = "showFloatingAlert"
    }
}
