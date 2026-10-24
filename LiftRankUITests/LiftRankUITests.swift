import XCTest

final class LiftRankUITests: XCTestCase {
    private func tab(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons["mainTab.\(name)"]
    }

    @MainActor
    private func auditAccessibility(_ app: XCUIApplication, screen: String, checks: XCUIAccessibilityAuditType = .all) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = screen
        screenshot.lifetime = .keepAlways
        add(screenshot)
        do {
            try app.performAccessibilityAudit(for: checks)
        } catch {
            XCTFail("\(screen) accessibility audit failed: \(error)")
        }
    }

    private func launchDemo(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingDemoMode"] + arguments
        app.launch()
        return app
    }

    private func launchCurrentAccount(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        let accountFixture = arguments.contains("-uiTestingRestoredAuthenticatedAccount")
            ? []
            : ["-uiTestingAuthenticatedAccount"]
        app.launchArguments += accountFixture + arguments
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

    func testActiveWorkoutRPEAndReorderMenusExposeAccessibleActions() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout", "-uiTestingActiveWorkoutWithExercise"])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()

        let exercise = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Barbell Bench Press")).firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        exercise.tap()
        XCTAssertTrue(app.navigationBars["Track exercise"].waitForExistence(timeout: 5))

        for value in 6...10 {
            XCTAssertTrue(app.buttons["RPE \(value)"].waitForExistence(timeout: 5))
        }
        app.buttons["RPE 8"].tap()
        XCTAssertTrue(app.buttons["RPE 8"].exists)

        app.navigationBars.buttons.firstMatch.tap()
        let workoutOptions = app.buttons["Workout options"]
        XCTAssertTrue(workoutOptions.waitForExistence(timeout: 5))
        workoutOptions.tap()
        app.buttons["Reorder Exercises"].tap()
        let reorderExercise = app.buttons["Reorder Barbell Bench Press"]
        XCTAssertTrue(reorderExercise.waitForExistence(timeout: 5))
        reorderExercise.tap()
        XCTAssertTrue(app.buttons["Move earlier"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Move later"].exists)
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

    func testActiveWorkoutConflictOffersOneOpenActionAndExplicitDiscardOrCancel() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout"])
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()

        let plans = app.buttons["tracker.segment.plans"]
        XCTAssertTrue(plans.waitForExistence(timeout: 5))
        plans.tap()
        let activePlan = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Active plan")
        ).firstMatch
        XCTAssertTrue(activePlan.waitForExistence(timeout: 5))
        activePlan.tap()
        let planOptions = app.buttons["Plan detail options"]
        XCTAssertTrue(planOptions.waitForExistence(timeout: 5))
        planOptions.tap()
        app.buttons["Workouts"].tap()
        let startWorkout = app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "Start workout", "Repeat workout")
        ).firstMatch
        XCTAssertTrue(startWorkout.waitForExistence(timeout: 5))
        startWorkout.tap()

        XCTAssertTrue(app.buttons["Open Active Workout"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Discard Active & Start New"].exists)
        let cancelAction = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Cancel")
        ).firstMatch
        XCTAssertTrue(cancelAction.exists, app.debugDescription)
        XCTAssertFalse(app.buttons["Resume Active Workout"].exists)
        XCTAssertFalse(app.buttons["Review & Finish Active Workout"].exists)
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

        XCTAssertTrue(app.staticTexts["Workout saved"].exists)
        XCTAssertFalse(app.navigationBars.buttons["Done"].exists)
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

    func testCompletedWorkoutEditRequiresConfirmationBeforeDiscardingDraft() {
        let app = launchDemo(arguments: ["-uiTestingFocusedWorkoutSet"])
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()
        let editWorkout = app.buttons["Edit workout history"]
        XCTAssertTrue(editWorkout.waitForExistence(timeout: 8))
        editWorkout.tap()

        let notes = app.descendants(matching: .any)["workoutEdit.notes"]
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        notes.tap()
        notes.typeText("Draft note")

        app.navigationBars["Edit workout"].buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Keep Editing"].waitForExistence(timeout: 3))
        app.buttons["Keep Editing"].tap()
        XCTAssertTrue(notes.waitForExistence(timeout: 3))
        XCTAssertTrue((notes.value as? String)?.contains("Draft note") == true)

        app.navigationBars["Edit workout"].buttons["Cancel"].tap()
        app.buttons["Discard Changes"].tap()
        XCTAssertTrue(app.staticTexts["Barbell Bench Press"].waitForExistence(timeout: 5))
    }

    func testTrackerTodayPrioritizesActiveWorkout() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout"])
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()

        XCTAssertTrue(app.staticTexts["ACTIVE WORKOUT"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["NEXT WORKOUT"].exists)
    }

    func testWeeklyTrainingDayGoalCanBeSetOnHomeAndShownInTracker() {
        let app = launchDemo()
        let setGoal = app.buttons["weeklyTrainingGoal.set"]
        XCTAssertTrue(setGoal.waitForExistence(timeout: 8))
        setGoal.tap()

        let homeGoal = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Weekly training-day goal")
        ).firstMatch
        XCTAssertTrue(homeGoal.waitForExistence(timeout: 5))
        XCTAssertEqual(homeGoal.value as? String, "0 of 3 days")

        tab("track", in: app).tap()
        app.buttons["tracker.segment.progress"].tap()
        app.segmentedControls["tracker.progress.category"].buttons["Consistency"].tap()
        let trackerGoal = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Weekly training-day goal")
        ).firstMatch
        var attempts = 0
        while !trackerGoal.exists && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(trackerGoal.waitForExistence(timeout: 5))
        XCTAssertEqual(trackerGoal.value as? String, "0 of 3 days")
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
        XCTAssertTrue(app.buttons.matching(NSPredicate(
            format: "label == %@ OR label BEGINSWITH %@",
            "No previous set values",
            "Use previous workout values:"
        )).firstMatch.waitForExistence(timeout: 5))
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

    func testAccessibilityDynamicTypeKeepsWorkoutSetInputsReachable() {
        let app = launchDemo(arguments: [
            "-uiTestingActiveWorkout",
            "-uiTestingActiveWorkoutWithExercise",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()

        let exercise = app.staticTexts["Barbell Bench Press"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        exercise.tap()

        let reps = app.textFields["workout.set.1.reps"]
        for _ in 0..<8 where !reps.exists {
            app.swipeUp()
        }
        let weight = app.textFields["workout.set.1.weight"]
        let previousValues = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label BEGINSWITH %@",
            "No previous set values",
            "Use previous workout values:"
        )).firstMatch
        let rpe6 = app.buttons["RPE 6"]
        let setOptions = app.buttons.matching(NSPredicate(format: "label == %@", "Show set options")).firstMatch
        let completeSet = app.buttons.matching(NSPredicate(format: "label == %@", "Complete set")).firstMatch

        XCTAssertTrue(reps.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["PREVIOUS"].exists)
        XCTAssertTrue(weight.exists)
        XCTAssertTrue(previousValues.exists)
        XCTAssertTrue(rpe6.isHittable)
        XCTAssertGreaterThanOrEqual(rpe6.frame.height, 48)
        XCTAssertTrue(setOptions.isHittable)
        XCTAssertGreaterThanOrEqual(setOptions.frame.height, 52)
        XCTAssertLessThanOrEqual(setOptions.frame.height, 100)
        XCTAssertTrue(completeSet.exists)
        XCTAssertTrue(reps.isHittable)
        XCTAssertTrue(weight.isHittable)
        XCTAssertGreaterThanOrEqual(reps.frame.height, 52)
        XCTAssertGreaterThanOrEqual(weight.frame.height, 52)
        XCTAssertGreaterThanOrEqual(previousValues.frame.height, 44)
        XCTAssertGreaterThanOrEqual(completeSet.frame.width, 48)

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Accessibility XXXL workout set entry"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testFrenchCommaDecimalWeightCompletesAWorkoutSet() {
        let app = launchDemo(arguments: [
            "-uiTestingActiveWorkout",
            "-uiTestingActiveWorkoutWithExercise",
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR"
        ])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()

        let exercise = app.staticTexts["Barbell Bench Press"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        exercise.tap()

        let reps = app.textFields["workout.set.1.reps"]
        let weight = app.textFields["workout.set.1.weight"]
        XCTAssertTrue(reps.waitForExistence(timeout: 5))
        reps.tap()
        reps.typeText("8")
        app.buttons["workout.setInput.keyboardAction"].tap()
        weight.typeText("72,5")

        let completeSet = app.buttons.matching(NSPredicate(format: "label == %@", "Complete set")).firstMatch
        XCTAssertTrue(completeSet.waitForExistence(timeout: 3))
        completeSet.tap()
        XCTAssertTrue(app.buttons["Mark set incomplete"].waitForExistence(timeout: 3))
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

        let searchExercises = app.textFields["Search exercises"]
        XCTAssertTrue(searchExercises.waitForExistence(timeout: 5))
        searchExercises.tap()
        searchExercises.typeText("zzzz-no-match")
        XCTAssertTrue(app.staticTexts["No exercises found"].waitForExistence(timeout: 5))
        app.buttons["Clear search and filters"].tap()

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

    func testSinglePlanShowsStopAndSwipeToDeleteActions() {
        let app = launchDemo()
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()
        let plans = app.buttons["tracker.segment.plans"]
        XCTAssertTrue(plans.waitForExistence(timeout: 5))
        plans.tap()

        let createPlan = app.buttons["Create plan"]
        if createPlan.waitForExistence(timeout: 2) {
            createPlan.tap()
            let planName = app.textFields["planFromHistory.name"]
            let phaseName = app.textFields["planFromHistory.phaseName"]
            XCTAssertTrue(planName.waitForExistence(timeout: 5))
            XCTAssertTrue(phaseName.waitForExistence(timeout: 5))
            planName.tap()
            planName.typeText("Simulator Plan")
            phaseName.tap()
            phaseName.typeText("Simulator Phase")
            let create = app.buttons["planFromHistory.continue"]
            XCTAssertTrue(create.isEnabled)
            create.tap()
        }

        XCTAssertTrue(app.staticTexts["My Plans"].waitForExistence(timeout: 5))
        let planRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tracker.plan.row.")).firstMatch
        XCTAssertTrue(planRow.waitForExistence(timeout: 5))
        planRow.tap()
        let stopProgram = app.buttons["tracker.program.stop"]
        XCTAssertTrue(stopProgram.waitForExistence(timeout: 5))
        stopProgram.tap()
        XCTAssertTrue(stopProgram.waitForNonExistence(timeout: 5))

        planRow.tap()
        XCTAssertTrue(stopProgram.waitForExistence(timeout: 5))
        var scrollAttempts = 0
        while !planRow.isHittable && scrollAttempts < 6 {
            app.swipeUp()
            scrollAttempts += 1
        }
        planRow.swipeLeft()
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["tracker.program.stop"].waitForExistence(timeout: 5))

        let planOptions = app.buttons["Plan detail options"]
        XCTAssertTrue(planOptions.waitForExistence(timeout: 5))
        planOptions.tap()
        app.buttons["Plan Overview"].tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "workouts have every exercise logged")
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
    }

    func testProgramSessionExerciseDisclosureMeetsMinimumTouchTarget() {
        let app = launchDemo()
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()

        let plans = app.buttons["tracker.segment.plans"]
        XCTAssertTrue(plans.waitForExistence(timeout: 5))
        plans.tap()

        let disclosure = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "exercises,", "sets")
        ).firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(disclosure.frame.height, 44)
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
        app.buttons["tracker.segment.progress"].tap()

        let categories = app.segmentedControls["tracker.progress.category"]
        XCTAssertTrue(categories.waitForExistence(timeout: 5))
        categories.buttons["Strength"].tap()
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
            XCTAssertTrue(app.staticTexts["Program consistency"].waitForExistence(timeout: 5))
        }

        categories.buttons["Muscle"].tap()
        let period = app.buttons["tracker.muscle.period"]
        XCTAssertTrue(period.isHittable)
        period.tap()
        app.buttons["Last week"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "Completed week")).firstMatch.exists)
    }

    func testMuscleWorkloadFiltersAndExerciseBreakdown() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        app.buttons["tracker.segment.progress"].tap()
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

        let muscle = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier != %@ AND identifier != %@",
            "tracker.muscle.", "tracker.muscle.period", "tracker.muscle.filter"
        )).firstMatch
        for _ in 0..<5 where !muscle.isHittable { app.swipeUp() }
        XCTAssertTrue(muscle.isHittable)
        muscle.tap()
        XCTAssertTrue(app.staticTexts["Four-week workload"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Contributing exercises · selected week"].exists)
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
            capture("Audit Track \(section)")
        }
        let categories = app.segmentedControls["tracker.progress.category"]
        for category in ["Strength", "Muscle", "Consistency"] {
            categories.buttons[category].tap()
            if category == "Strength" {
                let totalLabel = app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label == %@", "Three-Lift Total, 1065 lb"))
                    .firstMatch
                XCTAssertTrue(totalLabel.waitForExistence(timeout: 5))
            }
            if category == "Consistency" {
                XCTAssertTrue(app.staticTexts["Week 12 · Recovery & Performance Check"].exists)
                XCTAssertFalse(app.staticTexts["Week 12 · Week 12 · Recovery & Performance Check"].exists)
            }
            capture("Audit Progress \(category)")
        }
        for name in ["leaderboards", "forum", "profile"] {
            tab(name, in: app).tap()
            if name == "leaderboards" {
                let loading = app.descendants(matching: .any)["Updating leaderboard"]
                if loading.waitForExistence(timeout: 1) {
                    XCTAssertTrue(loading.waitForNonExistence(timeout: 15), "Leaderboard did not leave its loading state")
                }
            }
            capture("Audit \(name)")
        }
        XCTAssertTrue(app.buttons["me.personalProfile"].exists)
        app.buttons["me.publicProfile"].tap()
        XCTAssertTrue(app.staticTexts["alex.reyes"].waitForExistence(timeout: 5))
        XCTAssertTrue(tab("profile", in: app).waitForNonExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.5)
        capture("Audit Public profile")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["me.personalProfile"].tap()
        XCTAssertTrue(app.navigationBars["Personal profile"].waitForExistence(timeout: 5))
        capture("Audit Personal profile")
    }

    func testForumSortSelectionSurvivesSwitchingTabs() {
        let app = launchDemo()
        let forum = tab("forum", in: app)
        XCTAssertTrue(forum.waitForExistence(timeout: 8))
        forum.tap()
        XCTAssertTrue(app.navigationBars["Forum"].waitForExistence(timeout: 8))

        let topFeed = app.buttons["Top"]
        let newFeed = app.buttons["New"]
        XCTAssertTrue(topFeed.waitForExistence(timeout: 5))
        XCTAssertTrue(topFeed.isSelected)
        XCTAssertFalse(newFeed.isSelected)
        newFeed.tap()
        XCTAssertTrue(newFeed.isSelected)
        XCTAssertFalse(topFeed.isSelected)

        let sortMenu = app.buttons["Sort discussions by Top"]
        XCTAssertTrue(sortMenu.waitForExistence(timeout: 5))
        sortMenu.tap()
        app.buttons["New"].tap()
        XCTAssertTrue(app.buttons["Sort discussions by New"].waitForExistence(timeout: 5))

        tab("home", in: app).tap()
        forum.tap()
        XCTAssertTrue(app.buttons["Sort discussions by New"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPrimaryScreensPassContrastClippingAndTouchTargetAudit() {
        for appearance in ["light", "dark"] {
            let app = launchDemo(arguments: ["-liftrank.appearance", appearance,
                                              "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"])
            XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
            auditAccessibility(app, screen: "\(appearance) Home", checks: [.contrast, .textClipped, .hitRegion])

            tab("track", in: app).tap()
            auditAccessibility(app, screen: "\(appearance) Track Today", checks: [.contrast, .textClipped, .hitRegion])
            for section in ["plans", "library", "progress"] {
                app.buttons["tracker.segment.\(section)"].tap()
                auditAccessibility(app, screen: "\(appearance) Track \(section)", checks: [.contrast, .textClipped, .hitRegion])
            }
            let categories = app.segmentedControls["tracker.progress.category"]
            for category in ["Strength", "Muscle", "Body", "Consistency"] {
                categories.buttons[category].tap()
                auditAccessibility(app, screen: "\(appearance) Progress \(category)", checks: [.contrast, .textClipped, .hitRegion])
            }

            for name in ["leaderboards", "forum", "profile"] {
                tab(name, in: app).tap()
                auditAccessibility(app, screen: "\(appearance) \(name)", checks: [.contrast, .textClipped, .hitRegion])
            }
            app.terminate()
        }
    }

    @MainActor
    func testLeaderboardsPassPlatformAccessibilityAudit() {
        let app = launchDemo()
        let leaderboards = tab("leaderboards", in: app)
        XCTAssertTrue(leaderboards.waitForExistence(timeout: 8))
        leaderboards.tap()
        XCTAssertTrue(app.navigationBars["Leaderboards"].waitForExistence(timeout: 5))
        auditAccessibility(app, screen: "Leaderboards")
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
        XCTAssertTrue(app.buttons["training.programPreview.start"].waitForExistence(timeout: 3))
        let session = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "exercises,")).firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Week 1 preview"].exists)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Audit Program Preview Expanded Session"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLaunchesIntoAuthenticatedDemoWorkspace() {
        let app = launchDemo()

        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Enter Explicit Demo Mode"].exists)
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

    func testAccessibilityDynamicTypeKeepsTrackPlanNavigationReachable() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTestingDemoMode",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()

        let plans = app.buttons["tracker.segment.plans"]
        XCTAssertTrue(plans.waitForExistence(timeout: 5))
        XCTAssertTrue(plans.isHittable)
        plans.tap()
        XCTAssertTrue(app.staticTexts["Program details"].waitForExistence(timeout: 5))

        let repeatWorkout = app.buttons.matching(identifier: "Repeat workout").firstMatch
        for _ in 0..<6 where !repeatWorkout.isHittable { app.swipeUp() }
        XCTAssertTrue(repeatWorkout.isHittable)
        XCTAssertGreaterThan(repeatWorkout.frame.width, app.windows.firstMatch.frame.width * 0.65)
    }

    func testAccessibilityDynamicTypeOnboardingCanAdvance() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTestingOnboarding",
            "-uiTestingPrefilledOnboarding",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let build = app.buttons["Build My Lift Rivals"]
        XCTAssertTrue(build.waitForExistence(timeout: 8))
        XCTAssertTrue(build.isHittable)
        build.tap()

        XCTAssertTrue(app.staticTexts["What are you training for?"].waitForExistence(timeout: 5))
        let focus = app.buttons["onboarding.focus.powerlifting"]
        XCTAssertTrue(focus.waitForExistence(timeout: 5))
        for _ in 0..<4 where !focus.isHittable { app.swipeUp() }
        XCTAssertTrue(focus.isHittable)
        focus.tap()

        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.isEnabled)
        XCTAssertTrue(next.isHittable)
        next.tap()

        XCTAssertTrue(app.staticTexts["Build your lifter profile."].waitForExistence(timeout: 5))
        let username = app.textFields["Username"]
        for _ in 0..<10 where !username.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(username.isHittable)
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

        let awards = app.buttons["me.awards"]
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

    func testPublicProfileUsesCompactEmptyStatesAndKeepsAchievementsPrivate() {
        let app = launchDemo(arguments: ["-uiTestingEmptyCurrentUserLifts"])
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let publicProfile = app.descendants(matching: .any)["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.tap()

        XCTAssertTrue(tab("profile", in: app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["profile.noPublicData"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No public training data"].exists)
        XCTAssertFalse(app.buttons["profile.section.training"].exists)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "profile.achievement.locked").count, 0)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "profile.achievement.unlocked").count, 0)
    }

    func testPublicProfileUsesStrengthRecordSectionsAndKeepsAccountControlsSeparate() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        let publicProfile = app.descendants(matching: .any)["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.tap()

        XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 5))
        for section in ["overview", "prVideos", "training", "submissions"] {
            XCTAssertTrue(app.buttons["profile.section.\(section)"].waitForExistence(timeout: 5))
        }
        app.buttons["profile.section.training"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.completedWorkouts"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["profile.prVideos"].exists)
        app.buttons["profile.section.prVideos"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.prVideos"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Delete account"].exists)

        app.buttons["profile.section.submissions"].tap()
        XCTAssertTrue(app.staticTexts["Submissions"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()

        XCTAssertTrue(app.descendants(matching: .any)["me.profileHeader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["me.header.settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["me.header.editProfile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 location · 0 joined"].exists)

        let strength = app.descendants(matching: .any)["me.section.strengthProgress"]
        let topLifts = app.descendants(matching: .any)["me.section.topLifts"]
        let trainingStats = app.descendants(matching: .any)["me.section.trainingStats"]
        let recentPerformance = app.descendants(matching: .any)["me.section.recentPerformance"]

        XCTAssertFalse(strength.exists)
        app.buttons["Training details"].tap()
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

        let history = app.buttons["me.personalProfile"]
        var attempts = 0
        while !history.isHittable && attempts < 12 {
            app.swipeUp()
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
        XCTAssertTrue(gyms.isHittable)
        XCTAssertLessThan(gyms.frame.maxY, profileTab.frame.minY)
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

    func testDemoCompetitionFixtureShowsSubmittedVideoAndLeaderboardEntry() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        let leaderboard = tab("leaderboards", in: app)
        XCTAssertTrue(leaderboard.waitForExistence(timeout: 8))
        leaderboard.tap()
        let athlete = app.buttons["leaderboard.athlete.A0000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(athlete.waitForExistence(timeout: 5))
        athlete.tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["profile.prVideos"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "profile.liftVideo.")
        ).firstMatch.exists)

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Leaderboards"].waitForExistence(timeout: 8))
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
        let historySection = app.buttons["profile.section.training"]
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
        app.navigationBars["Profile Photo"].buttons["Done"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, expected)
        if app.keyboards.firstMatch.exists {
            app.keyboards.buttons["return"].tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        }
        let logWeight = app.buttons["editProfile.logBodyweight"]
        for _ in 0..<5 where !logWeight.isHittable { app.swipeUp() }
        XCTAssertTrue(logWeight.isHittable)
        logWeight.tap()
        XCTAssertTrue(app.navigationBars["Bodyweight Entry"].waitForExistence(timeout: 5))
        app.navigationBars["Bodyweight Entry"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        app.navigationBars["Edit Profile"].buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Keep Editing"].waitForExistence(timeout: 3))
        app.buttons["Keep Editing"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertEqual(name.value as? String, expected)
        app.navigationBars["Edit Profile"].buttons["Cancel"].tap()
        app.buttons["Discard Changes"].tap()
        XCTAssertFalse(app.navigationBars["Edit Profile"].waitForExistence(timeout: 2))
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
        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

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
        capture("Audit Substitute Recommendations")
        let firstExercise = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "substitute.exercise.")).firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 5))
        firstExercise.tap()
        XCTAssertTrue(app.buttons["About"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["History"].exists)
        app.swipeUp()
        capture("Audit Substitute Exercise Detail")
    }

    func testExerciseLibrarySupportsSearchCreationAndFocusedDetails() {
        let app = launchDemo()
        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()

        let library = app.buttons["Library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        library.tap()

        let exerciseIndex = app.buttons["Exercise index"]
        XCTAssertTrue(exerciseIndex.waitForExistence(timeout: 5))
        let firstExercise = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "45-Degree Back Extension Machine")
        ).firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 5))
        XCTAssertFalse(exerciseIndex.frame.intersects(firstExercise.frame), "The alphabet index must not cover an exercise row")
        exerciseIndex.tap()
        let jumpToB = app.buttons["B"].firstMatch
        XCTAssertTrue(jumpToB.waitForExistence(timeout: 5))
        jumpToB.tap()
        let benchBeforeSearch = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Barbell Bench Press")).firstMatch
        for _ in 0..<5 where !benchBeforeSearch.isHittable { app.swipeUp() }
        XCTAssertTrue(benchBeforeSearch.waitForExistence(timeout: 5))
        XCTAssertTrue(benchBeforeSearch.isHittable)

        let search = app.textFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        let createExercise = app.buttons["Create custom exercise"]
        XCTAssertTrue(createExercise.waitForExistence(timeout: 5))
        createExercise.tap()
        XCTAssertTrue(app.navigationBars["New Exercise"].waitForExistence(timeout: 5))
        capture("Audit Custom Exercise Form")
        let exerciseName = app.textFields["Exercise name"]
        exerciseName.tap()
        exerciseName.typeText("Audit exercise")
        XCTAssertEqual(exerciseName.value as? String, "Audit exercise")
        capture("Audit Custom Exercise Text Entry")
        app.navigationBars["New Exercise"].buttons["Cancel"].tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        capture("Audit Exercise Library Jump-to-Letter")
        search.tap()
        search.typeText("Barbell Bench Press")

        let bench = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Barbell Bench Press")).firstMatch
        XCTAssertTrue(bench.waitForExistence(timeout: 5))
        capture("Audit Exercise Library Search Results")
        bench.tap()

        let aboutTab = app.buttons["About"]
        XCTAssertTrue(aboutTab.waitForExistence(timeout: 5), "Missing About exercise detail tab")
        app.swipeUp()
        capture("Audit Exercise Detail About")
        app.swipeDown()
        for tab in ["History", "Records", "Charts"] {
            let tabButton = app.buttons[tab]
            XCTAssertTrue(tabButton.waitForExistence(timeout: 5), "Missing \(tab) exercise detail tab")
            tabButton.tap()
            XCTAssertTrue(tabButton.isSelected, "\(tab) exercise detail tab should be selected")
            app.swipeUp()
            capture("Audit Exercise Detail \(tab)")
            if tab == "History" {
                let historyEntry = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS %@", "October 12, 2026")
                ).firstMatch
                XCTAssertTrue(historyEntry.waitForExistence(timeout: 5))
                historyEntry.tap()
                XCTAssertTrue(app.navigationBars["Workout details"].waitForExistence(timeout: 5))
                capture("Audit Completed Workout Details")
                app.navigationBars["Workout details"].buttons["Done"].tap()
            }
            app.swipeDown()
        }
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

    func testLeaderboardDoesNotShowScoreFromPreviousRanking() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
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
        let leaderboards = tab("leaderboards", in: app)
        XCTAssertTrue(leaderboards.waitForExistence(timeout: 8))
        leaderboards.tap()
        XCTAssertTrue(app.navigationBars["Leaderboards"].waitForExistence(timeout: 8))

        let trailingRanking = app.buttons["Most improved"]
        XCTAssertTrue(trailingRanking.waitForExistence(timeout: 5))
        trailingRanking.tap()
        XCTAssertTrue(trailingRanking.isSelected)
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
        let leaderboardsTab = tab("leaderboards", in: app)
        XCTAssertTrue(leaderboardsTab.waitForExistence(timeout: 8))
        leaderboardsTab.tap()
        if !app.navigationBars["Leaderboards"].waitForExistence(timeout: 2) {
            leaderboardsTab.tap()
        }
        XCTAssertTrue(app.navigationBars["Leaderboards"].waitForExistence(timeout: 5))

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
        if !app.buttons["leaderboard.filter.scope"].waitForExistence(timeout: 2) {
            tab("leaderboards", in: app).tap()
        }

        let scope = app.buttons["leaderboard.filter.scope"]
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

        let videoBacked = app.buttons["leaderboard.filters.option.video_backed"]
        let allLifts = app.buttons["leaderboard.filters.option.all_lifts"]
        XCTAssertTrue(videoBacked.waitForExistence(timeout: 5))
        XCTAssertTrue(allLifts.waitForExistence(timeout: 5))
        XCTAssertTrue(videoBacked.isSelected)
        XCTAssertFalse(allLifts.isSelected)
        allLifts.tap()
        XCTAssertTrue(allLifts.isSelected)
        XCTAssertFalse(videoBacked.isSelected)

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

    func testLeaderboardAthleteIdentityWrapsWithoutTruncation() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        let leaderboards = tab("leaderboards", in: app)
        XCTAssertTrue(leaderboards.waitForExistence(timeout: 8))
        leaderboards.tap()

        let identity = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Crunch Fitness - South Beach")
        ).firstMatch
        XCTAssertTrue(identity.waitForExistence(timeout: 8))
        XCTAssertTrue(identity.label.contains("Crunch Fitness - South Beach"), identity.label)
        XCTAssertGreaterThanOrEqual(identity.frame.height, 24, "Athlete identity should wrap instead of clipping")
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

    func testSubmitLiftRequiresConfirmationBeforeDiscardingDraft() {
        let app = launchDemo()
        XCTAssertTrue(tab("leaderboards", in: app).waitForExistence(timeout: 8))
        tab("leaderboards", in: app).tap()
        app.buttons["leaderboard.submitLift"].tap()
        XCTAssertTrue(app.navigationBars["Submit Lift"].waitForExistence(timeout: 5))

        let caption = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Add a caption (optional)")
        ).firstMatch
        for _ in 0..<8 where !caption.isHittable { app.swipeUp() }
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        XCTAssertTrue(caption.isHittable)
        caption.tap()
        caption.typeText("Keep this draft")

        let close = app.navigationBars["Submit Lift"].buttons["Close"]
        XCTAssertTrue(close.exists)
        close.tap()
        XCTAssertTrue(app.buttons["Discard Draft"].waitForExistence(timeout: 5))
        app.buttons["Keep Editing"].tap()
        XCTAssertTrue(app.navigationBars["Submit Lift"].exists)

        close.tap()
        app.buttons["Discard Draft"].tap()
        XCTAssertTrue(app.navigationBars["Submit Lift"].waitForNonExistence(timeout: 5))
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
        let app = launchCurrentAccount()
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
        let app = launchDemo(arguments: ["-uiTestingEmptyCurrentUserLifts"])
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        let emptyAction = app.buttons["home.recentPRs.emptyAction"]
        for _ in 0..<5 where !emptyAction.isHittable { app.swipeUp() }
        XCTAssertTrue(emptyAction.waitForExistence(timeout: 5))
        XCTAssertTrue(emptyAction.isHittable)
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
        submit.tap()
        let success = app.alerts["Report submitted"]
        XCTAssertTrue(success.waitForExistence(timeout: 5))
        success.buttons["Done"].tap()
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
        let editProfile = app.buttons["legal.editProfile"]
        XCTAssertTrue(editProfile.exists)
        editProfile.tap()
        let cancel = app.buttons["profile.edit.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(app.staticTexts["Before you compete"].waitForExistence(timeout: 5))
    }

    func testOnboardingYearsTrainingControlChangesValue() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingOnboarding", "-uiTestingPrefilledOnboarding"]
        app.launch()

        XCTAssertTrue(app.buttons["Build My Lift Rivals"].waitForExistence(timeout: 8))
        app.buttons["Build My Lift Rivals"].tap()
        app.buttons["onboarding.focus.powerlifting"].tap()
        app.buttons["Continue"].tap()

        let increment = app.buttons["onboarding.yearsTraining.increment"]
        var attempts = 0
        while !increment.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(increment.waitForExistence(timeout: 5))
        let value = app.staticTexts["onboarding.yearsTraining.value"]
        guard let initialYears = Int(value.label) else {
            XCTFail("Years-training control should expose its current numeric value")
            return
        }
        increment.tap()
        XCTAssertEqual(value.label, String(initialYears + 1))
    }

    func testFreshOnboardingRequiresProfileDetailsBeforeAdvancing() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingOnboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Turn every lift into a ranking."].waitForExistence(timeout: 8))
        app.buttons["Build My Lift Rivals"].tap()
        XCTAssertTrue(app.staticTexts["What are you training for?"].waitForExistence(timeout: 5))
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

    func testFreshOnboardingUsesRequestedBodyweightAndLocationPrivacyDefaults() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingOnboarding"]
        app.launch()

        XCTAssertTrue(app.buttons["Build My Lift Rivals"].waitForExistence(timeout: 8))
        app.buttons["Build My Lift Rivals"].tap()
        XCTAssertTrue(app.staticTexts["What are you training for?"].waitForExistence(timeout: 5))
        app.buttons["onboarding.focus.generalFitness"].tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Build your lifter profile."].waitForExistence(timeout: 5))

        let hideBodyweight = app.switches["Hide exact bodyweight"]
        let hideCity = app.switches["Hide city"]
        var attempts = 0
        while (!hideBodyweight.isHittable || !hideCity.isHittable) && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(hideBodyweight.waitForExistence(timeout: 5))
        XCTAssertTrue(hideCity.waitForExistence(timeout: 5))
        XCTAssertEqual(hideBodyweight.value as? String, "0")
        XCTAssertEqual(hideCity.value as? String, "1")
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

    func testForumComposerRequiresConfirmationBeforeDiscardingDraft() {
        let app = launchDemo()
        tab("forum", in: app).tap()
        app.buttons["New discussion"].tap()

        let title = app.textFields["Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Training block draft")
        let body = app.textFields["forum.composer.body"]
        body.tap()
        body.typeText("Keep this text unless I confirm discard.")

        let composer = app.navigationBars["New discussion"]
        composer.buttons["Cancel"].tap()
        let discardAlert = app.alerts["Discard discussion draft?"]
        XCTAssertTrue(discardAlert.waitForExistence(timeout: 5))
        discardAlert.buttons["Keep Editing"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(body.exists)
        XCTAssertEqual(title.value as? String, "Training block draft")
        XCTAssertEqual(body.value as? String, "Keep this text unless I confirm discard.")

        composer.buttons["Cancel"].tap()
        discardAlert.buttons["Discard Draft"].tap()
        XCTAssertTrue(composer.waitForNonExistence(timeout: 5))
    }

    func testForumDemoAuthorUsesHumanReadableLabel() {
        let app = launchDemo()
        let forum = tab("forum", in: app)
        XCTAssertTrue(forum.waitForExistence(timeout: 8))
        forum.tap()
        XCTAssertTrue(app.staticTexts["Lift Rivals member"].waitForExistence(timeout: 10))
    }

    func testEmailConfirmationNoticeDoesNotHideSignInOrResendFailures() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTestingAuthentication",
            "-uiTestingEmailConfirmationRequired",
            "-uiTestingConfirmationResendFailure"
        ]
        app.launch()

        let email = app.textFields["Email"]
        XCTAssertTrue(email.waitForExistence(timeout: 8))
        email.tap()
        email.typeText("pending@example.test")
        app.segmentedControls.buttons["Create Account"].tap()
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("ValidPassword123")
        app.buttons["authentication.email.submit"].tap()

        let notice = app.descendants(matching: .any)["authentication.emailConfirmationNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("wrong")
        app.buttons["authentication.email.submit"].tap()
        XCTAssertTrue(app.staticTexts["Incorrect email or password. Check your details and try again."].waitForExistence(timeout: 5))
        XCTAssertTrue(notice.exists)

        app.buttons["Send again"].tap()
        XCTAssertTrue(app.staticTexts["Lift Rivals couldn't reach the server. Check your connection and try again."].waitForExistence(timeout: 5))
        XCTAssertTrue(notice.exists)
    }

}
