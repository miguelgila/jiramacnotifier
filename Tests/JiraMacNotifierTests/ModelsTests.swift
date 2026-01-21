import XCTest
@testable import JiraMacNotifier

final class ModelsTests: XCTestCase {

    func testJiraInstanceCoding() throws {
        let filter = JiraFilter(name: "Test Filter", jql: "assignee = currentUser()")
        let instance = JiraInstance(
            name: "Test Instance",
            url: "https://test.atlassian.net",
            username: "test@example.com",
            pollIntervalMinutes: 10,
            filters: [filter]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(instance)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JiraInstance.self, from: data)

        XCTAssertEqual(instance.id, decoded.id)
        XCTAssertEqual(instance.name, decoded.name)
        XCTAssertEqual(instance.url, decoded.url)
        XCTAssertEqual(instance.username, decoded.username)
        XCTAssertEqual(instance.pollIntervalMinutes, decoded.pollIntervalMinutes)
        XCTAssertEqual(instance.filters.count, decoded.filters.count)
        XCTAssertEqual(instance.filters.first?.jql, decoded.filters.first?.jql)
    }

    func testJiraFilterEquatable() {
        let filter1 = JiraFilter(id: UUID(), name: "Filter 1", jql: "test JQL")
        let filter2 = JiraFilter(id: filter1.id, name: "Filter 1", jql: "test JQL")
        let filter3 = JiraFilter(name: "Filter 2", jql: "different JQL")

        XCTAssertEqual(filter1, filter2)
        XCTAssertNotEqual(filter1, filter3)
    }

    func testIssueStateHasChanged() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600)

        let stateNotNotified = IssueState(
            issueId: "1",
            issueKey: "TEST-1",
            instanceId: UUID(),
            filterId: UUID(),
            summary: "Test",
            status: "Open",
            updatedAt: now,
            lastNotifiedAt: nil
        )
        XCTAssertTrue(stateNotNotified.hasChanged)

        let stateChanged = IssueState(
            issueId: "1",
            issueKey: "TEST-1",
            instanceId: UUID(),
            filterId: UUID(),
            summary: "Test",
            status: "Open",
            updatedAt: now,
            lastNotifiedAt: earlier
        )
        XCTAssertTrue(stateChanged.hasChanged)

        let stateNotChanged = IssueState(
            issueId: "1",
            issueKey: "TEST-1",
            instanceId: UUID(),
            filterId: UUID(),
            summary: "Test",
            status: "Open",
            updatedAt: earlier,
            lastNotifiedAt: now
        )
        XCTAssertFalse(stateNotChanged.hasChanged)
    }

    func testJiraSearchResponseDecoding() throws {
        let json = """
        {
            "startAt": 0,
            "maxResults": 50,
            "total": 1,
            "issues": [
                {
                    "id": "10001",
                    "key": "TEST-1",
                    "fields": {
                        "summary": "Test issue",
                        "status": {
                            "name": "Open"
                        },
                        "updated": "2024-01-01T12:00:00.000+0000",
                        "assignee": {
                            "displayName": "John Doe"
                        },
                        "reporter": {
                            "displayName": "Jane Smith"
                        },
                        "priority": {
                            "name": "High"
                        }
                    }
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(JiraSearchResponse.self, from: data)

        XCTAssertEqual(response.total, 1)
        XCTAssertEqual(response.issues.count, 1)
        XCTAssertEqual(response.issues.first?.key, "TEST-1")
        XCTAssertEqual(response.issues.first?.fields.summary, "Test issue")
        XCTAssertEqual(response.issues.first?.fields.status.name, "Open")
    }
}
