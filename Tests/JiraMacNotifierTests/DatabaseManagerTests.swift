import XCTest
@testable import JiraMacNotifier

final class DatabaseManagerTests: XCTestCase {
    var databaseManager: DatabaseManager!
    let testInstanceId = UUID()
    let testFilterId = UUID()

    override func setUp() {
        super.setUp()
        databaseManager = DatabaseManager()
    }

    override func tearDown() {
        try? databaseManager.deleteStatesForInstance(testInstanceId)
        super.tearDown()
    }

    func testSaveAndRetrieveIssueState() throws {
        let state = IssueState(
            issueId: "10001",
            issueKey: "TEST-1",
            instanceId: testInstanceId,
            filterId: testFilterId,
            summary: "Test issue",
            status: "Open",
            updatedAt: Date(),
            lastNotifiedAt: nil
        )

        try databaseManager.saveIssueState(state)

        let retrieved = try databaseManager.getIssueState(
            issueId: state.issueId,
            instanceId: testInstanceId,
            filterId: testFilterId
        )

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.issueId, state.issueId)
        XCTAssertEqual(retrieved?.issueKey, state.issueKey)
        XCTAssertEqual(retrieved?.summary, state.summary)
        XCTAssertEqual(retrieved?.status, state.status)
    }

    func testUpdateIssueState() throws {
        let originalState = IssueState(
            issueId: "10001",
            issueKey: "TEST-1",
            instanceId: testInstanceId,
            filterId: testFilterId,
            summary: "Original summary",
            status: "Open",
            updatedAt: Date(),
            lastNotifiedAt: nil
        )

        try databaseManager.saveIssueState(originalState)

        let updatedState = IssueState(
            issueId: "10001",
            issueKey: "TEST-1",
            instanceId: testInstanceId,
            filterId: testFilterId,
            summary: "Updated summary",
            status: "In Progress",
            updatedAt: Date(),
            lastNotifiedAt: Date()
        )

        try databaseManager.saveIssueState(updatedState)

        let retrieved = try databaseManager.getIssueState(
            issueId: "10001",
            instanceId: testInstanceId,
            filterId: testFilterId
        )

        XCTAssertEqual(retrieved?.summary, "Updated summary")
        XCTAssertEqual(retrieved?.status, "In Progress")
        XCTAssertNotNil(retrieved?.lastNotifiedAt)
    }

    func testMarkAsNotified() throws {
        let state = IssueState(
            issueId: "10001",
            issueKey: "TEST-1",
            instanceId: testInstanceId,
            filterId: testFilterId,
            summary: "Test issue",
            status: "Open",
            updatedAt: Date(),
            lastNotifiedAt: nil
        )

        try databaseManager.saveIssueState(state)

        let notificationDate = Date()
        try databaseManager.markAsNotified(
            issueId: state.issueId,
            instanceId: testInstanceId,
            filterId: testFilterId,
            at: notificationDate
        )

        let retrieved = try databaseManager.getIssueState(
            issueId: state.issueId,
            instanceId: testInstanceId,
            filterId: testFilterId
        )

        XCTAssertNotNil(retrieved?.lastNotifiedAt)
    }

    func testDeleteStatesForInstance() throws {
        let state1 = IssueState(
            issueId: "10001",
            issueKey: "TEST-1",
            instanceId: testInstanceId,
            filterId: testFilterId,
            summary: "Test issue 1",
            status: "Open",
            updatedAt: Date(),
            lastNotifiedAt: nil
        )

        let state2 = IssueState(
            issueId: "10002",
            issueKey: "TEST-2",
            instanceId: testInstanceId,
            filterId: testFilterId,
            summary: "Test issue 2",
            status: "Open",
            updatedAt: Date(),
            lastNotifiedAt: nil
        )

        try databaseManager.saveIssueState(state1)
        try databaseManager.saveIssueState(state2)

        try databaseManager.deleteStatesForInstance(testInstanceId)

        let retrieved1 = try databaseManager.getIssueState(
            issueId: state1.issueId,
            instanceId: testInstanceId,
            filterId: testFilterId
        )

        let retrieved2 = try databaseManager.getIssueState(
            issueId: state2.issueId,
            instanceId: testInstanceId,
            filterId: testFilterId
        )

        XCTAssertNil(retrieved1)
        XCTAssertNil(retrieved2)
    }

    func testGetNonExistentIssueState() throws {
        let retrieved = try databaseManager.getIssueState(
            issueId: "non-existent",
            instanceId: UUID(),
            filterId: UUID()
        )

        XCTAssertNil(retrieved)
    }
}
