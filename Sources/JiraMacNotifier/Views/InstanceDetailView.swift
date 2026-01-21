import SwiftUI

struct InstanceDetailView: View {
    @Binding var instance: JiraInstance
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var pollingService: PollingService

    @State private var token: String = ""
    @State private var showingAddFilter = false
    @State private var testConnectionStatus: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $instance.isEnabled)
                    .onChange(of: instance.isEnabled) { _ in
                        saveAndRestart()
                    }

                TextField("Name", text: $instance.name)
                TextField("URL", text: $instance.url)
                TextField("Username", text: $instance.username)

                HStack {
                    SecureField("API Token", text: $token)
                    if !token.isEmpty {
                        Button("Save Token") {
                            saveToken()
                        }
                    }
                }

                Stepper("Poll Interval: \(instance.pollIntervalMinutes) minutes",
                       value: $instance.pollIntervalMinutes,
                       in: 1...60)
                    .onChange(of: instance.pollIntervalMinutes) { _ in
                        saveAndRestart()
                    }

                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(isTesting || !hasToken())

                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    if let status = testConnectionStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(status.contains("Success") ? .green : .red)
                    }
                }
            } header: {
                Text("Instance Configuration")
            }

            Section {
                List {
                    ForEach($instance.filters) { $filter in
                        FilterRow(filter: $filter)
                            .onChange(of: filter) { _ in
                                saveAndRestart()
                            }
                    }
                    .onDelete(perform: deleteFilters)
                }

                Button(action: { showingAddFilter = true }) {
                    Label("Add Filter", systemImage: "plus")
                }
            } header: {
                Text("Filters")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(instance.name)
        .toolbar {
            Button("Save") {
                save()
            }
        }
        .sheet(isPresented: $showingAddFilter) {
            AddFilterView(instance: $instance, configManager: configManager, pollingService: pollingService)
        }
    }

    private func hasToken() -> Bool {
        configManager.hasToken(for: instance)
    }

    private func saveToken() {
        do {
            try configManager.updateInstance(instance, token: token)
            token = ""
            testConnectionStatus = nil
        } catch {
            testConnectionStatus = "Failed to save token: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            try configManager.updateInstance(instance)
            pollingService.restart()
        } catch {
            print("Failed to save: \(error)")
        }
    }

    private func saveAndRestart() {
        do {
            try configManager.updateInstance(instance)
            pollingService.restart()
        } catch {
            print("Failed to save: \(error)")
        }
    }

    private func testConnection() {
        isTesting = true
        testConnectionStatus = nil

        Task {
            do {
                let jiraClient = JiraClient()
                let success = try await jiraClient.testConnection(instance: instance)
                await MainActor.run {
                    testConnectionStatus = success ? "✓ Connection successful" : "✗ Connection failed"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testConnectionStatus = "✗ Error: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }

    private func deleteFilters(at offsets: IndexSet) {
        instance.filters.remove(atOffsets: offsets)
        saveAndRestart()
    }
}

struct FilterRow: View {
    @Binding var filter: JiraFilter

    var body: some View {
        HStack {
            Toggle("", isOn: $filter.isEnabled)
                .labelsHidden()

            VStack(alignment: .leading) {
                Text(filter.name)
                    .font(.headline)
                Text(filter.jql)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
