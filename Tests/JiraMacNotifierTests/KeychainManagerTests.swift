import XCTest
@testable import JiraMacNotifier

final class KeychainManagerTests: XCTestCase {
    var keychainManager: KeychainManager!
    let testInstanceId = "test-instance-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        keychainManager = KeychainManager.shared
    }

    override func tearDown() {
        try? keychainManager.deleteToken(for: testInstanceId)
        super.tearDown()
    }

    func testSaveAndRetrieveToken() throws {
        let token = "test-token-123"

        try keychainManager.saveToken(token, for: testInstanceId)
        let retrievedToken = try keychainManager.getToken(for: testInstanceId)

        XCTAssertEqual(token, retrievedToken)
    }

    func testUpdateToken() throws {
        let originalToken = "original-token"
        let updatedToken = "updated-token"

        try keychainManager.saveToken(originalToken, for: testInstanceId)
        try keychainManager.saveToken(updatedToken, for: testInstanceId)

        let retrievedToken = try keychainManager.getToken(for: testInstanceId)
        XCTAssertEqual(updatedToken, retrievedToken)
    }

    func testDeleteToken() throws {
        let token = "test-token"

        try keychainManager.saveToken(token, for: testInstanceId)
        try keychainManager.deleteToken(for: testInstanceId)

        XCTAssertThrowsError(try keychainManager.getToken(for: testInstanceId)) { error in
            XCTAssertTrue(error is KeychainError)
            if case KeychainError.itemNotFound = error {
                // Expected error
            } else {
                XCTFail("Expected itemNotFound error")
            }
        }
    }

    func testHasToken() throws {
        XCTAssertFalse(keychainManager.hasToken(for: testInstanceId))

        try keychainManager.saveToken("test-token", for: testInstanceId)
        XCTAssertTrue(keychainManager.hasToken(for: testInstanceId))

        try keychainManager.deleteToken(for: testInstanceId)
        XCTAssertFalse(keychainManager.hasToken(for: testInstanceId))
    }

    func testRetrieveNonExistentToken() {
        XCTAssertThrowsError(try keychainManager.getToken(for: "non-existent")) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }
}
