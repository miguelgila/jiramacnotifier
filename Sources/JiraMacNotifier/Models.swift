import Foundation

// MARK: - Configuration Models

struct JiraInstance: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var url: String
    var username: String
    var pollIntervalMinutes: Int
    var filters: [JiraFilter]
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, url: String, username: String, pollIntervalMinutes: Int = 5, filters: [JiraFilter] = [], isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
        self.pollIntervalMinutes = pollIntervalMinutes
        self.filters = filters
        self.isEnabled = isEnabled
    }
}

struct JiraFilter: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var jql: String
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, jql: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.jql = jql
        self.isEnabled = isEnabled
    }
}

// MARK: - Jira API Models

struct JiraSearchResponse: Codable, Sendable {
    let startAt: Int
    let maxResults: Int
    let total: Int
    let issues: [JiraIssue]
}

struct JiraIssue: Codable, Sendable {
    let id: String
    let key: String
    let fields: JiraIssueFields
}

struct JiraIssueFields: Codable, Sendable {
    let summary: String
    let status: JiraStatus
    let updated: String
    let assignee: JiraUser?
    let reporter: JiraUser?
    let priority: JiraPriority?
}

struct JiraStatus: Codable, Sendable {
    let name: String
}

struct JiraUser: Codable, Sendable {
    let displayName: String
}

struct JiraPriority: Codable, Sendable {
    let name: String
}

// MARK: - Persistence Models

struct IssueState: Equatable, Sendable {
    let issueId: String
    let issueKey: String
    let instanceId: UUID
    let filterId: UUID
    let summary: String
    let status: String
    let updatedAt: Date
    let lastNotifiedAt: Date?
    var isRead: Bool

    init(issueId: String, issueKey: String, instanceId: UUID, filterId: UUID, summary: String, status: String, updatedAt: Date, lastNotifiedAt: Date?, isRead: Bool = false) {
        self.issueId = issueId
        self.issueKey = issueKey
        self.instanceId = instanceId
        self.filterId = filterId
        self.summary = summary
        self.status = status
        self.updatedAt = updatedAt
        self.lastNotifiedAt = lastNotifiedAt
        self.isRead = isRead
    }

    var hasChanged: Bool {
        guard let lastNotified = lastNotifiedAt else { return true }
        return updatedAt > lastNotified
    }
}

// MARK: - Issue Display Model

struct IssueDisplayItem: Identifiable, Equatable, Sendable {
    let id: String // issueId
    let issueKey: String
    let summary: String
    let status: String
    let priority: String?
    let assignee: String?
    let updatedAt: Date
    let instanceId: UUID
    let instanceName: String
    let instanceUrl: String
    let filterId: UUID
    let filterName: String
    let isRead: Bool
    let isNew: Bool

    var jiraUrl: String {
        "\(instanceUrl)/browse/\(issueKey)"
    }
}

// MARK: - Status Tracking Models

struct InstancePollStatus: Identifiable, Equatable, Sendable {
    let id: UUID
    let instanceId: UUID
    let instanceName: String
    let lastPollTime: Date?
    let nextPollTime: Date?
    let isPolling: Bool
    let hasChanges: Bool
    let changeCount: Int
    let errorMessage: String?
}

struct FilterPollStatus: Identifiable, Equatable, Sendable {
    let id: UUID
    let filterId: UUID
    let filterName: String
    let issueCount: Int
    let newIssueCount: Int
    let updatedIssueCount: Int
    let lastPollTime: Date?
}

// MARK: - Logging Models

enum LogLevel: String, Codable, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

struct LogEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let message: String
    let instanceId: UUID?
    let filterId: UUID?

    init(id: UUID = UUID(), timestamp: Date = Date(), level: LogLevel, message: String, instanceId: UUID? = nil, filterId: UUID? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.instanceId = instanceId
        self.filterId = filterId
    }
}
