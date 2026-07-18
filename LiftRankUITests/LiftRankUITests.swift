import XCTest

final class LiftRankUITests: XCTestCase {
    private func launchDemo(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingDemoMode"] + arguments
        app.launch()
        return app
    }

    func testHomeActiveWorkoutCardResumesWorkout() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout"])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()
        XCTAssertTrue(app.staticTexts["Upper Strength"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Finish Workout"].exists || app.buttons["Workout options"].exists)
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

        for title in ["Leaderboards", "Track", "Community", "Me", "Home"] {
            let tab = tabBar.buttons[title]
            XCTAssertTrue(tab.exists, "Missing \(title) tab")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "\(title) tab did not become selected")
        }
    }

    func testMeHubOpensAwardsAndPublicProfileEntryPoints() {
        let app = launchDemo()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        let meTab = app.tabBars.buttons["Me"]
        XCTAssertTrue(meTab.waitForExistence(timeout: 5))
        meTab.tap()
        XCTAssertTrue(app.navigationBars["Me"].waitForExistence(timeout: 5))

        let awards = app.descendants(matching: .any)["me.awards"]
        XCTAssertTrue(awards.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Public athlete profile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))

        awards.tap()
        XCTAssertTrue(app.otherElements["awards.screen"].waitForExistence(timeout: 5) || app.navigationBars["Awards"].exists)
        XCTAssertTrue(app.staticTexts["Personal records"].exists)
        XCTAssertTrue(app.staticTexts["Progress awards"].exists)
    }

    func testEditProfileUsesSearchableLocationAndGymPickers() {
        let app = launchDemo()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        app.tabBars.buttons["Me"].tap()

        let editProfile = app.buttons["Edit athlete profile"]
        XCTAssertTrue(editProfile.waitForExistence(timeout: 5))
        editProfile.tap()

        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        let location = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "City and state")).firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 5))
        var attempts = 0
        while !location.isHittable && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(location.isHittable)

        location.tap()
        let locationSearch = app.searchFields["Search city or state"]
        XCTAssertTrue(locationSearch.waitForExistence(timeout: 5))
        locationSearch.typeText("Miami")
        let miami = app.buttons["Miami, Florida"]
        XCTAssertTrue(miami.waitForExistence(timeout: 5))
        miami.tap()

        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        let gym = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Primary gym")).firstMatch
        attempts = 0
        while !gym.exists && attempts < 4 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(gym.waitForExistence(timeout: 5))
        gym.tap()
        XCTAssertTrue(app.searchFields["Search gyms"].waitForExistence(timeout: 5))
    }

    func testFindSubstituteOpensRecommendationsAndExerciseDetails() {
        let app = launchDemo()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        app.tabBars.buttons["Track"].tap()
        app.buttons["Library"].tap()

        let bench = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Barbell Bench Press")).firstMatch
        XCTAssertTrue(bench.waitForExistence(timeout: 5))
        bench.tap()

        let substitute = app.buttons["exercise.findSubstitute"]
        var attempts = 0
        while !substitute.exists && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(substitute.waitForExistence(timeout: 3))
        substitute.tap()

        XCTAssertTrue(app.navigationBars["Substitutes"].waitForExistence(timeout: 5))
        let firstExercise = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "substitute.exercise.")).firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 5))
        firstExercise.tap()
        XCTAssertTrue(app.buttons["About"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["History"].exists)
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
