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
    }

    func testMeHubOpensAwardsAndPublicProfileEntryPoints() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        let meTab = tab("profile", in: app)
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
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Locked awards")).firstMatch.exists)
    }

    func testMeHubShowsLiftVideosAndOpensSelectedVideo() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

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
        XCTAssertTrue(app.staticTexts["LIFT VIDEO"].exists || app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "demo media")).firstMatch.exists)
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

        let doral = app.buttons["option.C0000000-0000-0000-0000-000000000020"]
        XCTAssertTrue(doral.waitForExistence(timeout: 5))
        doral.tap()

        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        let selectedDoral = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Crunch Fitness - Doral")
        ).firstMatch
        XCTAssertTrue(selectedDoral.waitForExistence(timeout: 5))

        app.navigationBars["Edit Profile"].buttons["Save"].tap()
        XCTAssertTrue(editProfile.waitForExistence(timeout: 5))
        editProfile.tap()
        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        let persistedDoral = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Crunch Fitness - Doral")
        ).firstMatch
        attempts = 0
        while !persistedDoral.exists && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(persistedDoral.waitForExistence(timeout: 5))
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

        let otherAthlete = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND value == %@", "leaderboard.athlete.", "Other athlete")
        ).firstMatch
        XCTAssertTrue(otherAthlete.waitForExistence(timeout: 5))
        otherAthlete.tap()
        XCTAssertTrue(app.buttons["profile.athleteOptions"].waitForExistence(timeout: 5))
    }

    func testSubmitLiftProducesSubmissionResult() {
        let app = launchDemo(arguments: ["-uiTestingGymFixture"])
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()

        let openSubmission = app.buttons["leaderboard.submitLift"]
        XCTAssertTrue(openSubmission.waitForExistence(timeout: 5))
        openSubmission.tap()
        XCTAssertTrue(app.navigationBars["Submit Lift"].waitForExistence(timeout: 5))

        let submit = app.buttons["lift.submit"]
        var attempts = 0
        while !submit.isHittable && attempts < 10 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertTrue(submit.isEnabled)
        submit.tap()

        XCTAssertTrue(app.staticTexts["lift.submissionResult"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["lift.submissionDone"].exists)
    }

    func testSubmitLiftGymPickerSearchesFullDirectory() {
        let app = launchDemo(arguments: ["-uiTestingGymFixture"])
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()
        app.buttons["leaderboard.submitLift"].tap()
        XCTAssertTrue(app.navigationBars["Submit Lift"].waitForExistence(timeout: 5))

        let gym = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Gym")
        ).firstMatch
        XCTAssertTrue(gym.waitForExistence(timeout: 5))
        gym.tap()

        let search = app.searchFields["Search gyms"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
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
    }

    func testBlockingAnotherAthleteChangesTheProfileAction() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()

        let otherAthlete = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND value == %@", "leaderboard.athlete.", "Other athlete")
        ).firstMatch
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

}
