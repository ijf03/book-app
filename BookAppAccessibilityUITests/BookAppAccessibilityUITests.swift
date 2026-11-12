import XCTest
import XCUIAutomation

final class BookAppAccessibilityUITests: XCTestCase {
    /// Audits the launch screen without signing in, submitting forms, or changing stored data.
    /// Run on a dedicated simulator; authenticated screens need the manual checklist as well.
    @MainActor
    func testLaunchScreenAccessibility() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "edu.monash.BookApp")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        let ready = NSPredicate { _, _ in
            app.buttons["auth.submit"].exists || app.tabBars.firstMatch.exists ||
                app.buttons["legacy.import"].exists || app.buttons["storage.retry"].exists
        }
        let expectation = XCTNSPredicateExpectation(predicate: ready, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 20), .completed)
        try app.performAccessibilityAudit(for: .all)
    }
}
