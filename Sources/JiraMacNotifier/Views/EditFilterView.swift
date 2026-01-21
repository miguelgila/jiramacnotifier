import SwiftUI

struct EditFilterView: View {
    @Binding var filter: JiraFilter
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var pollingService: PollingService

    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var jql: String
    @State private var isEnabled: Bool

    init(filter: Binding<JiraFilter>, configManager: ConfigurationManager, pollingService: PollingService) {
        self._filter = filter
        self.configManager = configManager
        self.pollingService = pollingService
        self._name = State(initialValue: filter.wrappedValue.name)
        self._jql = State(initialValue: filter.wrappedValue.jql)
        self._isEnabled = State(initialValue: filter.wrappedValue.isEnabled)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Filter")
                .font(.title2)
                .bold()

            Form {
                Section(header: Text("Filter Details")) {
                    TextField("Name", text: $name)
                    TextField("JQL Query", text: $jql, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("Enabled", isOn: $isEnabled)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveFilter()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || jql.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 300)
        .padding()
    }

    private func saveFilter() {
        filter.name = name
        filter.jql = jql
        filter.isEnabled = isEnabled

        // Find the instance and update it
        if let instanceIndex = configManager.instances.firstIndex(where: { $0.filters.contains(where: { $0.id == filter.id }) }) {
            try? configManager.updateInstance(configManager.instances[instanceIndex])
            pollingService.restart()
        }

        dismiss()
    }
}
