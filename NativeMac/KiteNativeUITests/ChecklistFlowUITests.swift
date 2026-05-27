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
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testTapTitleStartsInlineEditing() throws {
        let title = element("habit-title-\(japaneseID)")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()

        let editor = element("habit-editor-\(japaneseID)")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
    }

    func testInlineRenameOnlyAffectsToday() throws {
        let title = element("habit-title-\(japaneseID)")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()

        let editor = element("habit-editor-\(japaneseID)")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "德育")
        editor.typeText(XCUIKeyboardKey.return.rawValue)

        XCTAssertTrue(app.otherElements.matching(NSPredicate(format: "label == %@", "德育")).firstMatch.waitForExistence(timeout: 5))

        app.buttons["week-next-button"].tap()
        XCTAssertFalse(app.otherElements.matching(NSPredicate(format: "label == %@", "德育")).firstMatch.exists)
    }

    func testContextMenuTemplateRenameAffectsTodayAndFuture() throws {
        let title = element("habit-title-\(hairID)")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.rightClick()

        let rename = app.menuItems["修改模板名（从这一天起）"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        rename.tap()

        let editor = element("habit-editor-\(hairID)")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "政治")
        editor.typeText(XCUIKeyboardKey.return.rawValue)

        XCTAssertTrue(app.otherElements.matching(NSPredicate(format: "label == %@", "政治")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["week-next-button"].tap()
        XCTAssertTrue(app.otherElements.matching(NSPredicate(format: "label == %@", "政治")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["week-prev-button"].tap()
        app.buttons["week-prev-button"].tap()
        XCTAssertFalse(app.otherElements.matching(NSPredicate(format: "label == %@", "政治")).firstMatch.exists)
    }

    func testToggleCompletionMovesRowToBottomAndBack() throws {
        let row = element("habit-row-\(englishID)")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let originalY = row.frame.minY

        let toggle = element("habit-toggle-\(englishID)")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()

        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(row.frame.minY, originalY)

        toggle.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.frame.minY, originalY, accuracy: 1.0)
    }

    func testAddHabitPersists() throws {
        let input = app.textFields["add-habit-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("新事项")
        app.buttons["add-habit-button"].tap()

        XCTAssertTrue(app.otherElements.matching(NSPredicate(format: "label == %@", "新事项")).firstMatch.waitForExistence(timeout: 5))

        app.terminate()
        app = XCUIApplication()
        app.launch()
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.otherElements.matching(NSPredicate(format: "label == %@", "新事项")).firstMatch.waitForExistence(timeout: 5))
    }
}
