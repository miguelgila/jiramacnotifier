import Foundation
import Combine

@MainActor
final class PollingService: ObservableObject {
    @Published var isRunning = false
    @Published var lastPollTime: Date?
    @Published var errorMessage: String?
    @Published var pollStatuses: [UUID: InstancePollStatus] = [:]

    private var timers: [UUID: Timer] = [:]
    private var pollStartTimes: [UUID: Date] = [:]
    private var changeCounters: [UUID: Int] = [:]
    private let configManager: ConfigurationManager
    private let databaseManager: DatabaseManager
    private let jiraClient: JiraClient
    private let notificationService: NotificationService
    private let logManager = LogManager.shared

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
        let enabledCount = configManager.instances.filter { $0.isEnabled }.count
        logManager.log(.info, "Polling service started - monitoring \(enabledCount) enabled instance(s)")
        schedulePolling()
    }

    func stop() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        isRunning = false
        logManager.log(.info, "Polling service stopped - all timers cancelled")
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
            let enabledFilters = instance.filters.filter { $0.isEnabled }.count

            logManager.log(
                .info,
                "Scheduled polling for '\(instance.name)' every \(instance.pollIntervalMinutes) minutes (\(enabledFilters) active filter(s))",
                instanceId: instance.id
            )

            let timer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: true
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.pollInstance(instance)
                }
            }

            RunLoop.main.add(timer, forMode: .common)
            timers[instance.id] = timer

            // Poll immediately on start
            Task { @MainActor in
                await pollInstance(instance)
            }
        }
    }

    private func pollInstance(_ instance: JiraInstance) async {
        let pollTime = Date()
        pollStartTimes[instance.id] = pollTime

        // Update status to show polling in progress
        updatePollStatus(for: instance, isPolling: true, lastPollTime: pollTime)

        logManager.log(.info, "Starting poll for instance: \(instance.name)", instanceId: instance.id)

        var changeCount = 0
        var hasError = false
        var errorMsg: String?

        do {
            for filter in instance.filters where filter.isEnabled {
                let newChanges = try await pollFilter(instance: instance, filter: filter)
                changeCount += newChanges
            }
            lastPollTime = Date()
            errorMessage = nil

            logManager.log(.info, "Poll completed for \(instance.name): \(changeCount) changes detected", instanceId: instance.id)
        } catch {
            hasError = true
            errorMsg = "Error polling \(instance.name): \(error.localizedDescription)"
            errorMessage = errorMsg
            logManager.log(.error, errorMsg!, instanceId: instance.id)
        }

        // Update final status
        changeCounters[instance.id] = (changeCounters[instance.id] ?? 0) + changeCount
        updatePollStatus(
            for: instance,
            isPolling: false,
            lastPollTime: pollTime,
            hasChanges: changeCount > 0,
            changeCount: changeCounters[instance.id] ?? 0,
            errorMessage: hasError ? errorMsg : nil
        )
    }

    private func pollFilter(instance: JiraInstance, filter: JiraFilter) async throws -> Int {
        logManager.log(.debug, "Polling filter '\(filter.name)' with JQL: \(filter.jql)", instanceId: instance.id, filterId: filter.id)

        let issues = try await jiraClient.searchIssues(instance: instance, jql: filter.jql)
        logManager.log(.debug, "Found \(issues.count) issues for filter '\(filter.name)'", instanceId: instance.id, filterId: filter.id)

        var changeCount = 0
        for issue in issues {
            let didNotify = try await processIssue(issue, instance: instance, filter: filter)
            if didNotify {
                changeCount += 1
            }
        }

        return changeCount
    }

    private func processIssue(_ issue: JiraIssue, instance: JiraInstance, filter: JiraFilter) async throws -> Bool {
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
            lastNotifiedAt: existingState?.lastNotifiedAt,
            isRead: existingState?.isRead ?? false
        )

        // Save the new state
        try databaseManager.saveIssueState(newState)

        // Check if we should notify
        if shouldNotify(newState: newState, existingState: existingState) {
            let isNew = existingState == nil
            logManager.log(
                .info,
                "\(isNew ? "New" : "Updated") issue: \(issue.key) - \(issue.fields.summary)",
                instanceId: instance.id,
                filterId: filter.id
            )

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

            return true
        }

        return false
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

    private func updatePollStatus(
        for instance: JiraInstance,
        isPolling: Bool,
        lastPollTime: Date? = nil,
        hasChanges: Bool = false,
        changeCount: Int = 0,
        errorMessage: String? = nil
    ) {
        let nextPollTime: Date?
        if isRunning, let timer = timers[instance.id], timer.isValid {
            nextPollTime = Date().addingTimeInterval(TimeInterval(instance.pollIntervalMinutes * 60))
        } else {
            nextPollTime = nil
        }

        let status = InstancePollStatus(
            id: instance.id,
            instanceId: instance.id,
            instanceName: instance.name,
            lastPollTime: lastPollTime ?? pollStatuses[instance.id]?.lastPollTime,
            nextPollTime: nextPollTime,
            isPolling: isPolling,
            hasChanges: hasChanges,
            changeCount: changeCount,
            errorMessage: errorMessage
        )

        pollStatuses[instance.id] = status
    }

    func resetChangeCounter(for instanceId: UUID) {
        changeCounters[instanceId] = 0
        if let status = pollStatuses[instanceId] {
            pollStatuses[instanceId] = InstancePollStatus(
                id: status.id,
                instanceId: status.instanceId,
                instanceName: status.instanceName,
                lastPollTime: status.lastPollTime,
                nextPollTime: status.nextPollTime,
                isPolling: status.isPolling,
                hasChanges: false,
                changeCount: 0,
                errorMessage: status.errorMessage
            )
        }
    }
}
