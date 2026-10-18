import Foundation

/// Records awake-time AC/battery sessions. Event-driven; no polling.
@MainActor
final class PowerUsageRecorder: ObservableObject {
    @Published private(set) var sessions: [PowerSession] = []

    private let store: PowerHistoryStore
    private var segmentStartedAt: Date?
    private var isSleeping = false

    init(store: PowerHistoryStore = PowerHistoryStore()) {
        self.store = store
        var doc = store.load()
        // Recover: close any open session left from a previous crash/quit without flush.
        // Plan: on quit we close with endedAt; on crash an open session may remain —
        // keep its awakeDuration and close it so reports stay clean, then start fresh on handlePower.
        for i in doc.sessions.indices where doc.sessions[i].isOpen {
            doc.sessions[i].endedAt = Date()
        }
        store.save(doc)
        sessions = doc.sessions.sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: - Events

    func handlePower(_ kind: PowerSourceKind, at date: Date = Date()) {
        if isSleeping {
            // Power can change while asleep; apply on wake via handleWake.
            // Still record the intended kind by closing/opening without accruing sleep time.
        }

        freezeSegment(at: date)

        if let openIndex = openSessionIndex() {
            let open = sessions[openIndex]
            if open.kind == kind {
                // Same kind — continue (e.g. duplicate IOKit callback).
                if !isSleeping {
                    segmentStartedAt = date
                }
                persist()
                return
            }
            closeOpenSession(at: date)
        }

        if kind.isTrackable {
            startSession(kind: kind, at: date)
        } else {
            persist()
        }
    }

    func handleSleep(at date: Date = Date()) {
        guard !isSleeping else { return }
        freezeSegment(at: date)
        isSleeping = true
        persist()
    }

    func handleWake(currentKind: PowerSourceKind, at date: Date = Date()) {
        isSleeping = false

        if let openIndex = openSessionIndex() {
            let open = sessions[openIndex]
            if open.kind != currentKind {
                // Power changed during sleep — close old, start new without counting sleep.
                closeOpenSession(at: date)
                if currentKind.isTrackable {
                    startSession(kind: currentKind, at: date)
                } else {
                    persist()
                }
                return
            }
            segmentStartedAt = date
            persist()
            return
        }

        if currentKind.isTrackable {
            startSession(kind: currentKind, at: date)
        }
    }

    /// Close open session and persist (call on quit).
    func finalizeForQuit(at date: Date = Date()) {
        freezeSegment(at: date)
        closeOpenSession(at: date)
        persist()
    }

    func clearHistory() {
        sessions = []
        segmentStartedAt = nil
        store.clear()
        // Restart tracking for current power from outside via handlePower after clear.
    }

    // MARK: - Queries

    func sessionsIncludingLive(at date: Date = Date()) -> [PowerSession] {
        var list = sessions
        if let idx = openSessionIndex() {
            var live = list[idx]
            live.awakeDuration = awakeDuration(for: live, at: date)
            list[idx] = live
        }
        return list.sorted { $0.startedAt > $1.startedAt }
    }

    func awakeDuration(for session: PowerSession, at date: Date = Date()) -> TimeInterval {
        var total = session.awakeDuration
        if session.isOpen, let started = segmentStartedAt, !isSleeping {
            total += max(0, date.timeIntervalSince(started))
        }
        return total
    }

    func summary(from start: Date?, to end: Date = Date()) -> PowerUsageSummary {
        var battery: TimeInterval = 0
        var ac: TimeInterval = 0

        for session in sessionsIncludingLive(at: end) {
            let contribution = awakeOverlap(session: session, from: start, to: end, now: end)
            switch session.kind {
            case .battery: battery += contribution
            case .ac: ac += contribution
            case .unknown: break
            }
        }
        return PowerUsageSummary(batteryAwake: battery, acAwake: ac)
    }

    func exportCSV(at date: Date = Date()) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var lines = ["id,kind,started_at,ended_at,awake_seconds,awake_hms"]
        for session in sessionsIncludingLive(at: date) {
            let awake = awakeDuration(for: session, at: date)
            let ended = session.endedAt.map { iso.string(from: $0) } ?? ""
            let hms = Self.formatHMS(awake)
            lines.append([
                session.id.uuidString,
                session.kind.csvValue,
                iso.string(from: session.startedAt),
                ended,
                String(format: "%.0f", awake),
                hms
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private

    private func openSessionIndex() -> Int? {
        sessions.firstIndex { $0.isOpen }
    }

    private func startSession(kind: PowerSourceKind, at date: Date) {
        let session = PowerSession(kind: kind, startedAt: date, endedAt: nil, awakeDuration: 0)
        sessions.insert(session, at: 0)
        if !isSleeping {
            segmentStartedAt = date
        }
        persist()
    }

    private func closeOpenSession(at date: Date) {
        guard let idx = openSessionIndex() else { return }
        freezeSegment(at: date)
        sessions[idx].endedAt = date
        segmentStartedAt = nil
    }

    private func freezeSegment(at date: Date) {
        guard let started = segmentStartedAt, let idx = openSessionIndex(), !isSleeping else {
            segmentStartedAt = nil
            return
        }
        sessions[idx].awakeDuration += max(0, date.timeIntervalSince(started))
        segmentStartedAt = nil
    }

    /// Approximate awake time overlapping [start, end] by scaling session awake by calendar overlap ratio
    /// against session span. For open sessions, span ends at `now`.
    private func awakeOverlap(session: PowerSession, from start: Date?, to end: Date, now: Date) -> TimeInterval {
        let awake = awakeDuration(for: session, at: now)
        guard awake > 0 else { return 0 }

        let sessionStart = session.startedAt
        let sessionEnd = session.endedAt ?? now
        let rangeStart = start ?? .distantPast
        let overlapStart = max(sessionStart, rangeStart)
        let overlapEnd = min(sessionEnd, end)
        let overlap = overlapEnd.timeIntervalSince(overlapStart)
        guard overlap > 0 else { return 0 }

        let span = sessionEnd.timeIntervalSince(sessionStart)
        guard span > 0 else { return awake }
        // Prefer exact awake when the whole session is inside the window.
        if sessionStart >= rangeStart && sessionEnd <= end {
            return awake
        }
        return awake * (overlap / span)
    }

    private func persist() {
        let doc = PowerHistoryDocument(sessions: sessions)
        store.save(doc)
        objectWillChange.send()
    }

    static func formatHMS(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
