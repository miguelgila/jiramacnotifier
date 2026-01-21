import Foundation
import SQLite

final class DatabaseManager: @unchecked Sendable {
    private var db: Connection?
    private let issueStates = Table("issue_states")

    // Columns
    private let issueId = Expression<String>("issue_id")
    private let issueKey = Expression<String>("issue_key")
    private let instanceId = Expression<String>("instance_id")
    private let filterId = Expression<String>("filter_id")
    private let summary = Expression<String>("summary")
    private let status = Expression<String>("status")
    private let updatedAt = Expression<Date>("updated_at")
    private let lastNotifiedAt = Expression<Date?>("last_notified_at")
    private let isRead = Expression<Bool>("is_read")

    init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let fileManager = FileManager.default
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let dbDir = appSupport.appendingPathComponent("JiraMacNotifier", isDirectory: true)
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)

            let dbPath = dbDir.appendingPathComponent("jira_notifier.db").path
            db = try Connection(dbPath)

            try db?.run(issueStates.create(ifNotExists: true) { t in
                t.column(issueId)
                t.column(issueKey)
                t.column(instanceId)
                t.column(filterId)
                t.column(summary)
                t.column(status)
                t.column(updatedAt)
                t.column(lastNotifiedAt)
                t.column(isRead, defaultValue: false)
                t.primaryKey(issueId, instanceId, filterId)
            })

            // Create indexes for faster queries
            try db?.run(issueStates.createIndex(instanceId, ifNotExists: true))
            try db?.run(issueStates.createIndex(filterId, ifNotExists: true))

        } catch {
            print("Database setup error: \(error)")
        }
    }

    func saveIssueState(_ state: IssueState) throws {
        guard let db = db else { return }

        let insert = issueStates.insert(
            or: .replace,
            issueId <- state.issueId,
            issueKey <- state.issueKey,
            instanceId <- state.instanceId.uuidString,
            filterId <- state.filterId.uuidString,
            summary <- state.summary,
            status <- state.status,
            updatedAt <- state.updatedAt,
            lastNotifiedAt <- state.lastNotifiedAt,
            isRead <- state.isRead
        )

        try db.run(insert)
    }

    func getIssueState(issueId: String, instanceId: UUID, filterId: UUID) throws -> IssueState? {
        guard let db = db else { return nil }

        let query = issueStates.filter(
            self.issueId == issueId &&
            self.instanceId == instanceId.uuidString &&
            self.filterId == filterId.uuidString
        ).limit(1)

        guard let row = try db.pluck(query) else {
            return nil
        }

        // Safely unwrap UUIDs - return nil if invalid
        guard let instanceUUID = UUID(uuidString: row[self.instanceId]),
              let filterUUID = UUID(uuidString: row[self.filterId]) else {
            return nil
        }

        return IssueState(
            issueId: row[self.issueId],
            issueKey: row[self.issueKey],
            instanceId: instanceUUID,
            filterId: filterUUID,
            summary: row[self.summary],
            status: row[self.status],
            updatedAt: row[self.updatedAt],
            lastNotifiedAt: row[self.lastNotifiedAt],
            isRead: row[self.isRead]
        )
    }

    func markAsNotified(issueId: String, instanceId: UUID, filterId: UUID, at date: Date) throws {
        guard let db = db else { return }

        let query = issueStates.filter(
            self.issueId == issueId &&
            self.instanceId == instanceId.uuidString &&
            self.filterId == filterId.uuidString
        )

        try db.run(query.update(lastNotifiedAt <- date))
    }

    func deleteStatesForInstance(_ instanceId: UUID) throws {
        guard let db = db else { return }

        let query = issueStates.filter(self.instanceId == instanceId.uuidString)
        try db.run(query.delete())
    }

    func deleteStatesForFilter(filterId: UUID) throws {
        guard let db = db else { return }

        let query = issueStates.filter(self.filterId == filterId.uuidString)
        try db.run(query.delete())
    }

    func getAllIssueStates() throws -> [IssueState] {
        guard let db = db else { return [] }

        var states: [IssueState] = []

        for row in try db.prepare(issueStates.order(updatedAt.desc)) {
            // Safely unwrap UUIDs - skip rows with invalid data
            guard let instanceUUID = UUID(uuidString: row[instanceId]),
                  let filterUUID = UUID(uuidString: row[filterId]) else {
                continue // Skip invalid row
            }

            let state = IssueState(
                issueId: row[issueId],
                issueKey: row[issueKey],
                instanceId: instanceUUID,
                filterId: filterUUID,
                summary: row[summary],
                status: row[status],
                updatedAt: row[updatedAt],
                lastNotifiedAt: row[lastNotifiedAt],
                isRead: row[isRead]
            )
            states.append(state)
        }

        return states
    }

    func markAsRead(issueId: String, instanceId: UUID, filterId: UUID) throws {
        guard let db = db else { return }

        let query = issueStates.filter(
            self.issueId == issueId &&
            self.instanceId == instanceId.uuidString &&
            self.filterId == filterId.uuidString
        )

        try db.run(query.update(isRead <- true))
    }

    func markMultipleAsRead(issueIds: [String]) throws {
        guard let db = db else { return }

        let query = issueStates.filter(issueIds.contains(issueId))
        try db.run(query.update(isRead <- true))
    }

    func markAllAsRead() throws {
        guard let db = db else { return }

        try db.run(issueStates.update(isRead <- true))
    }
}
