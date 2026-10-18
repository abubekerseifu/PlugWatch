import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Alerts") {
                HStack {
                    Text("Unplugged threshold")
                    Spacer()
                    Text(thresholdLabel)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: $model.alertThresholdMinutes,
                    in: 0.5...120,
                    step: 0.5
                )

                HStack {
                    Text("Snooze duration")
                    Spacer()
                    Text("\(Int(model.snoozeMinutes)) min")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $model.snoozeMinutes, in: 5...120, step: 5)

                Toggle("Show floating alert panel", isOn: $model.showFloatingAlert)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }

            Section("About") {
                LabeledContent("Power monitoring", value: "IOKit (event-driven)")
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 360)
        .padding()
        .onAppear {
            model.refreshLaunchAtLogin()
        }
    }

    private var thresholdLabel: String {
        if model.alertThresholdMinutes < 1 {
            return "\(Int(model.alertThresholdMinutes * 60)) sec"
        }
        if model.alertThresholdMinutes == floor(model.alertThresholdMinutes) {
            return "\(Int(model.alertThresholdMinutes)) min"
        }
        return String(format: "%.1f min", model.alertThresholdMinutes)
    }
}
