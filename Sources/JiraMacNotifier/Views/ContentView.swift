import SwiftUI

struct ContentView: View {
    @StateObject private var configManager: ConfigurationManager
    @StateObject private var pollingService: PollingService

    @State private var showingAddInstance = false
    @State private var showingLogViewer = false
    @State private var selectedInstance: JiraInstance?

    init() {
        let configManager = ConfigurationManager()
        let pollingService = PollingService(configManager: configManager)
        _configManager = StateObject(wrappedValue: configManager)
        _pollingService = StateObject(wrappedValue: pollingService)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedInstance) {
                Section(header: Text("Jira Instances")) {
                    ForEach(configManager.instances) { instance in
                        InstanceRow(
                            instance: instance,
                            status: pollingService.pollStatuses[instance.id]
                        )
                        .tag(instance)
                    }
                    .onDelete(perform: deleteInstances)
                }
            }
            .navigationTitle("Jira Notifier")
            .toolbar {
                ToolbarItemGroup {
                    Button(action: { showingAddInstance = true }) {
                        Label("Add Instance", systemImage: "plus")
                    }

                    Divider()

                    Button(action: {
                        pollingService.isRunning ? pollingService.stop() : pollingService.start()
                    }) {
                        Label(
                            pollingService.isRunning ? "Stop Polling" : "Start Polling",
                            systemImage: pollingService.isRunning ? "pause.circle.fill" : "play.circle.fill"
                        )
                    }

                    if pollingService.isRunning {
                        Button(action: {
                            Task { @MainActor in
                                await pollingService.pollNow()
                            }
                        }) {
                            Label("Poll Now", systemImage: "arrow.clockwise")
                        }
                    }

                    Divider()

                    Button(action: { showingLogViewer = true }) {
                        Label("View Logs", systemImage: "doc.text.magnifyingglass")
                    }
                }
            }
        } content: {
            IssuesListView(
                configManager: configManager,
                pollingService: pollingService
            )
        } detail: {
            if let instance = selectedInstance {
                InstanceDetailView(
                    instance: binding(for: instance),
                    configManager: configManager,
                    pollingService: pollingService
                )
            } else {
                Text("Select an instance to configure")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingAddInstance) {
            AddInstanceView(configManager: configManager, pollingService: pollingService)
        }
        .sheet(isPresented: $showingLogViewer) {
            LogViewerView()
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            pollingService.start()
        }
    }

    private func binding(for instance: JiraInstance) -> Binding<JiraInstance> {
        guard let index = configManager.instances.firstIndex(where: { $0.id == instance.id }) else {
            fatalError("Instance not found")
        }
        return $configManager.instances[index]
    }

    private func deleteInstances(at offsets: IndexSet) {
        for index in offsets {
            let instance = configManager.instances[index]
            try? configManager.deleteInstance(instance)
        }
        pollingService.restart()
    }
}

struct InstanceRow: View {
    let instance: JiraInstance
    let status: InstancePollStatus?

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.system(size: 14, weight: .semibold))
            }

            // Instance info
            VStack(alignment: .leading, spacing: 4) {
                Text(instance.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(instance.url)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let lastPoll = status?.lastPollTime {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(timeAgo(lastPoll))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Status indicators
            VStack(alignment: .trailing, spacing: 4) {
                if let status = status, status.hasChanges {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.orange)
                        Text("\(status.changeCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }

                Text("\(instance.filters.count) filters")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let error = status?.errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .help(error)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        if let status = status {
            if let _ = status.errorMessage {
                return .red
            } else if status.isPolling {
                return .blue
            } else if status.hasChanges {
                return .orange
            } else if instance.isEnabled {
                return .green
            }
        }
        return instance.isEnabled ? .gray : .gray.opacity(0.5)
    }

    private var statusIcon: String {
        if let status = status {
            if let _ = status.errorMessage {
                return "xmark"
            } else if status.isPolling {
                return "arrow.clockwise"
            } else if status.hasChanges {
                return "bell.fill"
            } else if instance.isEnabled {
                return "checkmark"
            }
        }
        return instance.isEnabled ? "pause" : "circle"
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}
