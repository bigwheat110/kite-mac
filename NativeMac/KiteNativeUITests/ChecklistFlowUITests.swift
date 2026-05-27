import XCTest

final class ChecklistFlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private let japaneseID = "00000000-0000-0000-0000-000000000001"
    private let hairID = "00000000-0000-0000-0000-000000000002"
    private let englishID = "00000000-0000-0000-0000-000000000003"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitest-reset-state")
        app.launch()
    }

    func testTapTitleStartsInlineEditing() throws {
        let title = app.staticTexts["habit-title-\(japaneseID)"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()

        let editor = app.textFields["habit-editor-\(japaneseID)"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
    }

    func testInlineRenameOnlyAffectsToday() throws {
        let title = app.staticTexts["habit-title-\(japaneseID)"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()

        let editor = app.textFields["habit-editor-\(japaneseID)"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "德育")
        editor.typeText(XCUIKeyboardKey.return.rawValue)

        XCTAssertTrue(app.staticTexts["德育"].waitForExistence(timeout: 5))

        app.buttons["week-next-button"].tap()
        XCTAssertFalse(app.staticTexts["德育"].exists)
    }

    func testContextMenuTemplateRenameAffectsTodayAndFuture() throws {
        let row = app.otherElements["habit-row-\(hairID)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.rightClick()

        let rename = app.menuItems["修改模板名（今天及以后）"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        rename.tap()

        let editor = app.textFields["habit-editor-\(hairID)"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "政治")
        editor.typeText(XCUIKeyboardKey.return.rawValue)

        XCTAssertTrue(app.staticTexts["政治"].waitForExistence(timeout: 5))
        app.buttons["week-next-button"].tap()
        XCTAssertTrue(app.staticTexts["政治"].waitForExistence(timeout: 5))
        app.buttons["week-prev-button"].tap()
        app.buttons["week-prev-button"].tap()
        XCTAssertFalse(app.staticTexts["政治"].exists)
    }

    func testToggleCompletionMovesRowToBottomAndBack() throws {
        let toggle = app.buttons["habit-toggle-\(englishID)"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()

        let rows = app.otherElements.matching(identifier: "habit-row-\(englishID)")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))

        toggle.tap()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
    }

    func testAddHabitPersists() throws {
        let input = app.textFields["add-habit-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("新事项")
        app.buttons["add-habit-button"].tap()

        XCTAssertTrue(app.staticTexts["新事项"].waitForExistence(timeout: 5))

        app.terminate()
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["新事项"].waitForExistence(timeout: 5))
    }
}
