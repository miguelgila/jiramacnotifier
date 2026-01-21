import SwiftUI

struct AddInstanceView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var pollingService: PollingService

    @State private var name = ""
    @State private var url = ""
    @State private var username = ""
    @State private var token = ""
    @State private var pollIntervalMinutes = 5
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Instance Details")) {
                    TextField("Name (e.g., Work Jira)", text: $name)
                    TextField("URL (e.g., https://your-domain.atlassian.net)", text: $url)
                    TextField("Username/Email", text: $username)
                    SecureField("API Token", text: $token)

                    Stepper("Poll Interval: \(pollIntervalMinutes) minutes",
                           value: $pollIntervalMinutes,
                           in: 1...60)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Jira Instance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addInstance()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 500, height: 400)
    }

    private var isValid: Bool {
        !name.isEmpty && !url.isEmpty && !username.isEmpty && !token.isEmpty
    }

    private func addInstance() {
        let instance = JiraInstance(
            name: name,
            url: url.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            pollIntervalMinutes: pollIntervalMinutes
        )

        do {
            try configManager.addInstance(instance, token: token)
            pollingService.restart()
            dismiss()
        } catch {
            errorMessage = "Failed to add instance: \(error.localizedDescription)"
        }
    }
}

struct AddFilterView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var instance: JiraInstance
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var pollingService: PollingService

    @State private var name = ""
    @State private var jql = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Filter Details")) {
                    TextField("Name (e.g., My Open Issues)", text: $name)

                    VStack(alignment: .leading) {
                        Text("JQL Query")
                            .font(.headline)
                        TextEditor(text: $jql)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 100)
                            .border(Color.gray.opacity(0.3))

                        Text("Example: assignee = currentUser() AND status != Done")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Filter")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addFilter()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 500, height: 350)
    }

    private var isValid: Bool {
        !name.isEmpty && !jql.isEmpty
    }

    private func addFilter() {
        let filter = JiraFilter(name: name, jql: jql.trimmingCharacters(in: .whitespacesAndNewlines))
        instance.filters.append(filter)

        do {
            try configManager.updateInstance(instance)
            pollingService.restart()
            dismiss()
        } catch {
            errorMessage = "Failed to add filter: \(error.localizedDescription)"
        }
    }
}
