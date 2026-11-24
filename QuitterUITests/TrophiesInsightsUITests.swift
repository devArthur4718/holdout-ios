import XCTest

final class TrophiesInsightsUITests: XCTestCase {

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

    @MainActor
    func testInsightsCountASlipInItsPartOfTheDay() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingHabitDaysAgo", "3", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["Not enough data yet — this fills in as you log slips and urges."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Past streaks show up here after a slip."].exists)

        app.tabBars.buttons["Today"].tap()
        app.buttons["Log slip"].tap()
        app.buttons["Reset counter"].tap()
        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 5))

        let hour = Calendar.current.component(.hour, from: .now)
        let part = switch hour {
        case 5..<12: "Morning"
        case 12..<17: "Afternoon"
        case 17..<22: "Evening"
        default: "Night"
        }
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["\(part): 1 slip, 0 urges"].waitForExistence(timeout: 5))
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any.matching(NSPredicate(format: "label CONTAINS %@", "Best")).firstMatch.exists)
        XCTAssertTrue(any.matching(NSPredicate(format: "label CONTAINS %@", "Current")).firstMatch.exists)
    }
}
