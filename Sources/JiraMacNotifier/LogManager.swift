import Foundation

final class LogManager: @unchecked Sendable {
    static let shared = LogManager()

    private let logFileURL: URL
    private let maxLogEntries = 1000 // Keep last 1000 entries
    private let queue = DispatchQueue(label: "com.jiramacnotifier.logging", qos: .utility)

    private init() {
        let fileManager = FileManager.default
        let appSupport = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let logDir = appSupport.appendingPathComponent("JiraMacNotifier", isDirectory: true)
        try? fileManager.createDirectory(at: logDir, withIntermediateDirectories: true)

        logFileURL = logDir.appendingPathComponent("logs.json")
    }

    func log(_ level: LogLevel, _ message: String, instanceId: UUID? = nil, filterId: UUID? = nil) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            instanceId: instanceId,
            filterId: filterId
        )

        queue.async { [weak self] in
            self?.saveLogEntry(entry)
        }

        // Also print to console
        let prefix = level.rawValue
        print("[\(prefix)] \(message)")
    }

    private func saveLogEntry(_ entry: LogEntry) {
        var entries = loadLogs()
        entries.append(entry)

        // Keep only the last maxLogEntries
        if entries.count > maxLogEntries {
            entries = Array(entries.suffix(maxLogEntries))
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: logFileURL, options: .atomic)
        } catch {
            print("Failed to save log entry: \(error)")
        }
    }

    func loadLogs() -> [LogEntry] {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: logFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([LogEntry].self, from: data)
        } catch {
            print("Failed to load logs: \(error)")
            return []
        }
    }

    func clearLogs() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.logFileURL)
        }
    }

    func getLogs(level: LogLevel? = nil, instanceId: UUID? = nil, limit: Int? = nil) -> [LogEntry] {
        var logs = loadLogs()

        if let level = level {
            logs = logs.filter { $0.level == level }
        }

        if let instanceId = instanceId {
            logs = logs.filter { $0.instanceId == instanceId }
        }

        if let limit = limit {
            logs = Array(logs.suffix(limit))
        }

        return logs.reversed() // Most recent first
    }
}
