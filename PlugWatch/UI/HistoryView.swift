import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var tick = Date()
    @State private var confirmClear = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Power Usage History")
                .font(.title2.bold())

            summarySection

            Divider()

            HStack {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                Button("Export CSV…") {
                    model.exportHistoryCSV()
                }
                Button("Clear History…", role: .destructive) {
                    confirmClear = true
                }
            }

            sessionList
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 480)
        .onReceive(timer) { date in
            tick = date
        }
        .confirmationDialog(
            "Clear all power history?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                model.clearPowerHistory()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var summarySection: some View {
        let todayStart = Calendar.current.startOfDay(for: tick)
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: tick) ?? tick
        let today = model.powerSummary(from: todayStart, to: tick)
        let week = model.powerSummary(from: weekStart, to: tick)
        let all = model.powerSummary(from: nil, to: tick)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Summary (awake time)")
                .font(.headline)
            summaryRow(title: "Today", summary: today)
            summaryRow(title: "Last 7 days", summary: week)
            summaryRow(title: "All time", summary: all)
        }
    }

    private func summaryRow(title: String, summary: PowerUsageSummary) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .frame(width: 100, alignment: .leading)
            Text("Battery \(AppModel.formatDuration(summary.batteryAwake)) (\(Int(summary.batteryPercent.rounded()))%)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            Text("AC \(AppModel.formatDuration(summary.acAwake)) (\(Int(summary.acPercent.rounded()))%)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.subheadline)
    }

    private var sessionList: some View {
        let rows = model.powerSessions(at: tick)
        return Group {
            if rows.isEmpty {
                Text("No sessions recorded yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Table(rows) {
                    TableColumn("Source") { session in
                        Text(session.kind.displayName)
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("Started") { session in
                        Text(session.startedAt, format: .dateTime.month().day().hour().minute())
                            .monospacedDigit()
                    }
                    .width(min: 120, ideal: 150)

                    TableColumn("Ended") { session in
                        if let ended = session.endedAt {
                            Text(ended, format: .dateTime.month().day().hour().minute())
                                .monospacedDigit()
                        } else {
                            Text("Now")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 120, ideal: 150)

                    TableColumn("Awake") { session in
                        let awake = model.liveAwakeDuration(for: session, at: tick)
                        Text(AppModel.formatDuration(awake))
                            .monospacedDigit()
                    }
                    .width(min: 70, ideal: 90)
                }
            }
        }
    }
}
