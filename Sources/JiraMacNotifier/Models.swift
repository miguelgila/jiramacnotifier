import Foundation

// MARK: - Configuration Models

struct JiraInstance: Codable, Identifiable, Equatable, Sendable {
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

struct JiraFilter: Codable, Identifiable, Equatable, Sendable {
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

    var hasChanged: Bool {
        guard let lastNotified = lastNotifiedAt else { return true }
        return updatedAt > lastNotified
    }
}
