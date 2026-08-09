import XCTest

final class LiftRankUITests: XCTestCase {
    private func tab(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons["mainTab.\(name)"]
    }

    private func launchDemo(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingDemoMode"] + arguments
        app.launch()
        return app
    }

    private func launchCurrentAccount(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += arguments
        app.launch()
        return app
    }

    func testFirstLaunchPerformanceAuthenticatedShell() {
        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(metrics: [XCTClockMetric()], options: options) {
            let app = XCUIApplication()
            app.launchArguments += ["-uiTestingAuthentication"]
            app.launch()
            XCTAssertTrue(app.staticTexts["Lift Rivals"].waitForExistence(timeout: 8))
            app.terminate()
        }
    }

    func testFirstLaunchPerformanceRestoredAuthenticatedAccount() {
        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(metrics: [XCTClockMetric()], options: options) {
            let app = XCUIApplication()
            app.launchArguments += ["-uiTestingRestoredAuthenticatedAccount"]
            app.launch()
            XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
            app.terminate()
        }
    }

    func testAppOwnedRestoredLaunchPerformance() {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        let launchMetric = XCTOSSignpostMetric(
            subsystem: "com.liftrank.app",
            category: "Launch",
            name: "LiftRank launch"
        )

        measure(metrics: [launchMetric], options: options) {
            let app = XCUIApplication()
            app.launchArguments += ["-uiTestingRestoredAuthenticatedAccount"]
            app.launch()
            XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
            app.terminate()
        }
    }

