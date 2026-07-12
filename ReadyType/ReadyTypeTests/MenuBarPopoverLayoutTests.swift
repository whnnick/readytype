import XCTest
@testable import ReadyType

final class MenuBarPopoverLayoutTests: XCTestCase {
    func testPopoverUsesStableDesktopDimensions() {
        XCTAssertEqual(MenuBarPopoverLayout.width, 318)
        XCTAssertEqual(MenuBarPopoverLayout.height, 430)
    }
}
