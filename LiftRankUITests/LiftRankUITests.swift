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

    func testActiveWorkoutSetRestoresAfterAppRestart() {
        var app = launchDemo(arguments: [
            "-uiTestingActiveWorkout",
            "-uiTestingCompletedActiveSet",
            "-uiTestingPersistWorkoutSnapshots"
        ])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()
        let exercise = app.staticTexts["Barbell Bench Press"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        exercise.tap()
        let weight = app.textFields["workout.set.1.weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertEqual(weight.value as? String, "225")

        app.terminate()
        app = launchDemo(arguments: ["-uiTestingPersistWorkoutSnapshots"])
        let restoredResume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(restoredResume.waitForExistence(timeout: 8))
        restoredResume.tap()
        let restoredExercise = app.staticTexts["Barbell Bench Press"]
        XCTAssertTrue(restoredExercise.waitForExistence(timeout: 5))
        restoredExercise.tap()
        let restoredWeight = app.textFields["workout.set.1.weight"]
        XCTAssertTrue(restoredWeight.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredWeight.value as? String, "225")
    }

    func testActiveWorkoutOpenPerformance() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout"])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            startMeasuring()
            resume.tap()
            XCTAssertTrue(app.staticTexts["Upper Strength"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["Finish workout"].waitForExistence(timeout: 5))
            stopMeasuring()

            app.buttons["Minimize workout"].tap()
            XCTAssertTrue(resume.waitForExistence(timeout: 5))
        }
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

        XCTAssertTrue(app.staticTexts["Review workout"].waitForExistence(timeout: 5))
        let reviewScreenshot = XCTAttachment(screenshot: app.screenshot())
        reviewScreenshot.name = "Workout summary review screen"
        reviewScreenshot.lifetime = .keepAlways
        add(reviewScreenshot)

        let reviewSets = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Review'")).firstMatch
        XCTAssertTrue(reviewSets.waitForExistence(timeout: 5))
        reviewSets.tap()
        XCTAssertTrue(app.staticTexts["Tap an exercise to review or edit its sets."].waitForExistence(timeout: 5))
        let benchReviewRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'working sets'")).firstMatch
        var reviewScrollAttempts = 0
        while benchReviewRow.frame.maxY > app.frame.maxY - 170 && reviewScrollAttempts < 8 {
            if benchReviewRow.frame.minY < app.frame.minY {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
            reviewScrollAttempts += 1
        }
        XCTAssertTrue(benchReviewRow.isHittable)
        XCTAssertLessThanOrEqual(benchReviewRow.frame.maxY, app.frame.maxY - 170)
        benchReviewRow.tap()
        XCTAssertTrue(app.navigationBars["Track exercise"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["workout.set.1.reps"].isHittable)
        XCTAssertTrue(app.textFields["workout.set.1.weight"].isHittable)
        let exerciseReviewScreenshot = XCTAttachment(screenshot: app.screenshot())
        exerciseReviewScreenshot.name = "Workout exercise editing from summary"
        exerciseReviewScreenshot.lifetime = .keepAlways
        add(exerciseReviewScreenshot)
        let rpeChoice = app.buttons["Set RPE to 8"].firstMatch
        XCTAssertTrue(rpeChoice.waitForExistence(timeout: 5))
        var rpeScrollAttempts = 0
        while rpeChoice.frame.maxY > app.frame.maxY - 170 && rpeScrollAttempts < 5 {
            app.swipeUp()
            rpeScrollAttempts += 1
        }
        XCTAssertLessThanOrEqual(rpeChoice.frame.maxY, app.frame.maxY - 170)
        rpeChoice.tap()
        XCTAssertTrue(rpeChoice.isSelected)
        let rpeScreenshot = XCTAttachment(screenshot: app.screenshot())
        rpeScreenshot.name = "Exercise set RPE controls"
        rpeScreenshot.lifetime = .keepAlways
        add(rpeScreenshot)
        app.buttons["Review workout"].tap()

        if app.alerts.firstMatch.waitForExistence(timeout: 1) {
            app.alerts.firstMatch.buttons["Keep Private"].tap()
        }

        let effortSection = app.staticTexts["Workout effort · Optional"]
        let effortChoice = app.buttons["3 of 5, Solid"]
        var effortScrollAttempts = 0
        while !effortChoice.isHittable && effortScrollAttempts < 10 {
            app.swipeUp()
            effortScrollAttempts += 1
        }
        XCTAssertTrue(effortSection.isHittable)
        XCTAssertTrue(effortChoice.isHittable)
        app.swipeUp()
        effortChoice.tap()
        XCTAssertTrue(effortChoice.isSelected)
        let effortScreenshot = XCTAttachment(screenshot: app.screenshot())
        effortScreenshot.name = "Workout effort selector"
        effortScreenshot.lifetime = .keepAlways
        add(effortScreenshot)

        let save = app.buttons["workout.finish.save"]
        var attempts = 0
        while !save.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        XCTAssertTrue(app.staticTexts["Workout saved"].exists)
        let savedScreenshot = XCTAttachment(screenshot: app.screenshot())
        savedScreenshot.name = "Saved workout confirmation"
        savedScreenshot.lifetime = .keepAlways
        add(savedScreenshot)
        let achievements = app.buttons["workout.finish.saved.achievements"]
        XCTAssertTrue(achievements.waitForExistence(timeout: 5))
        achievements.tap()
        XCTAssertTrue(app.staticTexts["All achievements"].waitForExistence(timeout: 5))
        achievements.tap()
        let done = app.buttons["workout.finish.saved.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(finish.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Review workout"].waitForNonExistence(timeout: 5))
    }

    func testShortenedPlannedWorkoutSummaryShowsPlanCoverage() {
        let app = launchDemo(arguments: ["-uiTestingPlannedActiveWorkout"])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()

        let finish = app.buttons["Finish workout"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        let review = app.buttons["workout.finish.reviewIncomplete"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.tap()

        XCTAssertTrue(app.staticTexts["Review workout"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Will save shortened session"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'planned working sets logged'"))
            .firstMatch.exists)
    }

    func testExerciseTrendCanFocusExactSourceSetInWorkoutDetail() {
        let app = launchDemo(arguments: ["-uiTestingFocusedWorkoutSet"])
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()

        let focusedSet = app.descendants(matching: .any)["workout.detail.focusedSet"]
        XCTAssertTrue(focusedSet.waitForExistence(timeout: 8))
        let focusedSetLabel = app.staticTexts["Set 12"]
        XCTAssertTrue(focusedSetLabel.exists)
        XCTAssertTrue(focusedSetLabel.isHittable)

        app.buttons["Done"].tap()
        app.buttons["tracker.segment.progress"].tap()
        let categories = app.segmentedControls["tracker.progress.category"]
        XCTAssertTrue(categories.waitForExistence(timeout: 5))
        categories.buttons["Strength"].tap()
        let exercisePicker = app.descendants(matching: .any)["tracker.progress.exercisePicker"]
        XCTAssertTrue(exercisePicker.waitForExistence(timeout: 5))
        exercisePicker.tap()
        app.collectionViews.buttons["Barbell Bench Press"].tap()

        XCTAssertTrue(app.staticTexts["CURRENT EST. 1RM"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Log this exercise in another workout to see an estimated 1RM trend."].exists)
        XCTAssertFalse(app.staticTexts["INCREASE"].exists)
    }

    func testTrackerTodayPrioritizesActiveWorkout() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout"])
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()

        XCTAssertTrue(app.staticTexts["ACTIVE WORKOUT"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["NEXT WORKOUT"].exists)
    }

    func testWeeklyTrainingDayGoalCanBeSetAndChangedOnHome() {
        let app = launchDemo()
        let setGoal = app.buttons["weeklyTrainingGoal.set"]
        XCTAssertTrue(setGoal.waitForExistence(timeout: 8))
        setGoal.tap()

        let goalMenu = app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label == %@", "weeklyTrainingGoal.menu", "3 days")
        ).firstMatch
        XCTAssertTrue(goalMenu.waitForExistence(timeout: 5))
        goalMenu.tap()
        app.buttons["4 days per week"].tap()

        let homeGoal = app.descendants(matching: .any)["weeklyTrainingGoal.card"]
        XCTAssertTrue(homeGoal.waitForExistence(timeout: 5))
        XCTAssertEqual(homeGoal.value as? String, "0 of 4 days")

        tab("track", in: app).tap()
        app.buttons["tracker.segment.progress"].tap()
        let progressCategories = app.segmentedControls["tracker.progress.category"]
        XCTAssertTrue(progressCategories.waitForExistence(timeout: 5))
        progressCategories.buttons["Consistency"].tap()
        let progressGoal = app.descendants(matching: .any)["weeklyTrainingGoal.card"]
        XCTAssertTrue(progressGoal.waitForExistence(timeout: 5))
        XCTAssertEqual(progressGoal.value as? String, "0 of 4 days")
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
        let setEntryScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        setEntryScreenshot.name = "Active workout set entry layout"
        setEntryScreenshot.lifetime = .keepAlways
        add(setEntryScreenshot)
        XCTAssertTrue(app.buttons["workout.set.1.previousValues"].waitForExistence(timeout: 5))
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

        let startEmptyWorkout = app.buttons["Start freestyle workout"]
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

        XCTAssertTrue(app.buttons["Start freestyle workout"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Browse")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Continue workout"].exists)
    }

    func testTrackerPlansShowsActivePlanAndProgramLibrary() {
        let app = launchDemo()
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()
        let plans = app.buttons["tracker.segment.plans"]
        if !plans.waitForExistence(timeout: 5) {
            track.tap()
        }
        XCTAssertTrue(plans.waitForExistence(timeout: 5))
        plans.tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Active plan")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Workout program library")).firstMatch.waitForExistence(timeout: 5))

        let planOptions = app.buttons["Plan detail options"]
        XCTAssertTrue(planOptions.waitForExistence(timeout: 5))
        planOptions.tap()
        app.buttons["Plan Overview"].tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "workouts have all planned sets completed")
        ).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "planned sets logged")
        ).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(
                format: "label BEGINSWITH %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@",
                "Start next workout:",
                "Review unfinished week:",
                "Add next week"
            )
        ).firstMatch.exists)

        planOptions.tap()
        app.buttons["Plan Notes"].tap()
        let notesButton = app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "Add notes", "Edit notes")
        ).firstMatch
        var notesScrollAttempts = 0
        while !notesButton.isHittable && notesScrollAttempts < 6 {
            app.swipeUp()
            notesScrollAttempts += 1
        }
        XCTAssertTrue(notesButton.isHittable)
        notesButton.tap()
        let notesEditor = app.textViews.firstMatch
        XCTAssertTrue(notesEditor.waitForExistence(timeout: 5))
        notesEditor.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.95)).tap()
        notesEditor.typeText("\nNotes saved from the plan details screen.")
        app.navigationBars["Plan notes"].buttons["Save"].tap()
        let savedNotes = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Notes saved from the plan details screen.")
        ).firstMatch
        XCTAssertTrue(savedNotes.waitForExistence(timeout: 5))
        XCTAssertTrue(savedNotes.label.contains("Bundled 12-week powerlifting program."))
    }

    func testTrackerPlansOpenPerformance() {
        let app = launchDemo()
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()
        if !app.buttons["Today"].waitForExistence(timeout: 5) {
            track.tap()
        }
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 5))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            let today = app.buttons["Today"]
            XCTAssertTrue(today.waitForExistence(timeout: 5))
            today.tap()
            let plans = app.buttons["Plans"]
            XCTAssertTrue(plans.waitForExistence(timeout: 5))

            startMeasuring()
            plans.tap()
            XCTAssertTrue(app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Active plan")
            ).firstMatch.waitForExistence(timeout: 5))
            stopMeasuring()
        }
    }

    func testTrackerProgressOpenPerformance() {
        let app = launchDemo()
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()
        if !app.buttons["Today"].waitForExistence(timeout: 5) {
            track.tap()
        }
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 5))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            let today = app.buttons["tracker.segment.today"]
            today.tap()
            XCTAssertTrue(app.staticTexts["Today's training"].waitForExistence(timeout: 5))
            let progress = app.buttons["tracker.segment.progress"]
            XCTAssertTrue(progress.waitForExistence(timeout: 5))

            startMeasuring()
            progress.tap()
            XCTAssertTrue(app.segmentedControls["tracker.progress.category"].waitForExistence(timeout: 5))
            stopMeasuring()

            let categories = app.segmentedControls["tracker.progress.category"]
            XCTAssertTrue(categories.exists)
            categories.buttons["Strength"].tap()
            XCTAssertTrue(app.staticTexts["Strength"].exists)
            categories.buttons["Muscle"].tap()
            XCTAssertTrue(app.staticTexts["Muscle workload"].exists)
            categories.buttons["Consistency"].tap()
            XCTAssertTrue(app.staticTexts["Program consistency"].exists)
        }
    }

    func testProgressCategoriesAndControlsRemainResponsive() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        XCTAssertTrue(app.buttons["tracker.segment.progress"].waitForExistence(timeout: 5))
        app.buttons["tracker.segment.progress"].tap()

        let categories = app.segmentedControls["tracker.progress.category"]
        XCTAssertTrue(categories.waitForExistence(timeout: 5))
        categories.buttons["Strength"].tap()
        XCTAssertTrue(app.staticTexts["Bars compare your three lifts with your strongest; tiers use bodyweight-based standards."].waitForExistence(timeout: 5))
        let firstMuscleSwitch = Date()
        categories.buttons["Muscle"].tap()
        XCTAssertTrue(app.staticTexts["Muscle workload"].waitForExistence(timeout: 5))
        print("First Muscle switch: \(Date().timeIntervalSince(firstMuscleSwitch)) seconds")

        for _ in 0..<5 {
            categories.buttons["Strength"].tap()
            XCTAssertTrue(app.staticTexts["Strength"].waitForExistence(timeout: 5))

            categories.buttons["Muscle"].tap()
            XCTAssertTrue(app.staticTexts["Muscle workload"].waitForExistence(timeout: 5))

            categories.buttons["Consistency"].tap()
            XCTAssertTrue(categories.buttons["Consistency"].isSelected)
        }

        categories.buttons["Muscle"].tap()
        let period = app.buttons["tracker.muscle.period"]
        XCTAssertTrue(period.isHittable)
        period.tap()
        app.buttons["Last week"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "Completed week")).firstMatch.exists)
    }

    func testProgressStrengthCompareAtGymOpensGymLeaderboard() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        XCTAssertTrue(app.buttons["tracker.segment.progress"].waitForExistence(timeout: 5))
        app.buttons["tracker.segment.progress"].tap()
        app.segmentedControls["tracker.progress.category"].buttons["Strength"].tap()
        XCTAssertTrue(app.staticTexts["Bars compare your three lifts with your strongest; tiers use bodyweight-based standards."].waitForExistence(timeout: 5))
        let strengthOverview = XCTAttachment(screenshot: app.screenshot())
        strengthOverview.name = "Progress strength at accessibility size"
        strengthOverview.lifetime = .keepAlways
        add(strengthOverview)

        let compareButton = app.buttons["tracker.progress.compareAtGym"]
        for _ in 0..<6 where !compareButton.isHittable { app.swipeUp() }
        XCTAssertTrue(compareButton.waitForExistence(timeout: 5))
        let strengthComparison = XCTAttachment(screenshot: app.screenshot())
        strengthComparison.name = "Progress strength comparison action at accessibility size"
        strengthComparison.lifetime = .keepAlways
        add(strengthComparison)
        XCTAssertTrue(compareButton.label.contains("Compare 3-lift total at"))
        compareButton.tap()

        XCTAssertEqual(tab("leaderboards", in: app).value as? String, "selected")
        XCTAssertTrue(app.buttons["leaderboard.filter.compare_with"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["leaderboard.filter.compare_with"].label.contains("Lift Rivals Demo Gym"))
    }

    func testMuscleWorkloadFiltersAndExerciseBreakdown() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        let progress = app.buttons["tracker.segment.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        progress.tap()
        app.segmentedControls["tracker.progress.category"].buttons["Muscle"].tap()
        let filter = app.buttons["tracker.muscle.filter"]
        for _ in 0..<5 where !filter.isHittable { app.swipeUp() }
        XCTAssertTrue(filter.isHittable)
        filter.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "No primary sets (")).firstMatch.tap()
        XCTAssertFalse(app.staticTexts["Below target"].exists)
        filter.tap()
        app.buttons["Logged work"].tap()
        let overview = XCTAttachment(screenshot: app.screenshot())
        overview.name = "Muscle workload overview"
        overview.lifetime = .keepAlways
        add(overview)

        let historicalLatsWeek = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "tracker.muscleWeek.lats.")
        ).firstMatch
        XCTAssertTrue(historicalLatsWeek.waitForExistence(timeout: 5))
        XCTAssertTrue(historicalLatsWeek.isEnabled)
        historicalLatsWeek.tap()
        XCTAssertTrue(app.staticTexts["Four-week workload"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Contributing exercises"].exists)
        let detail = XCTAttachment(screenshot: app.screenshot())
        detail.name = "Muscle exercise breakdown"
        detail.lifetime = .keepAlways
        add(detail)
        let workout = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open workout ·")).firstMatch
        for _ in 0..<5 where !workout.isHittable { app.swipeUp() }
        XCTAssertTrue(workout.isHittable)
        workout.tap()
        XCTAssertTrue(app.buttons["Repeat workout"].waitForExistence(timeout: 5))
    }

    func testExerciseLibraryFilterSheetRemainsUsableAtAccessibilitySize() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        let library = app.buttons["tracker.segment.library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        for _ in 0..<3 where !library.isHittable { app.swipeLeft() }
        library.tap()

        let filters = app.buttons["Filter exercise library"]
        XCTAssertTrue(filters.waitForExistence(timeout: 5))
        filters.tap()
        XCTAssertTrue(app.navigationBars["Exercise Filters"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Barbell"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Show ")
        ).firstMatch.isHittable)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Exercise filters at accessibility text size"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["Barbell"].tap()
        let apply = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Show ")
        ).firstMatch
        XCTAssertTrue(apply.isHittable)
        apply.tap()
        XCTAssertTrue(app.navigationBars["Exercise Filters"].waitForNonExistence(timeout: 5))
    }

    func testCustomExerciseFormRemainsUsableAtAccessibilitySize() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        let library = app.buttons["tracker.segment.library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        for _ in 0..<3 where !library.isHittable { app.swipeLeft() }
        library.tap()

        let create = app.buttons["Create custom exercise"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        XCTAssertTrue(app.navigationBars["New Exercise"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Exercise name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Save"].exists)
        let trackingOption = app.buttons["Weight + Reps"]
        XCTAssertTrue(trackingOption.waitForExistence(timeout: 5))
        for _ in 0..<8 where !trackingOption.isHittable { app.swipeUp() }
        XCTAssertTrue(trackingOption.isHittable)
        trackingOption.tap()

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Custom exercise tracking options at accessibility text size"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["New Exercise"].waitForNonExistence(timeout: 5))
    }

    func testWorkoutHistoryCalendarRemainsUsableAtAccessibilitySize() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        app.buttons["tracker.segment.progress"].tap()
        app.segmentedControls["tracker.progress.category"].buttons["Consistency"].tap()

        let calendarTitle = app.staticTexts["Workout calendar"]
        for _ in 0..<12 where !calendarTitle.isHittable { app.swipeUp() }
        XCTAssertTrue(calendarTitle.isHittable)
        let day = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "completed workout")
        ).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        for _ in 0..<6 where !day.isHittable { app.swipeUp() }
        XCTAssertTrue(day.isHittable)
        day.tap()
        XCTAssertTrue(day.isSelected)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Workout history calendar at accessibility text size"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testFirstProgressOpenWithMuscleFocus() {
        let app = launchDemo()
        let profileTab = tab("profile", in: app)
        XCTAssertTrue(profileTab.waitForExistence(timeout: 8))
        profileTab.tap()
        let settingsButton = app.buttons["me.header.settings"]
        if !settingsButton.waitForExistence(timeout: 5) {
            profileTab.tap()
        }
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        let focus = app.buttons["settings.trainingFocus"]
        for _ in 0..<8 where !focus.isHittable { app.swipeUp() }
        XCTAssertTrue(focus.isHittable)
        focus.tap()
        app.buttons["Bodybuilding"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForNonExistence(timeout: 5))

        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        if !app.buttons["tracker.segment.progress"].waitForExistence(timeout: 5) {
            tab("track", in: app).tap()
        }
        let started = Date()
        app.buttons["tracker.segment.progress"].tap()
        XCTAssertTrue(app.staticTexts["Bodybuilding"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Muscle workload"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["What are you training for?"].exists)
        print("First Progress open with Muscle focus: \(Date().timeIntervalSince(started)) seconds")
    }

    func testScreenAuditNavigation() {
        let app = launchDemo()
        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Personal 3-lift total"].waitForExistence(timeout: 5))
        capture("Audit Home")
        let track = tab("track", in: app)
        track.tap()
        if !app.buttons["tracker.segment.today"].waitForExistence(timeout: 5) {
            track.tap()
        }
        for section in ["today", "plans", "library", "progress"] {
            let button = app.buttons["tracker.segment.\(section)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            if section == "today" {
                let scheduledStart = app.buttons["training.today.startScheduledWorkout"]
                if scheduledStart.exists {
                    XCTAssertTrue(scheduledStart.isHittable)
                }
            }
            capture("Audit Track \(section)")
        }
        let categories = app.segmentedControls["tracker.progress.category"]
        for category in ["Strength", "Muscle", "Consistency"] {
            categories.buttons[category].tap()
            capture("Audit Progress \(category)")
        }
        for name in ["leaderboards", "forum", "profile"] {
            tab(name, in: app).tap()
            capture("Audit \(name)")
        }
        XCTAssertTrue(app.buttons["me.personalProfile"].exists)
        app.buttons["me.publicProfile"].tap()
        capture("Audit Public profile")
        app.navigationBars.buttons.firstMatch.tap()
        tab("profile", in: app).tap()
        let personalProfile = app.buttons["me.personalProfile"]
        for _ in 0..<5 where !personalProfile.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(personalProfile.isHittable)
        personalProfile.tap()
        XCTAssertTrue(app.navigationBars["Personal profile"].waitForExistence(timeout: 5))
        capture("Audit Personal profile")
    }

    func testLeaderboardControlsStayInsideViewportAtAccessibilitySize() throws {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        let leaderboardTab = tab("leaderboards", in: app)
        XCTAssertTrue(leaderboardTab.waitForExistence(timeout: 8))
        leaderboardTab.tap()
        XCTAssertTrue(app.navigationBars["Leaderboards"].waitForExistence(timeout: 8))

        let scope = app.buttons["leaderboard.filter.compare_with"]
        XCTAssertTrue(scope.waitForExistence(timeout: 5))
        guard scope.frame.height > 64 else {
            throw XCTSkip("Run this layout check with Accessibility XXL enabled in the simulator.")
        }
        app.buttons["leaderboard.ranking.absolute"].tap()

        let controls = [
            scope,
            app.buttons["leaderboard.filter.exercise"],
            app.buttons["leaderboard.ranking.absolute"],
            app.buttons["leaderboard.ranking.pound-for-pound"],
            app.buttons["leaderboard.ranking.total"],
            app.buttons["leaderboard.ranking.relative-total"]
        ]
        for control in controls {
            XCTAssertTrue(control.waitForExistence(timeout: 5), "Missing visible leaderboard control: \(control.identifier)")
            var scrollAttempts = 0
            while !control.isHittable && scrollAttempts < 6 {
                app.swipeUp()
                scrollAttempts += 1
            }
            XCTAssertTrue(control.isHittable, "Leaderboard control is not hittable: \(control.identifier)")
            XCTAssertGreaterThanOrEqual(control.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX)
        }

        let topScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        topScreenshot.name = "Leaderboard accessibility ranking controls"
        topScreenshot.lifetime = .keepAlways
        add(topScreenshot)

        let moreFilters = app.buttons["leaderboard.filter.more"]
        var scrollAttempts = 0
        while !moreFilters.isHittable && scrollAttempts < 5 {
            app.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(moreFilters.waitForExistence(timeout: 5))
        XCTAssertTrue(moreFilters.isHittable)
        XCTAssertGreaterThanOrEqual(moreFilters.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(moreFilters.frame.maxX, app.frame.maxX)

        let filtersScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        filtersScreenshot.name = "Leaderboard accessibility filter controls"
        filtersScreenshot.lifetime = .keepAlways
        add(filtersScreenshot)

        app.swipeUp()
        let firstAthlete = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "leaderboard.athlete.")
        ).firstMatch
        XCTAssertTrue(firstAthlete.waitForExistence(timeout: 5))
        let visibleBottom = app.frame.maxY - 170
        XCTAssertLessThanOrEqual(firstAthlete.frame.height, visibleBottom - 80)
        var athleteScrollAttempts = 0
        while firstAthlete.frame.maxY > visibleBottom && athleteScrollAttempts < 6 {
            app.swipeUp()
            athleteScrollAttempts += 1
        }
        XCTAssertTrue(firstAthlete.isHittable)
        XCTAssertLessThanOrEqual(firstAthlete.frame.maxY, visibleBottom)

        let athleteScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        athleteScreenshot.name = "Leaderboard accessibility athlete row"
        athleteScreenshot.lifetime = .keepAlways
        add(athleteScreenshot)
    }

    func testProgramLibraryOpensExtractedProgramPreview() {
        let app = launchDemo(arguments: ["-uiTestingNoActiveWorkout"])
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
        XCTAssertTrue(app.scrollViews["training.programPreview.screen"].exists)
        let previewScreenshot = XCTAttachment(screenshot: app.screenshot())
        previewScreenshot.name = "Program preview at accessibility text size"
        previewScreenshot.lifetime = .keepAlways
        add(previewScreenshot)
        let weekPreview = app.staticTexts.matching(NSPredicate(format: "label == %@", "Week 1 preview")).firstMatch
        XCTAssertTrue(weekPreview.waitForExistence(timeout: 5))
        for _ in 0..<10 where !weekPreview.isHittable { app.swipeUp() }
        XCTAssertTrue(weekPreview.isHittable)
        let firstSession = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Full Body A")
        ).firstMatch
        XCTAssertTrue(firstSession.waitForExistence(timeout: 5))
        for _ in 0..<10 where !firstSession.isHittable { app.swipeUp() }
        XCTAssertTrue(firstSession.isHittable)
        let sessionsScreenshot = XCTAttachment(screenshot: app.screenshot())
        sessionsScreenshot.name = "Program sessions at accessibility text size"
        sessionsScreenshot.lifetime = .keepAlways
        add(sessionsScreenshot)
        let firstExercise = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Back Squat")
        ).firstMatch
        if firstExercise.exists {
            app.swipeUp()
            app.swipeUp()
            let exerciseScreenshot = XCTAttachment(screenshot: app.screenshot())
            exerciseScreenshot.name = "Program exercises at accessibility text size"
            exerciseScreenshot.lifetime = .keepAlways
            add(exerciseScreenshot)
        }
        let startProgram = app.buttons["training.programPreview.start"]
        XCTAssertTrue(startProgram.waitForExistence(timeout: 3))
        XCTAssertTrue(startProgram.isEnabled)


        let previewScroll = app.scrollViews["training.programPreview.screen"]
        let editSetup = app.buttons["Edit existing setup"]
        XCTAssertTrue(editSetup.waitForExistence(timeout: 5))
        for _ in 0..<20 {
            let frame = editSetup.frame
            if frame.minY >= app.frame.minY + 120 && frame.maxY <= app.frame.maxY - 180 { break }
            let startsAboveViewport = frame.minY < app.frame.minY + 120
            let start = previewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: startsAboveViewport ? 0.3 : 0.72))
            let end = previewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: startsAboveViewport ? 0.5 : 0.52))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertGreaterThanOrEqual(editSetup.frame.minY, app.frame.minY + 120)
        XCTAssertLessThanOrEqual(editSetup.frame.maxY, app.frame.maxY - 180)
        XCTAssertTrue(editSetup.isHittable)
        XCTAssertTrue(editSetup.isEnabled)
        editSetup.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let saveSetup = app.buttons["Save setup changes"]
        XCTAssertTrue(saveSetup.waitForExistence(timeout: 5))
        XCTAssertEqual(startProgram.label, "Save setup changes")
        let setupTitle = app.staticTexts.matching(NSPredicate(format: "label == %@", "Program setup")).firstMatch
        XCTAssertTrue(setupTitle.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let frame = setupTitle.frame
            if frame.minY >= app.frame.minY + 120 && frame.maxY <= app.frame.maxY - 180 { break }
            let startsAboveViewport = frame.minY < app.frame.minY + 120
            let start = previewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: startsAboveViewport ? 0.3 : 0.72))
            let end = previewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: startsAboveViewport ? 0.5 : 0.52))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(setupTitle.isHittable)
        let setupScreenshot = XCTAttachment(screenshot: app.screenshot())
        setupScreenshot.name = "Program setup at accessibility text size"
        setupScreenshot.lifetime = .keepAlways
        add(setupScreenshot)

        let progressionLabel = app.staticTexts["Progression"]
        XCTAssertTrue(progressionLabel.waitForExistence(timeout: 5))
        for _ in 0..<12 where !progressionLabel.isHittable { previewScroll.swipeUp() }
        XCTAssertTrue(progressionLabel.isHittable)
        let progressionScreenshot = XCTAttachment(screenshot: app.screenshot())
        progressionScreenshot.name = "Program progression choices at accessibility text size"
        progressionScreenshot.lifetime = .keepAlways
        add(progressionScreenshot)

        let percentageOption = app.buttons["Percentage"]
        XCTAssertTrue(percentageOption.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let frame = percentageOption.frame
            if frame.minY >= app.frame.minY + 120 && frame.maxY <= app.frame.maxY - 180 { break }
            let startsAboveViewport = frame.minY < app.frame.minY + 120
            let start = previewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: startsAboveViewport ? 0.3 : 0.72))
            let end = previewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: startsAboveViewport ? 0.5 : 0.52))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(percentageOption.isHittable)
        let trainingDaysLabel = app.staticTexts["Training days"]
        XCTAssertTrue(trainingDaysLabel.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let frame = trainingDaysLabel.frame
            if frame.minY >= app.frame.minY + 120 && frame.maxY <= app.frame.maxY - 180 { break }
            let startsAboveViewport = frame.minY < app.frame.minY + 120
            let start = previewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: startsAboveViewport ? 0.3 : 0.72))
            let end = previewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: startsAboveViewport ? 0.5 : 0.52))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(trainingDaysLabel.isHittable)
        let firstTrainingDay = app.staticTexts.matching(NSPredicate(format: "label == %@", "Full Body A")).firstMatch
        XCTAssertTrue(firstTrainingDay.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let frame = firstTrainingDay.frame
            if frame.minY >= app.frame.minY + 120 && frame.maxY <= app.frame.maxY - 180 { break }
            let startsAboveViewport = frame.minY < app.frame.minY + 120
            let start = previewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: startsAboveViewport ? 0.3 : 0.72))
            let end = previewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: startsAboveViewport ? 0.5 : 0.52))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(firstTrainingDay.isHittable)
        let trainingDaysScreenshot = XCTAttachment(screenshot: app.screenshot())
        trainingDaysScreenshot.name = "Program training days at accessibility text size"
        trainingDaysScreenshot.lifetime = .keepAlways
        add(trainingDaysScreenshot)




    }

    func testLaunchesIntoAuthenticatedDemoWorkspace() {
        let app = launchDemo()

        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Explore demo"].exists)
    }

    func testPrimaryNavigationTabsAreReachable() {
        let app = launchDemo()
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))

        for (name, title) in [("home", "Home"), ("leaderboards", "Leaderboards"), ("track", "Track"), ("forum", "Forum"), ("profile", "Me")] {
            let item = tab(name, in: app)
            XCTAssertTrue(item.exists, "Missing \(title) tab")
            item.tap()
            XCTAssertEqual(item.value as? String, "selected", "\(title) tab did not become selected")
        }
        XCTAssertFalse(app.buttons["mainTab.community"].exists)
        XCTAssertFalse(app.buttons["mainTab.utility"].exists)
        XCTAssertEqual(tab("track", in: app).frame.midX, app.windows.firstMatch.frame.midX, accuracy: 1)
        XCTAssertEqual(app.tabBars.count, 0, "The custom floating navigation should not sit above a native tab bar")
    }

    func testPrimaryNavigationTabsRemainResponsive() {
        let app = launchDemo()
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        measure(metrics: [XCTClockMetric()], options: options) {
            startMeasuring()
            tab("leaderboards", in: app).tap()
            XCTAssertTrue(app.navigationBars["Leaderboards"].waitForExistence(timeout: 5))
            tab("track", in: app).tap()
            XCTAssertTrue(app.buttons["tracker.segment.today"].waitForExistence(timeout: 5))
            tab("profile", in: app).tap()
            XCTAssertTrue(app.navigationBars["Me"].waitForExistence(timeout: 5))
            let home = tab("home", in: app)
            home.tap()
            let settings = app.buttons["Open settings"]
            if !settings.waitForExistence(timeout: 2) {
                home.tap()
            }
            XCTAssertTrue(settings.waitForExistence(timeout: 5))
            stopMeasuring()
        }
        app.terminate()
    }

    func testNotificationsOpenPerformance() {
        let app = launchDemo()
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        let notifications = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Notifications")
        ).firstMatch
        XCTAssertTrue(notifications.waitForExistence(timeout: 5))

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            startMeasuring()
            notifications.tap()
            XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
            stopMeasuring()

            app.buttons["Close"].tap()
            XCTAssertTrue(app.navigationBars["Notifications"].waitForNonExistence(timeout: 5))
        }
    }

    func testHomeScrollPerformance() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Recent submitted PRs"].waitForExistence(timeout: 5))

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            startMeasuring()
            app.swipeUp()
            let weeklyGoal = app.buttons["weeklyTrainingGoal.set"]
            let weeklyGoalProgress = app.staticTexts["Training-day goal"]
            XCTAssertTrue(
                weeklyGoal.waitForExistence(timeout: 5) ||
                weeklyGoalProgress.waitForExistence(timeout: 5)
            )
            stopMeasuring()

            app.swipeDown()
            XCTAssertTrue(app.staticTexts["Recent submitted PRs"].waitForExistence(timeout: 5))
        }
    }

    func testSettingsDoneDismissalPerformance() {
        let app = launchDemo()
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            let settings = app.buttons["Open settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 5))
            settings.tap()
            let navigationBar = app.navigationBars["Settings"]
            if !navigationBar.waitForExistence(timeout: 2) {
                settings.tap()
            }
            XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))

            startMeasuring()
            app.buttons["Done"].tap()
            XCTAssertTrue(navigationBar.waitForNonExistence(timeout: 5))
            stopMeasuring()
        }

        let settings = app.buttons["Open settings"]
        settings.tap()
        if !app.navigationBars["Settings"].waitForExistence(timeout: 2) {
            settings.tap()
        }
        let privateProfile = app.buttons["Profile visibility"]
        XCTAssertTrue(privateProfile.waitForExistence(timeout: 5))
        let expectedValue = privateProfile.value as? String == "Private" ? "Public" : "Private"
        privateProfile.tap()
        app.buttons[expectedValue].tap()
        XCTAssertEqual(privateProfile.value as? String, expectedValue)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForNonExistence(timeout: 5))

        settings.tap()
        XCTAssertTrue(privateProfile.waitForExistence(timeout: 5))
        XCTAssertEqual(privateProfile.value as? String, expectedValue)
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
        app.buttons["me.trainingDetails"].tap()

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
        XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 5))
        XCTAssertTrue(tab("profile", in: app).waitForNonExistence(timeout: 5))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 5))
    }

    func testPublicProfileUsesCompactEmptyStateWhenNoLiftDataIsVisible() {
        let app = launchDemo(arguments: ["-uiTestingEmptyRecentPRs"])
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        if !app.navigationBars["Me"].waitForExistence(timeout: 2) {
            tab("profile", in: app).tap()
        }
        XCTAssertTrue(app.navigationBars["Me"].waitForExistence(timeout: 5))

        let publicProfile = app.buttons["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()

        XCTAssertTrue(tab("profile", in: app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["profile.noPublicData"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["profile.sectionNavigation"].exists)
        XCTAssertFalse(app.staticTexts["Delete account"].exists)
    }

    func testPublicProfileKeepsAccountControlsSeparateFromAthleteOptions() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        if !app.navigationBars["Me"].waitForExistence(timeout: 2) {
            tab("profile", in: app).tap()
        }
        XCTAssertTrue(app.navigationBars["Me"].waitForExistence(timeout: 5))

        let publicProfile = app.buttons["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.tap()

        XCTAssertTrue(app.buttons["profile.athleteOptions"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["me.header.settings"].exists)
        XCTAssertFalse(app.buttons["Delete account"].exists)
    }

    func testProfileShowsVerifiedScoreInPreferredWeightUnit() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        XCTAssertTrue(app.navigationBars["Me"].waitForExistence(timeout: 5))
        app.buttons["me.personalProfile"].tap()
        let score = app.staticTexts["profile.strength.score"]
        XCTAssertTrue(score.waitForExistence(timeout: 5))
        XCTAssertEqual(score.label, "315 lb")
        XCTAssertTrue(app.state == .runningForeground)
    }

    func testMePublicProfileNavigationDoesNotFreezeOnRepeatedOpen() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        if !app.navigationBars["Me"].waitForExistence(timeout: 2) {
            tab("profile", in: app).tap()
        }
        XCTAssertTrue(app.navigationBars["Me"].waitForExistence(timeout: 5))

        for _ in 0..<2 {
            let publicProfile = app.buttons["me.publicProfile"]
            XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
            publicProfile.tap()

            XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 5))
            XCTAssertTrue(tab("profile", in: app).waitForNonExistence(timeout: 5))
            let trainingSection = app.buttons["profile.section.training"]
            XCTAssertTrue(trainingSection.waitForExistence(timeout: 5))
            trainingSection.tap()
            XCTAssertTrue(app.staticTexts["Rankings are not shown here"].waitForExistence(timeout: 5))

            let back = app.navigationBars.buttons.firstMatch
            back.tap()
            if !app.navigationBars["Me"].waitForExistence(timeout: 2) {
                back.tap()
            }
            XCTAssertTrue(app.navigationBars["Me"].waitForExistence(timeout: 5))
            XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 5))
        }
    }

    func testMePublicProfileBackPerformance() {
        let app = launchDemo()
        let meTab = tab("profile", in: app)
        XCTAssertTrue(meTab.waitForExistence(timeout: 8))
        meTab.tap()
        if !app.navigationBars["Me"].waitForExistence(timeout: 2) {
            meTab.tap()
        }
        XCTAssertTrue(app.navigationBars["Me"].waitForExistence(timeout: 5))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            let publicProfile = app.buttons["me.publicProfile"]
            XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
            publicProfile.tap()
            XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 5))

            startMeasuring()
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.navigationBars["Me"].waitForExistence(timeout: 5))
            XCTAssertTrue(meTab.exists)
            stopMeasuring()
        }
    }

    func testMeHubSectionOrderAndCompactHeaderActions() {
        let app = launchDemo()
        let meScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        XCTAssertTrue(meScrollView.waitForExistence(timeout: 5))

        XCTAssertTrue(app.descendants(matching: .any)["me.profileHeader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["me.header.settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["me.header.editProfile"].waitForExistence(timeout: 5))

        let strength = app.descendants(matching: .any)["me.section.strengthProgress"]
        let topLifts = app.descendants(matching: .any)["me.section.topLifts"]
        let trainingStats = app.descendants(matching: .any)["me.section.trainingStats"]
        let recentPerformance = app.descendants(matching: .any)["me.section.recentPerformance"]

        XCTAssertFalse(strength.exists)
        app.buttons["me.trainingDetails"].tap()
        XCTAssertTrue(strength.waitForExistence(timeout: 5))
        XCTAssertTrue(topLifts.waitForExistence(timeout: 5))
        XCTAssertTrue(trainingStats.waitForExistence(timeout: 5))
        XCTAssertTrue(recentPerformance.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["me.strength.tier"].exists)
        for lift in ["squat", "bench", "deadlift"] {
            XCTAssertTrue(app.descendants(matching: .any)["me.strength.lift.\(lift)"].exists)
        }

        let deadliftProgress = app.buttons["me.strength.lift.deadlift"]
        var progressAttempts = 0
        while !deadliftProgress.isHittable && progressAttempts < 8 {
            meScrollView.swipeUp()
            progressAttempts += 1
        }
        XCTAssertTrue(deadliftProgress.isHittable)
        deadliftProgress.tap()
        XCTAssertTrue(app.navigationBars["Deadlift history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Submit a new deadlift lift"].exists)
        app.buttons["Done"].tap()

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Me strength progress"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertLessThan(strength.frame.minY, topLifts.frame.minY)
        XCTAssertLessThan(topLifts.frame.minY, trainingStats.frame.minY)
        XCTAssertLessThan(trainingStats.frame.minY, recentPerformance.frame.minY)

        let history = app.buttons["me.personalProfile"]
        var attempts = 0
        while !history.isHittable && attempts < 12 {
            meScrollView.swipeUp()
            attempts += 1
        }

        let awardsHistory = app.otherElements["me.section.awardsHistory"]
        XCTAssertTrue(awardsHistory.waitForExistence(timeout: 5))
        XCTAssertTrue(history.isHittable)
        XCTAssertFalse(app.buttons["me.accountActions.signOut"].exists)
    }

    func testMeHubBottomActionsRemainAboveFloatingTabBar() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let gyms = app.buttons["me.gyms"]
        let profileTab = tab("profile", in: app)
        var attempts = 0
        while attempts < 12 && (!gyms.isHittable || gyms.frame.maxY >= profileTab.frame.minY) {
            app.swipeUp()
            attempts += 1
        }

        XCTAssertTrue(gyms.waitForExistence(timeout: 5))
        XCTAssertTrue(gyms.label.contains("1 location · 0 joined"))
        XCTAssertTrue(gyms.isHittable)
        XCTAssertLessThan(gyms.frame.maxY, profileTab.frame.minY)
    }

    func testMeTrainingDetailsPreservesStrengthRowAccessibility() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        XCTAssertTrue(app.buttons["me.trainingDetails"].waitForExistence(timeout: 5))
        app.buttons["me.trainingDetails"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["me.strength.tier"].waitForExistence(timeout: 5))
        let deadlift = app.buttons["me.strength.lift.deadlift"]
        XCTAssertTrue(deadlift.waitForExistence(timeout: 5))
        deadlift.tap()
        XCTAssertTrue(app.navigationBars["Deadlift history"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.firstMatch.tap()
        tab("profile", in: app).tap()
        let personalProfile = app.buttons["me.personalProfile"]
        for _ in 0..<12 where !personalProfile.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(personalProfile.isHittable)
        personalProfile.tap()
        XCTAssertTrue(app.navigationBars["Personal profile"].waitForExistence(timeout: 5))
    }

    func testAwardsSectionPrioritizesUnlockedAndClosestEntries() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let awards = app.descendants(matching: .any)["me.awards"]
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
        let closestHeader = app.staticTexts["Closest awards"]
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
        XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 5))

        let videoLibrary = app.descendants(matching: .any)["profile.prVideos"]
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

    func testProfileLiftVideoOpenPerformance() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        let publicProfile = app.buttons["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 5))

        let videoLibrary = app.descendants(matching: .any)["profile.prVideos"]
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

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            startMeasuring()
            video.tap()
            XCTAssertTrue(app.navigationBars["Lift video"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.descendants(matching: .any)["profile.liftVideoPlayer"].waitForExistence(timeout: 5))
            stopMeasuring()

            app.buttons["Done"].tap()
            XCTAssertTrue(app.navigationBars["Lift video"].waitForNonExistence(timeout: 5))
        }
    }

    func testCurrentAccountShowsSubmittedVideoAndLeaderboardEntry() {
        let app = launchCurrentAccount()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let publicProfile = app.buttons["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 8))
        publicProfile.tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 8))

        let videoLibrary = app.descendants(matching: .any)["profile.prVideos"]
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

        app.buttons["leaderboard.ranking.absolute"].tap()
        app.buttons["leaderboard.filter.exercise"].tap()
        let deadlift = app.buttons["option.conventional_deadlift"]
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
        XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 5))

        let videoLibrary = app.descendants(matching: .any)["profile.prVideos"]
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
        app.buttons["leaderboard.ranking.absolute"].tap()
        app.buttons["leaderboard.filter.exercise"].tap()
        let bench = app.buttons["option.bench"]
        XCTAssertTrue(bench.waitForExistence(timeout: 5))
        bench.tap()
        XCTAssertTrue(app.staticTexts["YOU"].waitForExistence(timeout: 8))
    }

    func testWorkoutHistoryFiltersCanBeClearedAfterNoMatches() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        let historyRoute = app.buttons["me.personalProfile"]
        for _ in 0..<6 where !historyRoute.isHittable { app.swipeUp() }
        XCTAssertTrue(historyRoute.isHittable)
        historyRoute.tap()
        let historySection = app.buttons["profile.section.history"]
        let navigation = app.scrollViews["profile.sectionNavigation"]
        for _ in 0..<3 where !historySection.isHittable { navigation.swipeLeft() }
        XCTAssertTrue(historySection.isHittable)
        historySection.tap()
        let filter = app.textFields["Filter workout history by exercise"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.tap()
        let query = "NoSuchExerciseForHistoryAudit"
        filter.typeText(query)
        XCTAssertTrue(app.staticTexts["No workouts match"].waitForExistence(timeout: 5))
        XCTAssertTrue(filter.exists)
        app.buttons["Clear filters"].tap()
        XCTAssertNotEqual(filter.value as? String, query)
        XCTAssertFalse(app.staticTexts["No workouts match"].exists)
    }

    func testBodyweightCheckInCreateEditDeleteUpdatesProgress() {
        var app = launchDemo(arguments: ["-uiTestingPersistWorkoutSnapshots"])
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        var progress = app.buttons["tracker.segment.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        progress.tap()
        app.segmentedControls["tracker.progress.category"].buttons["Strength"].tap()

        let relativeTotalText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "×")
        ).firstMatch
        XCTAssertTrue(relativeTotalText.waitForExistence(timeout: 5))
        let initialRelativeTotal = relativeTotalText.label

        var noWeight = app.staticTexts["No bodyweight logged yet"]
        for _ in 0..<8 where !noWeight.isHittable { app.swipeUp() }
        XCTAssertTrue(noWeight.waitForExistence(timeout: 5))
        app.buttons["Log bodyweight"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Bodyweight Entry"].waitForExistence(timeout: 5))
        let weight = app.textFields["Enter weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        let originalValue = weight.value as? String ?? ""
        XCTAssertFalse(originalValue.isEmpty)
        app.navigationBars["Bodyweight Entry"].buttons["Save"].tap()

        let trendPrompt = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "One entry logged" )).firstMatch
        XCTAssertTrue(trendPrompt.waitForExistence(timeout: 5))
        let createdRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", originalValue, "edit")).firstMatch
        XCTAssertTrue(createdRow.waitForExistence(timeout: 5))
        for _ in 0..<8 where !createdRow.isHittable { app.swipeUp() }
        app.swipeUp()
        XCTAssertTrue(createdRow.isHittable)
        createdRow.tap()

        XCTAssertTrue(app.navigationBars["Bodyweight Entry"].waitForExistence(timeout: 5))
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: originalValue.count) + "182")
        app.navigationBars["Bodyweight Entry"].buttons["Save"].tap()
        var editedRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "182", "edit")).firstMatch
        XCTAssertTrue(editedRow.waitForExistence(timeout: 5))
        for _ in 0..<8 where !relativeTotalText.isHittable { app.swipeDown() }
        XCTAssertTrue(relativeTotalText.isHittable)
        XCTAssertNotEqual(relativeTotalText.label, initialRelativeTotal)

        tab("profile", in: app).tap()
        app.buttons["me.personalProfile"].tap()
        let profileWeight = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Logged weight ·")).firstMatch
        XCTAssertTrue(profileWeight.waitForExistence(timeout: 5))
        XCTAssertTrue(profileWeight.label.contains("182"))

        app.terminate()
        app = launchDemo(arguments: ["-uiTestingPersistWorkoutSnapshots"])
        tab("profile", in: app).tap()
        app.buttons["me.personalProfile"].tap()
        let relaunchedProfileWeight = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Logged weight ·")
        ).firstMatch
        XCTAssertTrue(relaunchedProfileWeight.waitForExistence(timeout: 5))
        XCTAssertTrue(relaunchedProfileWeight.label.contains("182"))

        app.navigationBars.buttons["Me"].tap()
        tab("track", in: app).tap()
        progress = app.buttons["tracker.segment.progress"]
        progress.tap()
        app.segmentedControls["tracker.progress.category"].buttons["Strength"].tap()
        noWeight = app.staticTexts["No bodyweight logged yet"]
        editedRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "182", "edit")).firstMatch
        for _ in 0..<8 where !editedRow.isHittable { app.swipeUp() }
        app.swipeUp()
        XCTAssertTrue(editedRow.isHittable)

        editedRow.tap()
        XCTAssertTrue(app.navigationBars["Bodyweight Entry"].waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "Delete Entry").firstMatch.tap()
        let deleteConfirmation = app.sheets["Delete this bodyweight entry?"].buttons["Delete Entry"]
        XCTAssertTrue(deleteConfirmation.waitForExistence(timeout: 5))
        deleteConfirmation.tap()
        XCTAssertTrue(app.navigationBars["Bodyweight Entry"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(noWeight.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "182", "edit")).firstMatch.exists)
        let missingBodyweightSummary = app.staticTexts["Needs total and bodyweight"]
        for _ in 0..<8 where !missingBodyweightSummary.isHittable { app.swipeDown() }
        XCTAssertTrue(missingBodyweightSummary.waitForExistence(timeout: 5))

        tab("profile", in: app).tap()
        app.buttons["me.personalProfile"].tap()
        let profileWeightAfterDelete = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Logged weight ·")
        ).firstMatch
        XCTAssertFalse(profileWeightAfterDelete.waitForExistence(timeout: 2))

        app.terminate()
        app = launchDemo(arguments: ["-uiTestingPersistWorkoutSnapshots"])
        tab("profile", in: app).tap()
        app.buttons["me.personalProfile"].tap()
        let persistedProfileWeight = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Logged weight ·")
        ).firstMatch
        XCTAssertFalse(persistedProfileWeight.waitForExistence(timeout: 2))

        app.navigationBars.buttons["Me"].tap()
        tab("track", in: app).tap()
        progress = app.buttons["tracker.segment.progress"]
        progress.tap()
        app.segmentedControls["tracker.progress.category"].buttons["Strength"].tap()
        let persistedNoWeight = app.staticTexts["No bodyweight logged yet"]
        for _ in 0..<8 where !persistedNoWeight.isHittable { app.swipeUp() }
        XCTAssertTrue(persistedNoWeight.waitForExistence(timeout: 5))
    }

    func testEditProfileKeepsUnsavedFieldsAfterPhotoManager() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        let edit = app.buttons["Edit athlete profile"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let name = app.textFields["editProfile.displayName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(" Updated")
        let expected = name.value as? String
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Profile photo")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Profile Photo"].waitForExistence(timeout: 5))
        let photoManagerScreenshot = XCTAttachment(screenshot: app.screenshot())
        photoManagerScreenshot.name = "Profile photo manager at accessibility text size"
        photoManagerScreenshot.lifetime = .keepAlways
        add(photoManagerScreenshot)
        app.navigationBars["Profile Photo"].buttons["Done"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, expected)
        if app.keyboards.buttons["return"].exists { app.keyboards.buttons["return"].tap() }
        let logWeight = app.buttons["editProfile.logBodyweight"]
        for _ in 0..<5 where !logWeight.isHittable { app.swipeUp() }
        XCTAssertTrue(logWeight.isHittable)
        logWeight.tap()
        XCTAssertTrue(app.navigationBars["Bodyweight Entry"].waitForExistence(timeout: 5))
        app.navigationBars["Bodyweight Entry"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        app.navigationBars["Edit Profile"].buttons["Cancel"].tap()
    }

    func testProfilePhotoLibraryOpensAtAccessibilitySize() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        let edit = app.buttons["Edit athlete profile"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Profile photo")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Profile Photo"].waitForExistence(timeout: 5))
        app.buttons["Choose Photo"].tap()
        let firstPhoto = app.cells.firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 15))
        firstPhoto.tap()
        XCTAssertTrue(app.staticTexts["Adjust Photo"].waitForExistence(timeout: 10))
        let cropScreenshot = XCTAttachment(screenshot: app.screenshot())
        cropScreenshot.name = "Profile photo crop editor at accessibility text size"
        cropScreenshot.lifetime = .keepAlways
        add(cropScreenshot)
    }

    func testEditProfileUsesSearchableLocationAndGymPickers() {
        let app = launchDemo(arguments: ["-uiTestingGymFixture"])
        let meTab = tab("profile", in: app)
        XCTAssertTrue(meTab.waitForExistence(timeout: 8))
        meTab.tap()

        let editProfile = app.buttons["Edit athlete profile"]
        if !editProfile.waitForExistence(timeout: 5) {
            meTab.tap()
        }
        XCTAssertTrue(editProfile.waitForExistence(timeout: 5))
        editProfile.tap()

        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        let profileEditTopScreenshot = XCTAttachment(screenshot: app.screenshot())
        profileEditTopScreenshot.name = "Profile edit form at accessibility text size"
        profileEditTopScreenshot.lifetime = .keepAlways
        add(profileEditTopScreenshot)
        let location = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Location")).firstMatch
        var attempts = 0
        while (!location.exists || !location.isHittable) && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(location.waitForExistence(timeout: 5))
        XCTAssertTrue(location.isHittable)

        location.tap()
        let locationSearch = app.searchFields["Search city or state"]
        XCTAssertTrue(locationSearch.waitForExistence(timeout: 5))
        locationSearch.typeText("Miami")
        let locationOptionsScreenshot = XCTAttachment(screenshot: app.screenshot())
        locationOptionsScreenshot.name = "Profile location options at accessibility text size"
        locationOptionsScreenshot.lifetime = .keepAlways
        add(locationOptionsScreenshot)
        let miami = app.buttons["Miami, Florida · US"]
        XCTAssertTrue(miami.waitForExistence(timeout: 5))
        miami.tap()

        XCTAssertTrue(locationSearch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        let gym = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Primary gym")).firstMatch
        attempts = 0
        while !gym.isHittable && attempts < 4 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(gym.isHittable)
        gym.tap()
        let gymSearch = app.searchFields["Search name, city, or state"]
        if !gymSearch.waitForExistence(timeout: 5), gym.isHittable {
            gym.tap()
        }
        XCTAssertTrue(gymSearch.waitForExistence(timeout: 5))
        let gymOptionsScreenshot = XCTAttachment(screenshot: app.screenshot())
        gymOptionsScreenshot.name = "Profile gym options at accessibility text size"
        gymOptionsScreenshot.lifetime = .keepAlways
        add(gymOptionsScreenshot)

        let southBeach = app.buttons["option.C0000000-0000-0000-0000-000000000063"]
        XCTAssertTrue(southBeach.waitForExistence(timeout: 5))
        southBeach.tap()

        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        let selectedSouthBeach = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Crunch Fitness - South Beach")
        ).firstMatch
        XCTAssertTrue(selectedSouthBeach.waitForExistence(timeout: 5))

        let profileEditLocationScreenshot = XCTAttachment(screenshot: app.screenshot())
        profileEditLocationScreenshot.name = "Profile edit location and gym at accessibility text size"
        profileEditLocationScreenshot.lifetime = .keepAlways
        add(profileEditLocationScreenshot)
        app.navigationBars["Edit Profile"].buttons["Save"].tap()
        XCTAssertTrue(editProfile.waitForExistence(timeout: 5))
        for _ in 0..<5 where !editProfile.isHittable { app.swipeDown() }
        XCTAssertTrue(editProfile.isHittable)
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
        let reopenedLocation = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Location")).firstMatch
        for _ in 0..<5 where !reopenedLocation.isHittable { app.swipeUp() }
        reopenedLocation.tap()
        XCTAssertTrue(locationSearch.waitForExistence(timeout: 5))
        locationSearch.typeText("Toronto")
        app.buttons["Toronto, Ontario · CA"].tap()
        let noGym = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "No primary gym")).firstMatch
        XCTAssertTrue(noGym.waitForExistence(timeout: 5))
        app.navigationBars["Edit Profile"].buttons["Save"].tap()
        XCTAssertTrue(editProfile.waitForExistence(timeout: 5))
        editProfile.tap()
        let toronto = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Toronto, Ontario · CA")).firstMatch
        for _ in 0..<5 where !toronto.isHittable { app.swipeUp() }
        XCTAssertTrue(toronto.isHittable)
        XCTAssertTrue(noGym.exists)
        app.navigationBars["Edit Profile"].buttons["Cancel"].tap()
    }

    func testFindSubstituteOpensRecommendationsAndExerciseDetails() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        app.buttons["Library"].tap()

        let exerciseSearch = app.textFields["Search exercises"]
        XCTAssertTrue(exerciseSearch.waitForExistence(timeout: 5))
        exerciseSearch.tap()
        exerciseSearch.typeText("Barbell Bench Press")
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
        let substitutesScreenshot = XCTAttachment(screenshot: app.screenshot())
        substitutesScreenshot.name = "Exercise substitutes at accessibility XXL"
        substitutesScreenshot.lifetime = .keepAlways
        add(substitutesScreenshot)
        let firstExercise = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "substitute.exercise.")).firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 5))
        firstExercise.tap()
        XCTAssertTrue(app.buttons["About"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.firstMatch.exists)
        XCTAssertTrue(app.buttons["History"].exists)
        let exerciseDetailScreenshot = XCTAttachment(screenshot: app.screenshot())
        exerciseDetailScreenshot.name = "Substitute exercise detail at accessibility XXL"
        exerciseDetailScreenshot.lifetime = .keepAlways
        add(exerciseDetailScreenshot)
    }

    func testExerciseLibrarySupportsSearchCreationAndFocusedDetails() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()

        let library = app.buttons["Library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        library.tap()

        let search = app.textFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Create custom exercise"].exists)
        search.tap()
        search.typeText("Barbell Bench Press")

        let bench = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Barbell Bench Press")).firstMatch
        XCTAssertTrue(bench.waitForExistence(timeout: 5))
        bench.tap()

        for tab in ["About", "History", "Records", "Charts"] {
            XCTAssertTrue(app.buttons[tab].waitForExistence(timeout: 5), "Missing \(tab) exercise detail tab")
        }
    }

    func testTrackerSwitchingFromSearchDismissesKeyboardBeforePlanOptions() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        app.buttons["Library"].tap()

        let search = app.textFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("bench")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))

        app.buttons["Plans"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        let options = app.buttons["Plan options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2))
    }

    func testExerciseLibraryOpenPerformance() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        XCTAssertTrue(app.buttons["Library"].waitForExistence(timeout: 5))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            let today = app.buttons["Today"]
            XCTAssertTrue(today.waitForExistence(timeout: 5))
            today.tap()
            let library = app.buttons["Library"]
            XCTAssertTrue(library.waitForExistence(timeout: 5))

            startMeasuring()
            library.tap()
            XCTAssertTrue(app.textFields["Search exercises"].waitForExistence(timeout: 5))
            stopMeasuring()
        }
    }

    func testLeaderboardScoreModeChangeDoesNotRetainPreviousValue() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])

        let leaderboards = tab("leaderboards", in: app)
        XCTAssertTrue(leaderboards.waitForExistence(timeout: 8))
        leaderboards.tap()
        XCTAssertTrue(app.navigationBars["Leaderboards"].waitForExistence(timeout: 8))

        let relativeRanking = app.buttons["Pound-for-pound"]
        XCTAssertTrue(relativeRanking.waitForExistence(timeout: 5))
        relativeRanking.tap()
        let staleScore = app.staticTexts["1.75x"]
        XCTAssertTrue(staleScore.waitForExistence(timeout: 5))

        let totalRanking = app.buttons["Total"]
        XCTAssertTrue(totalRanking.waitForExistence(timeout: 5))
        totalRanking.tap()

        let transitionScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        transitionScreenshot.name = "Leaderboard total transition"
        transitionScreenshot.lifetime = .keepAlways
        add(transitionScreenshot)

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
        let leaderboardsTab = tab("leaderboards", in: app)
        XCTAssertTrue(leaderboardsTab.waitForExistence(timeout: 8))
        leaderboardsTab.tap()
        if !app.navigationBars["Leaderboards"].waitForExistence(timeout: 2) {
            leaderboardsTab.tap()
        }
        XCTAssertTrue(app.navigationBars["Leaderboards"].waitForExistence(timeout: 5))

        app.buttons["leaderboard.ranking.absolute"].tap()
        let exerciseFilter = app.buttons["leaderboard.filter.exercise"]
        XCTAssertTrue(exerciseFilter.waitForExistence(timeout: 5))
        exerciseFilter.tap()
        let bench = app.buttons["option.bench"]
        if !bench.waitForExistence(timeout: 2) {
            exerciseFilter.tap()
        }
        XCTAssertTrue(bench.waitForExistence(timeout: 5))
        bench.tap()
        if !bench.waitForNonExistence(timeout: 2) {
            bench.tap()
        }
        XCTAssertTrue(bench.waitForNonExistence(timeout: 5))
        let selectedBench = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Exercise, Barbell bench press"),
            object: exerciseFilter
        )
        XCTAssertEqual(XCTWaiter.wait(for: [selectedBench], timeout: 5), .completed)

        let otherAthlete = app.buttons["leaderboard.athlete.A0000000-0000-0000-0000-000000000001"]
        var attempts = 0
        while !otherAthlete.exists && attempts < 4 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(otherAthlete.waitForExistence(timeout: 5))
        otherAthlete.tap()
        let athleteOptions = app.buttons["profile.athleteOptions"]
        if !athleteOptions.waitForExistence(timeout: 2), otherAthlete.isHittable {
            otherAthlete.tap()
        }
        XCTAssertTrue(athleteOptions.waitForExistence(timeout: 5))
    }

    func testLeaderboardExerciseSearchUsesExercisePrompt() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()

        app.buttons["leaderboard.ranking.absolute"].tap()
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

    func testMeShowsSearchableGymDirectory() {
        let app = launchDemo(arguments: ["-uiTestingGymFixture"])
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let gyms = app.buttons["me.gyms"]
        var attempts = 0
        while !gyms.isHittable && attempts < 10 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(gyms.isHittable)
        gyms.tap()

        XCTAssertTrue(app.navigationBars["Gyms"].waitForExistence(timeout: 5))
        let search = app.textFields["gyms.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Cutler Bay")
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Crunch Fitness - Cutler Bay")
        ).firstMatch.waitForExistence(timeout: 5))
    }

    func testLeaderboardScopeSearchIncludesGyms() {
        let app = launchDemo(arguments: ["-uiTestingGymFixture"])
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()
        if !app.buttons["leaderboard.filter.compare_with"].waitForExistence(timeout: 2) {
            tab("leaderboards", in: app).tap()
        }

        let scope = app.buttons["leaderboard.filter.compare_with"]
        XCTAssertTrue(scope.waitForExistence(timeout: 5))
        scope.tap()
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

        let oldestAgeGroup = app.buttons["leaderboard.filters.option.70+"]
        var scrollAttempts = 0
        while !oldestAgeGroup.isHittable && scrollAttempts < 8 {
            app.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(oldestAgeGroup.isHittable)
        XCTAssertFalse(app.buttons["leaderboard.filters.option.hidden"].exists)
        let ageScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        ageScreenshot.name = "Leaderboard age filters"
        ageScreenshot.lifetime = .keepAlways
        add(ageScreenshot)
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
        let verification = app.switches["Require lift video"]
        let scrollView = app.scrollViews.firstMatch
        var attempts = 0
        while (!verification.isHittable || verification.frame.maxY >= app.staticTexts["lift.submitReason"].frame.minY) && attempts < 8 {
            scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.05, thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            attempts += 1
        }
        XCTAssertTrue(verification.waitForExistence(timeout: 5))
        XCTAssertTrue(verification.isHittable)
        XCTAssertGreaterThanOrEqual(verification.frame.minY, app.navigationBars["Submit Lift"].frame.maxY)
        verification.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(submit.isEnabled)
        submit.tap()

        XCTAssertTrue(app.staticTexts["lift.submissionResult"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Current leaderboard placement"].exists)
        XCTAssertTrue(app.staticTexts["Video filter active"].exists)
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
            XCTAssertTrue(app.staticTexts["Current leaderboard placement"].exists)
            return
        }
        if alert.exists {
            XCTFail("Submission failed before video upload: \(alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | "))")
        } else {
            XCTFail("Submission did not produce a result within 60 seconds")
        }
    }

    func testHomeShowsUsefulRecentPREmptyState() {
        let app = launchDemo(arguments: ["-uiTestingEmptyRecentPRs"])
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.recentPRs.emptyAction"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Log your first PR"].exists)
    }

    func testHomeRecentPROpenPerformance() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        let recentPR = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Open Barbell bench press PR")
        ).firstMatch
        XCTAssertTrue(recentPR.waitForExistence(timeout: 5))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            startMeasuring()
            recentPR.tap()
            XCTAssertTrue(app.navigationBars["PR details"].waitForExistence(timeout: 5))
            stopMeasuring()

            app.buttons["Done"].tap()
            XCTAssertTrue(app.navigationBars["PR details"].waitForNonExistence(timeout: 5))
        }
    }

    func testLeaderboardOpenPerformance() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        let home = tab("home", in: app)
        let leaderboards = tab("leaderboards", in: app)
        XCTAssertTrue(home.waitForExistence(timeout: 8))
        XCTAssertTrue(leaderboards.waitForExistence(timeout: 8))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            startMeasuring()
            leaderboards.tap()
            XCTAssertTrue(app.navigationBars["Leaderboards"].waitForExistence(timeout: 8))
            stopMeasuring()

            home.tap()
            XCTAssertTrue(home.waitForExistence(timeout: 5))
        }
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
        let confirmBlock = app.buttons["Block athlete"]
        XCTAssertTrue(confirmBlock.waitForExistence(timeout: 5))
        confirmBlock.tap()

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
        XCTAssertTrue(submit.isHittable)
        submit.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let confirmation = app.alerts["Report submitted"]
        let failure = app.staticTexts["The report could not be submitted. Try again."]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5) || failure.waitForExistence(timeout: 0.1))
        XCTAssertFalse(failure.exists)
        confirmation.buttons["Done"].tap()
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

        XCTAssertTrue(app.staticTexts["Track your lifts. See your progress."].waitForExistence(timeout: 8))
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.staticTexts["What are you training for?"].waitForExistence(timeout: 5))
        app.buttons["onboarding.focus.bodybuilding"].tap()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Build your lifter profile."].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Username"].value as? String, "launch_lifter")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["What are your best lifts?"].waitForExistence(timeout: 5))
        app.buttons["I’ll add my lifts later"].tap()

        XCTAssertTrue(app.staticTexts["You’re ready to compete."].waitForExistence(timeout: 5))
        app.buttons["Enter Lift Rivals"].tap()
        XCTAssertTrue(app.staticTexts["Before you compete"].waitForExistence(timeout: 8))
    }

    func testOnboardingYearsTrainingControlChangesValue() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingOnboarding", "-uiTestingPrefilledOnboarding"]
        app.launch()

        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 8))
        app.buttons["Get started"].tap()
        let powerlifting = app.buttons["onboarding.focus.powerlifting"]
        for _ in 0..<5 where !powerlifting.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(powerlifting.isHittable)
        powerlifting.tap()
        XCTAssertTrue(powerlifting.isSelected)
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        let increment = app.buttons["onboarding.yearsTraining.increment"]
        var attempts = 0
        while !increment.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(increment.waitForExistence(timeout: 5))
        let value = app.staticTexts["onboarding.yearsTraining.value"]
        XCTAssertEqual(value.label, "0")
        increment.tap()
        XCTAssertEqual(value.label, "1")
    }

    func testFreshOnboardingRequiresProfileDetailsBeforeAdvancing() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingOnboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Track your lifts. See your progress."].waitForExistence(timeout: 8))
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.staticTexts["What are you training for?"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Continue"].isEnabled)
        app.buttons["onboarding.focus.generalFitness"].tap()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Build your lifter profile."].waitForExistence(timeout: 5))
        let username = app.textFields["Username"]
        XCTAssertTrue(username.exists)
        XCTAssertTrue(app.buttons["onboarding.location.country"].exists)
        XCTAssertTrue(app.buttons["onboarding.location.region"].exists)
        XCTAssertTrue(app.buttons["onboarding.location.city"].exists)

        username.tap()
        username.typeText("fresh_lifter")
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Build your lifter profile."].exists)
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

    func testForumFailedPostSubmissionPreservesDraft() {
        let app = launchDemo()
        let forum = tab("forum", in: app)
        XCTAssertTrue(forum.waitForExistence(timeout: 8))
        forum.tap()
        app.buttons["New discussion"].tap()

        let title = app.textFields["Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Bench press plateau")

        let body = app.descendants(matching: .any)["forum.composer.body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap()
        body.typeText("My bench has stalled for three weeks.")
        app.buttons["Publish"].tap()

        XCTAssertTrue(app.staticTexts["Posting is unavailable in the simulator demo."].waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Bench press plateau")
        XCTAssertEqual(body.value as? String, "My bench has stalled for three weeks.")
        XCTAssertTrue(app.navigationBars["New discussion"].exists)
    }

    func testForumAuthorsCanEditAndDeleteTheirContent() {
        let app = launchDemo(arguments: ["-uiTestingEditableForumThread"])
        let forum = tab("forum", in: app)
        XCTAssertTrue(forum.waitForExistence(timeout: 8))
        forum.tap()

        let title = app.staticTexts["Editable UI test discussion"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        title.tap()

        let discussionActions = app.buttons["forum.discussion.actions"]
        XCTAssertTrue(discussionActions.waitForExistence(timeout: 5))
        discussionActions.tap()
        app.buttons["Edit discussion"].tap()

        let editTitle = app.textFields["forum.edit.title"]
        XCTAssertTrue(editTitle.waitForExistence(timeout: 5))
        editTitle.tap()
        editTitle.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Editable UI test discussion".count))
        editTitle.typeText("Updated UI test discussion")

        let editBody = app.descendants(matching: .any)["forum.edit.body"]
        editBody.tap()
        editBody.typeText("Updated discussion body")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Updated UI test discussion"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Updated discussion body")).firstMatch.exists)

        let commentActions = app.buttons["forum.comment.actions"]
        XCTAssertTrue(commentActions.waitForExistence(timeout: 5))
        commentActions.tap()
        app.buttons["Edit comment"].tap()
        let editComment = app.descendants(matching: .any)["forum.edit.body"]
        XCTAssertTrue(editComment.waitForExistence(timeout: 5))
        editComment.tap()
        editComment.typeText("Updated UI test comment")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Updated UI test comment")).firstMatch.waitForExistence(timeout: 5))

        commentActions.tap()
        app.buttons["forum.comment.delete"].firstMatch.tap()
        app.buttons["forum.comment.delete.confirm"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["0 comments"].waitForExistence(timeout: 5))

        let reply = app.descendants(matching: .any)["forum.reply.body"]
        reply.tap()
        reply.typeText("Keep my reply draft if posting fails.")
        app.buttons["forum.reply.submit"].tap()
        XCTAssertTrue(app.staticTexts["Commenting is unavailable in the simulator demo."].waitForExistence(timeout: 5))
        XCTAssertEqual(reply.value as? String, "Keep my reply draft if posting fails.")

        discussionActions.tap()
        app.buttons["forum.discussion.delete"].firstMatch.tap()
        app.buttons["forum.discussion.delete.confirm"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Editable UI test discussion"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Updated UI test discussion"].waitForNonExistence(timeout: 5))
    }

}
