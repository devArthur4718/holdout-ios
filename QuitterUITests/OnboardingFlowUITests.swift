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
        XCTAssertTrue(app.staticTexts["From now on every minute counts for something. Your first trophy is at 1 day."].exists)
        let arc = app.descendants(matching: .any)["elapsed"]
        XCTAssertTrue(arc.exists)
        XCTAssertTrue(arc.label.hasSuffix("of the way to 1 day."))

        app.buttons["Go to my habits"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Add my first habit"].exists)
        XCTAssertTrue(app.staticTexts["BET-FREE FOR"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Next trophy — 1 day")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Online poker"].exists) // its chip
        XCTAssertTrue(app.tabBars.buttons["Today"].exists)

        // Resetting the counter asks first (it logs a slip), then restarts it.
        XCTAssertFalse(app.buttons["I have an urge"].exists)
        app.buttons["Reset Counter"].tap()
        XCTAssertTrue(app.staticTexts["Log a slip"].waitForExistence(timeout: 5))
        app.buttons["Stress"].tap()
        XCTAssertTrue(app.buttons["Stress"].isSelected)
        app.buttons["confirmSlip"].tap()
        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["toast"].label.hasPrefix("Counter reset"))
        XCTAssertFalse(app.staticTexts["Log a slip"].exists)

        // The habit's detail: tabs and reasons.
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
        XCTAssertFalse(app.buttons["Urge timer"].exists)
        XCTAssertTrue(app.buttons["Reset Counter"].exists)
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
        // With the software keyboard up, Save sits under it; close the keyboard first.
        let done = app.toolbars.buttons["Done"]
        if done.exists { done.tap() }
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Rolling tobacco"].waitForExistence(timeout: 5))

        app.buttons["More options"].tap()
        app.buttons["Delete habit"].tap()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No habits yet"].waitForExistence(timeout: 5))
    }
}