    func testHomeActiveWorkoutCardResumesWorkout() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout"])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()
        XCTAssertTrue(app.staticTexts["Upper Strength"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Finish Workout"].exists || app.buttons["Workout options"].exists)
    }

    func testEmptyActiveWorkoutCanEndAndReturnToHome() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout"])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()

        let finish = app.buttons["Finish workout"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()

        let endWorkout = app.buttons["End Workout"]
        XCTAssertTrue(endWorkout.waitForExistence(timeout: 5))
        endWorkout.tap()

        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(finish.exists)
    }

    func testCompletedActiveWorkoutSavesAndDismissesTheWorkoutFlow() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout", "-uiTestingCompletedActiveSet"])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()

        let finish = app.buttons["Finish workout"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        let review = app.buttons["workout.finish.reviewIncomplete"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.tap()

        XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 5))
        if app.alerts.firstMatch.waitForExistence(timeout: 1) {
            app.alerts.firstMatch.buttons["Keep Private"].tap()
        }

        let save = app.buttons["workout.finish.save"]
        var attempts = 0
        while !save.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(finish.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Workout complete"].waitForNonExistence(timeout: 5))
    }

    func testTrackerTodayPrioritizesActiveWorkout() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout"])
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()

        XCTAssertTrue(app.staticTexts["ACTIVE WORKOUT"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["NEXT WORKOUT"].exists)
    }

    func testSetEntryMovesAcrossRowsAndDismissesKeyboardAfterFinalWeight() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout", "-uiTestingActiveWorkoutWithExercise"])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()

        let firstExercise = app.staticTexts["Barbell Bench Press"]
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 5))
        firstExercise.tap()

        let keyboardAction = app.buttons["workout.setInput.keyboardAction"]
        let firstReps = app.textFields["workout.set.1.reps"]
        let firstWeight = app.textFields["workout.set.1.weight"]
        XCTAssertTrue(firstReps.waitForExistence(timeout: 5))
        firstReps.tap()
        firstReps.typeText("8")
        XCTAssertTrue(keyboardAction.waitForExistence(timeout: 3))
        keyboardAction.tap()
        firstWeight.typeText("100")
        XCTAssertEqual(firstWeight.value as? String, "100")

        let fields = [
            ("workout.set.2.reps", "8"),
            ("workout.set.2.weight", "100"),
            ("workout.set.3.reps", "8"),
            ("workout.set.3.weight", "100")
        ]
        for (identifier, value) in fields {
            keyboardAction.tap()
            let field = app.textFields[identifier]
            XCTAssertTrue(field.waitForExistence(timeout: 3))
            field.typeText(value)
        }

        XCTAssertEqual(keyboardAction.label, "Done")
        keyboardAction.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
    }

    func testActiveWorkoutCanCreateAndAddCustomExercise() {
        let app = launchDemo(arguments: ["-uiTestingNoActiveWorkout"])
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()

        let startEmptyWorkout = app.buttons["Start empty workout"]
        XCTAssertTrue(startEmptyWorkout.waitForExistence(timeout: 5))
        startEmptyWorkout.tap()

        let addExercise = app.buttons["Add exercise"]
        XCTAssertTrue(addExercise.waitForExistence(timeout: 5))
        addExercise.tap()

        let createCustom = app.buttons["workout.addExercise.createCustom"]
        XCTAssertTrue(createCustom.waitForExistence(timeout: 5))
        createCustom.tap()

        XCTAssertTrue(app.navigationBars["New Exercise"].waitForExistence(timeout: 5))
        let name = app.textFields["Exercise name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Sled Drag")
        app.navigationBars["New Exercise"].buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Sled Drag"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Finish workout"].exists)
    }

    func testTrackerTodayOffersFocusedEmptyWorkoutActions() {
        let app = launchDemo(arguments: ["-uiTestingNoActiveWorkout"])
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()

        XCTAssertTrue(app.buttons["Start empty workout"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Browse")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Continue workout"].exists)
    }

    func testTrackerPlansShowsActivePlanAndProgramLibrary() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        app.buttons["Plans"].tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Active plan")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Workout program library")).firstMatch.waitForExistence(timeout: 5))
    }

    func testProgramLibraryOpensExtractedProgramPreview() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        app.buttons["Plans"].tap()

        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Workout program library")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        if library.value as? String == "Collapsed" {
            library.tap()
        }

        let template = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Preview ")
        ).firstMatch
        var attempts = 0
        while !template.exists && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()

        XCTAssertTrue(app.navigationBars["Program Preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["training.programPreview.screen"].exists)
        XCTAssertTrue(app.buttons["Start 12-Week Program"].waitForExistence(timeout: 3))
    }

    func testLaunchesIntoAuthenticatedDemoWorkspace() {
        let app = launchDemo()

        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Enter Explicit Demo Mode"].exists)
    }

    func testPrimaryNavigationTabsAreReachable() {
        let app = launchDemo()
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))

        for (name, title) in [("leaderboards", "Leaderboards"), ("track", "Track"), ("profile", "Me"), ("home", "Home")] {
            let item = tab(name, in: app)
            XCTAssertTrue(item.exists, "Missing \(title) tab")
            item.tap()
            XCTAssertEqual(item.value as? String, "selected", "\(title) tab did not become selected")
        }
        XCTAssertFalse(app.buttons["mainTab.community"].exists)
        XCTAssertEqual(app.tabBars.count, 0, "The custom floating navigation should not sit above a native tab bar")
    }

    func testPrimaryNavigationTabsRemainResponsive() {
        let app = launchDemo()
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric()], options: options) {
            for (name, title) in [("leaderboards", "Leaderboards"), ("track", "Track"), ("profile", "Me"), ("home", "Home")] {
                let item = tab(name, in: app)
                item.tap()
                XCTAssertEqual(item.value as? String, "selected", "\(title) tab did not become selected")
            }
        }
        app.terminate()
    }

    func testCurrentAccountLaunchToFirstNavigationPerformance() {
        measureCurrentAccountLaunchToFirstNavigation()
    }

    func testRestoredAccountLaunchToFirstNavigationPerformance() {
        measureCurrentAccountLaunchToFirstNavigation(arguments: ["-uiTestingRestoredAuthenticatedAccount"])
    }

    func testCurrentAccountLaunchToFirstNavigationWithWorkoutSyncPerformance() {
        measureCurrentAccountLaunchToFirstNavigation(arguments: ["-uiTestingStartupWorkoutSync"])
    }

    func testCurrentAccountPostLaunchNavigationPerformance() {
        measureCurrentAccountPostLaunchNavigation()
    }

    func testRestoredAccountPostLaunchNavigationPerformance() {
        measureCurrentAccountPostLaunchNavigation(arguments: ["-uiTestingRestoredAuthenticatedAccount"])
    }

    func testCurrentAccountPostLaunchNavigationWithWorkoutSyncPerformance() {
        measureCurrentAccountPostLaunchNavigation(arguments: ["-uiTestingStartupWorkoutSync"])
    }

    private func measureCurrentAccountLaunchToFirstNavigation(arguments: [String] = []) {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            startMeasuring()
            let app = launchCurrentAccount(arguments: arguments)
            XCTAssertTrue(tab("home", in: app).exists)
            tab("leaderboards", in: app).tap()
            XCTAssertTrue(app.staticTexts["Leaderboards"].exists)
            stopMeasuring()
            app.terminate()
        }
    }

    private func measureCurrentAccountPostLaunchNavigation(arguments: [String] = []) {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            let app = launchCurrentAccount(arguments: arguments)
            Thread.sleep(forTimeInterval: 2.2)
            startMeasuring()
            tab("leaderboards", in: app).tap()
            XCTAssertTrue(app.staticTexts["Leaderboards"].exists)
            stopMeasuring()
            app.terminate()
        }
    }

    func testMeHubOpensAwardsAndPublicProfileEntryPoints() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        let meTab = tab("profile", in: app)
        XCTAssertTrue(meTab.waitForExistence(timeout: 5))
        meTab.tap()
        XCTAssertTrue(app.navigationBars["Me"].waitForExistence(timeout: 5))

        let awards = app.descendants(matching: .any)["me.awards.strength"]
        XCTAssertTrue(awards.waitForExistence(timeout: 5))
        let publicProfile = app.descendants(matching: .any)["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["me.header.settings"].waitForExistence(timeout: 5))

        awards.tap()
        XCTAssertTrue(app.navigationBars["Awards"].waitForExistence(timeout: 5) || app.staticTexts["RIVAL TIER"].waitForExistence(timeout: 5))
        XCTAssertTrue(tab("profile", in: app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Squat"].exists)
        XCTAssertTrue(app.staticTexts["Bench"].exists)
        XCTAssertTrue(app.staticTexts["Deadlift"].exists)
        XCTAssertTrue(app.buttons["awards.shareRivalTier"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Personal records"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Locked awards")).firstMatch.exists)

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.tap()
        XCTAssertTrue(app.staticTexts["Rankings, progress, videos, and achievements"].waitForExistence(timeout: 5))
        XCTAssertTrue(tab("profile", in: app).waitForNonExistence(timeout: 5))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 5))
    }

    func testPublicProfileUsesCompactEmptyStatesAndAchievementPreview() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let publicProfile = app.descendants(matching: .any)["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.tap()

        XCTAssertTrue(tab("profile", in: app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No submissions yet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No lift videos yet"].waitForExistence(timeout: 5))

        let details = app.staticTexts["More athlete details"]
        var attempts = 0
        while !details.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(details.isHittable)
        details.tap()

        XCTAssertTrue(app.staticTexts["No strength history yet"].waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(
            app.descendants(matching: .any).matching(identifier: "profile.achievement.locked").count,
            4
        )
    }

    func testMePublicProfileNavigationDoesNotFreezeOnRepeatedOpen() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        XCTAssertTrue(app.navigationBars["Me"].waitForExistence(timeout: 5))

        for _ in 0..<2 {
            let publicProfile = app.buttons["me.publicProfile"]
            XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
            publicProfile.tap()

            XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Rankings, progress, videos, and achievements"].waitForExistence(timeout: 5))
            XCTAssertTrue(tab("profile", in: app).waitForNonExistence(timeout: 5))

            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.navigationBars["Me"].waitForExistence(timeout: 5))
            XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 5))
        }
    }

    func testMeHubSectionOrderAndCompactHeaderActions() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        XCTAssertTrue(app.descendants(matching: .any)["me.profileHeader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["me.header.settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["me.header.editProfile"].waitForExistence(timeout: 5))

        let strength = app.otherElements["me.section.strengthProgress"]
        let topLifts = app.otherElements["me.section.topLifts"]
        let trainingStats = app.otherElements["me.section.trainingStats"]
        let recentPerformance = app.otherElements["me.section.recentPerformance"]

        XCTAssertTrue(strength.waitForExistence(timeout: 5))
        XCTAssertTrue(topLifts.waitForExistence(timeout: 5))
        XCTAssertTrue(trainingStats.waitForExistence(timeout: 5))
        XCTAssertTrue(recentPerformance.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["me.strength.tier"].exists)
        for lift in ["squat", "bench", "deadlift"] {
            XCTAssertTrue(app.descendants(matching: .any)["me.strength.lift.\(lift)"].exists)
        }

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Me strength progress"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertLessThan(strength.frame.minY, topLifts.frame.minY)
        XCTAssertLessThan(topLifts.frame.minY, trainingStats.frame.minY)
        XCTAssertLessThan(trainingStats.frame.minY, recentPerformance.frame.minY)

        let signOut = app.buttons["me.accountActions.signOut"]
        var attempts = 0
        while !signOut.exists && attempts < 12 {
            app.swipeUp()
            attempts += 1
        }

        let awardsHistory = app.otherElements["me.section.awardsHistory"]
        let accountSettings = app.otherElements["me.section.accountSettings"]
        let accountActions = app.otherElements["me.section.accountActions"]
        XCTAssertTrue(awardsHistory.waitForExistence(timeout: 5))
        XCTAssertTrue(accountSettings.waitForExistence(timeout: 5))
        XCTAssertTrue(accountActions.waitForExistence(timeout: 5))
        XCTAssertLessThan(awardsHistory.frame.minY, accountSettings.frame.minY)
        XCTAssertLessThan(accountSettings.frame.minY, accountActions.frame.minY)
    }

    func testMeHubBottomActionsRemainAboveFloatingTabBar() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let signOut = app.buttons["me.accountActions.signOut"]
        let profileTab = tab("profile", in: app)
        var attempts = 0
        while attempts < 12 && (!signOut.isHittable || signOut.frame.maxY >= profileTab.frame.minY) {
            app.swipeUp()
            attempts += 1
        }

        XCTAssertTrue(signOut.waitForExistence(timeout: 5))
        XCTAssertTrue(signOut.isHittable)
        XCTAssertLessThan(signOut.frame.maxY, profileTab.frame.minY)
    }

    func testAwardsSectionPrioritizesUnlockedAndClosestEntries() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let awards = app.descendants(matching: .any)["me.awards.strength"]
        var attempts = 0
        while !awards.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(awards.isHittable)
        awards.tap()

        let unlockedHeader = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Unlocked awards")
        ).firstMatch
        let closestHeader = app.staticTexts["Next 3 closest awards"]
        let lockedHeader = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Locked awards")
        ).firstMatch

        XCTAssertTrue(unlockedHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(closestHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(lockedHeader.waitForExistence(timeout: 5))

        XCTAssertLessThan(unlockedHeader.frame.minY, closestHeader.frame.minY)
        XCTAssertLessThan(closestHeader.frame.minY, lockedHeader.frame.minY)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Progress summary:")
        ).firstMatch.exists)
        XCTAssertTrue(app.buttons["awards.shareRivalTier"].waitForExistence(timeout: 5))
    }

    func testMeHubShowsLiftVideosAndOpensSelectedVideo() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let publicProfile = app.buttons["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))

        let videoLibrary = app.descendants(matching: .any)["profile.liftVideos"]
        var attempts = 0
        while !videoLibrary.exists && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(videoLibrary.waitForExistence(timeout: 5))

        let video = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "profile.liftVideo.")
        ).firstMatch
        XCTAssertTrue(video.waitForExistence(timeout: 5))
        video.tap()

        XCTAssertTrue(app.navigationBars["Lift video"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["profile.liftVideoPlayer"].waitForExistence(timeout: 5))
    }

    func testCurrentAccountShowsSubmittedVideoAndLeaderboardEntry() {
        let app = launchCurrentAccount()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let publicProfile = app.buttons["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 8))
        publicProfile.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8))

        let videoLibrary = app.descendants(matching: .any)["profile.liftVideos"]
        var attempts = 0
        while !videoLibrary.exists && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(videoLibrary.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "profile.liftVideo.")
        ).firstMatch.exists)

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()
        XCTAssertTrue(app.staticTexts["Leaderboards"].waitForExistence(timeout: 8))

        app.buttons["leaderboard.filter.exercise"].tap()
        let deadlift = app.buttons["leaderboard.filters.option.conventional_deadlift"]
        XCTAssertTrue(deadlift.waitForExistence(timeout: 5))
        deadlift.tap()

        XCTAssertTrue(app.staticTexts["YOU"].waitForExistence(timeout: 15))
    }

    func testCompetitionFixtureShowsCurrentVideoAndLeaderboardPlacement() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let publicProfile = app.buttons["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))

        let videoLibrary = app.descendants(matching: .any)["profile.liftVideos"]
        var attempts = 0
        while !videoLibrary.exists && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(videoLibrary.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "profile.liftVideo.")
        ).firstMatch.exists)

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 5))
        tab("leaderboards", in: app).tap()
        XCTAssertTrue(app.staticTexts["Leaderboards"].waitForExistence(timeout: 5))
        app.buttons["leaderboard.filter.exercise"].tap()
        let bench = app.buttons["option.bench"]
        XCTAssertTrue(bench.waitForExistence(timeout: 5))
        bench.tap()
        XCTAssertTrue(app.staticTexts["YOU"].waitForExistence(timeout: 8))
    }

    func testEditProfileUsesSearchableLocationAndGymPickers() {
        let app = launchDemo(arguments: ["-uiTestingGymFixture"])
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let editProfile = app.buttons["Edit athlete profile"]
        XCTAssertTrue(editProfile.waitForExistence(timeout: 5))
        editProfile.tap()

        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        let location = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Location")).firstMatch
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

        let southBeach = app.buttons["option.C0000000-0000-0000-0000-000000000063"]
        XCTAssertTrue(southBeach.waitForExistence(timeout: 5))
        southBeach.tap()

        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        let selectedSouthBeach = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Crunch Fitness - South Beach")
        ).firstMatch
        XCTAssertTrue(selectedSouthBeach.waitForExistence(timeout: 5))

        app.navigationBars["Edit Profile"].buttons["Save"].tap()
        XCTAssertTrue(editProfile.waitForExistence(timeout: 5))
        editProfile.tap()
        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        let persistedSouthBeach = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Crunch Fitness - South Beach")
        ).firstMatch
        attempts = 0
        while !persistedSouthBeach.exists && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(persistedSouthBeach.waitForExistence(timeout: 5))
    }

    func testFindSubstituteOpensRecommendationsAndExerciseDetails() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
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
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()

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

    func testCurrentAccountLeaderboardDoesNotShowScoreFromPreviousRanking() {
        let app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "System prompts") { alert in
            if alert.buttons["Not Now"].exists {
                alert.buttons["Not Now"].tap()
                return true
            }
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            return false
        }
        app.launch()

        let leaderboards = tab("leaderboards", in: app)
        XCTAssertTrue(leaderboards.waitForExistence(timeout: 8))
        leaderboards.tap()
        XCTAssertTrue(app.navigationBars["Leaderboards"].waitForExistence(timeout: 8))

        let relativeRanking = app.buttons["Round-for-pound"]
        XCTAssertTrue(relativeRanking.waitForExistence(timeout: 5))
        relativeRanking.tap()
        Thread.sleep(forTimeInterval: 2)

        let totalRanking = app.buttons["Total"]
        XCTAssertTrue(totalRanking.waitForExistence(timeout: 5))
        totalRanking.tap()

        let transitionScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        transitionScreenshot.name = "Leaderboard total transition"
        transitionScreenshot.lifetime = .keepAlways
        add(transitionScreenshot)

        let staleScore = app.staticTexts["3.4 lb"]
        let transitionDeadline = Date().addingTimeInterval(2)
        while Date() < transitionDeadline, !app.staticTexts["315 lb"].exists {
            XCTAssertFalse(staleScore.exists, "The previous ranking score was formatted as a total weight")
            Thread.sleep(forTimeInterval: 0.05)
        }

        XCTAssertFalse(staleScore.exists)
        XCTAssertTrue(app.staticTexts["315 lb"].waitForExistence(timeout: 8))

        let finalScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        finalScreenshot.name = "Leaderboard total settled"
        finalScreenshot.lifetime = .keepAlways
        add(finalScreenshot)
    }

    func testLeaderboardFiltersAndOpensAnotherAthleteProfile() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()
        XCTAssertTrue(app.navigationBars["Leaderboards"].waitForExistence(timeout: 5))

        let exerciseFilter = app.buttons["leaderboard.filter.exercise"]
        XCTAssertTrue(exerciseFilter.waitForExistence(timeout: 5))
        exerciseFilter.tap()
        let bench = app.buttons["Barbell bench press"]
        XCTAssertTrue(bench.waitForExistence(timeout: 5))
        bench.tap()
        XCTAssertEqual(exerciseFilter.label, "Exercise, Barbell bench press")

        let otherAthlete = app.buttons["leaderboard.athlete.A0000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(otherAthlete.waitForExistence(timeout: 5))
        otherAthlete.tap()
        XCTAssertTrue(app.buttons["profile.athleteOptions"].waitForExistence(timeout: 5))
    }

    func testLeaderboardExerciseSearchUsesExercisePrompt() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()

        app.buttons["leaderboard.filter.exercise"].tap()
        let exerciseSearch = app.searchFields["Search exercises"]
        if !exerciseSearch.waitForExistence(timeout: 2) {
            let searchButton = app.buttons["Search"]
            XCTAssertTrue(searchButton.waitForExistence(timeout: 3))
            searchButton.tap()
        }

        XCTAssertTrue(exerciseSearch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.searchFields["Search gyms"].exists)
        exerciseSearch.tap()
        exerciseSearch.typeText("bench")
        XCTAssertTrue(app.buttons["option.bench"].waitForExistence(timeout: 5))
    }

    func testLeaderboardScopeSearchIncludesGyms() {
        let app = launchDemo(arguments: ["-uiTestingGymFixture"])
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()

        app.buttons["leaderboard.filter.scope"].tap()
        let scopeSearch = app.searchFields["Search locations or gyms"]
        if !scopeSearch.waitForExistence(timeout: 2) {
            let searchButton = app.buttons["Search"]
            XCTAssertTrue(searchButton.waitForExistence(timeout: 3))
            searchButton.tap()
        }

        XCTAssertTrue(scopeSearch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.searchFields["Search exercises"].exists)
        scopeSearch.tap()
        scopeSearch.typeText("Cutler Bay")
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Crunch Fitness - Cutler Bay")
        ).firstMatch.waitForExistence(timeout: 5))
    }

    func testLeaderboardFilterOptionsWrapInsideViewport() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()

        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "More filters")
        ).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Filters"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["leaderboard.filters.results"].exists)

        let intermediate = app.buttons["leaderboard.filters.option.intermediate"]
        XCTAssertTrue(intermediate.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(intermediate.frame.minX, window.minX)
        XCTAssertLessThanOrEqual(intermediate.frame.maxX, window.maxX)

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Leaderboard filters wrapped"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testSubmitLiftProducesSubmissionResult() {
        let app = launchDemo()
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()

        let openSubmission = app.buttons["leaderboard.submitLift"]
        XCTAssertTrue(openSubmission.waitForExistence(timeout: 5))
        openSubmission.tap()
        XCTAssertTrue(app.navigationBars["Submit Lift"].waitForExistence(timeout: 5))

        let submit = app.buttons["lift.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertFalse(submit.isEnabled)
        XCTAssertTrue(app.staticTexts["lift.submitReason"].waitForExistence(timeout: 5))
        let verification = app.switches["Request verification"]
        var attempts = 0
        while !verification.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(verification.waitForExistence(timeout: 5))
        XCTAssertTrue(verification.isHittable)
        verification.tap()
        XCTAssertTrue(submit.isEnabled)
        submit.tap()

        XCTAssertTrue(app.staticTexts["lift.submissionResult"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Provisional placement"].exists)
        XCTAssertTrue(app.buttons["lift.submissionDone"].exists)
    }

    func testSubmitLiftGymPickerSearchesFullDirectory() {
        let app = launchDemo(arguments: ["-uiTestingGymFixture"])
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()
        app.buttons["leaderboard.submitLift"].tap()
        XCTAssertTrue(app.navigationBars["Submit Lift"].waitForExistence(timeout: 5))

        let gym = app.buttons["lift.gym"]
        XCTAssertTrue(gym.waitForExistence(timeout: 5))
        var attempts = 0
        while !gym.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(gym.isHittable)
        gym.tap()

        let search = app.searchFields["Search gyms"]
        if !search.waitForExistence(timeout: 2) {
            let searchButton = app.buttons["Search"]
            XCTAssertTrue(searchButton.waitForExistence(timeout: 3))
            searchButton.tap()
        }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Cutler Bay")
        let cutlerBay = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Crunch Fitness - Cutler Bay")
        ).firstMatch
        XCTAssertTrue(cutlerBay.waitForExistence(timeout: 5))
        cutlerBay.tap()

        XCTAssertTrue(app.navigationBars["Submit Lift"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Crunch Fitness - Cutler Bay")
        ).firstMatch.waitForExistence(timeout: 5))

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Submit Lift selected gym"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testCurrentAccountSubmitLiftOffersNoGymOption() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()
        app.buttons["leaderboard.submitLift"].tap()
        XCTAssertTrue(app.navigationBars["Submit Lift"].waitForExistence(timeout: 5))

        let gym = app.buttons["lift.gym"]
        XCTAssertTrue(gym.waitForExistence(timeout: 5))
        var attempts = 0
        while !gym.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(gym.isHittable)
        gym.tap()

        XCTAssertTrue(app.buttons["option.no-gym"].waitForExistence(timeout: 5))
    }

    func testCurrentAccountSubmitsFirstGalleryVideoWithoutGym() {
        let app = launchCurrentAccount()
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()
        app.buttons["leaderboard.submitLift"].tap()
        XCTAssertTrue(app.navigationBars["Submit Lift"].waitForExistence(timeout: 5))

        let selectVideo = app.buttons["lift.video.select"]
        var attempts = 0
        while !selectVideo.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(selectVideo.waitForExistence(timeout: 5))
        XCTAssertTrue(selectVideo.isHittable)
        selectVideo.tap()

        let firstVideo = app.images.matching(
            NSPredicate(format: "identifier == %@", "PXGGridLayout-Info")
        ).firstMatch
        XCTAssertTrue(firstVideo.waitForExistence(timeout: 8))
        let thumbnailFrame = firstVideo.frame
        let appFrame = app.frame
        app.coordinate(withNormalizedOffset: CGVector(
            dx: thumbnailFrame.midX / appFrame.width,
            dy: thumbnailFrame.midY / appFrame.height
        )).tap()
        if app.buttons["Add"].waitForExistence(timeout: 2) {
            app.buttons["Add"].tap()
        }

        XCTAssertTrue(app.buttons["lift.video.review"].waitForExistence(timeout: 30))

        let submit = app.buttons["lift.submit"]
        attempts = 0
        while !submit.isHittable && attempts < 10 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertTrue(submit.isEnabled)
        submit.tap()

        let result = app.staticTexts["lift.submissionResult"]
        let alert = app.alerts["Lift not submitted"]
        let deadline = Date().addingTimeInterval(60)
        while !result.exists && !alert.exists && Date() < deadline {
            Thread.sleep(forTimeInterval: 1)
        }
        if result.exists {
            XCTAssertTrue(
                app.staticTexts["Video-backed"].waitForExistence(timeout: 5),
                "The lift was saved, but the selected video was not uploaded and linked."
            )
            XCTAssertTrue(app.staticTexts["Provisional placement"].exists)
            return
        }
        if alert.exists {
            XCTFail("Submission failed before video upload: \(alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | "))")
        } else {
            XCTFail("Submission did not produce a result within 60 seconds")
        }
    }

    func testHomeShowsUsefulRecentPREmptyState() {
        let app = launchDemo()
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.recentPRs.emptyAction"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Log your first PR"].exists)
    }

    func testBlockingAnotherAthleteChangesTheProfileAction() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()

        let otherAthlete = app.buttons["leaderboard.athlete.A0000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(otherAthlete.waitForExistence(timeout: 5))
        otherAthlete.tap()

        let options = app.buttons["profile.athleteOptions"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        let block = app.buttons["profile.blockAthlete"]
        XCTAssertTrue(block.waitForExistence(timeout: 5))
        block.tap()

        let blocked = NSPredicate(format: "value == %@", "Blocked")
        expectation(for: blocked, evaluatedWith: options)
        waitForExpectations(timeout: 5)
        options.tap()
        XCTAssertTrue(app.buttons["profile.unblockAthlete"].waitForExistence(timeout: 5))
    }

    func testReportingAnotherAthletesLiftSubmitsAndDismisses() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()

        let otherAthlete = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND value == %@", "leaderboard.athlete.", "Other athlete")
        ).firstMatch
        XCTAssertTrue(otherAthlete.waitForExistence(timeout: 5))
        otherAthlete.tap()

        let liftOptions = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "profile.liftOptions.")
        ).firstMatch
        XCTAssertTrue(liftOptions.waitForExistence(timeout: 5))
        liftOptions.tap()
        let report = app.buttons["profile.reportLift"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        report.tap()

        XCTAssertTrue(app.navigationBars["Report Lift"].waitForExistence(timeout: 5))
        let submit = app.buttons["report.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.navigationBars["Report Lift"].waitForNonExistence(timeout: 5))
    }

    func testAuthenticatedAccountDeletionReturnsToSignIn() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingAuthenticatedAccount"]
        app.launch()

        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        let settings = app.buttons["Open settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let deleteAccount = app.buttons["Delete Account"]
        var attempts = 0
        while !deleteAccount.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(deleteAccount.waitForExistence(timeout: 5))
        deleteAccount.tap()

        let confirm = app.buttons["Delete Account and Local Data"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Lift Rivals"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Sign In"].exists)
    }

    func testOnboardingSavesProfileAndAdvancesToLegalAcceptance() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingOnboarding", "-uiTestingPrefilledOnboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Turn every lift into a ranking."].waitForExistence(timeout: 8))
        app.buttons["Build My Lift Rivals"].tap()
        XCTAssertTrue(app.staticTexts["What are you working toward?"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Build your lifter profile."].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Username"].value as? String, "launch_lifter")
        app.buttons["Save Profile"].tap()
        XCTAssertTrue(app.staticTexts["What are your best lifts?"].waitForExistence(timeout: 5))
        app.buttons["I’ll add my lifts later"].tap()

        XCTAssertTrue(app.staticTexts["You’re ready to compete."].waitForExistence(timeout: 5))
        app.buttons["Enter Lift Rivals"].tap()
        XCTAssertTrue(app.staticTexts["Before you compete"].waitForExistence(timeout: 8))
    }

    func testUnauthenticatedRoutingDoesNotExposeDemoEntryInReleaseContract() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingAuthentication"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Lift Rivals"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textFields["Email"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.buttons["Sign In"].exists)
        let createAccount = app.segmentedControls.buttons["Create Account"]
        XCTAssertTrue(createAccount.exists)
        createAccount.tap()
        XCTAssertTrue(createAccount.isSelected)
    }

    func testProductionReviewerCanSignIn() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["LIFTRANK_REVIEW_EMAIL"],
              let password = environment["LIFTRANK_REVIEW_PASSWORD"] else {
            throw XCTSkip("Production reviewer credentials were not provided.")
        }

        let app = XCUIApplication()
        app.launch()

        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 8))
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(passwordField.exists)
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons["authentication.email.submit"].tap()
        let homeTab = tab("home", in: app)
        let acceptButton = app.buttons["Accept and Continue"]
        if !homeTab.waitForExistence(timeout: 5), acceptButton.waitForExistence(timeout: 20) {
            let privacyConsent = app.switches["I have read and accept Privacy Notice"]
            XCTAssertTrue(privacyConsent.waitForExistence(timeout: 5))
            if !privacyConsent.isHittable {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.33, dy: 0.615)).tap()
            }
            for label in [
                "I have read and accept Privacy Notice",
                "I have read and accept Terms of Use",
                "I have read and accept Fitness Disclaimer"
            ] {
                let consent = app.switches[label]
                XCTAssertTrue(consent.waitForExistence(timeout: 5), "Missing legal consent: \(label)")
                if consent.value as? String != "1" {
                    consent.tap()
                }
                if consent.value as? String != "1" {
                    consent.tap()
                }
                XCTAssertEqual(consent.value as? String, "1")
            }
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: acceptButton)
            waitForExpectations(timeout: 5)
            acceptButton.tap()
        }
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        if !homeTab.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.33, dy: 0.615)).tap()
        }
        if !homeTab.isHittable {
            app.tap()
            expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: homeTab)
            waitForExpectations(timeout: 5)
        }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Production reviewer signed in"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testAuthenticationFormProvidesResponsiveValidation() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingAuthentication"]
        app.launch()

        let submit = app.buttons["authentication.email.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 8))
        XCTAssertTrue(submit.isEnabled)

        submit.tap()
        XCTAssertTrue(app.staticTexts["Enter your email address."].waitForExistence(timeout: 5))

        let email = app.textFields["Email"]
        email.tap()
        email.typeText("reviewer@example.com")

        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("short")
        XCTAssertTrue(submit.isEnabled)

        let createAccount = app.segmentedControls.buttons["Create Account"]
        createAccount.tap()
        XCTAssertTrue(createAccount.isSelected)
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
        XCTAssertTrue(app.staticTexts["New passwords must contain at least 10 characters."].waitForExistence(timeout: 5))
    }

}
