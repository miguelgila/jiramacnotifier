import Foundation
import Combine

@MainActor
class PollingService: ObservableObject {
    @Published var isRunning = false
    @Published var lastPollTime: Date?
    @Published var errorMessage: String?

    private var timers: [UUID: Timer] = [:]
    private let configManager: ConfigurationManager
    private let databaseManager: DatabaseManager
    private let jiraClient: JiraClient
    private let notificationService: NotificationService

    init(
        configManager: ConfigurationManager,
        databaseManager: DatabaseManager = DatabaseManager(),
        jiraClient: JiraClient = JiraClient(),
        notificationService: NotificationService = .shared
    ) {
        self.configManager = configManager
        self.databaseManager = databaseManager
        self.jiraClient = jiraClient
        self.notificationService = notificationService
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        schedulePolling()
    }

    func stop() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        isRunning = false
    }

    func restart() {
        stop()
        start()
    }

    private func schedulePolling() {
        // Cancel existing timers
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()

        // Schedule timer for each enabled instance
        for instance in configManager.instances where instance.isEnabled {
            let interval = TimeInterval(instance.pollIntervalMinutes * 60)

            let timer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: true
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.pollInstance(instance)
                }
            }

            timers[instance.id] = timer

            // Poll immediately on start
            Task {
                await pollInstance(instance)
            }
        }
    }

    private func pollInstance(_ instance: JiraInstance) async {
        do {
            for filter in instance.filters where filter.isEnabled {
                try await pollFilter(instance: instance, filter: filter)
            }
            lastPollTime = Date()
            errorMessage = nil
        } catch {
            errorMessage = "Error polling \(instance.name): \(error.localizedDescription)"
            print(errorMessage!)
        }
    }

    private func pollFilter(instance: JiraInstance, filter: JiraFilter) async throws {
        let issues = try await jiraClient.searchIssues(instance: instance, jql: filter.jql)

        for issue in issues {
            try await processIssue(issue, instance: instance, filter: filter)
        }
    }

    private func processIssue(_ issue: JiraIssue, instance: JiraInstance, filter: JiraFilter) async throws {
        let updatedAt = ISO8601DateFormatter().date(from: issue.fields.updated) ?? Date()

        let existingState = try databaseManager.getIssueState(
            issueId: issue.id,
            instanceId: instance.id,
            filterId: filter.id
        )

        let newState = IssueState(
            issueId: issue.id,
            issueKey: issue.key,
            instanceId: instance.id,
            filterId: filter.id,
            summary: issue.fields.summary,
            status: issue.fields.status.name,
            updatedAt: updatedAt,
            lastNotifiedAt: existingState?.lastNotifiedAt
        )

        // Save the new state
        try databaseManager.saveIssueState(newState)

        // Check if we should notify
        if shouldNotify(newState: newState, existingState: existingState) {
            await MainActor.run {
                notificationService.sendNotification(
                    for: issue,
                    instanceName: instance.name,
                    filterName: filter.name
                )
            }

            // Mark as notified
            try databaseManager.markAsNotified(
                issueId: issue.id,
                instanceId: instance.id,
                filterId: filter.id,
                at: Date()
            )
        }
    }

    private func shouldNotify(newState: IssueState, existingState: IssueState?) -> Bool {
        guard let existingState = existingState else {
            // New issue, notify
            return true
        }

        // Check if issue was updated since last notification
        if let lastNotified = existingState.lastNotifiedAt {
            return newState.updatedAt > lastNotified
        }

        // Never notified before
        return true
    }

    func pollNow() async {
        for instance in configManager.instances where instance.isEnabled {
            await pollInstance(instance)
        }
    }
}
