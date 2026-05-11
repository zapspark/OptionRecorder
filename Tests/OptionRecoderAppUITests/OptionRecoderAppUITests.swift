import AppKit
import XCTest

@MainActor
final class OptionRecoderAppUITests: XCTestCase {
    func testCreateWheelPositionAddCashSecuredPutAndAssignIt() throws {
        let storeURL = temporaryStoreURL()
        try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())

        let app = XCUIApplication()
        app.launchEnvironment["OPTIONRECORDER_STORE_URL"] = storeURL.path()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-NSQuitAlwaysKeepsWindows", "NO"
        ]

        addTeardownBlock {
            app.terminate()
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        app.launch()
        app.activate()

        let addPositionButton = ensureMainWindow(in: app)

        addPositionButton.click()
        let tickerField = app.textFields["new-position-ticker-field"]
        XCTAssertTrue(tickerField.waitForExistence(timeout: 5))
        replaceText(in: tickerField, with: "AAPL")

        let contractQuantityField = app.textFields["new-position-contract-quantity-field"]
        XCTAssertTrue(contractQuantityField.waitForExistence(timeout: 5))
        XCTAssertTrue(contractQuantityField.waitForValue("100", timeout: 5), app.debugDescription)

        let submitButton = app.buttons["new-position-submit-button"]
        XCTAssertTrue(
            submitButton.waitForEnabled(timeout: 5),
            app.debugDescription
        )
        submitButton.click()

        let sharesMetric = app.staticTexts["shares-metric-value"]
        XCTAssertTrue(sharesMetric.waitForExistence(timeout: 5), app.debugDescription)
        assertMetrics(
            app,
            shares: "0",
            premium: "$0.00",
            adjustedCost: "$0.00",
            openTrades: "0"
        )

        addTrade(app, strike: "180", premium: "2.50")

        XCTAssertTrue(app.staticTexts["Cash-Secured Put"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Open"].waitForExistence(timeout: 5))
        assertMetrics(
            app,
            shares: "0",
            premium: "$250.00",
            adjustedCost: "$0.00",
            openTrades: "1"
        )

        XCTAssertTrue(app.buttons["trade-expired-button"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["trade-rolled-button"].waitForExistence(timeout: 5), app.debugDescription)
        selectQuickStatus("trade-assigned-button", in: app)

        XCTAssertTrue(app.staticTexts["Assigned"].waitForExistence(timeout: 5))
        assertMetrics(
            app,
            shares: "100",
            premium: "$250.00",
            adjustedCost: "$177.50",
            openTrades: "0"
        )

        selectStatus("Expired", in: app)

        XCTAssertTrue(app.staticTexts["Expired"].waitForExistence(timeout: 5))
        assertMetrics(
            app,
            shares: "0",
            premium: "$250.00",
            adjustedCost: "$0.00",
            openTrades: "0"
        )

        let activeCloseButton = app.radioButtons["Active Close"]
        XCTAssertTrue(activeCloseButton.waitForExistence(timeout: 5), app.debugDescription)
        activeCloseButton.click()

        addTrade(app, strike: "180", premium: "1.00")

        XCTAssertTrue(app.staticTexts["Active Close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Closed"].waitForExistence(timeout: 5))
        assertMetrics(
            app,
            shares: "0",
            premium: "$150.00",
            adjustedCost: "$0.00",
            openTrades: "0"
        )

        deletePosition(app, ticker: "AAPL", strategy: "Wheel")
        XCTAssertTrue(app.staticTexts["No Positions"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Select a Position"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["shares-metric-value"].exists, app.debugDescription)
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "OptionRecoderAppUITests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "OptionRecorder.sqlite", directoryHint: .notDirectory)
    }

    private func ensureMainWindow(in app: XCUIApplication) -> XCUIElement {
        let addPositionButton = app.buttons["add-position-button"]
        if addPositionButton.waitForExistence(timeout: 15) {
            return addPositionButton
        }

        app.activate()
        app.typeKey("n", modifierFlags: [.command])
        if addPositionButton.waitForExistence(timeout: 5) {
            return addPositionButton
        }

        let fileMenu = app.menuBars.menuBarItems["File"]
        if fileMenu.waitForExistence(timeout: 2) {
            fileMenu.click()
            let newWindowItem = app.menuItems["New Window"]
            if newWindowItem.waitForExistence(timeout: 2) {
                newWindowItem.click()
            }
        }

        XCTAssertTrue(addPositionButton.waitForExistence(timeout: 10), app.debugDescription)
        return addPositionButton
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

    private func addTrade(_ app: XCUIApplication, strike: String, premium: String) {
        XCTAssertTrue(app.staticTexts["Strike"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Premium"].waitForExistence(timeout: 5), app.debugDescription)

        replaceText(in: app.textFields["trade-strike-field"], with: strike)
        replaceText(in: app.textFields["trade-premium-field"], with: premium)

        let addTradeButton = app.buttons["add-trade-form-button"]
        XCTAssertTrue(addTradeButton.waitForEnabled(timeout: 5), app.debugDescription)
        addTradeButton.click()
    }

    private func selectStatus(_ status: String, in app: XCUIApplication) {
        let statusPicker = app.popUpButtons["trade-status-picker"]
        XCTAssertTrue(statusPicker.waitForExistence(timeout: 5), app.debugDescription)
        statusPicker.click()

        let menuItem = app.menuItems[status]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), app.debugDescription)
        menuItem.click()
    }

    private func selectQuickStatus(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForEnabled(timeout: 5), app.debugDescription)
        button.click()
    }

    private func deletePosition(_ app: XCUIApplication, ticker: String, strategy: String) {
        let deleteButton = app.buttons["delete-position-button-\(ticker)-\(strategy)"]
        XCTAssertTrue(deleteButton.waitForEnabled(timeout: 5), app.debugDescription)
        deleteButton.click()

        XCTAssertTrue(app.staticTexts["Delete Book?"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["This will delete \(ticker) \(strategy) and all of its trades."].exists, app.debugDescription)
        let confirmButton = app.sheets.firstMatch.buttons["Delete Book"]
        XCTAssertTrue(confirmButton.waitForEnabled(timeout: 5), app.debugDescription)
        confirmButton.click()

        let row = app.descendants(matching: .any)["position-row-\(ticker)-\(strategy)"]
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), app.debugDescription)
    }

    private func assertMetrics(
        _ app: XCUIApplication,
        shares: String,
        premium: String,
        adjustedCost: String,
        openTrades: String
    ) {
        XCTAssertTrue(
            app.staticTexts["shares-metric-value"].waitForValue(shares, timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(
            app.staticTexts["premium-metric-value"].waitForValue(premium, timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(
            app.staticTexts["adjusted-cost-metric-value"].waitForValue(adjustedCost, timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(
            app.staticTexts["open-trades-metric-value"].waitForValue(openTrades, timeout: 5),
            app.debugDescription
        )
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

    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
