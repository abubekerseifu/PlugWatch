import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @State private var tick = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.powerKind.displayName)
            Text(model.habitState.displayName)
                .foregroundStyle(.secondary)

            if model.powerKind.isOnBattery,
               model.habitState != .pluggedIn,
               model.habitState != .dismissedThisCycle {
                Text("Unplugged: \(model.awakeUnpluggedDurationText(at: tick))")
                    .monospacedDigit()
            }

            Divider()

            Button("Snooze \(Int(model.snoozeMinutes)) min") {
                model.snoozeAlert()
            }
            .disabled(model.habitState == .pluggedIn || model.habitState == .dismissedThisCycle)

            Button("Pause Until Plug In") {
                model.pauseUntilPlug()
            }
            .disabled(model.habitState == .pluggedIn || model.habitState == .dismissedThisCycle)

            Divider()

            Button("History…") {
                model.openHistoryWindow()
            }

            Button("Settings…") {
                model.openSettingsWindow()
            }

            Button("Quit PlugWatch") {
                model.quit()
            }
        }
        .onReceive(timer) { date in
            // Only ticks while the menu is open — no global background 1 Hz timer in AppModel.
            tick = date
        }
    }
}
