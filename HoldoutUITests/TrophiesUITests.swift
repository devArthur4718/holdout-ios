import XCTest

final class TrophiesUITests: XCTestCase {

    @MainActor
    func testTrophiesShowEarnedAndNextAndTakeAPersonalGoal() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingHabitDaysAgo", "10", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        app.tabBars.buttons["Trophies"].tap()
        XCTAssertTrue(app.navigationBars["Trophies"].waitForExistence(timeout: 5))
        let earned = NSPredicate(format: "label BEGINSWITH %@", "1 week, earned")
        XCTAssertTrue(app.descendants(matching: .any).matching(earned).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["30 days, not earned yet. Next"].exists)
        XCTAssertTrue(app.staticTexts["Next trophy — 30 days"].exists)

        app.buttons["Add personal goal"].tap()
        let days = app.textFields["goalDays"]
        XCTAssertTrue(days.waitForExistence(timeout: 5))
        days.typeText("30")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["There's already a trophy at 30 days."].waitForExistence(timeout: 5))

        days.tap()
        days.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "15")
        app.textFields["goalName"].tap()
        app.textFields["goalName"].typeText("Beach trip")
        app.navigationBars.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Next trophy — Beach trip"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Personal goal: Beach trip, 15 days, not earned yet. Next"].exists)
    }
}
