import Foundation

/// Atomic JSON persistence under Application Support.
final class PowerHistoryStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "com.plugwatch.history.store")

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = base.appendingPathComponent("com.plugwatch.app", isDirectory: true)
            self.fileURL = dir.appendingPathComponent("power_history.json")
        }

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    var storageURL: URL { fileURL }

    func load() -> PowerHistoryDocument {
        queue.sync {
            ensureDirectory()
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return .empty
            }
            do {
                let data = try Data(contentsOf: fileURL)
                return try decoder.decode(PowerHistoryDocument.self, from: data)
            } catch {
                return .empty
            }
        }
    }

    func save(_ document: PowerHistoryDocument) {
        queue.sync {
            ensureDirectory()
            do {
                let data = try encoder.encode(document)
                let temp = fileURL.appendingPathExtension("tmp")
                try data.write(to: temp, options: .atomic)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temp)
                } else {
                    try FileManager.default.moveItem(at: temp, to: fileURL)
                }
            } catch {
                // Best-effort; next successful write will recover.
            }
        }
    }

    func clear() {
        save(.empty)
    }

    private func ensureDirectory() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}
