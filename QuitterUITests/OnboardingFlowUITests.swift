import XCTest

final class OnboardingFlowUITests: XCTestCase {

    @MainActor
    func testWelcomeToNewHabitToCounterToHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] // Empty, throwaway database.
        app.launch()

        app.buttons["Add my first habit"].tap()
        XCTAssertTrue(app.navigationBars["New habit"].waitForExistence(timeout: 5))

        let name = app.textFields["name"]
        XCTAssertEqual(name.value as? String, "Cigarettes")

        // Picking another kind swaps the default name.
        app.buttons["Gambling"].tap()
        XCTAssertEqual(name.value as? String, "Gambling")

        // A blank name disables Start.
        // The text is right-aligned, so tap its end to put the cursor after it.
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10))
        XCTAssertFalse(app.buttons["Start the counter"].isEnabled)
        name.typeText("Online poker")

        app.buttons["Start the counter"].tap()

        // The counter reads the saved habit back.
        XCTAssertTrue(app.staticTexts["Your counter is running"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Online poker"].exists)
        XCTAssertTrue(app.staticTexts["elapsed"].exists)

        app.buttons["Go to my habits"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Add my first habit"].exists)
        XCTAssertTrue(app.staticTexts["BET-FREE FOR"].exists)
        XCTAssertTrue(app.buttons["Online poker"].exists) // its chip
        XCTAssertTrue(app.tabBars.buttons["Habits"].exists)

        // Logging a slip asks first, then restarts the counter.
        app.buttons["Log slip"].tap()
        XCTAssertTrue(app.staticTexts["Log a slip"].waitForExistence(timeout: 5))
        app.buttons["Stress"].tap()
        XCTAssertTrue(app.buttons["Stress"].isSelected)
        app.buttons["Reset counter"].tap()
        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["toast"].label.hasPrefix("Counter reset"))
        XCTAssertFalse(app.staticTexts["Log a slip"].exists)

        // The urge timer runs, and riding it out is confirmed on the home.
        XCTAssertTrue(app.staticTexts["toast"].waitForNonExistence(timeout: 6))
        app.buttons["I have an urge"].tap()
        XCTAssertTrue(app.staticTexts["RIDE IT OUT"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Breathe in for four. Hold for four. Out for six."].exists)
        app.buttons["I got through it"].tap()
        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["toast"].label, "Urge logged and outlasted. That is 1 this month.")

        // The habit's detail: tabs, and a reason that the urge timer then shows.
        XCTAssertTrue(app.staticTexts["toast"].waitForNonExistence(timeout: 6))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Next trophy")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Online poker"].waitForExistence(timeout: 5))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.staticTexts["Clean"].exists)
        app.buttons["Reasons"].tap()
        app.buttons["Add a reason"].tap()
        let reasonField = app.textFields.firstMatch
        XCTAssertTrue(reasonField.waitForExistence(timeout: 5))
        reasonField.typeText("For my lungs")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["For my lungs"].waitForExistence(timeout: 5))
        app.buttons["Urge timer"].tap()
        XCTAssertTrue(app.staticTexts["“For my lungs”"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        app.navigationBars.buttons.firstMatch.tap() // Back
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        // Settings: deleting everything returns to the welcome screen.
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Export as CSV"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Delete all data")).firstMatch.tap()
        app.buttons["Delete everything"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Add my first habit"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEditAndDeleteAHabit() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.buttons["Add my first habit"].tap()
        app.buttons["Start the counter"].tap()
        app.buttons["Go to my habits"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Next trophy")).firstMatch.tap()

        app.buttons["More options"].tap()
        app.buttons["Edit habit"].tap()
        XCTAssertTrue(app.navigationBars["Edit habit"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.datePickers.firstMatch.exists)
        let name = app.textFields["name"]
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "Rolling tobacco")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Rolling tobacco"].waitForExistence(timeout: 5))

        app.buttons["More options"].tap()
        app.buttons["Delete habit"].tap()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No habits yet"].waitForExistence(timeout: 5))
    }
}
