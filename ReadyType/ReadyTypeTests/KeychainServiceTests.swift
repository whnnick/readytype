import XCTest
@testable import ReadyType

final class KeychainServiceTests: XCTestCase {
    private var service: KeychainService!
    private var serviceName: String!
    private let account = "deepseek"

    override func setUpWithError() throws {
        try super.setUpWithError()
        serviceName = "ReadyTypeTests.\(UUID().uuidString)"
        service = KeychainService(service: serviceName)

        do {
            try service.saveAPIKey("probe", account: account)
            try service.deleteAPIKey(account: account)
        } catch {
            throw XCTSkip("System Keychain is unavailable in this test environment: \(error)")
        }
    }

    override func tearDown() {
        try? service.deleteAPIKey(account: account)
        service = nil
        serviceName = nil
        super.tearDown()
    }

    func testSaveAndLoadAPIKeyFromKeychain() throws {
        try service.saveAPIKey("test-secret", account: account)

        XCTAssertEqual(try service.loadAPIKey(account: account), "test-secret")
        XCTAssertTrue(try service.hasAPIKey(account: account))
    }

    func testSaveUpdatesExistingAPIKey() throws {
        try service.saveAPIKey("old-secret", account: account)

        try service.saveAPIKey("new-secret", account: account)

        XCTAssertEqual(try service.loadAPIKey(account: account), "new-secret")
    }

    func testDeleteRemovesAPIKey() throws {
        try service.saveAPIKey("test-secret", account: account)

        try service.deleteAPIKey(account: account)

        XCTAssertNil(try service.loadAPIKey(account: account))
        XCTAssertFalse(try service.hasAPIKey(account: account))
    }
}
