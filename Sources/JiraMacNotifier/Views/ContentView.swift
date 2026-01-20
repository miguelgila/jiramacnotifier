import SwiftUI

struct ContentView: View {
    @StateObject private var configManager: ConfigurationManager
    @StateObject private var pollingService: PollingService

    @State private var showingAddInstance = false
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
                Section("Jira Instances") {
                    ForEach(configManager.instances) { instance in
                        InstanceRow(instance: instance)
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
                }
            }
        } detail: {
            if let instance = selectedInstance {
                InstanceDetailView(
                    instance: binding(for: instance),
                    configManager: configManager,
                    pollingService: pollingService
                )
            } else {
                Text("Select an instance")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingAddInstance) {
            AddInstanceView(configManager: configManager, pollingService: pollingService)
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

    var body: some View {
        HStack {
            Image(systemName: instance.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(instance.isEnabled ? .green : .gray)

            VStack(alignment: .leading) {
                Text(instance.name)
                    .font(.headline)
                Text(instance.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(instance.filters.count) filters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
