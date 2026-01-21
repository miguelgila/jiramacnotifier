import XCTest
@testable import JiraMacNotifier

final class ConfigurationManagerTests: XCTestCase {
    var configManager: ConfigurationManager!

    override func setUp() {
        super.setUp()
        configManager = ConfigurationManager()
        // Clear any existing instances
        configManager.instances = []
        configManager.saveConfiguration()
    }

    override func tearDown() {
        // Clean up test instances
        for instance in configManager.instances {
            try? configManager.deleteInstance(instance)
        }
        super.tearDown()
    }

    func testAddInstance() throws {
        let instance = JiraInstance(
            name: "Test Instance",
            url: "https://test.atlassian.net",
            username: "test@example.com"
        )
        let token = "test-token-123"

        try configManager.addInstance(instance, token: token)

        XCTAssertEqual(configManager.instances.count, 1)
        XCTAssertEqual(configManager.instances.first?.name, instance.name)
        XCTAssertTrue(configManager.hasToken(for: instance))
    }

    func testUpdateInstance() throws {
        var instance = JiraInstance(
            name: "Original Name",
            url: "https://test.atlassian.net",
            username: "test@example.com"
        )
        let token = "test-token"

        try configManager.addInstance(instance, token: token)

        instance.name = "Updated Name"
        instance.pollIntervalMinutes = 15

        try configManager.updateInstance(instance)

        XCTAssertEqual(configManager.instances.first?.name, "Updated Name")
        XCTAssertEqual(configManager.instances.first?.pollIntervalMinutes, 15)
    }

    func testDeleteInstance() throws {
        let instance = JiraInstance(
            name: "Test Instance",
            url: "https://test.atlassian.net",
            username: "test@example.com"
        )
        let token = "test-token"

        try configManager.addInstance(instance, token: token)
        XCTAssertEqual(configManager.instances.count, 1)

        try configManager.deleteInstance(instance)

        XCTAssertEqual(configManager.instances.count, 0)
        XCTAssertFalse(configManager.hasToken(for: instance))
    }

    func testPersistence() throws {
        let instance = JiraInstance(
            name: "Test Instance",
            url: "https://test.atlassian.net",
            username: "test@example.com"
        )
        let token = "test-token"

        try configManager.addInstance(instance, token: token)

        // Create a new config manager to test persistence
        let newConfigManager = ConfigurationManager()

        XCTAssertEqual(newConfigManager.instances.count, 1)
        XCTAssertEqual(newConfigManager.instances.first?.name, instance.name)
        XCTAssertEqual(newConfigManager.instances.first?.url, instance.url)

        // Clean up
        try newConfigManager.deleteInstance(instance)
    }

    func testMultipleInstances() throws {
        let instance1 = JiraInstance(
            name: "Instance 1",
            url: "https://test1.atlassian.net",
            username: "test1@example.com"
        )

        let instance2 = JiraInstance(
            name: "Instance 2",
            url: "https://test2.atlassian.net",
            username: "test2@example.com"
        )

        try configManager.addInstance(instance1, token: "token1")
        try configManager.addInstance(instance2, token: "token2")

        XCTAssertEqual(configManager.instances.count, 2)
        XCTAssertTrue(configManager.hasToken(for: instance1))
        XCTAssertTrue(configManager.hasToken(for: instance2))
    }
}
