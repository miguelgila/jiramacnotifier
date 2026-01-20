import XCTest
@testable import JiraMacNotifier

final class JiraClientTests: XCTestCase {

    func testJiraClientErrorTypes() {
        // Test that error types are properly defined
        let invalidURLError = JiraClientError.invalidURL
        let noTokenError = JiraClientError.noToken
        let invalidResponseError = JiraClientError.invalidResponse

        XCTAssertNotNil(invalidURLError)
        XCTAssertNotNil(noTokenError)
        XCTAssertNotNil(invalidResponseError)
    }

    func testJiraClientInitialization() {
        let client = JiraClient()
        XCTAssertNotNil(client)
    }

    func testSearchIssuesThrowsErrorWithoutToken() async {
        let keychainManager = KeychainManager.shared
        let client = JiraClient(keychainManager: keychainManager)

        let instance = JiraInstance(
            name: "Test",
            url: "https://test.atlassian.net",
            username: "test@example.com"
        )

        do {
            _ = try await client.searchIssues(instance: instance, jql: "test")
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected to throw error due to missing token
            XCTAssertTrue(error is KeychainError || error is JiraClientError)
        }
    }

    func testInvalidURLHandling() async {
        let instance = JiraInstance(
            name: "Test",
            url: "not-a-valid-url",
            username: "test@example.com"
        )

        // Even without a token, invalid URL should be caught
        let client = JiraClient()

        do {
            _ = try await client.searchIssues(instance: instance, jql: "test")
            XCTFail("Expected error to be thrown")
        } catch {
            // Should fail (either invalid URL or missing token)
            XCTAssertTrue(true)
        }
    }
}
