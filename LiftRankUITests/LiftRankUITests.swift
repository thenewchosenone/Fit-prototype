import XCTest

final class LiftRankUITests: XCTestCase {
    private func tab(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let titles = ["home": "Home", "leaderboards": "Rankings", "track": "Track", "forum": "Feed", "profile": "Me"]
        return app.tabBars.buttons[titles[name] ?? name]
    }

    private func selectTrackTab(in app: XCUIApplication) {
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 5))
        track.tap()
        if !app.buttons["tracker.segment.progress"].waitForExistence(timeout: 5) { track.tap() }
        XCTAssertTrue(track.isSelected)
    }

    private func progressCategory(_ name: String, in app: XCUIApplication) -> XCUIElement {
        if name == "Consistency" { return app.staticTexts["tracker.progress.summary"] }
        return app.descendants(matching: .any)["tracker.progress.category.\(name.lowercased())"].firstMatch
    }

    private func selectProgressCategory(_ name: String, in app: XCUIApplication) {
        let back = app.buttons["tracker.progress.overview"]
        if back.exists { back.tap() }
        if name == "Consistency" { return }
        let destination = progressCategory(name, in: app)
        for _ in 0..<8 where !destination.isHittable { app.swipeUp() }
        XCTAssertTrue(destination.isHittable)
        destination.tap()
    }

    private func meHeader(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["me.profileHeader"]
    }

    private func launchDemo(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingDemoMode"] + arguments
        if !arguments.contains("-UIPreferredContentSizeCategoryName") {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        }
        if !arguments.contains("-liftrank.appearance") {
            app.launchArguments += ["-liftrank.appearance", "Dark"]
        }
        app.launch()
        return app
    }

    private func launchCurrentAccount(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += arguments
        app.launch()
        return app
    }

    func testFriendsFeedIsVisibleAndShowsActivityInline() {
        let app = launchDemo()
        let feed = tab("forum", in: app)
        XCTAssertTrue(feed.waitForExistence(timeout: 10))
        feed.tap()
        let friends = app.buttons["Friends"]
        if !friends.isHittable { app.scrollViews.firstMatch.swipeLeft() }
        XCTAssertTrue(friends.waitForExistence(timeout: 5))
        friends.tap()
        XCTAssertTrue(app.buttons["Activity sharing settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Workout started · Session details are private"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["feed.friendActivity.liftWeight"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Friends feed with inline training activity"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        tab("home", in: app).tap()
        let rivals = app.scrollViews["home.closestRivals"]
        for _ in 0..<8 where !rivals.isHittable || rivals.frame.maxY > app.tabBars.firstMatch.frame.minY {
            app.swipeUp()
        }
        XCTAssertTrue(rivals.isHittable)
        XCTAssertLessThanOrEqual(rivals.frame.maxY, app.tabBars.firstMatch.frame.minY)
        rivals.swipeLeft()
        let rivalsScreenshot = XCTAttachment(screenshot: app.screenshot())
        rivalsScreenshot.name = "Home closest rivals carousel after swiping"
        rivalsScreenshot.lifetime = .keepAlways
        add(rivalsScreenshot)
    }

    func testAccentColorPersistsAcrossRelaunch() {
        let app = launchDemo()
        var originalTabImage: Data?
        func openAccentPicker() -> XCUIElement {
            let home = tab("home", in: app)
            XCTAssertTrue(home.waitForExistence(timeout: 8))
            if originalTabImage == nil {
                originalTabImage = home.screenshot().pngRepresentation
            }
            let settings = app.buttons["Open settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 5))
            settings.tap()
            let settingsScreen = app.navigationBars["Settings"]
            if !settingsScreen.waitForExistence(timeout: 2) { settings.tap() }
            XCTAssertTrue(settingsScreen.waitForExistence(timeout: 5))
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Appearance")).firstMatch.tap()
            let picker = app.buttons["settings.accentColor"]
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            return picker
        }

        var picker = openAccentPicker()
        let original = (picker.value as? String) ?? "Lime"
        let chosen = original == "Blue" ? "Green" : "Blue"
        picker.tap()
        for color in ["Lime", "Orange", "Red", "Pink", "Purple", "Blue", "Teal", "Green"] {
            XCTAssertTrue(app.buttons[color].waitForExistence(timeout: 3), "Missing accent option: \(color)")
        }
        let chosenColor = app.buttons[chosen]
        XCTAssertTrue(chosenColor.waitForExistence(timeout: 5))
        chosenColor.tap()
        if !chosenColor.isSelected { chosenColor.tap() }
        XCTAssertTrue(chosenColor.isSelected)
        let accentScreen = app.navigationBars["Accent color"]
        XCTAssertTrue(accentScreen.waitForExistence(timeout: 5))
        let back = accentScreen.buttons.firstMatch
        back.tap()
        let appearanceScreen = app.navigationBars["Appearance"]
        XCTAssertTrue(appearanceScreen.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.value as? String, chosen)

        app.buttons["Close"].tap()
        let home = tab("home", in: app)
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        XCTAssertNotEqual(originalTabImage, home.screenshot().pngRepresentation, "The selected tab should update to the new accent")

        app.terminate()
        app.launch()
        picker = openAccentPicker()
        XCTAssertEqual(picker.value as? String, chosen)
        picker.tap()
        let originalColor = app.buttons[original]
        originalColor.tap()
        if !originalColor.isSelected { originalColor.tap() }
        XCTAssertTrue(originalColor.isSelected)
    }

    func testImageInspiredThemesPersistAcrossAppearanceAndAccentOverride() {
        let app = XCUIApplication()
        continueAfterFailure = false
        app.launchArguments += ["-uiTestingDemoMode", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        func openSettings() {
            let home = tab("home", in: app)
            XCTAssertTrue(home.waitForExistence(timeout: 8))
            if !home.isSelected { home.tap() }
            XCTAssertTrue(app.buttons["home.lastWorkout"].waitForExistence(timeout: 8))
            let settings = app.buttons["Open settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 8))
            settings.tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Appearance")).firstMatch.tap()
            XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 5))
        }

        func chooseTheme(_ name: String) {
            let themeRow = app.buttons["settings.colorTheme"]
            themeRow.tap()
            XCTAssertTrue(app.navigationBars["Color theme"].waitForExistence(timeout: 5))
            let option = app.buttons["settings.theme.\(name)"]
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
            app.navigationBars["Color theme"].buttons.firstMatch.tap()
            XCTAssertEqual(themeRow.value as? String, name)
        }

        func chooseAccent(_ name: String) {
            let accentRow = app.buttons["settings.accentColor"]
            accentRow.tap()
            XCTAssertTrue(app.navigationBars["Accent color"].waitForExistence(timeout: 5))
            let option = app.buttons[name]
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
            app.navigationBars["Accent color"].buttons.firstMatch.tap()
            XCTAssertEqual(accentRow.value as? String, name)
        }

        func appearanceControl() -> XCUIElement {
            app.buttons["settings.appearance"]
        }

        func setAppearance(_ name: String) {
            let picker = appearanceControl()
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            if picker.value as? String != name {
                picker.tap()
                let option = app.buttons[name]
                XCTAssertTrue(option.waitForExistence(timeout: 5))
                option.tap()
            }
            XCTAssertEqual(appearanceControl().value as? String, name)
        }

        func verifyMainTabContent(capture: Bool = false) {
            let visibleContent: [(String, String, XCUIElement)] = [
                ("home", "Home workout content", app.buttons["home.lastWorkout"]),
                ("leaderboards", "Rankings action", app.buttons["leaderboard.submitLift"]),
                ("track", "Track Today segment", app.buttons["tracker.segment.today"]),
                ("forum", "Forum community control", app.buttons["forum.community"]),
                ("profile", "Me profile header", meHeader(in: app))
            ]
            for (tabName, description, content) in visibleContent {
                let destination = tab(tabName, in: app)
                XCTAssertTrue(destination.waitForExistence(timeout: 8), "Missing \(tabName) tab")
                if !destination.isSelected { destination.tap() }
                XCTAssertTrue(destination.isSelected, "\(tabName) tab did not select")
                XCTAssertTrue(content.waitForExistence(timeout: 8), "Missing \(description)")
                XCTAssertTrue(content.isHittable, "\(description) is not visible after theme change")
                if capture {
                    let attachment = XCTAttachment(screenshot: app.screenshot())
                    attachment.name = "\(description) after theme change"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }

        verifyMainTabContent()

        openSettings()
        let themeRow = app.buttons["settings.colorTheme"]
        let accentRow = app.buttons["settings.accentColor"]
        let appearancePicker = appearanceControl()
        XCTAssertTrue(themeRow.waitForExistence(timeout: 5))
        XCTAssertTrue(accentRow.waitForExistence(timeout: 5))
        XCTAssertTrue(appearancePicker.waitForExistence(timeout: 5))
        let originalTheme = themeRow.value as? String ?? "Classic"
        let originalAccent = accentRow.value as? String ?? "Lime"
        let originalAppearance = appearancePicker.value as? String ?? "System"

        let palettes = [
            (name: "Seal & Navy", accent: "Crimson Pink"),
            (name: "Onyx & Indigo", accent: "Tropical Mint"),
            (name: "Mandarin & Forest", accent: "Crest Yellow")
        ]
        for palette in palettes {
            chooseTheme(palette.name)
            XCTAssertEqual(accentRow.value as? String, palette.accent)
            app.buttons["Close"].tap()
            verifyMainTabContent(capture: palette.name == "Seal & Navy")
            openSettings()
        }

        let overrideAccent = originalAccent == "Blue" ? "Purple" : "Blue"
        chooseAccent(overrideAccent)
        setAppearance("Light")
        app.buttons["Close"].tap()
        verifyMainTabContent()

        openSettings()
        setAppearance("Dark")
        app.buttons["Close"].tap()
        verifyMainTabContent()
        app.terminate()
        app.launch()
        openSettings()
        XCTAssertEqual(themeRow.value as? String, "Mandarin & Forest")
        XCTAssertEqual(accentRow.value as? String, overrideAccent)
        XCTAssertEqual(appearanceControl().value as? String, "Dark")

        chooseTheme(originalTheme)
        chooseAccent(originalAccent)
        setAppearance(originalAppearance)
        app.buttons["Close"].tap()
    }

    func testThemeChangeFromMeKeepsHomeContentVisible() {
        let app = XCUIApplication()
        continueAfterFailure = false
        app.launchArguments += ["-uiTestingDemoMode", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let home = tab("home", in: app)
        XCTAssertTrue(home.waitForExistence(timeout: 8))
        let homeContent = app.buttons["home.lastWorkout"]
        XCTAssertTrue(homeContent.waitForExistence(timeout: 8))
        XCTAssertTrue(homeContent.isHittable, "Home must be rendered before navigating to Me")
        let me = tab("profile", in: app)
        XCTAssertTrue(me.waitForExistence(timeout: 8))
        me.tap()
        XCTAssertTrue(meHeader(in: app).waitForExistence(timeout: 5))
        app.buttons["me.header.settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Appearance")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 5))

        let themeRow = app.buttons["settings.colorTheme"]
        XCTAssertTrue(themeRow.isHittable)
        let originalTheme = themeRow.value as? String ?? "Classic"
        let selectedTheme = originalTheme == "Seal & Navy" ? "Classic" : "Seal & Navy"
        let colorThemeLabel = themeRow.staticTexts["Color theme"]
        XCTAssertTrue(colorThemeLabel.isHittable)
        colorThemeLabel.tap()
        let themePage = app.navigationBars["Color theme"]
        if !themePage.waitForExistence(timeout: 3) {
            XCTAssertTrue(colorThemeLabel.isHittable, "Color theme label left Appearance before the detail opened")
            colorThemeLabel.tap()
        }
        XCTAssertTrue(themePage.waitForExistence(timeout: 5))
        let option = app.buttons["settings.theme.\(selectedTheme)"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        app.navigationBars["Color theme"].buttons.firstMatch.tap()
        app.buttons["Close"].tap()

        home.tap()
        XCTAssertTrue(homeContent.waitForExistence(timeout: 8))
        XCTAssertTrue(homeContent.isHittable, "Home content is blank after changing theme from Me")
        let homeScreenshot = XCTAttachment(screenshot: app.screenshot())
        homeScreenshot.name = "Home content after theme changed from Me"
        homeScreenshot.lifetime = .keepAlways
        add(homeScreenshot)

        let settings = app.buttons["Open settings"]
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Appearance")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 5))
        let restoredThemeRow = app.buttons["settings.colorTheme"]
        restoredThemeRow.staticTexts["Color theme"].tap()
        XCTAssertTrue(app.navigationBars["Color theme"].waitForExistence(timeout: 5))
        app.buttons["settings.theme.\(originalTheme)"].tap()
        app.navigationBars["Color theme"].buttons.firstMatch.tap()
        app.buttons["Close"].tap()
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
        XCTAssertTrue(app.buttons["Minimize workout"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["End empty workout"].exists || app.buttons["Workout options"].exists)
    }

    func testActiveWorkoutSetRestoresAfterAppRestart() {
        var app = launchDemo(arguments: [
            "-uiTestingActiveWorkout",
            "-uiTestingCompletedActiveSet",
            "-uiTestingPersistWorkoutSnapshots"
        ])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()
        XCTAssertTrue(app.buttons["Minimize workout"].waitForExistence(timeout: 5))
        let exercise = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Barbell Bench Press")).firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        exercise.tap()
        let weight = app.textFields["workout.set.1.weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertEqual(weight.value as? String, "225")

        app.terminate()
        app = launchDemo(arguments: ["-uiTestingPersistWorkoutSnapshots"])
        let restoredResume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(restoredResume.waitForExistence(timeout: 8))
        restoredResume.tap()
        XCTAssertTrue(app.buttons["Minimize workout"].waitForExistence(timeout: 5))
        let restoredExercise = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Barbell Bench Press")).firstMatch
        XCTAssertTrue(restoredExercise.waitForExistence(timeout: 5))
        restoredExercise.tap()
        let restoredWeight = app.textFields["workout.set.1.weight"]
        XCTAssertTrue(restoredWeight.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredWeight.value as? String, "225")

        app.navigationBars.buttons.firstMatch.tap()
        let finish = app.buttons["Review to finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        let reviewIncomplete = app.buttons["workout.finish.reviewIncomplete"]
        XCTAssertTrue(reviewIncomplete.waitForExistence(timeout: 5))
        reviewIncomplete.tap()
        XCTAssertTrue(app.staticTexts["Review workout"].waitForExistence(timeout: 5))
        let save = app.buttons["workout.finish.save"]
        for _ in 0..<10 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.staticTexts["Workout saved"].waitForExistence(timeout: 5))
        let done = app.buttons["workout.finish.saved.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.buttons["home.lastWorkout"].waitForExistence(timeout: 5))

        app.terminate()
        app = launchDemo(arguments: ["-uiTestingPersistWorkoutSnapshots"])
        XCTAssertTrue(app.buttons["home.lastWorkout"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Upper Strength"].exists)
        tab("track", in: app).tap()
        app.buttons["tracker.segment.progress"].tap()
        selectProgressCategory("Consistency", in: app)
        let today = Date.now.formatted(date: .complete, time: .omitted)
        let oneCompletedWorkoutToday = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", today, "1 completed workout")
        ).firstMatch
        for _ in 0..<12 where !oneCompletedWorkoutToday.isHittable { app.swipeUp() }
        XCTAssertTrue(oneCompletedWorkoutToday.waitForExistence(timeout: 5))
        oneCompletedWorkoutToday.tap()
        XCTAssertTrue(app.staticTexts["Upper Strength"].waitForExistence(timeout: 5))
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
            let minimize = app.buttons["Minimize workout"]
            let finish = app.buttons["End empty workout"]
            if !minimize.waitForExistence(timeout: 5) {
                XCTAssertTrue(resume.waitForExistence(timeout: 3))
                resume.tap()
            }
            XCTAssertTrue(minimize.waitForExistence(timeout: 5))
            XCTAssertTrue(finish.waitForExistence(timeout: 5))
            stopMeasuring()

            minimize.tap()
            XCTAssertTrue(resume.waitForExistence(timeout: 5))
        }
    }

    func testEmptyActiveWorkoutCanEndAndReturnToHome() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout"])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()

        let finish = app.buttons["End empty workout"]
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

        let finish = app.buttons["Review to finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()

        XCTAssertTrue(app.staticTexts["Review workout"].waitForExistence(timeout: 5))
        let reviewScreenshot = XCTAttachment(screenshot: app.screenshot())
        reviewScreenshot.name = "Workout summary review screen"
        reviewScreenshot.lifetime = .keepAlways
        add(reviewScreenshot)

        let reviewSets = app.staticTexts["Review exercises & sets"]
        XCTAssertTrue(reviewSets.waitForExistence(timeout: 5))
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
        let setOptions = app.buttons["Show set options"].firstMatch
        XCTAssertTrue(setOptions.waitForExistence(timeout: 5))
        setOptions.tap()
        let rpeChoice = app.buttons["Set effort to 8 out of 10, RPE"].firstMatch
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

        selectTrackTab(in: app)
        app.buttons["tracker.segment.progress"].tap()
        XCTAssertTrue(app.staticTexts["tracker.progress.summary"].waitForExistence(timeout: 5))
        let recentBench = app.buttons["tracker.progress.recentExercise.barbell_bench_press"]
        XCTAssertTrue(recentBench.waitForExistence(timeout: 5))
        XCTAssertTrue(recentBench.label.contains("262.5 lb"))
        for _ in 0..<6 where !recentBench.isHittable { app.swipeUp() }
        recentBench.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tracker.progress.exercisePicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Latest estimated 1RM"].waitForExistence(timeout: 5))
    }

    func testShortenedPlannedWorkoutSummaryShowsPlanCoverage() {
        let app = launchDemo(arguments: ["-uiTestingPlannedActiveWorkout"])
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()

        let finish = app.buttons["Review to finish"]
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
        if !track.isSelected { track.tap() }
        XCTAssertTrue(track.isSelected)
        app.buttons["tracker.segment.progress"].tap()
        XCTAssertTrue(progressCategory("Strength", in: app).waitForExistence(timeout: 5))
        selectProgressCategory("Strength", in: app)
        let exercisePicker = app.descendants(matching: .any)["tracker.progress.exercisePicker"]
        XCTAssertTrue(exercisePicker.waitForExistence(timeout: 5))
        exercisePicker.tap()
        XCTAssertTrue(app.navigationBars["Choose exercise"].waitForExistence(timeout: 5))
        let search = app.searchFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Barbell Bench Press")
        app.keyboards.buttons["Search"].tap()
        let benchExercise = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@", "Barbell Bench Press,", "Barbell · Chest")).firstMatch
        guard benchExercise.waitForExistence(timeout: 5) else {
            XCTFail("The exercise picker should expose the bench press row")
            return
        }
        benchExercise.tap()

        XCTAssertTrue(app.staticTexts["Current estimated 1RM"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["About this trend"].exists)
        XCTAssertTrue(app.staticTexts["Log this exercise in another workout to see an estimated 1RM trend."].exists)
        XCTAssertFalse(app.staticTexts["INCREASE"].exists)
    }

    func testTrackerTodayPrioritizesActiveWorkout() {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout"])
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()
        XCTAssertTrue(track.isSelected)

        XCTAssertTrue(app.staticTexts["ACTIVE WORKOUT"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["NEXT WORKOUT"].exists)
    }

    func testWeeklyTrainingDayGoalCanBeSetAndChangedOnHome() {
        let app = launchDemo()
        let goalMenu = app.buttons["weeklyTrainingGoal.menu"]
        let initialGoal = goalMenu.exists ? Int(goalMenu.label.filter(\.isNumber)) : nil
        let setGoal = app.buttons["weeklyTrainingGoal.set"]
        if !goalMenu.waitForExistence(timeout: 2) {
            XCTAssertTrue(setGoal.waitForExistence(timeout: 8))
            setGoal.tap()
        }
        XCTAssertTrue(goalMenu.waitForExistence(timeout: 5))
        goalMenu.tap()
        app.buttons["4 days per week"].tap()

        let homeGoal = app.descendants(matching: .any)["weeklyTrainingGoal.card"]
        XCTAssertTrue(homeGoal.waitForExistence(timeout: 5))
        let homeGoalValue = homeGoal.value as? String
        XCTAssertTrue(homeGoalValue?.contains("goal 4") == true)

        tab("track", in: app).tap()
        app.buttons["tracker.segment.progress"].tap()
        XCTAssertTrue(progressCategory("Consistency", in: app).waitForExistence(timeout: 5))
        selectProgressCategory("Consistency", in: app)
        let progressGoal = app.descendants(matching: .any)["weeklyTrainingGoal.card"]
        XCTAssertTrue(progressGoal.waitForExistence(timeout: 5))
        XCTAssertEqual(progressGoal.value as? String, homeGoalValue)

        goalMenu.tap()
        if let initialGoal {
            app.buttons["\(initialGoal) day\(initialGoal == 1 ? "" : "s") per week"].tap()
        } else {
            app.buttons["Turn off goal"].tap()
        }
    }

    func testSetEntryMovesAcrossRowsAndDismissesKeyboardAfterFinalWeight() {
        auditSetEntryKeyboard()
    }

    func testSetEntryKeyboardAtAccessibilitySize() {
        auditSetEntryKeyboard(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
    }

    func testSetEntryKeyboardInLightAppearance() {
        auditSetEntryKeyboard(arguments: ["-liftrank.appearance", "Light"])
    }

    private func auditSetEntryKeyboard(arguments: [String] = []) {
        let app = launchDemo(arguments: ["-uiTestingActiveWorkout", "-uiTestingActiveWorkoutWithExercise"] + arguments)
        let resume = app.buttons["home.activeWorkout.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()
        let minimize = app.buttons["Minimize workout"]
        if !minimize.waitForExistence(timeout: 5) { resume.tap() }
        XCTAssertTrue(minimize.waitForExistence(timeout: 8), "Resume should present the active session before its exercises are queried.")

        let firstExercise = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Barbell Bench Press")
        ).firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 5))
        firstExercise.tap()

        let keyboardAction = app.buttons["workout.setInput.keyboardAction"]
        let firstReps = app.textFields["workout.set.1.reps"]
        let firstWeight = app.textFields["workout.set.1.weight"]
        for _ in 0..<4 {
            if firstReps.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(firstReps.waitForExistence(timeout: 5))
        let setEntryScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        setEntryScreenshot.name = "Active workout set entry layout"
        setEntryScreenshot.lifetime = .keepAlways
        add(setEntryScreenshot)
        let previousValues = app.buttons["workout.set.1.previousValues"]
        XCTAssertTrue(previousValues.waitForExistence(timeout: 5))
        XCTAssertTrue(previousValues.label.contains("lb"))
        XCTAssertFalse(previousValues.label.contains("kg"))
        XCTAssertNotNil(previousValues.label.range(of: #"[\d,.]+ lb × 8"#, options: .regularExpression))
        firstWeight.tap()
        firstWeight.typeText("100.5")
        XCTAssertTrue(keyboardAction.waitForExistence(timeout: 3))
        let hideKeyboard = app.buttons["workout.setInput.hideKeyboard"]
        XCTAssertTrue(hideKeyboard.waitForExistence(timeout: 3))
        let keyboardScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        keyboardScreenshot.name = "Set entry with keyboard visible"
        keyboardScreenshot.lifetime = .keepAlways
        add(keyboardScreenshot)
        for _ in 0..<3 {
            hideKeyboard.tap()
            XCTAssertTrue(keyboardAction.waitForNonExistence(timeout: 3))
            XCTAssertTrue(hideKeyboard.waitForNonExistence(timeout: 3))
            XCTAssertEqual(firstWeight.value as? String, "100.5")
            firstWeight.tap()
            XCTAssertTrue(keyboardAction.waitForExistence(timeout: 3))
            XCTAssertTrue(hideKeyboard.waitForExistence(timeout: 3))
        }
        keyboardAction.tap()
        firstReps.typeText("8")
        XCTAssertEqual(firstReps.value as? String, "8")

        XCTAssertEqual(keyboardAction.label, "Log set")
        keyboardAction.tap()
        XCTAssertTrue(keyboardAction.waitForNonExistence(timeout: 3))
        let skipRest = app.buttons["Skip rest"]
        XCTAssertTrue(skipRest.waitForExistence(timeout: 3))
        skipRest.tap()
        for number in 2...3 {
            let weight = app.textFields["workout.set.\(number).weight"]
            weight.tap()
            weight.typeText("100")
            XCTAssertEqual(keyboardAction.label, "Next")
            keyboardAction.tap()
            let reps = app.textFields["workout.set.\(number).reps"]
            reps.typeText("8")
            XCTAssertEqual(keyboardAction.label, "Log set")
            keyboardAction.tap()
            XCTAssertTrue(keyboardAction.waitForNonExistence(timeout: 3))
            XCTAssertEqual(app.buttons["workout.set.\(number).completion"].label, "Mark set incomplete")
        }

        XCTAssertTrue(keyboardAction.waitForNonExistence(timeout: 3))
        XCTAssertEqual(app.textFields["workout.set.3.weight"].value as? String, "100")
        XCTAssertEqual(app.textFields["workout.set.3.reps"].value as? String, "8")
        let finalSetCompletion = app.buttons["workout.set.3.completion"]
        let completedLabel = NSPredicate(format: "label == %@", "Mark set incomplete")
        let addRest = app.buttons["Add 30 seconds of rest"]
        XCTAssertFalse(addRest.isEnabled)
        XCTAssertFalse(skipRest.isEnabled)
        XCTAssertFalse(app.buttons["Rest remaining"].exists)
        XCTAssertTrue(app.buttons["Rest between sets"].exists)
        let finalScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        finalScreenshot.name = "No rest timer after final workout set"
        finalScreenshot.lifetime = .keepAlways
        add(finalScreenshot)

        for _ in 0..<4 {
            if finalSetCompletion.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(finalSetCompletion.waitForExistence(timeout: 3))
        XCTAssertTrue(finalSetCompletion.isHittable)
        expectation(for: completedLabel, evaluatedWith: finalSetCompletion)
        waitForExpectations(timeout: 3)

        let completedSetsScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        completedSetsScreenshot.name = "Completed exercise after logging every set"
        completedSetsScreenshot.lifetime = .keepAlways
        add(completedSetsScreenshot)
    }

    func testActiveWorkoutCanCreateAndAddCustomExercise() {
        let app = launchDemo(arguments: ["-uiTestingNoActiveWorkout"])
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()
        if !track.isSelected { track.tap() }
        XCTAssertTrue(track.isSelected)

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
        XCTAssertTrue(app.buttons["Review to finish"].exists)
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

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Active program")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Workout program library")).firstMatch.waitForExistence(timeout: 5))

        let planView = app.segmentedControls.firstMatch
        XCTAssertTrue(planView.waitForExistence(timeout: 5))
        app.buttons["Overview"].tap()
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
                "Review saved sessions & remaining sets",
                "Add next week"
            )
        ).firstMatch.exists)

        app.buttons["Notes"].tap()
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
        notesEditor.tap()
        notesEditor.typeText("ZQ")
        XCTAssertTrue((notesEditor.value as? String)?.contains("ZQ") == true)
        app.navigationBars["Plan notes"].buttons["Save"].tap()
        let savedNotes = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "ZQ")
        ).firstMatch
        XCTAssertTrue(savedNotes.waitForExistence(timeout: 5))
        XCTAssertTrue(savedNotes.label.contains("ZQ"))
    }

    func testTrackerPlansOpenPerformance() {
        let app = launchDemo()
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()
        let today = app.buttons["tracker.segment.today"]
        if !today.waitForExistence(timeout: 5) {
            track.tap()
        }
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            let today = app.buttons["tracker.segment.today"]
            XCTAssertTrue(today.waitForExistence(timeout: 5))
            today.tap()
            let plans = app.buttons["tracker.segment.plans"]
            XCTAssertTrue(plans.waitForExistence(timeout: 5))

            startMeasuring()
            plans.tap()
            XCTAssertTrue(plans.isSelected)
            XCTAssertTrue(app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Workout program library")
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
            XCTAssertTrue(progressCategory("Strength", in: app).waitForExistence(timeout: 5))
            stopMeasuring()

            selectProgressCategory("Strength", in: app)
            XCTAssertTrue(app.buttons["tracker.progress.exercisePicker"].waitForExistence(timeout: 5))
            selectProgressCategory("Muscle", in: app)
            XCTAssertTrue(app.staticTexts["Muscle workload"].exists)
            selectProgressCategory("Consistency", in: app)
            XCTAssertTrue(app.staticTexts["tracker.progress.summary"].exists)
        }
    }

    func testProgressCategoriesAndControlsRemainResponsive() {
        let app = launchDemo(arguments: ["-liftrank.theme", "Seal & Navy"])
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        XCTAssertTrue(app.buttons["tracker.segment.progress"].waitForExistence(timeout: 5))
        app.buttons["tracker.segment.progress"].tap()

        func capture(_ category: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Progress · \(category) · Seal & Navy"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        XCTAssertTrue(progressCategory("Strength", in: app).waitForExistence(timeout: 5))
        selectProgressCategory("Strength", in: app)
        XCTAssertTrue(app.buttons["tracker.progress.exercisePicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tracker.progress.exercisePicker"].waitForExistence(timeout: 5))
        capture("Strength")
        let firstMuscleSwitch = Date()
        selectProgressCategory("Muscle", in: app)
        XCTAssertTrue(app.staticTexts["Muscle workload"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tracker.muscle.period"].waitForExistence(timeout: 5))
        capture("Muscle")
        print("First Muscle switch: \(Date().timeIntervalSince(firstMuscleSwitch)) seconds")

        for _ in 0..<5 {
            selectProgressCategory("Strength", in: app)
            XCTAssertTrue(app.buttons["tracker.progress.exercisePicker"].waitForExistence(timeout: 5))

            selectProgressCategory("Muscle", in: app)
            XCTAssertTrue(app.staticTexts["Muscle workload"].waitForExistence(timeout: 5))

            selectProgressCategory("Consistency", in: app)
            XCTAssertTrue(app.staticTexts["tracker.progress.summary"].exists)
        }

        XCTAssertFalse(app.staticTexts["Workout calendar"].exists)
        XCTAssertFalse(app.staticTexts["Training pattern"].exists)
        XCTAssertFalse(app.staticTexts["Program consistency"].exists)
        let weeklyGoal = app.descendants(matching: .any)["weeklyTrainingGoal.card"]
        let setWeeklyGoal = app.buttons["weeklyTrainingGoal.set"]
        XCTAssertFalse(weeklyGoal.exists || setWeeklyGoal.exists, "Weekly goal controls belong in recaps")
        capture("Consistency")

        selectProgressCategory("Body", in: app)
        XCTAssertTrue(app.staticTexts["Bodyweight trend"].waitForExistence(timeout: 5))
        let logBodyweight = app.buttons["Log bodyweight"]
        XCTAssertTrue(logBodyweight.waitForExistence(timeout: 5))
        XCTAssertTrue(logBodyweight.isHittable)
        capture("Body")

        selectProgressCategory("Muscle", in: app)
        let period = app.buttons["tracker.muscle.period"]
        XCTAssertTrue(period.isHittable)
        period.tap()
        app.buttons["Last week"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "Completed week")).firstMatch.exists)
    }

    func testStrengthLayoutAudit() {
        auditStrengthLayout(arguments: [], name: "Dark")
    }

    func testStrengthLayoutAuditInLightAppearance() {
        auditStrengthLayout(arguments: ["-liftrank.appearance", "Light"], name: "Light")
    }

    func testStrengthLayoutAuditAtAccessibilitySize() {
        auditStrengthLayout(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"], name: "Accessibility")
    }

    func testStrengthGoalCreateEditRemoveWithoutExerciseHistoryAtAccessibilitySize() {
        let app = launchDemo(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        selectTrackTab(in: app)
        app.buttons["tracker.segment.progress"].tap()
        selectProgressCategory("Strength", in: app)
        app.buttons["tracker.progress.exercisePicker"].tap()
        let search = app.searchFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Cable Crunch")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Cable Crunch")).firstMatch.tap()
        let addGoal = app.buttons["Add goal"]
        let editGoal = app.buttons["Edit goal"]
        for _ in 0..<12 where !addGoal.isHittable && !editGoal.isHittable { app.swipeUp() }
        (editGoal.exists ? editGoal : addGoal).tap()
        let editor = app.navigationBars["Strength goal"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let target = app.textFields["Target weight"]
        XCTAssertTrue(target.exists)
        target.tap()
        target.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + "135")
        XCTAssertTrue(editor.buttons["Save"].isEnabled)
        editor.buttons["Save"].tap()
        XCTAssertTrue(editGoal.waitForExistence(timeout: 5))
        for _ in 0..<6 where !editGoal.isHittable { app.swipeUp() }
        editGoal.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let remove = app.buttons["Remove goal"]
        for _ in 0..<6 where !remove.isHittable { app.swipeUp() }
        remove.tap()
        XCTAssertTrue(addGoal.waitForExistence(timeout: 5))
    }

    private func auditStrengthLayout(arguments: [String], name: String) {
        let app = launchDemo(arguments: ["-uiTestingNoActiveWorkout"] + arguments)
        let trackTab = tab("track", in: app)
        XCTAssertTrue(trackTab.waitForExistence(timeout: 5))
        XCTAssertTrue(trackTab.isHittable)
        selectTrackTab(in: app)
        XCTAssertTrue(trackTab.isSelected, "Track should become selected before entering Progress")
        XCTAssertTrue(app.buttons["tracker.segment.progress"].waitForExistence(timeout: 5))
        app.buttons["tracker.segment.progress"].tap()
        XCTAssertTrue(progressCategory("Strength", in: app).waitForExistence(timeout: 5))
        selectProgressCategory("Strength", in: app)

        func capture(_ section: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Strength \(name) · \(section)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        func trackNavigationTop() -> CGFloat {
            app.tabBars.firstMatch.frame.minY
        }

        func reveal(_ element: XCUIElement, fullyVisible: Bool = true) -> Bool {
            for _ in 0..<32 {
                let top = max(app.buttons["tracker.segment.progress"].frame.maxY,
                              progressCategory("Strength", in: app).frame.maxY) + 10
                let bottom = trackNavigationTop() - 12
                if element.exists {
                    let frame = element.frame
                    let visible = fullyVisible
                        ? frame.minY >= top && frame.maxY <= bottom
                        : frame.midY >= top && frame.midY <= bottom
                    if visible { break }
                }
                let above = element.exists && element.frame.midY < top
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.62))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: above ? 0.65 : 0.53))
                start.press(forDuration: 0.1, thenDragTo: end)
            }
            guard element.exists else { return false }
            let frame = element.frame
            return element.isHittable &&
                (fullyVisible
                    ? frame.minY >= max(app.buttons["tracker.segment.progress"].frame.maxY,
                                        progressCategory("Strength", in: app).frame.maxY) + 10 &&
                      frame.maxY <= trackNavigationTop() - 12
                    : frame.midY >= max(app.buttons["tracker.segment.progress"].frame.maxY,
                                        progressCategory("Strength", in: app).frame.maxY) + 10 &&
                      frame.midY <= trackNavigationTop() - 12)
        }

        XCTAssertTrue(app.buttons["tracker.progress.exercisePicker"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Chest,")).firstMatch.exists)
        capture("Summary")
        let picker = app.buttons["tracker.progress.exercisePicker"]
        guard reveal(picker) else { XCTFail("Reveal the exercise picker clear of the native tab bar"); return }
        capture("Exercise metrics")
        picker.tap()
        XCTAssertTrue(app.navigationBars["Choose exercise"].waitForExistence(timeout: 5))
        capture("Exercise picker")
        let search = app.searchFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Barbell Bench Press")
        app.keyboards.buttons["Search"].tap()
        let bench = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@", "Barbell Bench Press,", "Barbell · Chest")
        ).firstMatch
        XCTAssertTrue(bench.waitForExistence(timeout: 5), "Select the seeded Bench Press history for chart coverage")
        bench.tap()
        let estimatedMaxChart = app.descendants(matching: .any)["tracker.strength.estimatedMaxChart"].firstMatch
        let chartVisible = reveal(estimatedMaxChart, fullyVisible: false)
        if !chartVisible {
            capture("Estimated max chart visibility failure")
            let progressFrame = app.buttons["tracker.segment.progress"].frame
            print("Estimated max chart diagnostic · exists: \(estimatedMaxChart.exists), frame: \(estimatedMaxChart.frame), hittable: \(estimatedMaxChart.isHittable), progress: \(progressFrame), Track: \(trackNavigationTop())")
            XCTFail("Reveal the estimated 1RM chart")
            return
        }
        capture("Estimated max chart")
        let trendMetricPicker = app.descendants(matching: .any)["tracker.strength.trendMetric"].firstMatch
        guard reveal(trendMetricPicker) else { XCTFail("Reveal the trend metric picker"); return }
        trendMetricPicker.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        let weightChart = app.descendants(matching: .any)["tracker.strength.weightChart"].firstMatch
        guard reveal(weightChart, fullyVisible: false) else { XCTFail("Reveal the logged-weight chart"); return }
        capture("Weight chart")
        weightChart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let selectedPerformance = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Selected performance")).firstMatch
        XCTAssertTrue(selectedPerformance.waitForExistence(timeout: 5))
        XCTAssertTrue(selectedPerformance.label.contains(" lb"))
        XCTAssertFalse(selectedPerformance.label.contains(" kg"))
        guard reveal(selectedPerformance, fullyVisible: false) else { XCTFail("Reveal selected chart performance"); return }
        capture("Selected performance")
        let viewWorkout = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "View workout ·")).firstMatch
        guard reveal(viewWorkout, fullyVisible: false) else { XCTFail("Reveal the source-workout action"); return }
        viewWorkout.tap()
        XCTAssertTrue(app.buttons["More workout actions"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let recordsDisclosure = app.buttons["Records and source workouts"]
        guard reveal(recordsDisclosure) else { XCTFail("Reveal records and source workouts clear of the native tab bar"); return }
        capture("Exercise progress summary")
        recordsDisclosure.tap()
        let repRecords = app.staticTexts["Best sets by rep range · last 3M"]
        guard reveal(repRecords, fullyVisible: false) else { XCTFail("Reveal the selected-period rep records"); return }
        capture("Exercise records")
        XCTAssertFalse(app.staticTexts["Bodyweight"].exists)
        XCTAssertFalse(app.buttons["Log bodyweight"].exists)

    }

    func testProgressHistoryOpensSavedWorkout() {
        let app = launchDemo()
        selectTrackTab(in: app)
        app.buttons["tracker.segment.progress"].tap()
        let history = app.buttons["tracker.progress.history"]
        for _ in 0..<8 where !history.isHittable { app.swipeUp() }
        XCTAssertTrue(history.isHittable)
        history.tap()
        XCTAssertTrue(app.navigationBars["Workout history"].waitForExistence(timeout: 5))
        let workout = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "sets •")).firstMatch
        for _ in 0..<8 where !workout.isHittable { app.swipeUp() }
        XCTAssertTrue(workout.isHittable)
        workout.tap()
        XCTAssertTrue(app.buttons["More workout actions"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Workout history"].waitForExistence(timeout: 5))
    }

    func testRecentExerciseOpensItsChart() {
        let app = launchDemo()
        selectTrackTab(in: app)
        app.buttons["tracker.segment.progress"].tap()
        let change = app.staticTexts["tracker.progress.change.barbell_bench_press"]
        XCTAssertTrue(change.waitForExistence(timeout: 5))
        XCTAssertTrue(change.isHittable, "Progress should be visible before opening an exercise")
        XCTAssertTrue(change.label.hasPrefix("+"), "Demo history should show a visible improvement")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Exercise progress visible on overview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let recent = app.buttons["tracker.progress.recentExercise.barbell_bench_press"]
        for _ in 0..<6 where !recent.isHittable { app.swipeUp() }
        XCTAssertTrue(recent.isHittable)
        recent.tap()
        XCTAssertTrue(app.buttons["tracker.progress.exercisePicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tracker.progress.overview"].exists)
        app.buttons["tracker.progress.overview"].tap()
        app.buttons["About exercise progress"].tap()
        XCTAssertTrue(app.alerts["About exercise progress"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        let recaps = app.buttons["tracker.progress.recaps"]
        for _ in 0..<8 where !recaps.isHittable { app.swipeUp() }
        recaps.tap()
        XCTAssertTrue(app.navigationBars["Training recaps"].waitForExistence(timeout: 5))
        app.buttons["This week"].tap()
        XCTAssertTrue(app.buttons["weeklyTrainingGoal.set"].exists || app.descendants(matching: .any)["weeklyTrainingGoal.card"].exists)
    }

    func testProgressOverviewOpensSeparateMuscleWorkload() {
        let app = launchDemo()
        selectTrackTab(in: app)
        app.buttons["tracker.segment.progress"].tap()
        selectProgressCategory("Muscle", in: app)
        XCTAssertTrue(app.buttons["tracker.muscle.period"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Recent training signal"].exists)
        selectProgressCategory("Consistency", in: app)
        XCTAssertTrue(app.staticTexts["tracker.progress.summary"].exists)
    }

    func testLeaderboardScopeCanSelectPrimaryGym() {
        let app = launchDemo()
        let leaderboards = tab("leaderboards", in: app)
        XCTAssertTrue(leaderboards.waitForExistence(timeout: 8))
        leaderboards.tap()
        XCTAssertTrue(leaderboards.isSelected)

        let scope = app.buttons["leaderboard.filter.compare_with"]
        XCTAssertTrue(scope.waitForExistence(timeout: 5))
        scope.tap()
        let gym = app.buttons["option.gym:D0000000-0000-0000-0000-000000000100"]
        XCTAssertTrue(gym.waitForExistence(timeout: 5))
        gym.tap()
        XCTAssertTrue(scope.label.contains("Lift Rivals Demo Gym"))
    }

    func testMuscleWorkloadFiltersAndExerciseBreakdown() {
        let app = launchDemo()
        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        let progress = app.buttons["tracker.segment.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        progress.tap()
        selectProgressCategory("Muscle", in: app)
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
        let app = launchDemo(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
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
        let app = launchDemo(arguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
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
        let app = launchDemo(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        selectTrackTab(in: app)
        XCTAssertTrue(tab("track", in: app).isSelected, "Track should be selected at XXXL before opening Progress")
        XCTAssertTrue(app.buttons["tracker.segment.progress"].waitForExistence(timeout: 5))
        app.buttons["tracker.segment.progress"].tap()
        selectProgressCategory("Consistency", in: app)
        let history = app.buttons["tracker.progress.history"]
        for _ in 0..<10 where !history.isHittable { app.swipeUp() }
        history.tap()

        let calendarTitle = app.staticTexts["Workout calendar"]
        let contentTop = app.navigationBars["Workout history"].frame.maxY + 10
        let contentBottom = app.tabBars.firstMatch.frame.minY - 12
        func scrollProgressContent(towardTop: Bool) {
            let startY = contentTop + (contentBottom - contentTop) * (towardTop ? 0.32 : 0.78)
            let endY = contentTop + (contentBottom - contentTop) * (towardTop ? 0.78 : 0.32)
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: startY / app.frame.height))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: endY / app.frame.height))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        for _ in 0..<12 where !calendarTitle.isHittable {
            let aboveViewport = calendarTitle.exists && calendarTitle.frame.midY < contentTop
            scrollProgressContent(towardTop: aboveViewport)
        }
        XCTAssertTrue(calendarTitle.isHittable)
        let calendarScreenshot = XCTAttachment(screenshot: app.screenshot())
        calendarScreenshot.name = "Consistency calendar at accessibility text size"
        calendarScreenshot.lifetime = .keepAlways
        add(calendarScreenshot)
        let days = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "completed workout")
        )
        for _ in 0..<12 where !days.allElementsBoundByIndex.contains(where: { $0.isHittable }) {
            let candidate = days.firstMatch
            let aboveViewport = candidate.exists && candidate.frame.midY < contentTop
            scrollProgressContent(towardTop: aboveViewport)
        }
        guard let visibleDay = days.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("No calendar date is visible")
            return
        }
        let day = app.buttons[visibleDay.label]
        XCTAssertTrue(day.isHittable)
        let selectedDateLabel = visibleDay.label.components(separatedBy: ", ").dropLast().joined(separator: ", ")
        day.tap()
        let selectedDateScreenshot = XCTAttachment(screenshot: app.screenshot())
        selectedDateScreenshot.name = "Selected completed workout date at accessibility text size"
        selectedDateScreenshot.lifetime = .keepAlways
        add(selectedDateScreenshot)
        XCTAssertTrue(app.staticTexts[selectedDateLabel].waitForExistence(timeout: 5))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Workout history calendar at accessibility text size"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testFirstProgressOpenWithMuscleFocus() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingDemoMode", "-liftrank.progress.category", ""]
        app.launch()
        let profileTab = tab("profile", in: app)
        XCTAssertTrue(profileTab.waitForExistence(timeout: 8))
        profileTab.tap()
        let settingsButton = app.buttons["me.header.settings"]
        if !settingsButton.waitForExistence(timeout: 5) {
            profileTab.tap()
        }
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Training"].tap()
        let focus = app.buttons["settings.trainingFocus"]
        for _ in 0..<8 where !focus.isHittable { app.swipeUp() }
        XCTAssertTrue(focus.isHittable)
        focus.tap()
        app.buttons["Bodybuilding"].tap()
        let close = app.navigationBars["Training"].buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(app.navigationBars["Training"].waitForNonExistence(timeout: 5))

        XCTAssertTrue(tab("track", in: app).waitForExistence(timeout: 8))
        tab("track", in: app).tap()
        if !app.buttons["tracker.segment.progress"].waitForExistence(timeout: 5) {
            tab("track", in: app).tap()
        }
        let started = Date()
        app.buttons["tracker.segment.progress"].tap()
        XCTAssertTrue(app.staticTexts["tracker.progress.summary"].exists)
        XCTAssertTrue(app.staticTexts["Muscle workload"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["What are you training for?"].exists)
        print("First Progress open with Muscle focus: \(Date().timeIntervalSince(started)) seconds")
    }

    func testScreenAuditNavigation() {
        auditScreenNavigation(contentSize: "UICTContentSizeCategoryL")
    }

    func testScreenAuditNavigationAtAccessibilitySize() {
        auditScreenNavigation(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
    }

    func testScreenAuditNavigationInLightAppearance() {
        auditScreenNavigation(contentSize: "UICTContentSizeCategoryL", appearance: "Light")
    }

    private func auditScreenNavigation(contentSize: String, appearance: String = "Dark") {
        let app = launchDemo(arguments: [
            "-UIPreferredContentSizeCategoryName", contentSize,
            "-liftrank.appearance", appearance
        ])
        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        for name in ["home", "leaderboards", "track", "forum", "profile"] {
            let button = tab(name, in: app)
            XCTAssertTrue(button.isHittable, "Main tab must remain visible: \(name)")
            XCTAssertGreaterThanOrEqual(button.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
        }
        capture("Audit Home")
        let homeScroll = app.scrollViews.firstMatch
        let bodyweight = app.buttons["home.quickAction.bodyweight"]
        for _ in 0..<16 where !bodyweight.isHittable { homeScroll.swipeUp() }
        XCTAssertTrue(bodyweight.isHittable)
        bodyweight.tap()
        XCTAssertTrue(app.navigationBars["Bodyweight Entry"].waitForExistence(timeout: 5))
        let weight = app.textFields["Enter weight"]
        for _ in 0..<6 where !weight.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(weight.isHittable)
        weight.tap()
        let originalWeight = weight.value as? String ?? ""
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: originalWeight.count) + "184")
        XCTAssertEqual(weight.value as? String, "184")
        capture("Audit Bodyweight keyboard")
        app.navigationBars["Bodyweight Entry"].buttons["Cancel"].tap()
        let recentPR = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Open ", " PR,")).firstMatch
        XCTAssertTrue(recentPR.waitForExistence(timeout: 5))
        capture("Audit Home recent PR")
        recentPR.tap()
        XCTAssertTrue(app.navigationBars["PR details"].waitForExistence(timeout: 5))
        capture("Audit PR details")
        app.navigationBars["PR details"].buttons["Done"].tap()
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
            if section == "library" && contentSize == "UICTContentSizeCategoryAccessibilityXXXL" {
                XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Jump to exercises beginning with ")).count, 0)
            }
            capture("Audit Track \(section)")
        }
        XCTAssertTrue(progressCategory("Strength", in: app).waitForExistence(timeout: 5))
        for category in ["Strength", "Muscle", "Consistency"] {
            selectProgressCategory(category, in: app)
            capture("Audit Progress \(category)")
        }
        for name in ["leaderboards", "forum", "profile"] {
            tab(name, in: app).tap()
            if name == "forum" && contentSize == "UICTContentSizeCategoryAccessibilityXXXL" {
                let feedPicker = app.buttons["forum.feed"]
                XCTAssertTrue(feedPicker.isHittable)
                XCTAssertGreaterThanOrEqual(feedPicker.frame.minX, app.frame.minX)
                XCTAssertLessThanOrEqual(feedPicker.frame.maxX, app.frame.maxX)

                let communityPicker = app.buttons["forum.community"]
                XCTAssertTrue(communityPicker.waitForExistence(timeout: 5))
                XCTAssertTrue(communityPicker.isHittable)
                XCTAssertGreaterThanOrEqual(communityPicker.frame.minX, app.frame.minX)
                XCTAssertLessThanOrEqual(communityPicker.frame.maxX, app.frame.maxX)
                communityPicker.tap()
                XCTAssertTrue(app.navigationBars["Communities"].waitForExistence(timeout: 5))
                XCTAssertTrue(app.buttons["All communities"].isHittable)
                app.buttons["Done"].tap()
                let sortMenu = app.buttons["forum.sort"]
                XCTAssertTrue(sortMenu.waitForExistence(timeout: 5))
                XCTAssertTrue(sortMenu.isHittable)
                XCTAssertGreaterThanOrEqual(sortMenu.frame.minX, app.frame.minX)
                XCTAssertLessThanOrEqual(sortMenu.frame.maxX, app.frame.maxX)
            }
            if name == "profile" {
                for identifier in ["me.header.settings", "me.header.editProfile"] {
                    let button = app.buttons[identifier]
                    XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing profile action: \(identifier)")
                    XCTAssertGreaterThanOrEqual(button.frame.width, 44)
                    XCTAssertGreaterThanOrEqual(button.frame.height, 44, "Profile action target is too short: \(identifier)")
                }
            }
            capture("Audit \(name)")
        }
        let personalProfile = app.buttons["me.personalProfile"]
        for _ in 0..<10 where !personalProfile.isHittable { app.swipeUp() }
        XCTAssertTrue(personalProfile.isHittable)
        let publicProfile = app.buttons["me.publicProfile"]
        for _ in 0..<10 where !publicProfile.isHittable { app.scrollViews.firstMatch.swipeDown() }
        XCTAssertTrue(publicProfile.isHittable)
        publicProfile.tap()
        capture("Audit Public profile")
        app.navigationBars.buttons.firstMatch.tap()
        tab("profile", in: app).tap()
        for _ in 0..<5 where !personalProfile.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(personalProfile.isHittable)
        personalProfile.tap()
        XCTAssertTrue(app.navigationBars["Personal profile"].waitForExistence(timeout: 5))
        capture("Audit Personal profile")
    }

    func testLeaderboardControlsStayInsideViewportAtAccessibilitySize() throws {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let leaderboardTab = tab("leaderboards", in: app)
        XCTAssertTrue(leaderboardTab.waitForExistence(timeout: 8))
        leaderboardTab.tap()
        XCTAssertTrue(app.navigationBars["Leaderboards"].waitForExistence(timeout: 8))

        let scope = app.buttons["leaderboard.filter.compare_with"]
        XCTAssertTrue(scope.waitForExistence(timeout: 5))
        guard scope.frame.height > 64 else {
            throw XCTSkip("Run this layout check with Accessibility XXL enabled in the simulator.")
        }

        let controls = [
            scope,
            app.buttons["leaderboard.ranking.absolute"],
            app.buttons["leaderboard.ranking.pound-for-pound"],
            app.buttons["leaderboard.ranking.total"],
            app.buttons["leaderboard.ranking.relative-total"]
        ]
        for control in controls {
            XCTAssertTrue(control.waitForExistence(timeout: 5), "Missing visible leaderboard control: \(control.identifier)")
            var scrollAttempts = 0
            while !control.isHittable && scrollAttempts < 6 {
                if control.frame.minY < 0 {
                    app.swipeDown()
                } else {
                    app.swipeUp()
                }
                scrollAttempts += 1
            }
            XCTAssertTrue(control.isHittable, "Leaderboard control is not hittable: \(control.identifier)")
            XCTAssertGreaterThanOrEqual(control.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX)
        }
        app.buttons["leaderboard.ranking.absolute"].tap()

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

    func testAdaptiveProgramScheduleChangesItsPreview() {
        let app = launchDemo(arguments: ["-uiTestingNoActiveWorkout"])
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()
        if !track.isSelected { track.tap() }
        XCTAssertTrue(track.isSelected)
        app.buttons["Plans"].tap()
        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Workout program library")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        if library.value as? String == "Collapsed" { library.tap() }
        let template = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Preview Adaptive Strength,")).firstMatch
        for _ in 0..<12 where !template.isHittable { app.swipeUp() }
        XCTAssertTrue(template.isHittable)
        template.tap()
        let preview = app.scrollViews["training.programPreview.screen"]
        let newCycle = app.buttons["Set up a new cycle"]
        if newCycle.exists { newCycle.tap() }
        let picker = app.descendants(matching: .any).matching(identifier: "training.programPreview.daysPerWeek").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        func positionPicker(_ picker: XCUIElement) {
            for _ in 0..<20 {
                let frame = picker.frame
                if frame.minY > 120 && frame.maxY < app.frame.maxY - 200 { break }
                let above = frame.minY < 120
                let start = preview.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: above ? 0.3 : 0.72))
                let end = preview.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: above ? 0.5 : 0.52))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
        }
        positionPicker(picker)
        picker.tap()
        let sixDays = app.buttons["6 days"]
        XCTAssertTrue(sixDays.waitForExistence(timeout: 5))
        sixDays.tap()
        if !sixDays.waitForNonExistence(timeout: 2) { sixDays.tap() }
        XCTAssertTrue(app.staticTexts["6 days/week"].waitForExistence(timeout: 3))
        let lastDay = preview.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", Legs B,")).firstMatch
        XCTAssertTrue(lastDay.waitForExistence(timeout: 3))
        let updatedPicker = app.descendants(matching: .any).matching(identifier: "training.programPreview.daysPerWeek").firstMatch
        positionPicker(updatedPicker)
        updatedPicker.tap()
        let twoDays = app.buttons["2 days"]
        XCTAssertTrue(twoDays.waitForExistence(timeout: 5))
        twoDays.tap()
        if !twoDays.waitForNonExistence(timeout: 2) { twoDays.tap() }
        XCTAssertTrue(app.staticTexts["2 days/week"].waitForExistence(timeout: 3))
        let secondDay = preview.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", Full Body B,")).firstMatch
        XCTAssertTrue(secondDay.waitForExistence(timeout: 3))
        XCTAssertFalse(lastDay.exists)
        XCTAssertTrue(app.buttons["training.programPreview.start"].isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Adaptive strength two-day preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testProgramLibraryFiltersSearchAndClearAtAccessibilitySize() {
        func openProgramLibrary(in app: XCUIApplication) {
            let track = tab("track", in: app)
            XCTAssertTrue(track.waitForExistence(timeout: 8))
            track.tap()
            if !track.isSelected { track.tap() }
            XCTAssertTrue(track.isSelected)
            let plans = app.buttons["tracker.segment.plans"]
            XCTAssertTrue(plans.waitForExistence(timeout: 5))
            if !plans.isSelected { plans.tap() }
            XCTAssertTrue(plans.isSelected)
            let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Workout program library")).firstMatch
            XCTAssertTrue(library.waitForExistence(timeout: 5))
            for _ in 0..<12 where !library.isHittable { app.swipeUp() }
            XCTAssertTrue(library.isHittable)
            if library.value as? String == "Collapsed" { library.tap() }
            let expanded = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", "Expanded"),
                object: library
            )
            XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 5), .completed)
            let search = app.textFields["Search programs by name or equipment"]
            for _ in 0..<12 where !search.isHittable { app.swipeUp() }
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            XCTAssertTrue(search.isHittable)
        }

        func capture(_ name: String, app: XCUIApplication) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        let app = launchDemo(arguments: ["-uiTestingNoActiveWorkout"])
        openProgramLibrary(in: app)
        let defaultCount = app.staticTexts["plans.programCount"]
        XCTAssertTrue(defaultCount.waitForExistence(timeout: 5))
        let fullCatalogCount = defaultCount.label
        capture("Program library default filters", app: app)

        func choose(_ label: String, value: String, in app: XCUIApplication) {
            let menu = app.buttons[label]
            XCTAssertTrue(menu.waitForExistence(timeout: 5))
            XCTAssertTrue(menu.isHittable)
            menu.tap()
            let option = app.buttons[value]
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
            XCTAssertEqual(menu.value as? String, value)
        }

        choose("Program category", value: "Powerlifting", in: app)
        choose("Includes equipment", value: "Barbell", in: app)
        choose("Training frequency", value: "3 days per week", in: app)
        let filteredCount = app.staticTexts["plans.programCount"]
        XCTAssertTrue(filteredCount.waitForExistence(timeout: 5))
        let totalProgramCount = fullCatalogCount.split(whereSeparator: { !$0.isNumber }).first.flatMap { Int($0) }
        let matchingProgramCount = filteredCount.label.split(whereSeparator: { !$0.isNumber }).first.flatMap { Int($0) }
        XCTAssertNotNil(totalProgramCount)
        XCTAssertNotNil(matchingProgramCount)
        XCTAssertGreaterThan(matchingProgramCount ?? 0, 0)
        XCTAssertLessThan(matchingProgramCount ?? totalProgramCount ?? 0, totalProgramCount ?? 0)
        let clearAll = app.buttons["Clear program search and filters"]
        XCTAssertTrue(clearAll.exists, "Clear all should be available while filters return results")
        capture("Program library combined filters", app: app)

        let search = app.textFields["Search programs by name or equipment"]
        search.tap()
        search.typeText("NoMatchingProgram771")
        XCTAssertTrue(app.staticTexts["No matching programs"].waitForExistence(timeout: 5))
        XCTAssertTrue(clearAll.exists, "Clear all should remain available for an empty result")
        capture("Program library empty search", app: app)
        if app.keyboards.buttons["Search"].exists {
            app.keyboards.buttons["Search"].tap()
        } else {
            search.typeText("\n")
        }
        clearAll.tap()
        XCTAssertEqual(search.value as? String, search.placeholderValue)
        XCTAssertEqual(app.buttons["Program category"].value as? String, "All categories")
        XCTAssertEqual(app.buttons["Includes equipment"].value as? String, "Any equipment")
        XCTAssertEqual(app.buttons["Training frequency"].value as? String, "Any frequency")
        XCTAssertEqual(defaultCount.label, fullCatalogCount)
        XCTAssertFalse(app.staticTexts["No matching programs"].exists)
        capture("Program library cleared filters", app: app)
        app.terminate()

        let largeApp = launchDemo(arguments: ["-uiTestingNoActiveWorkout", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openProgramLibrary(in: largeApp)
        let category = largeApp.buttons["Program category"]
        let equipment = largeApp.buttons["Includes equipment"]
        let frequency = largeApp.buttons["Training frequency"]
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        XCTAssertTrue(equipment.waitForExistence(timeout: 5))
        XCTAssertTrue(frequency.waitForExistence(timeout: 5))

        func revealAtAccessibilitySize(_ element: XCUIElement) {
            for _ in 0..<12 where !element.isHittable { largeApp.swipeUp() }
            XCTAssertTrue(element.isHittable)
        }

        revealAtAccessibilitySize(category)
        capture("Program library filters at Accessibility XXXL", app: largeApp)
        choose("Program category", value: "Powerlifting", in: largeApp)
        revealAtAccessibilitySize(equipment)
        choose("Includes equipment", value: "Barbell", in: largeApp)
        revealAtAccessibilitySize(frequency)
        choose("Training frequency", value: "3 days per week", in: largeApp)
        let accessibilityCount = largeApp.staticTexts["plans.programCount"]
        XCTAssertTrue(accessibilityCount.waitForExistence(timeout: 5))
        let accessibilityMatches = accessibilityCount.label.split(whereSeparator: { !$0.isNumber }).first.flatMap { Int($0) }
        XCTAssertGreaterThan(accessibilityMatches ?? 0, 0)
        XCTAssertLessThan(accessibilityMatches ?? totalProgramCount ?? 0, totalProgramCount ?? 0)
        capture("Program library selected filters at Accessibility XXXL", app: largeApp)
        let accessibilityClear = largeApp.buttons["Clear program search and filters"]
        revealAtAccessibilitySize(accessibilityClear)
        accessibilityClear.tap()
        XCTAssertEqual(category.value as? String, "All categories")
        XCTAssertEqual(equipment.value as? String, "Any equipment")
        XCTAssertEqual(frequency.value as? String, "Any frequency")
        XCTAssertEqual(accessibilityCount.label, fullCatalogCount)
        capture("Program library cleared filters at Accessibility XXXL", app: largeApp)
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
            NSPredicate(format: "label BEGINSWITH %@", "Preview Full Body Foundation")
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
        let weekPreview = app.staticTexts.matching(NSPredicate(format: "label == %@", "Template · Week 1 preview")).firstMatch
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
        let otherSetup = app.buttons["Other setup options"]
        for _ in 0..<20 where !otherSetup.isHittable { previewScroll.swipeDown() }
        XCTAssertTrue(otherSetup.isHittable)
        otherSetup.tap()
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

        let progressionOption = app.buttons["Adaptive Rep Range"]
        XCTAssertTrue(progressionOption.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let frame = progressionOption.frame
            if frame.minY >= app.frame.minY + 120 && frame.maxY <= app.frame.maxY - 180 { break }
            let startsAboveViewport = frame.minY < app.frame.minY + 120
            let start = previewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: startsAboveViewport ? 0.3 : 0.72))
            let end = previewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: startsAboveViewport ? 0.5 : 0.52))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(progressionOption.isHittable)
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

        for (name, title) in [("home", "Home"), ("leaderboards", "Leaderboards"), ("track", "Track"), ("forum", "Feed"), ("profile", "Me")] {
            let item = tab(name, in: app)
            XCTAssertTrue(item.exists, "Missing \(title) tab")
            item.tap()
            XCTAssertTrue(item.isSelected, "\(title) tab did not become selected")
        }
        XCTAssertEqual(tab("track", in: app).frame.midX, app.windows.firstMatch.frame.midX, accuracy: 1)
        XCTAssertEqual(app.tabBars.count, 1, "Primary navigation uses one native tab bar")
    }

    func testPrimaryNavigationAtAccessibilitySize() {
        let app = launchDemo(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let expectedTabs = [
            ("home", "Home"),
            ("leaderboards", "Rankings"),
            ("track", "Track"),
            ("forum", "Feed"),
            ("profile", "Me")
        ]
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        for (name, title) in expectedTabs {
            let item = tab(name, in: app)
            XCTAssertTrue(item.isHittable, "Missing accessible \(title) tab")
            item.tap()
            XCTAssertTrue(item.isSelected)
            if name == "forum" {
                let communityPicker = app.buttons["forum.community"]
                let sortMenu = app.buttons["forum.sort"]
                XCTAssertTrue(communityPicker.waitForExistence(timeout: 5))
                XCTAssertTrue(communityPicker.isHittable)
                XCTAssertTrue(sortMenu.waitForExistence(timeout: 5))
                XCTAssertTrue(sortMenu.isHittable)
                let forumScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                forumScreenshot.name = "Forum feed controls at largest accessibility text size"
                forumScreenshot.lifetime = .keepAlways
                add(forumScreenshot)
                communityPicker.tap()
                XCTAssertTrue(app.navigationBars["Communities"].waitForExistence(timeout: 5))
                XCTAssertTrue(app.buttons["All communities"].isHittable)
                let directoryScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                directoryScreenshot.name = "Community directory at largest accessibility text size"
                directoryScreenshot.lifetime = .keepAlways
                add(directoryScreenshot)
                app.buttons["Done"].tap()
                XCTAssertTrue(sortMenu.waitForExistence(timeout: 5))
            }
        }
        let settings = app.buttons["me.header.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isHittable)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Native tabs at largest accessibility text size"
        screenshot.lifetime = .keepAlways
        add(screenshot)
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
            XCTAssertTrue(meHeader(in: app).waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["Your PR highlights"].waitForExistence(timeout: 5))

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            startMeasuring()
            app.swipeUp()
            let weeklyGoal = app.buttons["weeklyTrainingGoal.set"]
            let weeklyGoalProgress = app.descendants(matching: .any)["weeklyTrainingGoal.card"]
            XCTAssertTrue(
                weeklyGoal.waitForExistence(timeout: 5) ||
                weeklyGoalProgress.waitForExistence(timeout: 5)
            )
            stopMeasuring()

            app.swipeDown()
            XCTAssertTrue(app.staticTexts["Your PR highlights"].waitForExistence(timeout: 5))
        }
    }

    func testEverySettingsTogglePersistsWhenReopened() {
        let app = launchDemo(arguments: ["-uiTestingNoActiveWorkout"])
        XCTAssertTrue(tab("home", in: app).waitForExistence(timeout: 8))
        let groups = [
            ("Privacy", ["Share workout starts with friends", "Share new top lifts with friends", "Show lift videos", "Share usage analytics"]),
            ("Training", ["Auto-share eligible PRs publicly", "Auto-start rest in new workouts", "Adjust rest to logged effort"]),
            ("Notifications", ["Workout day reminders", "Missed workout reminders", "Suggest days for missed workouts"])
        ]
        func open(_ section: String) {
            app.buttons["Open settings"].tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
            app.buttons[section].tap()
            XCTAssertTrue(app.navigationBars[section].waitForExistence(timeout: 5))
        }
        func control(_ name: String) -> XCUIElement {
            let element = app.switches[name].firstMatch
            for _ in 0..<8 where !element.isHittable { app.swipeUp() }
            XCTAssertTrue(element.isHittable, name)
            return element
        }
        func close(_ section: String) {
            let close = app.navigationBars[section].buttons["Close"]
            let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: close)
            XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
            XCTAssertFalse(app.alerts["Couldn’t save settings"].exists)
            close.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(app.navigationBars[section].waitForNonExistence(timeout: 5))
        }
        for (section, names) in groups {
            for name in names {
                open(section)
                let toggle = control(name)
                let original = toggle.value as? String
                XCTAssertTrue(original == "0" || original == "1", name)
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                let changed = original == "1" ? "0" : "1"
                let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", changed), object: toggle)
                XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed, name)
                close(section)
                open(section)
                let reopened = control(name)
                XCTAssertEqual(reopened.value as? String, changed, name)
                reopened.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                close(section)
                open(section)
                XCTAssertEqual(control(name).value as? String, original, name)
                close(section)
            }
        }
    }

    func testPlansAddExerciseAndSwitchPlan() {
        let app = launchDemo(arguments: ["-uiTestingNoActiveWorkout"])
        selectTrackTab(in: app)
        app.buttons["tracker.segment.plans"].tap()
        func openExercisePicker() {
            let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Options for '")).firstMatch
            for _ in 0..<8 where !options.isHittable { app.swipeUp() }
            XCTAssertTrue(options.isHittable)
            options.tap()
            app.buttons["Add exercise to plan"].tap()
        }
        openExercisePicker()
        XCTAssertTrue(app.navigationBars["Add Exercises"].waitForExistence(timeout: 5))
        let select = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Select ' AND label != 'Select exercises'")).firstMatch
        XCTAssertTrue(select.waitForExistence(timeout: 5))
        let name = String(select.label.dropFirst("Select ".count))
        select.tap()
        app.buttons["Add 1 to workout"].tap()
        XCTAssertTrue(app.navigationBars["Add Exercises"].waitForNonExistence(timeout: 5))
        openExercisePicker()
        XCTAssertTrue(app.navigationBars["Add Exercises"].waitForExistence(timeout: 5))
        app.textFields["Search exercises"].tap()
        app.textFields["Search exercises"].typeText(name)
        XCTAssertTrue(app.buttons["Already in workout"].waitForExistence(timeout: 5))
        app.navigationBars["Add Exercises"].buttons["Cancel"].tap()
        let switchPlan = app.buttons["tracker.plans.switch"]
        for _ in 0..<8 where !switchPlan.isHittable { app.swipeDown() }
        switchPlan.tap()
        XCTAssertTrue(app.navigationBars["Switch plan"].waitForExistence(timeout: 5))
        app.buttons["Use freestyle"].tap()
        XCTAssertTrue(app.navigationBars["Switch plan"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(switchPlan.label.contains("Freestyle"))
        switchPlan.tap()
        let savedPlan = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Use plan'")).firstMatch
        XCTAssertTrue(savedPlan.waitForExistence(timeout: 5))
        savedPlan.tap()
        XCTAssertTrue(app.navigationBars["Switch plan"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(switchPlan.label.contains("Freestyle"))
    }

    func testSettingsCloseDismissalPerformance() {
        let app = launchDemo(arguments: ["-uiTestingSettingsSaveFailure"])
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
            XCTAssertFalse(navigationBar.buttons["Done"].exists)
            XCTAssertFalse(navigationBar.buttons["Cancel"].exists)

            startMeasuring()
            navigationBar.buttons["Close"].tap()
            XCTAssertTrue(navigationBar.waitForNonExistence(timeout: 5))
            stopMeasuring()
        }

        let settings = app.buttons["Open settings"]
        settings.tap()
        if !app.navigationBars["Settings"].waitForExistence(timeout: 2) {
            settings.tap()
        }
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Appearance")).firstMatch.tap()
        let appearanceBar = app.navigationBars["Appearance"]
        XCTAssertTrue(appearanceBar.waitForExistence(timeout: 5))
        XCTAssertTrue(appearanceBar.buttons["Settings"].exists)
        XCTAssertTrue(appearanceBar.buttons["Close"].exists)
        XCTAssertFalse(appearanceBar.buttons["Done"].exists)
        XCTAssertFalse(appearanceBar.buttons["Cancel"].exists)
        let appearanceScreenshot = XCTAttachment(screenshot: app.screenshot())
        appearanceScreenshot.name = "Appearance navigation without duplicate dismissal"
        appearanceScreenshot.lifetime = .keepAlways
        add(appearanceScreenshot)

        for (identifier, title) in [("settings.colorTheme", "Color theme"), ("settings.accentColor", "Accent color")] {
            app.buttons[identifier].tap()
            let pickerBar = app.navigationBars[title]
            XCTAssertTrue(pickerBar.waitForExistence(timeout: 5))
            XCTAssertFalse(pickerBar.buttons["Close"].exists)
            XCTAssertFalse(pickerBar.buttons["Done"].exists)
            pickerBar.buttons.firstMatch.tap()
            XCTAssertTrue(appearanceBar.waitForExistence(timeout: 5))
        }

        let accentRow = app.buttons["settings.accentColor"]
        guard let originalAccent = accentRow.value as? String else {
            XCTFail("Accent setting should expose its selected value")
            return
        }
        let changedAccent = originalAccent == "Lime" ? "Orange" : "Lime"
        accentRow.tap()
        XCTAssertTrue(app.navigationBars["Accent color"].waitForExistence(timeout: 5))
        app.buttons[changedAccent].tap()
        XCTAssertTrue(app.buttons[changedAccent].isSelected)
        app.navigationBars["Accent color"].buttons.firstMatch.tap()
        XCTAssertEqual(accentRow.value as? String, changedAccent)

        accentRow.tap()
        XCTAssertTrue(app.navigationBars["Accent color"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[changedAccent].isSelected)
        app.buttons[originalAccent].tap()
        XCTAssertTrue(app.buttons[originalAccent].isSelected)
        app.navigationBars["Accent color"].buttons.firstMatch.tap()
        XCTAssertEqual(accentRow.value as? String, originalAccent)

        appearanceBar.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Training"].tap()
        let trainingBar = app.navigationBars["Training"]
        let focus = app.buttons["settings.trainingFocus"]
        XCTAssertTrue(focus.waitForExistence(timeout: 5))
        let expectedFocus = focus.value as? String == "Bodybuilding" ? "Powerlifting" : "Bodybuilding"
        focus.tap()
        app.buttons[expectedFocus].tap()
        let saveFailure = app.alerts["Couldn’t save settings"]
        XCTAssertTrue(saveFailure.waitForExistence(timeout: 5))
        saveFailure.buttons["Keep editing"].tap()
        XCTAssertEqual(focus.value as? String, expectedFocus)
        XCTAssertFalse(trainingBar.buttons["Save"].exists)
        XCTAssertFalse(trainingBar.buttons["Done"].exists)
        trainingBar.buttons["Close"].tap()
        let discard = app.alerts["Leave without confirming changes?"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.buttons["Keep editing"].tap()
        let retry = app.buttons["settings.retrySave"]
        for _ in 0..<6 where !retry.isHittable { app.swipeUp() }
        XCTAssertTrue(retry.isHittable)
        retry.tap()
        XCTAssertTrue(trainingBar.buttons["Close"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["settings.saveError"].exists)
        for _ in 0..<6 where !focus.isHittable { app.swipeDown() }
        XCTAssertEqual(focus.value as? String, expectedFocus)
        let trainingScreenshot = XCTAttachment(screenshot: app.screenshot())
        trainingScreenshot.name = "Training automatically saved with Close only"
        trainingScreenshot.lifetime = .keepAlways
        add(trainingScreenshot)
        trainingBar.buttons["Close"].tap()
        XCTAssertTrue(trainingBar.waitForNonExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Training"].tap()
        XCTAssertTrue(focus.waitForExistence(timeout: 5))
        XCTAssertEqual(focus.value as? String, expectedFocus)
        trainingBar.buttons["Settings"].tap()
        app.buttons["Privacy"].tap()
        let privateProfile = app.buttons["Profile visibility"]
        XCTAssertTrue(privateProfile.waitForExistence(timeout: 5))
        let expectedValue = privateProfile.value as? String == "Private" ? "Public" : "Private"
        privateProfile.tap()
        app.buttons[expectedValue].tap()
        XCTAssertEqual(privateProfile.value as? String, expectedValue)
        XCTAssertTrue(app.navigationBars["Privacy"].buttons["Close"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Privacy"].buttons["Save"].exists)
        app.navigationBars["Privacy"].buttons["Settings"].tap()
        XCTAssertFalse(app.navigationBars["Settings"].buttons["Cancel"].exists)
        XCTAssertFalse(app.navigationBars["Settings"].buttons["Save"].exists)
        app.buttons["Privacy"].tap()
        XCTAssertEqual(privateProfile.value as? String, expectedValue)
        app.navigationBars["Privacy"].buttons["Close"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForNonExistence(timeout: 5))

        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Privacy"].tap()
        XCTAssertTrue(privateProfile.waitForExistence(timeout: 5))
        XCTAssertEqual(privateProfile.value as? String, expectedValue)
        app.navigationBars["Privacy"].buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Units")).firstMatch.tap()
        let units = app.buttons["settings.preferredUnit"]
        XCTAssertTrue(units.waitForExistence(timeout: 5))
        let expectedUnit = units.value as? String == "Pounds" ? "Kilograms" : "Pounds"
        units.tap()
        app.buttons[expectedUnit].tap()
        XCTAssertTrue(app.navigationBars["Units"].buttons["Close"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Units"].buttons["Save"].exists)
        app.navigationBars["Units"].buttons["Close"].tap()
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Units")).firstMatch.tap()
        XCTAssertTrue(units.waitForExistence(timeout: 5))
        XCTAssertEqual(units.value as? String, expectedUnit)
        app.navigationBars["Units"].buttons["Settings"].tap()
        app.buttons["Privacy"].tap()
        let preview = app.buttons["Preview public profile"]
        for _ in 0..<8 where !preview.isHittable { app.swipeUp() }
        preview.tap()
        let previewBar = app.navigationBars["Public preview"]
        XCTAssertTrue(previewBar.waitForExistence(timeout: 5))
        XCTAssertFalse(previewBar.buttons["Done"].exists)
        XCTAssertFalse(previewBar.buttons["Close"].exists)
        app.buttons["Public profile privacy settings"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 5))
        app.navigationBars["Privacy"].buttons["Settings"].tap()
        app.buttons["About & support"].tap()
        app.buttons["About Lift Rivals"].tap()
        let about = app.navigationBars["About Lift Rivals"]
        XCTAssertTrue(about.waitForExistence(timeout: 5))
        XCTAssertFalse(about.buttons["Done"].exists)
        XCTAssertFalse(about.buttons["Close"].exists)
        about.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["About & support"].waitForExistence(timeout: 5))
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
        let profileHeader = app.descendants(matching: .any)["me.profileHeader"]
        if !profileHeader.waitForExistence(timeout: 2) { meTab.tap() }
        XCTAssertTrue(profileHeader.waitForExistence(timeout: 5))
        let awards = app.descendants(matching: .any)["me.awards"]
        for _ in 0..<8 where !awards.isHittable || awards.frame.maxY >= tab("profile", in: app).frame.minY { app.swipeUp() }
        XCTAssertTrue(awards.waitForExistence(timeout: 5))
        let publicProfile = app.descendants(matching: .any)["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["me.header.settings"].waitForExistence(timeout: 5))

        awards.tap()
        let awardsScreen = app.navigationBars["Awards"]
        if !awardsScreen.waitForExistence(timeout: 2) && !app.staticTexts["RIVAL TIER"].exists { awards.tap() }
        XCTAssertTrue(awardsScreen.waitForExistence(timeout: 5) || app.staticTexts["RIVAL TIER"].waitForExistence(timeout: 5))
        XCTAssertTrue(tab("profile", in: app).isHittable)
        let homeTab = tab("home", in: app)
        homeTab.tap()
        expectation(for: NSPredicate(format: "selected == true"), evaluatedWith: homeTab)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(homeTab.isSelected, "Home must be selected before returning to Me")
        tab("profile", in: app).tap()
        XCTAssertTrue(awardsScreen.waitForExistence(timeout: 5), "Switching tabs must preserve the Me navigation stack")
        XCTAssertTrue(app.staticTexts["Squat"].exists)
        XCTAssertTrue(app.staticTexts["Bench"].exists)
        XCTAssertTrue(app.staticTexts["Deadlift"].exists)
        XCTAssertTrue(app.buttons["awards.shareRivalTier"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Personal records"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Other awards")).firstMatch.exists)

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 5))
        for _ in 0..<8 where !publicProfile.isHittable { app.swipeDown() }
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 5))
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 5))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 5))
    }

    func testPublicProfileUsesCompactEmptyStateWhenNoLiftDataIsVisible() {
        let app = launchDemo(arguments: ["-uiTestingEmptyRecentPRs"])
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        if !meHeader(in: app).waitForExistence(timeout: 2) {
            tab("profile", in: app).tap()
        }
        XCTAssertTrue(meHeader(in: app).waitForExistence(timeout: 5))

        let publicProfile = app.buttons["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()

        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["profile.noPublicData"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["profile.sectionNavigation"].exists)
        XCTAssertFalse(app.staticTexts["Delete account"].exists)
    }

    func testPublicProfileKeepsAccountControlsSeparateFromAthleteOptions() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        if !meHeader(in: app).waitForExistence(timeout: 2) {
            tab("profile", in: app).tap()
        }
        XCTAssertTrue(meHeader(in: app).waitForExistence(timeout: 5))

        let publicProfile = app.buttons["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.tap()

        XCTAssertTrue(app.navigationBars["Public preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Public preview"].buttons["Back"].exists)
        XCTAssertTrue(app.buttons["Public profile privacy settings"].exists)
        XCTAssertFalse(app.buttons["profile.athleteOptions"].exists)
        XCTAssertFalse(app.buttons["me.header.settings"].exists)
        XCTAssertFalse(app.buttons["Delete account"].exists)
    }

    func testProfileShowsVerifiedScoreInPreferredWeightUnit() {
        let app = launchDemo(arguments: ["-uiTestingCompetitionFixture"])
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        XCTAssertTrue(meHeader(in: app).waitForExistence(timeout: 5))
        app.buttons["me.personalProfile"].tap()
        app.buttons["profile.sectionNavigation"].tap()
        app.buttons["Overview"].tap()
        let score = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Submitted three-lift total,")).firstMatch
        XCTAssertTrue(score.waitForExistence(timeout: 5))
        XCTAssertEqual(score.label, "Submitted three-lift total, 315 lb")
        XCTAssertTrue(app.state == .runningForeground)
    }

    func testMePublicProfileNavigationDoesNotFreezeOnRepeatedOpen() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        if !meHeader(in: app).waitForExistence(timeout: 2) {
            tab("profile", in: app).tap()
        }
        XCTAssertTrue(meHeader(in: app).waitForExistence(timeout: 5))

        for _ in 0..<2 {
            let publicProfile = app.buttons["me.publicProfile"]
            XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
            publicProfile.tap()

            XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 5))
            XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 5))
            let trainingSection = app.buttons["profile.section.training"]
            XCTAssertTrue(trainingSection.waitForExistence(timeout: 5))
            trainingSection.tap()
            XCTAssertTrue(app.buttons["View Leaderboards"].waitForExistence(timeout: 5))

            let back = app.navigationBars["Public preview"].buttons["Back"]
            back.tap()
            XCTAssertTrue(meHeader(in: app).waitForExistence(timeout: 5))
            XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 5))
        }
    }

    func testMePublicProfileBackPerformance() {
        let app = launchDemo()
        let meTab = tab("profile", in: app)
        XCTAssertTrue(meTab.waitForExistence(timeout: 8))
        meTab.tap()
        if !meHeader(in: app).waitForExistence(timeout: 2) {
            meTab.tap()
        }
        XCTAssertTrue(meHeader(in: app).waitForExistence(timeout: 5))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) {
            let publicProfile = app.buttons["me.publicProfile"]
            XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
            publicProfile.tap()
            XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 5))

            startMeasuring()
            app.navigationBars["Public preview"].buttons["Back"].tap()
            XCTAssertTrue(meHeader(in: app).waitForExistence(timeout: 5))
            XCTAssertTrue(meTab.exists)
            stopMeasuring()
        }
    }

    func testMeHubSectionOrderAndCompactHeaderActions() {
        let app = launchDemo()
        let profileTab = tab("profile", in: app)
        XCTAssertTrue(profileTab.waitForExistence(timeout: 8))
        profileTab.tap()
        XCTAssertTrue(profileTab.isSelected)
        let meScrollView = app.scrollViews.containing(.any, identifier: "me.profileHeader").firstMatch
        XCTAssertTrue(meScrollView.waitForExistence(timeout: 5))

        XCTAssertTrue(app.descendants(matching: .any)["me.profileHeader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["me.header.settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["me.header.editProfile"].waitForExistence(timeout: 5))

        let total = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Total submitted strength")).firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertTrue(total.isHittable)
        total.tap()
        XCTAssertTrue(app.navigationBars["Total strength"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Me strength record"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let history = app.buttons["me.personalProfile"]
        var attempts = 0
        while !history.isHittable && attempts < 12 {
            meScrollView.swipeUp()
            attempts += 1
        }

        let awards = app.buttons["me.awards"]
        XCTAssertTrue(awards.waitForExistence(timeout: 5))
        XCTAssertLessThan(awards.frame.minY, history.frame.minY)
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
        XCTAssertTrue(gyms.label.contains("Primary:") && gyms.label.contains("joined"))
        XCTAssertTrue(gyms.isHittable)
        XCTAssertLessThan(gyms.frame.maxY, profileTab.frame.minY)
    }

    func testMeOpensStrengthHistoryThroughAwards() {
        let app = launchDemo()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 8))
        tab("profile", in: app).tap()
        let header = app.descendants(matching: .any)["me.profileHeader"]
        if !header.waitForExistence(timeout: 2) { tab("profile", in: app).tap() }
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        let awards = app.buttons["me.awards"]
        for _ in 0..<8 where !awards.isHittable || awards.frame.maxY >= tab("profile", in: app).frame.minY { app.swipeUp() }
        XCTAssertTrue(awards.isHittable)
        awards.tap()
        let deadlift = app.buttons["View Deadlift workout history"]
        for _ in 0..<8 where !deadlift.isHittable { app.swipeUp() }
        XCTAssertTrue(deadlift.waitForExistence(timeout: 5))
        deadlift.tap()
        XCTAssertTrue(app.navigationBars["Deadlift history"].waitForExistence(timeout: 5))

        app.buttons["Done"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(tab("profile", in: app).waitForExistence(timeout: 5))
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
        let profileTab = tab("profile", in: app)
        XCTAssertTrue(profileTab.waitForExistence(timeout: 8))
        profileTab.tap()
        let profileHeader = app.descendants(matching: .any)["me.profileHeader"]
        if !profileHeader.waitForExistence(timeout: 4) { profileTab.tap() }
        XCTAssertTrue(profileHeader.waitForExistence(timeout: 5), "Me should open after one bounded tab retry.")

        let awards = app.descendants(matching: .any)["me.awards"]
        var attempts = 0
        while !awards.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(awards.isHittable)
        app.staticTexts["Rival tier & awards"].tap()
        XCTAssertTrue(app.navigationBars["Awards"].waitForExistence(timeout: 5))

        let earnedHeader = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Earned awards")
        ).firstMatch
        let closestHeader = app.staticTexts["Closest awards"]
        let otherHeader = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Other awards")
        ).firstMatch

        XCTAssertTrue(earnedHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(closestHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(otherHeader.waitForExistence(timeout: 5))

        XCTAssertLessThan(closestHeader.frame.minY, earnedHeader.frame.minY)
        XCTAssertLessThan(earnedHeader.frame.minY, otherHeader.frame.minY)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "[0-9]+ earned")
        ).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "[0-9]+ remaining")
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

        let videosSection = app.buttons["profile.section.prVideos"]
        XCTAssertTrue(videosSection.waitForExistence(timeout: 5))
        videosSection.tap()

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

        let videosSection = app.buttons["profile.section.prVideos"]
        XCTAssertTrue(videosSection.waitForExistence(timeout: 5))
        videosSection.tap()

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

            app.navigationBars["Lift video"].buttons["Done"].tap()
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

        let videosSection = app.buttons["profile.section.prVideos"]
        XCTAssertTrue(videosSection.waitForExistence(timeout: 5))
        videosSection.tap()

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
        let profileTab = tab("profile", in: app)
        profileTab.tap()
        let profileHeader = app.descendants(matching: .any)["me.profileHeader"]
        if !profileHeader.waitForExistence(timeout: 2) { profileTab.tap() }
        XCTAssertTrue(profileHeader.waitForExistence(timeout: 5))

        let publicProfile = app.descendants(matching: .any)["me.publicProfile"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.sectionNavigation"].waitForExistence(timeout: 5))

        let videosSection = app.buttons["profile.section.prVideos"]
        XCTAssertTrue(videosSection.waitForExistence(timeout: 5))
        videosSection.tap()

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
        let exerciseFilter = app.buttons["leaderboard.filter.exercise"]
        XCTAssertTrue(exerciseFilter.waitForExistence(timeout: 5))
        exerciseFilter.tap()
        let bench = app.buttons["option.bench"]
        if !bench.waitForExistence(timeout: 2) { exerciseFilter.tap() }
        XCTAssertTrue(bench.waitForExistence(timeout: 5))
        bench.tap()
        if !bench.waitForNonExistence(timeout: 2) { bench.tap() }
        XCTAssertTrue(bench.waitForNonExistence(timeout: 5))
        let selectedBench = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Exercise, Barbell bench press"),
            object: exerciseFilter
        )
        XCTAssertEqual(XCTWaiter.wait(for: [selectedBench], timeout: 5), .completed)
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
        let sectionMenu = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Profile sections")
        ).firstMatch
        XCTAssertTrue(sectionMenu.waitForExistence(timeout: 5))
        sectionMenu.tap()
        let historySection = app.buttons["Workouts"]
        XCTAssertTrue(historySection.waitForExistence(timeout: 5))
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
        let progress = app.buttons["tracker.segment.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        progress.tap()
        selectProgressCategory("Strength", in: app)
        app.buttons["Records and source workouts"].tap()

        let relativeTotal = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "×")).firstMatch
        XCTAssertTrue(relativeTotal.waitForExistence(timeout: 5))
        let initialRelativeTotal = relativeTotal.label
        XCTAssertFalse(app.staticTexts["Bodyweight"].exists)
        XCTAssertFalse(app.buttons["Log bodyweight"].exists)

        func openHomeBodyweightEditor() {
            let homeTab = tab("home", in: app)
            if !homeTab.exists { app.navigationBars.buttons["BackButton"].tap() }
            tab("home", in: app).tap()
            let bodyweightAction = app.buttons["home.quickAction.bodyweight"]
            let homeScroll = app.scrollViews.firstMatch
            for _ in 0..<16 where !bodyweightAction.isHittable { homeScroll.swipeUp() }
            XCTAssertTrue(bodyweightAction.isHittable)
            bodyweightAction.tap()
            XCTAssertTrue(app.navigationBars["Bodyweight Entry"].waitForExistence(timeout: 5))
        }

        openHomeBodyweightEditor()
        let weight = app.textFields["Enter weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        let originalValue = weight.value as? String ?? ""
        XCTAssertFalse(originalValue.isEmpty)
        app.navigationBars["Bodyweight Entry"].buttons["Save"].tap()

        openHomeBodyweightEditor()
        weight.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: originalValue.count) + "182")
        app.navigationBars["Bodyweight Entry"].buttons["Save"].tap()

        tab("track", in: app).tap()
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        progress.tap()
        selectProgressCategory("Strength", in: app)
        app.buttons["Records and source workouts"].tap()
        let updatedRelativeTotal = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "×")).firstMatch
        XCTAssertTrue(updatedRelativeTotal.waitForExistence(timeout: 5))
        let updatedTotalExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", initialRelativeTotal),
            object: updatedRelativeTotal
        )
        XCTAssertEqual(XCTWaiter.wait(for: [updatedTotalExpectation], timeout: 5), .completed)

        tab("profile", in: app).tap()
        app.buttons["me.personalProfile"].tap()
        app.buttons["Athlete details"].tap()
        app.buttons["Profile details"].tap()
        let profileWeight = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Logged weight ·")).firstMatch
        XCTAssertTrue(profileWeight.waitForExistence(timeout: 5))
        XCTAssertTrue(profileWeight.label.contains("182"))

        app.terminate()
        app = launchDemo(arguments: ["-uiTestingPersistWorkoutSnapshots"])
        tab("profile", in: app).tap()
        app.buttons["me.personalProfile"].tap()
        app.buttons["Athlete details"].tap()
        app.buttons["Profile details"].tap()
        let relaunchedProfileWeight = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Logged weight ·")
        ).firstMatch
        XCTAssertTrue(relaunchedProfileWeight.waitForExistence(timeout: 5))
        XCTAssertTrue(relaunchedProfileWeight.label.contains("182"))

        openHomeBodyweightEditor()
        app.buttons["Delete Entry"].tap()
        let deleteConfirmation = app.sheets["Delete this bodyweight entry?"].buttons["Delete Entry"]
        XCTAssertTrue(deleteConfirmation.waitForExistence(timeout: 5))
        deleteConfirmation.tap()
        XCTAssertTrue(app.navigationBars["Bodyweight Entry"].waitForNonExistence(timeout: 5))

        tab("track", in: app).tap()
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        progress.tap()
        selectProgressCategory("Strength", in: app)
        app.buttons["Records and source workouts"].tap()
        let missingBodyweightSummary = app.staticTexts["Needs total and bodyweight"]
        for _ in 0..<8 where !missingBodyweightSummary.isHittable { app.swipeDown() }
        XCTAssertTrue(missingBodyweightSummary.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Bodyweight"].exists)

        tab("profile", in: app).tap()
        app.buttons["me.personalProfile"].tap()
        app.buttons["Athlete details"].tap()
        app.buttons["Profile details"].tap()
        let profileWeightAfterDelete = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Logged weight ·")
        ).firstMatch
        XCTAssertFalse(profileWeightAfterDelete.waitForExistence(timeout: 2))

        app.terminate()
        app = launchDemo(arguments: ["-uiTestingPersistWorkoutSnapshots"])
        tab("profile", in: app).tap()
        app.buttons["me.personalProfile"].tap()
        app.buttons["Athlete details"].tap()
        app.buttons["Profile details"].tap()
        let persistedProfileWeight = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Logged weight ·")
        ).firstMatch
        XCTAssertFalse(persistedProfileWeight.waitForExistence(timeout: 2))
    }

    func testEditProfileKeepsUnsavedFieldsAfterPhotoManager() {
        let app = launchDemo()
        let meTab = tab("profile", in: app)
        XCTAssertTrue(meTab.waitForExistence(timeout: 8))
        meTab.tap()
        let edit = app.buttons["Edit athlete profile"]
        if !edit.waitForExistence(timeout: 5) { meTab.tap() }
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
        if app.keyboards.buttons["return"].exists { name.typeText(XCUIKeyboardKey.return.rawValue) }
        let logWeight = app.buttons["editProfile.logBodyweight"]
        for _ in 0..<5 where !logWeight.isHittable { app.swipeUp() }
        XCTAssertTrue(logWeight.isHittable)
        logWeight.tap()
        XCTAssertTrue(app.navigationBars["Bodyweight Entry"].waitForExistence(timeout: 5))
        app.navigationBars["Bodyweight Entry"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        app.navigationBars["Edit Profile"].buttons["Cancel"].tap()
    }

    func testProfilePhotoLibraryOpensAtAccessibilitySize() throws {
        let app = launchDemo(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let profileTab = tab("profile", in: app)
        XCTAssertTrue(profileTab.waitForExistence(timeout: 8))
        profileTab.tap()
        let edit = app.buttons["Edit athlete profile"]
        if !edit.waitForExistence(timeout: 3) { profileTab.tap() }
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Profile photo")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Profile Photo"].waitForExistence(timeout: 5))
        app.buttons["Choose Photo"].tap()
        let pickerLoading = app.staticTexts["Loading..."]
        let unavailablePicker = app.descendants(matching: .any)["PUPickerUnavailableView"]
        if pickerLoading.waitForExistence(timeout: 2) {
            _ = pickerLoading.waitForNonExistence(timeout: 20)
        }
        if pickerLoading.exists || unavailablePicker.exists {
            throw XCTSkip("The simulator's system Photos picker remained unavailable in its loading view; verify photo selection on a physical device.")
        }
        var firstPhoto: XCUIElement?
        for _ in 0..<3 {
            firstPhoto = app.cells.allElementsBoundByIndex.first { cell in
                let frame = cell.frame
                return frame.origin.x.isFinite && frame.origin.y.isFinite &&
                    frame.width > 0 && frame.height > 0 && cell.isHittable
            }
            if firstPhoto != nil { break }
            app.swipeUp()
        }
        guard let firstPhoto else {
            throw XCTSkip("The Photos picker exposed no selectable image in this simulator; verify image selection and cropping on a populated physical device.")
        }
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
        XCTAssertFalse(bench.label.localizedCaseInsensitiveContains("push exercise"))
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
        let track = tab("track", in: app)
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        track.tap()
        if !track.isSelected { track.tap() }
        XCTAssertTrue(track.isSelected)

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
        app.buttons["Charts"].tap()
        XCTAssertTrue(app.staticTexts["Includes completed working sets from recovery/deload workouts."].waitForExistence(timeout: 5))
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
        let profileTab = tab("profile", in: app)
        profileTab.tap()
        let profileHeader = app.descendants(matching: .any)["me.profileHeader"]
        if !profileHeader.waitForExistence(timeout: 2) { profileTab.tap() }
        XCTAssertTrue(profileHeader.waitForExistence(timeout: 5))

        let gyms = app.descendants(matching: .any)["me.gyms"]
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

        app.buttons["leaderboard.filters.group.division"].tap()
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
        XCTAssertFalse(app.switches["Require lift video"].exists)

        let requiredInputs = app.textFields.matching(identifier: "Required")
        XCTAssertEqual(requiredInputs.count, 2)
        requiredInputs.element(boundBy: 0).tap()
        requiredInputs.element(boundBy: 0).typeText("315")
        requiredInputs.element(boundBy: 1).tap()
        requiredInputs.element(boundBy: 1).typeText("1")

        let submitReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: submit
        )
        XCTAssertEqual(XCTWaiter.wait(for: [submitReady], timeout: 8), .completed)
        submit.tap()

        XCTAssertTrue(app.staticTexts["lift.submissionResult"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Self-reported"].exists)
        XCTAssertTrue(app.staticTexts["This lift is saved, but no playable video is attached."].exists)
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
        let app = launchDemo()
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

        let activity = app.buttons["profile.section.submissions"]
        XCTAssertTrue(activity.waitForExistence(timeout: 5))
        activity.tap()
        let liftOptions = app.descendants(matching: .any).matching(
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
        XCTAssertFalse(submit.isEnabled)
        let reasonPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Choose a reason")).firstMatch
        XCTAssertTrue(reasonPicker.waitForExistence(timeout: 5))
        reasonPicker.tap()
        app.buttons["Incorrect weight"].tap()
        XCTAssertTrue(submit.isEnabled)
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

        let account = app.buttons["Account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        account.tap()
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5))
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

    func testOnboardingTakenUsernameStaysOnProfileStep() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingOnboarding", "-uiTestingPrefilledOnboarding", "-uiTestingUsernameUnavailable"]
        app.launch()
        let stronger = app.buttons["onboarding.goal.get_stronger"]
        XCTAssertTrue(stronger.waitForExistence(timeout: 5))
        for _ in 0..<5 where stronger.frame.maxY >= app.buttons["onboarding.next"].frame.minY {
            app.scrollViews.firstMatch.swipeUp()
        }
        stronger.tap()
        app.buttons["onboarding.next"].tap()
        XCTAssertTrue(app.staticTexts["Set up your profile."].waitForExistence(timeout: 5))
        app.buttons["onboarding.next"].tap()
        XCTAssertTrue(app.staticTexts["That username is already taken."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Username"].exists)
        XCTAssertEqual(app.textFields["Username"].value as? String, "launch_lifter")
        XCTAssertTrue(app.staticTexts["STEP 2 OF 4"].exists)
    }

    func testOnboardingSavesProfileAndAdvancesToLegalAcceptance() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingOnboarding", "-uiTestingPrefilledOnboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["What are you training for?"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Continue"].isEnabled)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "onboarding.goal.")).count, 4)
        XCTAssertFalse(app.staticTexts["Training style (optional) · choose one"].exists)
        let stronger = app.buttons["onboarding.goal.get_stronger"]
        for _ in 0..<5 where stronger.frame.maxY >= app.buttons["onboarding.next"].frame.minY {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(stronger.isHittable)
        stronger.tap()
        XCTAssertTrue(stronger.isSelected)
        XCTAssertTrue(app.buttons["Continue"].isEnabled)
        let goalsScreenshot = XCTAttachment(screenshot: app.screenshot())
        goalsScreenshot.name = "Primary training goals"
        goalsScreenshot.lifetime = .keepAlways
        add(goalsScreenshot)
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Set up your profile."].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Username"].value as? String, "launch_lifter")
        let profileScreenshot = XCTAttachment(screenshot: app.screenshot())
        profileScreenshot.name = "Onboarding profile identity"
        profileScreenshot.lifetime = .keepAlways
        add(profileScreenshot)
        let bodyweight = app.textFields["onboarding.bodyweight"]
        for _ in 0..<5 where bodyweight.frame.maxY >= app.buttons["onboarding.next"].frame.minY {
            app.scrollViews.firstMatch.swipeUp()
        }
        bodyweight.tap()
        if let current = bodyweight.value as? String, current != "Not set" {
            bodyweight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        app.buttons["Done"].tap()
        XCTAssertEqual(bodyweight.value as? String, "Not set")
        bodyweight.tap()
        bodyweight.typeText("185.5")
        app.buttons["Done"].tap()
        XCTAssertEqual(bodyweight.value as? String, "185.5")
        let trainingScreenshot = XCTAttachment(screenshot: app.screenshot())
        trainingScreenshot.name = "Onboarding measurements"
        trainingScreenshot.lifetime = .keepAlways
        add(trainingScreenshot)
        let city = app.buttons["onboarding.location.city"]
        for _ in 0..<5 where city.frame.maxY >= app.buttons["onboarding.next"].frame.minY {
            app.scrollViews.firstMatch.swipeUp()
        }
        city.tap()
        XCTAssertTrue(app.staticTexts["Common cities"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["onboarding.city.search"].exists)
        let cityScreenshot = XCTAttachment(screenshot: app.screenshot())
        cityScreenshot.name = "Onboarding common cities"
        cityScreenshot.lifetime = .keepAlways
        add(cityScreenshot)
        app.buttons["Orlando"].tap()
        XCTAssertTrue(city.label.contains("Orlando"))
        city.tap()
        let citySearch = app.textFields["onboarding.city.search"]
        citySearch.tap()
        citySearch.typeText("Mia")
        let miami = app.buttons["Miami"]
        XCTAssertTrue(miami.waitForExistence(timeout: 5))
        miami.tap()
        XCTAssertTrue(city.label.contains("Miami"))
        city.tap()
        XCTAssertTrue(app.staticTexts["Common cities"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        for field in ["profile", "bodyweight", "location"] {
            let audience = app.buttons["onboarding.privacy.\(field)"]
            for _ in 0..<8 where !audience.isHittable {
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(audience.isHittable)
            XCTAssertEqual(audience.value as? String, "Public")
        }
        let locationAudience = app.buttons["onboarding.privacy.location"]
        locationAudience.tap()
        app.buttons["Friends"].tap()
        XCTAssertEqual(locationAudience.value as? String, "Friends")
        let weightAudience = app.buttons["onboarding.privacy.bodyweight"]
        weightAudience.tap()
        app.buttons["Private"].tap()
        XCTAssertEqual(weightAudience.value as? String, "Private")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Add starting lifts?"].waitForExistence(timeout: 5))
        app.buttons["Continue to policies"].tap()

        XCTAssertTrue(app.staticTexts["Review policies"].waitForExistence(timeout: 8))
        app.buttons["legal.back"].tap()
        XCTAssertTrue(app.staticTexts["Add starting lifts?"].waitForExistence(timeout: 5))
        app.buttons["Previous step"].tap()
        XCTAssertEqual(app.textFields["Username"].value as? String, "launch_lifter")
        XCTAssertEqual(app.textFields["onboarding.bodyweight"].value as? String, "185.5")
        XCTAssertTrue(app.buttons["onboarding.location.city"].label.contains("Miami"))
        for _ in 0..<8 where !locationAudience.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertEqual(locationAudience.value as? String, "Friends")
        XCTAssertEqual(weightAudience.value as? String, "Private")
        app.buttons["Continue"].tap()
        app.buttons["Continue to policies"].tap()
        XCTAssertTrue(app.staticTexts["Review policies"].waitForExistence(timeout: 8))
    }

    func testOnboardingYearsTrainingControlChangesValue() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingOnboarding", "-uiTestingPrefilledOnboarding"]
        app.launch()

        let powerlifting = app.buttons["onboarding.goal.powerlifting"]
        XCTAssertTrue(powerlifting.waitForExistence(timeout: 8))
        for _ in 0..<5 where powerlifting.frame.maxY >= app.buttons["onboarding.next"].frame.minY {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(powerlifting.isHittable)
        powerlifting.tap()
        XCTAssertTrue(powerlifting.isSelected)
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        let years = app.textFields["onboarding.yearsTraining"]
        for _ in 0..<8 where !years.isHittable { app.swipeUp() }
        XCTAssertTrue(years.isHittable)
        XCTAssertEqual(years.value as? String, "Not set")
        years.tap()
        years.typeText("0")
        app.buttons["Done"].tap()
        XCTAssertEqual(years.value as? String, "0")
        app.buttons["Continue"].tap()
        app.buttons["Previous step"].tap()
        XCTAssertEqual(years.value as? String, "0")
    }

    func testFreshOnboardingAllowsOptionalProfileDetailsToWait() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingOnboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["What are you training for?"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Continue"].isEnabled)
        let focus = app.buttons["onboarding.goal.generalFitness"]
        for _ in 0..<5 where focus.frame.maxY >= app.buttons["onboarding.next"].frame.minY {
            app.scrollViews.firstMatch.swipeUp()
        }
        focus.tap()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Set up your profile."].waitForExistence(timeout: 5))
        let username = app.textFields["Username"]
        XCTAssertTrue(username.exists)
        XCTAssertFalse(app.buttons["Add optional profile details"].exists)
        XCTAssertTrue(app.buttons["onboarding.photo"].exists)
        XCTAssertTrue(app.textFields["Bio (optional)"].exists)

        app.buttons["Continue"].tap()
        add(XCTAttachment(screenshot: app.screenshot()))
        XCTAssertTrue(app.staticTexts["Choose a username to continue."].waitForExistence(timeout: 5))
        username.tap()
        username.typeText("fresh_lifter")
        app.buttons["Done"].tap()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Add starting lifts?"].waitForExistence(timeout: 5))
        app.buttons["Continue to policies"].tap()
        XCTAssertTrue(app.staticTexts["Review policies"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["STEP 4 OF 4"].exists)
        XCTAssertFalse(app.buttons["Accept and Continue"].isEnabled)
    }

    func testUnauthenticatedRoutingDoesNotExposeDemoEntryInReleaseContract() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingAuthentication"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Lift Rivals"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["Lift Rivals logo"].exists)
        XCTAssertTrue(app.textFields["Email"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.buttons["Sign In"].exists)
        XCTAssertTrue(app.staticTexts["Welcome back. Sign in to continue."].exists)
        let guestEntry = app.buttons["Create a guest profile"]
        XCTAssertTrue(guestEntry.exists)
        if !guestEntry.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(guestEntry.isHittable)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Authentication guest entry"
        attachment.lifetime = .keepAlways
        add(attachment)
        let createAccount = app.segmentedControls.buttons["Create Account"]
        XCTAssertTrue(createAccount.exists)
        createAccount.tap()
        XCTAssertTrue(createAccount.isSelected)
        XCTAssertTrue(app.staticTexts["Create your account to save and sync your training."].exists)
        XCTAssertFalse(app.buttons["Forgot password?"].exists)

        guestEntry.tap()
        XCTAssertTrue(app.staticTexts["Review policies"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Accept and Continue"].exists)
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
            let privacyConsent = app.buttons["I have read and acknowledge Privacy Notice"]
            XCTAssertTrue(privacyConsent.waitForExistence(timeout: 5))
            if !privacyConsent.isHittable {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.33, dy: 0.615)).tap()
            }
            for label in [
                "I have read and acknowledge Privacy Notice",
                "I have read and accept Terms of Use",
                "I have read and accept Fitness Disclaimer"
            ] {
                let consent = app.buttons[label]
                XCTAssertTrue(consent.waitForExistence(timeout: 5), "Missing legal consent: \(label)")
                if consent.value as? String != "Checked" {
                    consent.tap()
                }
                if consent.value as? String != "Checked" {
                    consent.tap()
                }
                XCTAssertEqual(consent.value as? String, "Checked")
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
        app.launchArguments += ["-uiTestingAuthentication", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let submit = app.buttons["authentication.email.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 8))
        XCTAssertTrue(submit.isEnabled)

        submit.tap()
        XCTAssertTrue(app.descendants(matching: .any)["Enter your email address."].waitForExistence(timeout: 5))

        let email = app.textFields["Email"]
        email.tap()
        let invalidEmail = "reviewer.example.com"
        email.typeText(invalidEmail)

        let nextKey = app.keyboards.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "next")
        ).firstMatch
        XCTAssertTrue(nextKey.waitForExistence(timeout: 5))
        XCTAssertTrue(nextKey.isHittable, "Email should expose a reachable Next key.")
        nextKey.tap()
        let doneKey = app.keyboards.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "done")
        ).firstMatch
        XCTAssertTrue(doneKey.waitForExistence(timeout: 5))
        add(XCTAttachment(screenshot: app.screenshot()))
        XCTAssertTrue(doneKey.isHittable, "Next should move focus to the password field and expose a reachable Done key.")
        doneKey.tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        submit.tap()
        XCTAssertTrue(app.descendants(matching: .any)["Enter a valid email address."].waitForExistence(timeout: 5))

        email.tap()
        email.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: invalidEmail.count))
        email.typeText("reviewer@example.com")

        let createAccount = app.segmentedControls.buttons["Create Account"]
        createAccount.tap()
        XCTAssertTrue(createAccount.isSelected)
        XCTAssertTrue(app.staticTexts["Create your account to save and sync your training."].exists)
        XCTAssertFalse(app.buttons["Forgot password?"].exists)

        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("short")
        XCTAssertTrue(submit.isEnabled)
        let passwordDoneKey = app.keyboards.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "done")
        ).firstMatch
        XCTAssertTrue(passwordDoneKey.waitForExistence(timeout: 5))
        XCTAssertTrue(passwordDoneKey.isHittable, "The password field should expose a reachable Done key.")
        passwordDoneKey.tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertEqual(submit.label, "Create Account")
        XCTAssertTrue(submit.isHittable)
        submit.tap()
        XCTAssertTrue(app.descendants(matching: .any)["New passwords must contain at least 10 characters."].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Sign In"].tap()
        XCTAssertFalse(app.staticTexts["New passwords must contain at least 10 characters."].exists)
        XCTAssertTrue(app.buttons["Forgot password?"].exists)
    }

    func testEmailConfirmationResendErrorAndSignInErrorRemainVisible() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingAuthentication", "-uiTestingEmailConfirmation"]
        app.launch()

        let createAccount = app.segmentedControls.buttons["Create Account"]
        XCTAssertTrue(createAccount.waitForExistence(timeout: 8))
        createAccount.tap()

        let emailValue = "new-lifter@example.test"
        let email = app.textFields["Email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText(emailValue)

        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("valid-testing-password")
        let doneKey = app.keyboards.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "done")
        ).firstMatch
        XCTAssertTrue(doneKey.waitForExistence(timeout: 5))
        XCTAssertTrue(doneKey.isHittable)
        doneKey.tap()

        let submit = app.buttons["authentication.email.submit"]
        XCTAssertEqual(submit.label, "Create Account")
        submit.tap()

        let notice = app.descendants(matching: .any)["authentication.confirmation.notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Confirm your email"].exists)
        XCTAssertTrue(app.staticTexts[emailValue].exists)
        XCTAssertTrue(app.staticTexts["Open the link in your email to continue. Sign in if prompted. Check spam if the email does not arrive."].exists)

        let resend = app.buttons["authentication.confirmation.resend"]
        XCTAssertTrue(resend.isEnabled)
        resend.tap()
        let resendError = "Confirmation could not be sent. Try again."
        XCTAssertTrue(app.staticTexts[resendError].waitForExistence(timeout: 5))
        XCTAssertTrue(notice.exists, "A resend error should not hide the confirmation notice.")

        XCTAssertTrue(resend.isEnabled)
        resend.tap()
        let resendSuccess = "A new confirmation email is on the way."
        XCTAssertTrue(app.staticTexts[resendSuccess].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[resendError].waitForNonExistence(timeout: 5))

        password.tap()
        password.typeText("wrong-testing-password")
        let signInDoneKey = app.keyboards.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "done")
        ).firstMatch
        XCTAssertTrue(signInDoneKey.waitForExistence(timeout: 5))
        signInDoneKey.tap()
        XCTAssertEqual(submit.label, "Sign In")
        submit.tap()

        let signInError = "Email or password is incorrect. Check both and try again."
        XCTAssertTrue(app.staticTexts[signInError].waitForExistence(timeout: 5))
        XCTAssertTrue(notice.exists, "A sign-in error should remain visible with the confirmation notice.")

        email.tap()
        email.typeText("x")
        XCTAssertTrue(notice.waitForNonExistence(timeout: 5), "Editing the email should clear the stale confirmation notice.")
        XCTAssertTrue(app.staticTexts[signInError].waitForNonExistence(timeout: 5))
    }

    func testForumFailedPostSubmissionPreservesDraft() {
        let app = launchDemo(arguments: ["-uiTestingForumPublishFailure"])
        let forum = tab("forum", in: app)
        XCTAssertTrue(forum.waitForExistence(timeout: 8))
        forum.tap()
        let forumNavigation = app.navigationBars["Feed"]
        if !forumNavigation.waitForExistence(timeout: 3) { forum.tap() }
        XCTAssertTrue(forumNavigation.waitForExistence(timeout: 5))
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

    func testForumDemoPhotoAndVideoAttachmentsOpenViewer() {
        let app = launchDemo()
        let forum = tab("forum", in: app)
        XCTAssertTrue(forum.waitForExistence(timeout: 8))
        forum.tap()
        let newDiscussion = app.buttons["New discussion"]
        if !newDiscussion.waitForExistence(timeout: 5) { forum.tap() }
        XCTAssertTrue(newDiscussion.waitForExistence(timeout: 8))

        let photoTitle = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Photo test · Lift Rivals")).firstMatch
        XCTAssertTrue(photoTitle.waitForExistence(timeout: 8))
        var photoRevealAttempts = 0
        while photoTitle.frame.maxY > app.frame.maxY - 126 && photoRevealAttempts < 8 {
            app.swipeUp()
            photoRevealAttempts += 1
        }
        XCTAssertLessThanOrEqual(photoTitle.frame.maxY, app.frame.maxY - 126, "Reveal the photo post above the native tab bar.")
        let photoTitleText = app.staticTexts["Photo test · Lift Rivals"]
        XCTAssertTrue(photoTitleText.exists)
        let enabledUpvotePredicate = NSPredicate(format: "label == %@ AND enabled == true", "Upvote discussion")
        let upvote = app.buttons.matching(enabledUpvotePredicate).firstMatch
        var voteRevealAttempts = 0
        while (!upvote.isHittable || upvote.frame.maxY > app.frame.maxY - 126) && voteRevealAttempts < 8 {
            app.swipeUp()
            voteRevealAttempts += 1
        }
        XCTAssertTrue(upvote.waitForExistence(timeout: 5))
        XCTAssertTrue(upvote.isHittable)
        XCTAssertLessThanOrEqual(upvote.frame.maxY, app.frame.maxY - 126, "Keep the feed vote control above the tab bar.")
        upvote.tap()
        let removeUpvote = app.buttons["Remove upvote"].firstMatch
        XCTAssertTrue(removeUpvote.waitForExistence(timeout: 5))
        XCTAssertTrue(removeUpvote.isSelected)
        let enabledDownvotePredicate = NSPredicate(format: "label == %@ AND enabled == true", "Downvote discussion")
        let downvote = app.buttons.matching(enabledDownvotePredicate).firstMatch
        XCTAssertTrue(downvote.isHittable)
        downvote.tap()
        let removeDownvote = app.buttons["Remove downvote"].firstMatch
        XCTAssertTrue(removeDownvote.waitForExistence(timeout: 5))
        XCTAssertTrue(removeDownvote.isSelected)
        removeDownvote.tap()
        XCTAssertTrue(app.buttons["Upvote discussion"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Remove upvote"].firstMatch.exists)
        XCTAssertTrue(forum.isSelected)
        XCTAssertTrue(photoTitleText.exists, "Voting should keep the user on the feed card.")

        let feedPhoto = app.buttons["Open photo"].firstMatch
        for _ in 0..<8 where !feedPhoto.isHittable { app.swipeDown() }
        XCTAssertTrue(feedPhoto.waitForExistence(timeout: 8))
        for _ in 0..<20 where !feedPhoto.isEnabled { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        XCTAssertTrue(feedPhoto.isEnabled)
        feedPhoto.tap()
        XCTAssertTrue(app.navigationBars["Photo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["Discussion photo"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(feedPhoto.waitForExistence(timeout: 5), "Closing the feed preview should return to the feed.")
        for _ in 0..<8 where !photoTitleText.isHittable { app.swipeDown() }
        XCTAssertTrue(photoTitleText.isHittable)
        photoTitleText.tap()
        let discussionNavigation = app.navigationBars["Strength Training"]
        XCTAssertTrue(discussionNavigation.waitForExistence(timeout: 5), "The discussion title follows its community name.")
        let openPhoto = app.buttons["Open photo"]
        XCTAssertTrue(openPhoto.waitForExistence(timeout: 8))
        for _ in 0..<20 where !openPhoto.isEnabled { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        XCTAssertTrue(openPhoto.isEnabled)
        openPhoto.tap()
        XCTAssertTrue(app.navigationBars["Photo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["Discussion photo"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(openPhoto.waitForExistence(timeout: 5), "Closing the viewer should return to the thread with its attachment.")
        let mediaReturnScreenshot = XCTAttachment(screenshot: app.screenshot())
        mediaReturnScreenshot.name = "Forum photo thread after viewer return"
        mediaReturnScreenshot.lifetime = .keepAlways
        add(mediaReturnScreenshot)
        discussionNavigation.buttons.firstMatch.tap()
        let videoTitle = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Video test · App recording")).firstMatch
        var videoRevealAttempts = 0
        while videoTitle.frame.maxY > app.frame.maxY - 126 && videoRevealAttempts < 8 {
            app.swipeUp()
            videoRevealAttempts += 1
        }
        XCTAssertLessThanOrEqual(videoTitle.frame.maxY, app.frame.maxY - 126, "Reveal the video post above the native tab bar.")
        let videoTitleText = app.staticTexts["Video test · App recording"]
        XCTAssertTrue(videoTitleText.exists)
        videoTitleText.tap()
        let playVideo = app.buttons["Play video"]
        XCTAssertTrue(playVideo.waitForExistence(timeout: 8))
        for _ in 0..<20 where !playVideo.isEnabled { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        XCTAssertTrue(playVideo.isEnabled)
        playVideo.tap()
        XCTAssertTrue(app.navigationBars["Video"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["forum.media.player"].waitForExistence(timeout: 8))
    }

    func testForumAuthorsCanEditAndDeleteTheirContent() {
        let app = launchDemo(arguments: ["-uiTestingEditableForumThread"])
        let forum = tab("forum", in: app)
        XCTAssertTrue(forum.waitForExistence(timeout: 8))
        forum.tap()
        let newDiscussion = app.buttons["New discussion"]
        if !newDiscussion.waitForExistence(timeout: 5) { forum.tap() }
        XCTAssertTrue(newDiscussion.waitForExistence(timeout: 8))

        let title = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Editable UI test discussion")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        let commentsLink = app.buttons["forum.post.comments.00000000-0000-0000-0000-000000000211"]
        for _ in 0..<6 where !commentsLink.isHittable { app.swipeUp() }
        XCTAssertTrue(commentsLink.isHittable)
        commentsLink.tap()
        XCTAssertTrue(app.navigationBars["Strength Training"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Editable UI test comment"].waitForExistence(timeout: 5))
        let commentsDeepLinkScreenshot = XCTAttachment(screenshot: app.screenshot())
        commentsDeepLinkScreenshot.name = "Forum feed comments link opens the discussion thread"
        commentsDeepLinkScreenshot.lifetime = .keepAlways
        add(commentsDeepLinkScreenshot)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(newDiscussion.waitForExistence(timeout: 5))
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()

        let discussionActions = app.buttons["forum.discussion.actions"]
        if !discussionActions.waitForExistence(timeout: 4) { title.tap() }
        XCTAssertTrue(discussionActions.waitForExistence(timeout: 5))
        let reply = app.descendants(matching: .any)["forum.reply.body"]
        for _ in 0..<8 where !reply.isHittable { app.swipeUp() }
        XCTAssertTrue(reply.isHittable)
        XCTAssertLessThanOrEqual(reply.frame.maxY, forum.frame.minY, "The initial reply editor should be above the native tab bar.")
        let initialReplyScreenshot = XCTAttachment(screenshot: app.screenshot())
        initialReplyScreenshot.name = "Forum initial reply editor above tabs"
        initialReplyScreenshot.lifetime = .keepAlways
        add(initialReplyScreenshot)
        let collapseComment = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Collapse comment by")
        ).firstMatch
        for _ in 0..<6 where !collapseComment.isHittable { app.swipeUp() }
        XCTAssertTrue(collapseComment.waitForExistence(timeout: 5))
        XCTAssertTrue(collapseComment.isHittable)
        collapseComment.tap()
        XCTAssertTrue(app.staticTexts["Comment collapsed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Editable UI test comment"].exists)
        let expandComment = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Expand comment by")
        ).firstMatch
        XCTAssertTrue(expandComment.waitForExistence(timeout: 5))
        expandComment.tap()
        XCTAssertTrue(app.staticTexts["Editable UI test comment"].waitForExistence(timeout: 5))
        for _ in 0..<6 where !discussionActions.isHittable { app.swipeDown() }
        XCTAssertTrue(discussionActions.isHittable)
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
        for _ in 0..<8 where !reply.isHittable { app.swipeUp() }
        XCTAssertTrue(reply.isHittable)
        XCTAssertLessThanOrEqual(reply.frame.maxY, forum.frame.minY, "The reply editor should remain above the native tab bar after editing.")
        let editedReplyScreenshot = XCTAttachment(screenshot: app.screenshot())
        editedReplyScreenshot.name = "Forum reply editor after returning from edit"
        editedReplyScreenshot.lifetime = .keepAlways
        add(editedReplyScreenshot)

        for _ in 0..<6 where !commentActions.isHittable { app.swipeDown() }
        XCTAssertTrue(commentActions.isHittable)
        commentActions.tap()
        app.buttons["forum.comment.delete"].firstMatch.tap()
        app.buttons["forum.comment.delete.confirm"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["0 comments"].waitForExistence(timeout: 5))

        for _ in 0..<8 where !reply.isHittable { app.swipeUp() }
        XCTAssertTrue(reply.isHittable, "The reply editor should be reachable above the native tab bar.")
        XCTAssertLessThanOrEqual(reply.frame.maxY, forum.frame.minY)
        reply.tap()
        XCTAssertTrue(app.buttons["forum.reply.submit"].waitForExistence(timeout: 5))
        let replyKeyboardScreenshot = XCTAttachment(screenshot: app.screenshot())
        replyKeyboardScreenshot.name = "Forum reply editor focused"
        replyKeyboardScreenshot.lifetime = .keepAlways
        add(replyKeyboardScreenshot)
        reply.typeText("Keep my reply draft if posting fails.")
        app.buttons["forum.reply.submit"].tap()
        XCTAssertTrue(app.staticTexts["Commenting is unavailable in the simulator demo."].waitForExistence(timeout: 5))
        XCTAssertEqual(reply.value as? String, "Keep my reply draft if posting fails.")

        discussionActions.tap()
        app.buttons["forum.discussion.delete"].firstMatch.tap()
        app.buttons["forum.discussion.delete.confirm"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Editable UI test discussion")).firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Updated UI test discussion"].waitForNonExistence(timeout: 5))
    }

}
