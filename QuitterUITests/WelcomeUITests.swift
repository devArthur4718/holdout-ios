import XCTest

final class WelcomeUITests: XCTestCase {

    @MainActor
    func testWelcomeShowsContentAndOpensNewHabit() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Trophies at every hour and day milestone"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Skip to the demo data"].exists)

        app.buttons["Add my first habit"].tap()
        XCTAssertTrue(app.navigationBars["New habit"].waitForExistence(timeout: 5))
    }
}
