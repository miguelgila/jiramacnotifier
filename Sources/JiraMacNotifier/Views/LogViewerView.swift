import SwiftUI

struct LogViewerView: View {
    @State private var logs: [LogEntry] = []
    @State private var selectedLevel: LogLevel? = nil
    @State private var searchText: String = ""
    @State private var autoRefresh: Bool = false

    private let logManager = LogManager.shared
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var filteredLogs: [LogEntry] {
        var result = logs

        if let level = selectedLevel {
            result = result.filter { $0.level == level }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Logs")
                    .font(.title2)
                    .bold()

                Spacer()

                Toggle("Auto-refresh", isOn: $autoRefresh)
                    .toggleStyle(.switch)

                Picker("Level", selection: $selectedLevel) {
                    Text("All").tag(nil as LogLevel?)
                    Text("Debug").tag(LogLevel.debug as LogLevel?)
                    Text("Info").tag(LogLevel.info as LogLevel?)
                    Text("Warning").tag(LogLevel.warning as LogLevel?)
                    Text("Error").tag(LogLevel.error as LogLevel?)
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                Button(action: refreshLogs) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button(action: clearLogs) {
                    Label("Clear", systemImage: "trash")
                }
                .foregroundColor(.red)
            }
            .padding()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $searchText)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)

            Divider()

            // Logs list
            if filteredLogs.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No logs found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredLogs) { log in
                            LogEntryRow(log: log)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear(perform: refreshLogs)
        .onReceive(timer) { _ in
            if autoRefresh {
                refreshLogs()
            }
        }
    }

    private func refreshLogs() {
        logs = logManager.getLogs()
    }

    private func clearLogs() {
        logManager.clearLogs()
        refreshLogs()
    }
}

struct LogEntryRow: View {
    let log: LogEntry

    private var levelColor: Color {
        switch log.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    private var levelIcon: String {
        switch log.level {
        case .debug: return "ant.circle"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: levelIcon)
                .foregroundColor(levelColor)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.level.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(levelColor)

                    Text(formatDate(log.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }

                Text(log.message)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
