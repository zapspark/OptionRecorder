import AppKit
import XCTest

@MainActor
final class OptionRecoderAppUITests: XCTestCase {
    func testCreateWheelPositionAddPutAndAssignIt() throws {
        let storeURL = temporaryStoreURL()
        try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())

        let app = XCUIApplication()
        app.launchEnvironment["OPTIONRECORDER_STORE_URL"] = storeURL.path()

        addTeardownBlock {
            app.terminate()
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        app.launch()
        app.activate()

        let addPositionButton = app.buttons["add-position-button"]
        XCTAssertTrue(addPositionButton.waitForExistence(timeout: 15), app.debugDescription)

        addPositionButton.click()
        let tickerField = app.textFields["new-position-ticker-field"]
        XCTAssertTrue(tickerField.waitForExistence(timeout: 5))
        replaceText(in: tickerField, with: "AAPL")

        let submitButton = app.buttons["new-position-submit-button"]
        XCTAssertTrue(
            submitButton.waitForEnabled(timeout: 5),
            app.debugDescription
        )
        submitButton.click()

        XCTAssertTrue(app.staticTexts["AAPL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Wheel"].waitForExistence(timeout: 5))

        replaceText(in: app.textFields["trade-strike-field"], with: "180")
        replaceText(in: app.textFields["trade-premium-field"], with: "2.50")
        app.buttons["add-trade-form-button"].click()

        XCTAssertTrue(app.staticTexts["Put"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Open"].waitForExistence(timeout: 5))

        let statusPicker = app.popUpButtons["trade-status-picker"]
        XCTAssertTrue(statusPicker.waitForExistence(timeout: 5), app.debugDescription)
        statusPicker.click()

        let assignedMenuItem = app.menuItems["Assigned"]
        XCTAssertTrue(assignedMenuItem.waitForExistence(timeout: 5))
        assignedMenuItem.click()

        XCTAssertTrue(app.staticTexts["Assigned"].waitForExistence(timeout: 5))
        let sharesMetric = app.staticTexts["shares-metric-value"]
        XCTAssertTrue(sharesMetric.waitForValue("100", timeout: 5), app.debugDescription)
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "OptionRecoderAppUITests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "OptionRecorder.sqlite", directoryHint: .notDirectory)
    }

    private func replaceText(in element: XCUIElement, with text: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        element.click()
        element.typeKey("a", modifierFlags: [.command])
        element.typeKey(.delete, modifierFlags: [])
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        element.typeKey("v", modifierFlags: [.command])
    }
}

private extension XCUIElement {
    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    func waitForValue(_ expectedValue: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND value == %@", expectedValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
