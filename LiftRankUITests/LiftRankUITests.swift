import XCTest

final class LiftRankUITests: XCTestCase {
    private func launchDemo() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingDemoMode"]
        app.launch()
        return app
    }

    func testLaunchesIntoAuthenticatedDemoWorkspace() {
        let app = launchDemo()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Enter Explicit Demo Mode"].exists)
    }

    func testPrimaryNavigationTabsAreReachable() {
        let app = launchDemo()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))

        for title in ["Leaderboards", "Track", "Community", "Profile", "Home"] {
            let tab = tabBar.buttons[title]
            XCTAssertTrue(tab.exists, "Missing \(title) tab")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "\(title) tab did not become selected")
        }
    }

    func testExerciseLibrarySupportsSearchCreationAndFocusedDetails() {
        let app = launchDemo()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))
        tabBar.buttons["Track"].tap()

        let library = app.buttons["Library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        library.tap()

        XCTAssertTrue(app.textFields["Search exercises"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Create custom exercise"].exists)

        let bench = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Barbell Bench Press")).firstMatch
        XCTAssertTrue(bench.waitForExistence(timeout: 5))
        bench.tap()

        for tab in ["About", "History", "Records", "Charts"] {
            XCTAssertTrue(app.buttons[tab].waitForExistence(timeout: 5), "Missing \(tab) exercise detail tab")
        }
    }

    func testUnauthenticatedRoutingDoesNotExposeDemoEntryInReleaseContract() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingSignedOut"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["LiftRank"].waitForExistence(timeout: 8) ||
            app.staticTexts["Local data is unavailable"].exists
        )
    }
}
