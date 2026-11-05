import XCTest

final class AboLifeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.private.AboLife.demo")
        app.launchEnvironment["ABOLIFE_DEMO"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["navigation.dashboard"].waitForExistence(timeout: 10))
        app.buttons["navigation.dashboard"].click()
        XCTAssertTrue(app.staticTexts["page.dashboard"].waitForExistence(timeout: 5))
    }

    func testNavigateCoreSections() {
        for section in ["finance", "statistics", "weeklyReview", "dashboard"] {
            app.buttons["navigation.\(section)"].click()
            XCTAssertTrue(app.staticTexts["page.\(section)"].waitForExistence(timeout: 5))
        }
        // The isolated demo contains yesterday's workout, never a completion today.
        XCTAssertFalse(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Full Body erledigt")).firstMatch.exists
        )
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Isoliertes Demo-Dashboard"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testExpenseValidationSavingAndDismissal() {
        app.buttons["quickadd.expense"].click()
        let amount = app.textFields["Betrag in EUR"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Speichern"].isEnabled)
        app.textFields["Titel / Name"].click()
        app.textFields["Titel / Name"].typeText("Demo-Testausgabe")
        amount.click()
        amount.typeText("7,50")
        app.buttons["Speichern"].click()
        XCTAssertTrue(app.staticTexts["Ausgabe gespeichert"].waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(amount.exists)
        app.buttons["navigation.finance"].click()
        XCTAssertTrue(app.staticTexts["Demo-Testausgabe"].waitForExistence(timeout: 5))
    }

    func testSettingsExposeSystemAppearance() {
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Darstellung"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Erscheinungsbild"].exists)
        for appearance in ["Hell", "Dunkel", "System"] {
            let option = app.radioButtons[appearance]
            option.click()
            XCTAssertEqual((option.value as? NSNumber)?.intValue, 1)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Demo-Einstellungen-\(appearance)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
    func testThreeDesignsAndAssistantScreenshots() throws {
        for (design, key) in [("Spatial", "spatial"), ("Bento", "bento"), ("Fieldnotes", "fieldnotes")] {
            app.typeKey(",", modifierFlags: .command)
            let option = app.radioButtons[design]
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.click()
            XCTAssertEqual((option.value as? NSNumber)?.intValue, 1)
            app.radioButtons[design == "Spatial" ? "Dunkel" : "Hell"].click()
            try capture("\(key)-settings")
            app.typeKey("w", modifierFlags: .command)
            for section in ["dashboard", "finance", "training", "habits", "weeklyReview"] {
                app.buttons["navigation.\(section)"].click()
                XCTAssertTrue(app.staticTexts["page.\(section)"].waitForExistence(timeout: 5))
                try capture("\(key)-\(section)")
            }
            app.buttons["navigation.ai"].click()
            XCTAssertTrue(app.textViews["Frage an AboLife AI"].waitForExistence(timeout: 5))
            try capture("\(key)-assistant")
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    private func capture(_ name: String) throws {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["ABOLIFE_UI_SCREENSHOTS"] {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: url.appendingPathComponent(name + ".png"))
        }
    }

}
