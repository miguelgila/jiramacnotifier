import Foundation

class ConfigurationManager: ObservableObject {
    @Published var instances: [JiraInstance] = []

    private let configFileURL: URL
    private let keychainManager = KeychainManager.shared

    init() {
        let fileManager = FileManager.default
        let appSupport = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let configDir = appSupport.appendingPathComponent("JiraMacNotifier", isDirectory: true)
        try? fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)

        configFileURL = configDir.appendingPathComponent("config.json")

        loadConfiguration()
    }

    func loadConfiguration() {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            instances = []
            return
        }

        do {
            let data = try Data(contentsOf: configFileURL)
            instances = try JSONDecoder().decode([JiraInstance].self, from: data)
        } catch {
            print("Failed to load configuration: \(error)")
            instances = []
        }
    }

    func saveConfiguration() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(instances)
            try data.write(to: configFileURL)
        } catch {
            print("Failed to save configuration: \(error)")
        }
    }

    func addInstance(_ instance: JiraInstance, token: String) throws {
        try keychainManager.saveToken(token, for: instance.id.uuidString)
        instances.append(instance)
        saveConfiguration()
    }

    func updateInstance(_ instance: JiraInstance, token: String? = nil) throws {
        if let token = token {
            try keychainManager.saveToken(token, for: instance.id.uuidString)
        }

        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            instances[index] = instance
            saveConfiguration()
        }
    }

    func deleteInstance(_ instance: JiraInstance) throws {
        try keychainManager.deleteToken(for: instance.id.uuidString)
        instances.removeAll { $0.id == instance.id }
        saveConfiguration()
    }

    func hasToken(for instance: JiraInstance) -> Bool {
        keychainManager.hasToken(for: instance.id.uuidString)
    }
}
