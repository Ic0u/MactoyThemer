import XCTest

final class WorkspaceNavigationTests: XCTestCase {
    @MainActor
    func testWorkspacesAndUpdateMenu() {
        let app = XCUIApplication()
        app.launch()
        let window = app.windows["MactoyThemer"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["Drop themes here"].exists)
        capture(window, named: "Install workspace")

        window.radioButtons["Settings"].click()
        XCTAssertTrue(window.staticTexts["Default theme"].waitForExistence(timeout: 3))
        XCTAssertTrue(window.buttons["Save settings"].exists)
        capture(window, named: "Settings workspace")

        window.radioButtons["Remove"].click()
        XCTAssertTrue(window.staticTexts["Installed theme"].waitForExistence(timeout: 3))
        XCTAssertTrue(window.buttons["Remove selected theme"].exists)
        XCTAssertTrue(window.buttons["Remove all themes"].exists)
        capture(window, named: "Remove workspace")

        window.radioButtons["Install"].click()
        XCTAssertTrue(window.buttons["Add themes…"].exists)
        app.menuBars.menuBarItems["MactoyThemer"].click()
        XCTAssertTrue(app.menuItems["Check for Updates…"].exists)
        XCTAssertTrue(app.menuItems["Automatically Check for Updates"].exists)
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    private func capture(_ window: XCUIElement, named name: String) {
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
