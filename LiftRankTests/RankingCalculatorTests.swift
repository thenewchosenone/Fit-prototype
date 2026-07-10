import XCTest
@testable import LiftRank

final class RankingCalculatorTests: XCTestCase {
    func testLeaderboardMovementPresentation() {
        XCTAssertEqual(LeaderboardMovementPresentation(4), .up(4))
        XCTAssertEqual(LeaderboardMovementPresentation(-3), .down(3))
        XCTAssertEqual(LeaderboardMovementPresentation(0), .unchanged)
    }

    func testEpleyOneRepMaxCalculation() {
        XCTAssertEqual(RankingCalculator.epleyOneRepMax(weight: 225, repetitions: 5), 262.5, accuracy: 0.001)
        XCTAssertEqual(RankingCalculator.epleyOneRepMax(weight: 315, repetitions: 1), 315, accuracy: 0.001)
    }

    func testPoundsToKilogramsConversion() {
        XCTAssertEqual(RankingCalculator.poundsToKilograms(220.46226218), 100, accuracy: 0.001)
    }

    func testWeightClassAssignment() {
        let weightClass = RankingCalculator.weightClass(for: 210, sexCategory: .male, classes: MockData.weightClasses)
        XCTAssertEqual(weightClass?.id, "usapl-m-100")
    }

    func testUSAPLWeightClassBoundaries() {
        XCTAssertEqual(RankingCalculator.weightClass(for: RankingCalculator.kilogramsToPounds(44), sexCategory: .female, classes: MockData.weightClasses)?.id, "usapl-f-44")
        XCTAssertEqual(RankingCalculator.weightClass(for: RankingCalculator.kilogramsToPounds(44.01), sexCategory: .female, classes: MockData.weightClasses)?.id, "usapl-f-48")
        XCTAssertEqual(RankingCalculator.weightClass(for: RankingCalculator.kilogramsToPounds(100.01), sexCategory: .female, classes: MockData.weightClasses)?.id, "usapl-f-100-plus")
        XCTAssertEqual(RankingCalculator.weightClass(for: RankingCalculator.kilogramsToPounds(52), sexCategory: .male, classes: MockData.weightClasses)?.id, "usapl-m-52")
        XCTAssertEqual(RankingCalculator.weightClass(for: RankingCalculator.kilogramsToPounds(140.01), sexCategory: .male, classes: MockData.weightClasses)?.id, "usapl-m-140-plus")
    }

    func testBodyweightMultiple() {
        XCTAssertEqual(RankingCalculator.bodyweightMultiple(oneRepMax: 495, bodyweight: 210), 2.357, accuracy: 0.001)
    }

    func testPowerliftingTotal() {
        XCTAssertEqual(RankingCalculator.powerliftingTotal(bench: 245, squat: 275, deadlift: 495), 1015)
    }

    func testRelativeTotal() {
        XCTAssertEqual(RankingCalculator.relativeTotal(total: 1015, bodyweight: 210), 4.833, accuracy: 0.001)
    }

    func testProgressPercentage() {
        XCTAssertEqual(RankingCalculator.progressPercentage(currentPersonalRecord: 315, previousPersonalRecord: 300), 5, accuracy: 0.001)
    }

    func testOverallScore() {
        XCTAssertEqual(RankingCalculator.overallScore(relativeStrength: 80, absoluteStrength: 70, recentProgress: 50), 71, accuracy: 0.001)
    }

    func testLeaderboardOrdering() {
        let seeded = MockData.community()
        let entries = RankingCalculator.leaderboardEntries(
            profiles: seeded.profiles,
            lifts: seeded.lifts.filter { $0.exerciseID == "deadlift" },
            rankingType: .absolute,
            verifiedOnly: true,
            currentUserID: MockData.demoUserID
        )
        XCTAssertGreaterThan(entries.count, 5)
        XCTAssertTrue(entries[0].score >= entries[1].score)
        XCTAssertTrue(entries.contains { $0.profile.id == MockData.demoUserID })
    }

    @MainActor
    func testLeaderboardUsesDailySnapshot() {
        let appState = AppState()
        appState.verifiedOnly = false
        appState.leaderboardFilters = LeaderboardFilters(exerciseID: "deadlift")
        appState.leaderboardFilters.rankingType = .absolute

        let referenceDate = Date(timeIntervalSince1970: 1_782_374_400)
        let snapshotDate = appState.leaderboardSnapshotDate(referenceDate: referenceDate)
        var pendingLift = makeLift(userID: appState.currentProfile.id, weight: 2_000)
        pendingLift.createdAt = snapshotDate.addingTimeInterval(60)
        pendingLift.performedAt = pendingLift.createdAt
        appState.repository.lifts.append(pendingLift)

        let currentSnapshot = appState.leaderboardEntries(referenceDate: referenceDate)
        XCTAssertFalse(currentSnapshot.contains { $0.lift.id == pendingLift.id })

        let nextDay = appState.nextLeaderboardUpdateDate(referenceDate: referenceDate).addingTimeInterval(60)
        let refreshedSnapshot = appState.leaderboardEntries(referenceDate: nextDay)
        XCTAssertTrue(refreshedSnapshot.contains { $0.lift.id == pendingLift.id })
        XCTAssertEqual(refreshedSnapshot.first?.lift.id, pendingLift.id)
    }

    @MainActor
    func testRankingNotificationOpensCurrentUsersGymLeaderboard() {
        let appState = AppState()
        guard let notification = appState.notifications.first(where: {
            $0.kind.localizedCaseInsensitiveContains("ranking")
        }) else {
            XCTFail("Expected a ranking notification")
            return
        }

        appState.openNotification(notification)

        XCTAssertEqual(appState.selectedTab, 1)
        XCTAssertEqual(appState.leaderboardFilters.exerciseID, "deadlift")
        XCTAssertEqual(appState.leaderboardFilters.gymID, appState.currentProfile.primaryGymID)
        XCTAssertEqual(appState.leaderboardFilters.rankingType, .absolute)
        XCTAssertTrue(appState.verifiedOnly)
        XCTAssertNotNil(appState.leaderboardFocusRequestID)
        XCTAssertTrue(appState.notifications.first(where: { $0.id == notification.id })?.isRead == true)
    }

    @MainActor
    func testOtherNotificationTypesOpenRelevantDestinations() {
        let appState = AppState()

        let liftNotification = NotificationItem(
            id: UUID(),
            title: "Lift approved",
            message: "Your lift was approved.",
            kind: "Lift approved",
            createdAt: .now,
            isRead: false
        )
        appState.repository.notifications.append(liftNotification)
        appState.openNotification(liftNotification)
        XCTAssertEqual(appState.selectedTab, 4)

        let friendNotification = NotificationItem(
            id: UUID(),
            title: "Friend request",
            message: "You have a friend request.",
            kind: "Friend request",
            createdAt: .now,
            isRead: false
        )
        appState.repository.notifications.append(friendNotification)
        appState.openNotification(friendNotification)
        XCTAssertEqual(appState.selectedTab, 3)
        XCTAssertEqual(appState.selectedCommunitySegment, "Messages")

        let gymNotification = NotificationItem(
            id: UUID(),
            title: "Gym request submitted",
            message: "Your gym is available.",
            kind: "Gym request",
            createdAt: .now,
            isRead: false
        )
        appState.repository.notifications.append(gymNotification)
        appState.openNotification(gymNotification)
        XCTAssertEqual(appState.selectedTab, 3)
        XCTAssertEqual(appState.selectedCommunitySegment, "Gyms")
    }

    @MainActor
    func testWorkoutStreakUsesCompletedWorkoutDates() {
        let appState = AppState()
        guard let prescriptionID = appState.workoutPrescriptions.first?.id else {
            XCTFail("Expected a seeded workout prescription")
            return
        }

        let calendar = Calendar.current
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12))!
        XCTAssertEqual(appState.workoutStreak(referenceDate: referenceDate), 0)

        for daysAgo in 0...2 {
            let performedAt = calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
            appState.repository.workoutSetLogs.append(
                WorkoutSetLog(
                    id: UUID(),
                    prescriptionID: prescriptionID,
                    performedAt: performedAt,
                    setNumber: daysAgo + 1,
                    weight: 225,
                    reps: 5,
                    rpe: 8,
                    isWarmup: false,
                    isComplete: true
                )
            )
        }

        XCTAssertEqual(appState.workoutStreak(referenceDate: referenceDate), 3)
    }

    @MainActor
    func testWorkoutStreakRemainsActiveWhenLastWorkoutWasYesterday() {
        let appState = AppState()
        guard let prescriptionID = appState.workoutPrescriptions.first?.id else {
            XCTFail("Expected a seeded workout prescription")
            return
        }

        let calendar = Calendar.current
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12))!
        for daysAgo in 1...2 {
            appState.repository.workoutSetLogs.append(
                WorkoutSetLog(
                    id: UUID(),
                    prescriptionID: prescriptionID,
                    performedAt: calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate)!,
                    setNumber: daysAgo,
                    weight: 225,
                    reps: 5,
                    rpe: 8,
                    isWarmup: false,
                    isComplete: true
                )
            )
        }

        XCTAssertEqual(appState.workoutStreak(referenceDate: referenceDate), 2)
    }

    @MainActor
    func testWorkoutFeedbackIsSavedAndReplacesSameDayEntry() {
        let appState = AppState()
        guard let session = appState.workoutSessions.first else {
            XCTFail("Expected a seeded workout session")
            return
        }

        appState.completeWorkout(session, effort: 4, notes: "Strong session")
        appState.completeWorkout(session, effort: 5, notes: "Updated note")

        let feedback = appState.workoutFeedback.filter { $0.sessionID == session.id }
        XCTAssertEqual(feedback.count, 1)
        XCTAssertEqual(feedback.first?.effort, 5)
        XCTAssertEqual(feedback.first?.notes, "Updated note")
    }

    @MainActor
    func testGymMembershipIsLimitedToThreeGyms() {
        let appState = AppState()
        let secondaryGyms = appState.gyms.filter { $0.id != appState.currentProfile.primaryGymID }

        XCTAssertEqual(appState.joinedGymCount, 1)
        XCTAssertTrue(appState.joinGym(secondaryGyms[0]))
        XCTAssertTrue(appState.joinGym(secondaryGyms[1]))
        XCTAssertEqual(appState.joinedGymCount, 3)
        XCTAssertFalse(appState.joinGym(secondaryGyms[2]))
        XCTAssertEqual(appState.joinedGymCount, 3)
    }

    @MainActor
    func testLeavingSecondaryGymAllowsJoiningAnother() {
        let appState = AppState()
        let secondaryGyms = appState.gyms.filter { $0.id != appState.currentProfile.primaryGymID }

        XCTAssertTrue(appState.joinGym(secondaryGyms[0]))
        XCTAssertTrue(appState.joinGym(secondaryGyms[1]))
        appState.leaveGym(secondaryGyms[0])

        XCTAssertEqual(appState.joinedGymCount, 2)
        XCTAssertTrue(appState.joinGym(secondaryGyms[2]))
        XCTAssertEqual(appState.joinedGymCount, 3)
    }

    @MainActor
    func testPrimaryGymCannotBeLeft() {
        let appState = AppState()
        guard let primaryGym = appState.gyms.first(where: { $0.id == appState.currentProfile.primaryGymID }) else {
            XCTFail("Expected primary gym")
            return
        }

        appState.leaveGym(primaryGym)

        XCTAssertTrue(appState.isGymJoined(primaryGym))
        XCTAssertEqual(appState.joinedGymCount, 1)
    }

    @MainActor
    func testLiftCannotBeSubmittedForUnjoinedGym() async {
        let appState = AppState()
        guard let unjoinedGym = appState.gyms.first(where: { !appState.isGymJoined($0) }) else {
            XCTFail("Expected an unjoined gym")
            return
        }

        await appState.submitLift(
            exercise: MockData.exercises[2],
            weight: 315,
            unit: .pounds,
            reps: 1,
            isActual: true,
            bodyweight: 210,
            date: .now,
            gymID: unjoinedGym.id,
            equipment: .raw,
            visibility: .publicLift,
            videoURL: nil,
            caption: "",
            requestVerification: false
        )

        XCTAssertNil(appState.lastSubmissionResult)
        XCTAssertFalse(appState.currentUserLifts.contains { $0.gymID == unjoinedGym.id })
    }

    @MainActor
    func testLeaderboardFiltersByRankingCardScopes() {
        let appState = AppState()
        appState.verifiedOnly = false

        var gymFilters = LeaderboardFilters(exerciseID: "deadlift")
        gymFilters.gymID = appState.currentProfile.primaryGymID
        appState.leaderboardFilters = gymFilters
        let gymEntries = appState.leaderboardEntries()
        XCTAssertFalse(gymEntries.isEmpty)
        XCTAssertTrue(gymEntries.allSatisfy { $0.lift.gymID == appState.currentProfile.primaryGymID })

        var cityFilters = LeaderboardFilters(exerciseID: "deadlift")
        cityFilters.city = appState.currentProfile.city
        cityFilters.state = appState.currentProfile.state
        appState.leaderboardFilters = cityFilters
        let cityEntries = appState.leaderboardEntries()
        XCTAssertFalse(cityEntries.isEmpty)
        XCTAssertTrue(cityEntries.allSatisfy { $0.profile.city == appState.currentProfile.city && $0.profile.state == appState.currentProfile.state })

        var weightClassFilters = LeaderboardFilters(exerciseID: nil)
        weightClassFilters.sexCategory = appState.currentProfile.sexCategory
        weightClassFilters.weightClassID = RankingCalculator.weightClass(
            for: appState.currentProfile.bodyweightPounds,
            sexCategory: appState.currentProfile.sexCategory,
            classes: MockData.weightClasses
        )?.id
        appState.leaderboardFilters = weightClassFilters
        let weightClassEntries = appState.leaderboardEntries()
        XCTAssertFalse(weightClassEntries.isEmpty)
        XCTAssertTrue(weightClassEntries.allSatisfy { entry in
            RankingCalculator.weightClass(
                for: entry.lift.bodyweightAtLift,
                sexCategory: entry.profile.sexCategory,
                classes: MockData.weightClasses
            )?.id == weightClassFilters.weightClassID
        })
    }

    func testTieHandlingUsesSameDisplayedRank() {
        let profileA = MockData.demoProfile
        var profileB = MockData.demoProfile
        profileB.id = UUID()
        profileB.username = "tie"
        let liftA = makeLift(userID: profileA.id, weight: 300)
        let liftB = makeLift(userID: profileB.id, weight: 300)
        let entries = RankingCalculator.leaderboardEntries(
            profiles: [profileA, profileB],
            lifts: [liftA, liftB],
            rankingType: .absolute,
            verifiedOnly: true,
            currentUserID: nil
        )
        XCTAssertEqual(entries.map(\.rank), [1, 1])
    }

    func testBestLiftSelection() {
        let lower = makeLift(userID: MockData.demoUserID, weight: 225)
        let higher = makeLift(userID: MockData.demoUserID, weight: 315)
        XCTAssertEqual(RankingCalculator.bestLift(exerciseID: "deadlift", submissions: [lower, higher])?.estimatedOneRepMax, 315)
    }

    func testWorkoutVolumeAndEstimatedMax() {
        let entry = WorkoutExerciseEntry(
            id: UUID(),
            planID: MockData.defaultWorkoutPlanID,
            week: 1,
            date: .now,
            day: "Monday",
            workout: "Push + Quads",
            exercise: "Incline DB Press",
            muscleGroup: "Upper Chest",
            targetSets: 3,
            targetReps: "8-10",
            sets: [
                WorkoutSetEntry(id: UUID(), weight: 100, reps: 10, rpe: 7),
                WorkoutSetEntry(id: UUID(), weight: 120, reps: 8, rpe: 9)
            ],
            isDone: true,
            notes: ""
        )
        XCTAssertEqual(entry.volume, 1960)
        XCTAssertEqual(entry.estimatedMax, 152, accuracy: 0.001)
    }

    func testTrainingExerciseLibraryHasBodyPartCoverage() {
        let library = MockData.trainingExerciseLibrary
        let bodyParts = Set(library.map(\.bodyPart))

        XCTAssertGreaterThanOrEqual(library.count, 30)
        XCTAssertTrue(bodyParts.contains("Chest"))
        XCTAssertTrue(bodyParts.contains("Back"))
        XCTAssertTrue(bodyParts.contains("Quads"))
        XCTAssertTrue(bodyParts.contains("Hamstrings"))
        XCTAssertTrue(bodyParts.contains("Glutes"))
        XCTAssertTrue(bodyParts.contains("Shoulders"))
        XCTAssertTrue(bodyParts.contains("Core"))
        XCTAssertTrue(library.allSatisfy { !$0.defaultReps.isEmpty && $0.defaultSets > 0 })
    }

    func testTrainingExerciseLibraryHasEquipmentCoverage() {
        let equipment = Set(MockData.trainingExerciseLibrary.map(\.equipment))

        XCTAssertTrue(equipment.contains("Barbell"))
        XCTAssertTrue(equipment.contains("Dumbbell"))
        XCTAssertTrue(equipment.contains("Cable"))
        XCTAssertTrue(equipment.contains("Machine"))
        XCTAssertTrue(equipment.contains("Bodyweight"))
    }

    func testEquipmentExerciseExpansionContainsGenericMachineAdditions() {
        let expansion = PopularExerciseCatalog.exercises
        let counts = Dictionary(grouping: expansion, by: \.equipment).mapValues(\.count)

        XCTAssertEqual(expansion.count, 166)
        XCTAssertEqual(counts["Machine"], 66)
        XCTAssertEqual(counts["Cable"], 50)
        XCTAssertEqual(counts["Dumbbell"], 50)
        XCTAssertEqual(Set(expansion.map(\.id)).count, expansion.count)
        XCTAssertEqual(Set(expansion.map { $0.name.lowercased() }).count, expansion.count)
        XCTAssertTrue(expansion.allSatisfy {
            !$0.name.isEmpty &&
            !$0.bodyPart.isEmpty &&
            !$0.workoutCategory.isEmpty &&
            $0.defaultSets > 0 &&
            !$0.defaultReps.isEmpty &&
            $0.defaultRestSeconds > 0
        })
    }

    func testCombinedTrainingLibraryHasUniqueIdentifiers() {
        let library = MockData.trainingExerciseLibrary
        XCTAssertEqual(Set(library.map(\.id)).count, library.count)
        XCTAssertEqual(Set(library.map { $0.name.lowercased() }).count, library.count)
    }

    func testBrandAliasesResolveToSingleGenericExercise() {
        let library = MockData.trainingExerciseLibrary
        let dyRowMatches = library.filter { $0.matchesSearch("Hammer Strength D.Y. Row") }
        let superInclineMatches = library.filter { $0.matchesSearch("Hammer Super Incline") }
        let wideChestMatches = library.filter { $0.matchesSearch("Hammer Wide Chest") }

        XCTAssertEqual(dyRowMatches.map(\.id), ["machine_iso_lateral_underhand_row"])
        XCTAssertEqual(superInclineMatches.map(\.id), ["machine_high_incline_chest_press"])
        XCTAssertEqual(wideChestMatches.map(\.id), ["machine_wide_grip_chest_press"])
        XCTAssertFalse(library.contains { $0.name.localizedCaseInsensitiveContains("Hammer Strength") })
    }

    func testAllPlannedGenericMachineMovementsArePresent() {
        let expectedIDs: Set<String> = [
            "machine_iso_lateral_underhand_row",
            "machine_plate_loaded_horizontal_bench_press",
            "machine_high_incline_chest_press",
            "machine_wide_grip_chest_press",
            "machine_front_lat_pulldown",
            "machine_plate_loaded_pec_fly",
            "machine_shrug",
            "machine_grip",
            "machine_neck_flexion",
            "machine_neck_extension",
            "machine_lateral_neck_flexion",
            "machine_linear_45_leg_press",
            "machine_iso_lateral_leg_press",
            "machine_iso_lateral_leg_curl",
            "machine_ground_base_squat",
            "machine_ground_base_rotational_twist"
        ]
        let libraryIDs = Set(MockData.trainingExerciseLibrary.map(\.id))
        XCTAssertTrue(expectedIDs.isSubset(of: libraryIDs))
    }

    func testWorkoutSetKeyboardNavigationMovesDownColumns() {
        let first = makeSetLog(setNumber: 1)
        let second = makeSetLog(setNumber: 2)
        let third = makeSetLog(setNumber: 3)
        let logs = [second, third, first]

        let focuses = WorkoutSetInputNavigator.orderedFocuses(for: logs)

        XCTAssertEqual(focuses, [
            WorkoutSetInputFocus(logID: first.id, field: .reps),
            WorkoutSetInputFocus(logID: second.id, field: .reps),
            WorkoutSetInputFocus(logID: third.id, field: .reps),
            WorkoutSetInputFocus(logID: first.id, field: .weight),
            WorkoutSetInputFocus(logID: second.id, field: .weight),
            WorkoutSetInputFocus(logID: third.id, field: .weight)
        ])
        XCTAssertEqual(
            WorkoutSetInputNavigator.next(after: focuses[2], in: logs),
            WorkoutSetInputFocus(logID: first.id, field: .weight)
        )
        XCTAssertNil(WorkoutSetInputNavigator.next(after: focuses[5], in: logs))
    }

    func testCompositeBodyPartsResolveToMultipleHighlightedRegions() {
        XCTAssertEqual(
            Set(ExerciseBodyRegionResolver.regions(for: "Chest/Triceps")),
            Set([.chest, .arms])
        )
        XCTAssertEqual(
            Set(ExerciseBodyRegionResolver.regions(for: "Quads/Glutes")),
            Set([.upperLegs, .glutes])
        )
        XCTAssertEqual(
            Set(ExerciseBodyRegionResolver.regions(for: "Back/Core")),
            Set([.back, .core])
        )
    }

    func testEveryCatalogExerciseHasSpecificBodyRegionArtwork() {
        let unexpectedFallbacks = MockData.trainingExerciseLibrary.filter { exercise in
            ExerciseBodyRegionResolver.regions(for: exercise.bodyPart) == [.fullBody] &&
                !exercise.bodyPart.localizedCaseInsensitiveContains("full body")
        }
        XCTAssertTrue(unexpectedFallbacks.isEmpty, "Missing body-region mapping for: \(unexpectedFallbacks.map(\.bodyPart))")
    }

    @MainActor
    func testChallengeJoinAndLeaveUpdatesMembershipState() {
        let repository = DemoRepository()
        guard let challenge = repository.challenges.first(where: { !$0.isJoined }) else {
            XCTFail("Expected an unjoined challenge")
            return
        }
        let participantCount = challenge.participantCount

        repository.setChallengeJoined(challenge, joined: true)
        let joined = repository.challenges.first { $0.id == challenge.id }
        XCTAssertEqual(joined?.isJoined, true)
        XCTAssertEqual(joined?.participantCount, participantCount + 1)

        repository.setChallengeJoined(challenge, joined: false)
        let left = repository.challenges.first { $0.id == challenge.id }
        XCTAssertEqual(left?.isJoined, false)
        XCTAssertEqual(left?.participantCount, participantCount)
    }

    @MainActor
    func testGymRequestAddsVisibleGymAndRequestRecord() {
        let repository = DemoRepository()
        let request = GymRequest(
            id: UUID(),
            name: "Crunch Fitness - Test Club",
            city: "Miami",
            state: "Florida",
            requestedBy: MockData.demoUserID,
            note: "Prototype request",
            createdAt: .now
        )

        repository.requestGym(request)

        XCTAssertEqual(repository.gymRequests.first?.name, request.name)
        XCTAssertEqual(repository.gyms.first?.name, request.name)
        XCTAssertTrue(repository.communityThreads.contains { $0.kind == .gym && $0.gymID == repository.gyms.first?.id })
    }

    @MainActor
    func testUserCanAddWorkoutEntry() {
        let repository = DemoRepository()
        let initialCount = repository.workoutEntries.count
        let entry = WorkoutExerciseEntry(
            id: UUID(),
            planID: MockData.defaultWorkoutPlanID,
            week: 1,
            date: .now,
            day: "Friday",
            workout: "Freestyle Workout",
            exercise: "Cable row",
            muscleGroup: "Back",
            targetSets: 3,
            targetReps: "10-12",
            sets: [WorkoutSetEntry(id: UUID(), weight: 120, reps: 12, rpe: 8)],
            isDone: true,
            notes: "Added by user"
        )

        repository.addWorkoutEntry(entry)

        XCTAssertEqual(repository.workoutEntries.count, initialCount + 1)
        XCTAssertEqual(repository.workoutEntries.first?.exercise, "Cable row")
        XCTAssertTrue(repository.workoutEntries.first?.isDone == true)
    }

    @MainActor
    func testDeletingWorkoutPlanRemovesOnlyThatPlansEntries() {
        let repository = DemoRepository()
        let plan = WorkoutPlan(id: UUID(), name: "Test Plan", createdAt: .now)
        let entry = WorkoutExerciseEntry(
            id: UUID(),
            planID: plan.id,
            week: 1,
            date: .now,
            day: "Friday",
            workout: "Pull",
            exercise: "Cable row",
            muscleGroup: "Back",
            targetSets: 3,
            targetReps: "10-12",
            sets: [],
            isDone: false,
            notes: ""
        )

        repository.addWorkoutPlan(plan)
        repository.addWorkoutEntry(entry)

        XCTAssertTrue(repository.workoutPlans.contains { $0.id == plan.id })
        XCTAssertTrue(repository.workoutEntries.contains { $0.planID == plan.id })

        repository.deleteWorkoutPlan(plan)

        XCTAssertFalse(repository.workoutPlans.contains { $0.id == plan.id })
        XCTAssertFalse(repository.workoutEntries.contains { $0.planID == plan.id })
        XCTAssertTrue(repository.workoutEntries.contains { $0.planID == MockData.defaultWorkoutPlanID })
    }

    func testChallengeThreadsAreNotSeededWhileChallengesAreDisabled() {
        let challenges = MockData.challenges
        let challengeThreads = MockData.communityThreads(for: challenges).filter { $0.kind == .challenge }

        XCTAssertTrue(challengeThreads.isEmpty)
    }

    @MainActor
    func testFriendRequestCanBeSentAndAccepted() {
        let repository = DemoRepository()
        guard let profile = repository.profiles.first(where: { profile in
            profile.id != repository.currentProfile.id &&
            !repository.friendRequests.contains { request in
                (request.fromUserID == repository.currentProfile.id && request.toUserID == profile.id) ||
                (request.fromUserID == profile.id && request.toUserID == repository.currentProfile.id)
            }
        }) else {
            XCTFail("Expected a profile without a request")
            return
        }

        repository.sendFriendRequest(to: profile)

        guard let request = repository.friendRequests.first(where: { $0.fromUserID == repository.currentProfile.id && $0.toUserID == profile.id }) else {
            XCTFail("Expected sent friend request")
            return
        }
        XCTAssertEqual(request.status, .pending)

        repository.respondToFriendRequest(request, status: .accepted)

        XCTAssertEqual(repository.friendRequests.first { $0.id == request.id }?.status, .accepted)
        XCTAssertNotNil(repository.friendRequests.first { $0.id == request.id }?.respondedAt)
    }

    @MainActor
    func testPendingSentFriendRequestCanBeCanceled() {
        let repository = DemoRepository()
        guard let request = repository.friendRequests.first(where: { $0.fromUserID == repository.currentProfile.id && $0.status == .pending }) else {
            XCTFail("Expected seeded outgoing friend request")
            return
        }

        repository.cancelFriendRequest(request)

        XCTAssertFalse(repository.friendRequests.contains { $0.id == request.id })
    }

    func testRelativeTimeFormatterDoesNotShowSeconds() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(LiftTimeFormatter.relativeNoSeconds(from: now.addingTimeInterval(-20), now: now), "Just now")
        XCTAssertEqual(LiftTimeFormatter.relativeNoSeconds(from: now.addingTimeInterval(-90), now: now), "1 min ago")
        XCTAssertFalse(LiftTimeFormatter.relativeNoSeconds(from: now.addingTimeInterval(-20), now: now).contains("sec"))
    }

    @MainActor
    func testMessageCanBeSentAndReported() {
        let repository = DemoRepository()
        guard let profile = repository.profiles.first(where: { $0.id != repository.currentProfile.id }) else {
            XCTFail("Expected another profile")
            return
        }
        let thread = repository.messageThread(with: profile)

        repository.addMessage(to: thread, body: "Can you spot bench later?")

        guard let sent = repository.directMessages.last(where: { $0.threadID == thread.id && $0.senderID == repository.currentProfile.id }) else {
            XCTFail("Expected sent message")
            return
        }
        XCTAssertEqual(sent.body, "Can you spot bench later?")

        repository.reportMessage(sent, reason: .spam, note: "Testing report")

        XCTAssertTrue(repository.directMessages.first { $0.id == sent.id }?.isReported == true)
        XCTAssertEqual(repository.messageReports.first?.messageID, sent.id)
        XCTAssertEqual(repository.messageReports.first?.reason, .spam)
    }

    @MainActor
    func testIndividualMessageCanBeDeleted() {
        let appState = AppState()
        guard let thread = appState.messageThreads.first,
              let message = appState.messages(for: thread).first else {
            XCTFail("Expected seeded message")
            return
        }
        let initialCount = appState.messages(for: thread).count

        appState.deleteMessage(message)

        XCTAssertEqual(appState.messages(for: thread).count, initialCount - 1)
        XCTAssertFalse(appState.directMessages.contains { $0.id == message.id })
    }

    @MainActor
    func testConversationDeletionRemovesThreadAndMessages() {
        let appState = AppState()
        guard let thread = appState.messageThreads.first else {
            XCTFail("Expected seeded message thread")
            return
        }

        appState.selectedMessageThread = thread
        appState.deleteMessageThread(thread)

        XCTAssertFalse(appState.messageThreads.contains { $0.id == thread.id })
        XCTAssertFalse(appState.directMessages.contains { $0.threadID == thread.id })
        XCTAssertNil(appState.selectedMessageThread)
    }

    @MainActor
    func testCommunityThreadCanBeLikedAndCommentedOn() {
        let appState = AppState()
        guard let thread = appState.communityThreads.first else {
            XCTFail("Expected seeded thread")
            return
        }

        appState.toggleThreadLike(thread)
        appState.addReply(to: thread, body: "I am in for this lift check.")

        let updatedThread = appState.currentThread(thread)
        XCTAssertTrue(appState.isThreadLiked(updatedThread))
        XCTAssertEqual(updatedThread.likeCount, thread.likeCount + 1)
        XCTAssertEqual(updatedThread.replyCount, thread.replyCount + 1)
        XCTAssertTrue(appState.replies(for: updatedThread).contains { $0.body == "I am in for this lift check." })
    }

    @MainActor
    func testSeededCommunityThreadsHaveVisibleReplies() {
        let appState = AppState()
        guard let thread = appState.communityThreads.first(where: { $0.replyCount > 0 }) else {
            XCTFail("Expected seeded thread with replies")
            return
        }

        XCTAssertFalse(appState.replies(for: thread).isEmpty)
    }

    @MainActor
    func testSeededActivitiesHaveVisibleComments() {
        let appState = AppState()
        guard let activity = appState.activities.first(where: { !appState.comments(for: $0).isEmpty }) else {
            XCTFail("Expected seeded activity comments")
            return
        }

        XCTAssertGreaterThan(appState.comments(for: activity).count, 0)
    }

    @MainActor
    func testActivityCanBeLikedSavedAndCommentedOn() {
        let appState = AppState()
        guard let activity = appState.activities.first else {
            XCTFail("Expected seeded activity")
            return
        }

        appState.toggleActivityLike(activity)
        appState.toggleActivitySave(activity)
        appState.addComment(to: activity, body: "Strong lift.")

        let updatedActivity = appState.currentActivity(activity)
        XCTAssertTrue(updatedActivity.isLiked)
        XCTAssertTrue(updatedActivity.isSaved)
        XCTAssertTrue(appState.comments(for: updatedActivity).contains { $0.body == "Strong lift." })
    }

    @MainActor
    func testProgramBuilderCanCloneAndDeleteWeeks() {
        let repository = DemoRepository()
        guard let originalWeek = repository.workoutWeeks.first(where: { $0.planID == MockData.defaultWorkoutPlanID && $0.weekNumber == 1 }) else {
            XCTFail("Expected seeded week")
            return
        }
        let originalSessionCount = repository.workoutSessions.filter { $0.weekID == originalWeek.id }.count
        let originalPrescriptionCount = repository.workoutPrescriptions.count

        let clonedWeek = repository.cloneWorkoutWeek(originalWeek)

        XCTAssertNotEqual(clonedWeek.id, originalWeek.id)
        XCTAssertEqual(clonedWeek.weekNumber, 3)
        XCTAssertEqual(repository.workoutSessions.filter { $0.weekID == clonedWeek.id }.count, originalSessionCount)
        XCTAssertGreaterThan(repository.workoutPrescriptions.count, originalPrescriptionCount)

        repository.deleteWorkoutWeek(clonedWeek)

        XCTAssertFalse(repository.workoutWeeks.contains { $0.id == clonedWeek.id })
        XCTAssertFalse(repository.workoutSessions.contains { $0.weekID == clonedWeek.id })
    }

    @MainActor
    func testCancelFreestyleWorkoutRemovesSession() {
        let appState = AppState()
        let session = appState.startFreestyleSession()

        appState.cancelWorkout(session)

        XCTAssertFalse(appState.workoutSessions.contains { $0.id == session.id })
        XCTAssertTrue(appState.prescriptions(for: session).isEmpty)
    }

    @MainActor
    func testCancelPlannedWorkoutClearsTodaysSetLogsOnly() {
        let appState = AppState()
        guard let session = appState.workoutSessions.first(where: { $0.name != "Freestyle Workout" }),
              let prescription = appState.prescriptions(for: session).first else {
            XCTFail("Expected seeded planned workout")
            return
        }

        var log = appState.addSetLog(to: prescription)
        log.weight = 225
        log.reps = 5
        log.isComplete = true
        appState.updateSetLog(log)

        appState.cancelWorkout(session)

        XCTAssertTrue(appState.workoutSessions.contains { $0.id == session.id })
        XCTAssertTrue(appState.activeSetLogs(for: prescription).isEmpty)
    }

    @MainActor
    func testCustomExerciseCanBeSavedAndAddedToSession() {
        let appState = AppState()
        guard let week = appState.selectedPlanWeeks.first else {
            XCTFail("Expected selected week")
            return
        }
        let session = appState.addSession(to: week, day: "Friday", name: "Arms")

        guard let exercise = appState.saveCustomExercise(name: "Cable Bayesian Curl", bodyPart: "Arms", equipment: "Cable", trackingType: "Weight + Reps") else {
            XCTFail("Expected custom exercise")
            return
        }
        appState.addExercise(exercise, to: session, sets: 3, reps: "10-15", restSeconds: 90)

        XCTAssertTrue(appState.customTrainingExercises.contains { $0.name == "Cable Bayesian Curl" })
        XCTAssertEqual(exercise.trackingType, "Weight + Reps")
        XCTAssertTrue(appState.prescriptions(for: session).contains { prescription in
            prescription.exerciseName == "Cable Bayesian Curl" &&
            prescription.sets == 3 &&
            prescription.reps == "10-15" &&
            prescription.restSeconds == 90
        })
    }

    @MainActor
    func testWorkoutSummaryUsesCompletedSetLogs() {
        let appState = AppState()
        guard let week = appState.selectedPlanWeeks.first else {
            XCTFail("Expected selected week")
            return
        }
        let session = appState.addSession(to: week, day: "Saturday", name: "Test Workout")
        let exercise = TrainingExerciseCatalogItem(id: "test_press", name: "Test Press", bodyPart: "Chest", workoutCategory: "Push", defaultSets: 2, defaultReps: "5", symbolName: "dumbbell.fill", equipment: "Barbell")
        appState.addExercises([exercise], to: session)
        guard let prescription = appState.prescriptions(for: session).first else {
            XCTFail("Expected prescription")
            return
        }

        var firstSet = appState.addSetLog(to: prescription)
        firstSet.weight = 100
        firstSet.reps = 5
        firstSet.rpe = 8
        firstSet.isComplete = true
        appState.updateSetLog(firstSet)

        var secondSet = appState.addSetLog(to: prescription)
        secondSet.weight = 110
        secondSet.reps = 4
        secondSet.rpe = 9
        secondSet.isComplete = true
        appState.updateSetLog(secondSet)

        let summary = appState.workoutSummary(for: session)

        XCTAssertEqual(summary.completedExercises, 1)
        XCTAssertEqual(summary.totalSets, 2)
        XCTAssertEqual(summary.totalVolume, 940)
        XCTAssertEqual(summary.bestSet?.weight, 110)
    }

    @MainActor
    func testStartingFreestyleSessionAddsWorkoutToActiveWeek() {
        let appState = AppState()
        guard let week = appState.selectedPlanWeeks.first else {
            XCTFail("Expected selected week")
            return
        }
        let initialCount = appState.sessions(for: week).count

        let session = appState.startFreestyleSession(in: week)

        XCTAssertEqual(session.name, "Freestyle Workout")
        XCTAssertEqual(appState.sessions(for: week).count, initialCount + 1)
        XCTAssertTrue(appState.sessions(for: week).contains { $0.id == session.id })
    }

    @MainActor
    func testFreestyleSessionCanReceiveExercisesImmediately() {
        let appState = AppState()
        guard let week = appState.selectedPlanWeeks.first,
              let exercise = appState.trainingExerciseLibrary.first else {
            XCTFail("Expected seeded week and exercise")
            return
        }

        let session = appState.startFreestyleSession(in: week)
        appState.addExercises([exercise], to: session)

        XCTAssertEqual(appState.prescriptions(for: session).count, 1)
        XCTAssertEqual(appState.prescriptions(for: session).first?.exerciseName, exercise.name)
    }

    @MainActor
    func testActiveSetLogsStartBlankWhenHistoryExists() {
        let appState = AppState()
        guard let week = appState.selectedPlanWeeks.first,
              let session = appState.sessions(for: week).first,
              let prescription = appState.prescriptions(for: session).first else {
            XCTFail("Expected seeded prescription")
            return
        }
        XCTAssertFalse(appState.setLogs(for: prescription).isEmpty)

        let activeLog = appState.addSetLog(to: prescription)

        XCTAssertEqual(activeLog.setNumber, 1)
        XCTAssertNil(activeLog.weight)
        XCTAssertNil(activeLog.reps)
        XCTAssertEqual(appState.activeSetLogs(for: prescription).count, 1)
    }

    private func makeLift(
        userID: UUID,
        weight: Double,
        exerciseID: String = "deadlift",
        repetitions: Int = 1
    ) -> LiftSubmission {
        LiftSubmission(
            id: UUID(),
            userID: userID,
            exerciseID: exerciseID,
            exerciseName: exerciseID.capitalized,
            weight: weight,
            unit: .pounds,
            normalizedWeightKilograms: RankingCalculator.poundsToKilograms(weight),
            repetitions: repetitions,
            isActualOneRepMax: repetitions == 1,
            estimatedOneRepMax: RankingCalculator.epleyOneRepMax(weight: weight, repetitions: repetitions),
            bodyweightAtLift: 200,
            bodyweightMultiple: RankingCalculator.bodyweightMultiple(oneRepMax: weight, bodyweight: 200),
            equipmentType: .raw,
            variation: "Conventional deadlift",
            gymID: MockData.demoGymID,
            performedAt: .now,
            localVideoURL: nil,
            remoteVideoURL: nil,
            caption: "",
            verificationStatus: .moderatorVerified,
            visibility: .publicLift,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeSetLog(setNumber: Int) -> WorkoutSetLog {
        WorkoutSetLog(
            id: UUID(),
            prescriptionID: UUID(),
            performedAt: .now,
            setNumber: setNumber,
            weight: nil,
            reps: nil,
            rpe: nil,
            isWarmup: false,
            isComplete: false
        )
    }

    func testLeaderboardTotalUsesOneRepPRsAndAllowsPartialTotals() {
        let seeded = MockData.community()
        let userID = seeded.profiles[0].id
        let lifts = [
            makeLift(userID: userID, weight: 300, exerciseID: "squat", repetitions: 1),
            makeLift(userID: userID, weight: 225, exerciseID: "bench", repetitions: 1),
            makeLift(userID: userID, weight: 500, exerciseID: "deadlift", repetitions: 1),
            makeLift(userID: userID, weight: 600, exerciseID: "deadlift", repetitions: 5)
        ]
        let entries = RankingCalculator.leaderboardEntries(
            profiles: seeded.profiles,
            lifts: lifts,
            rankingType: .total,
            verifiedOnly: false,
            currentUserID: nil
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].score, RankingCalculator.poundsToKilograms(1_025), accuracy: 0.001)
        XCTAssertEqual(entries[0].powerliftingBreakdown?.deadliftKilograms ?? 0, RankingCalculator.poundsToKilograms(500), accuracy: 0.001)

        let partialEntries = RankingCalculator.leaderboardEntries(
            profiles: seeded.profiles,
            lifts: [makeLift(userID: userID, weight: 500, exerciseID: "deadlift", repetitions: 1)],
            rankingType: .total,
            verifiedOnly: false,
            currentUserID: nil
        )
        XCTAssertEqual(partialEntries.count, 1)
        XCTAssertNil(partialEntries[0].powerliftingBreakdown?.benchKilograms)
    }

    func testExerciseLeaderboardUsesSubmittedWeightRatherThanEstimatedMax() {
        let seeded = MockData.community()
        let firstUser = seeded.profiles[0].id
        let secondUser = seeded.profiles[1].id
        var lighter = makeLift(userID: firstUser, weight: 300, exerciseID: "bench", repetitions: 10)
        lighter.estimatedOneRepMax = 400
        let heavier = makeLift(userID: secondUser, weight: 315, exerciseID: "bench", repetitions: 1)

        let entries = RankingCalculator.leaderboardEntries(
            profiles: seeded.profiles,
            lifts: [lighter, heavier],
            rankingType: .absolute,
            verifiedOnly: false,
            currentUserID: nil,
            exerciseID: "bench"
        )

        XCTAssertEqual(entries.first?.profile.id, secondUser)
        XCTAssertEqual(entries.first?.score, heavier.normalizedWeightKilograms)
    }

    @MainActor
    func testExerciseRepFilterAndModeNormalization() {
        let appState = AppState()
        appState.verifiedOnly = false
        appState.selectLeaderboardExercise("deadlift")
        appState.leaderboardFilters.repetitionCount = 1
        XCTAssertEqual(appState.leaderboardFilters.rankingType, .absolute)
        XCTAssertTrue(appState.leaderboardEntries().allSatisfy { $0.lift.repetitions == 1 })

        appState.selectLeaderboardExercise(nil)
        XCTAssertEqual(appState.leaderboardFilters.rankingType, .total)
        XCTAssertNil(appState.leaderboardFilters.repetitionCount)
    }

    @MainActor
    func testDefaultLeaderboardContainsSeededOpponents() {
        let appState = AppState()
        let entries = appState.leaderboardEntries()

        XCTAssertGreaterThan(entries.count, 1)
        XCTAssertTrue(entries.contains { $0.profile.id == appState.currentProfile.id })
        XCTAssertTrue(entries.contains { $0.profile.id != appState.currentProfile.id })
    }

    func testDefaultVerificationEligibilityIncludesCommunityVerified() {
        XCTAssertTrue(VerificationStatus.communityVerified.isDefaultLeaderboardEligible)
        XCTAssertTrue(VerificationStatus.moderatorVerified.isDefaultLeaderboardEligible)
        XCTAssertTrue(VerificationStatus.competitionVerified.isDefaultLeaderboardEligible)
        XCTAssertFalse(VerificationStatus.selfReported.isDefaultLeaderboardEligible)
        XCTAssertFalse(VerificationStatus.videoSubmitted.isDefaultLeaderboardEligible)
        XCTAssertFalse(VerificationStatus.rejected.isDefaultLeaderboardEligible)
    }

    func testAllSubmissionsIncludesSelfReportedTotal() {
        let seeded = MockData.community()
        let profile = seeded.profiles[1]
        var lifts = [
            makeLift(userID: profile.id, weight: 300, exerciseID: "squat"),
            makeLift(userID: profile.id, weight: 200, exerciseID: "bench"),
            makeLift(userID: profile.id, weight: 400, exerciseID: "deadlift")
        ]
        for index in lifts.indices { lifts[index].verificationStatus = .selfReported }

        let verified = RankingCalculator.leaderboardEntries(
            profiles: [profile], lifts: lifts, rankingType: .total,
            verifiedOnly: true, currentUserID: nil
        )
        let all = RankingCalculator.leaderboardEntries(
            profiles: [profile], lifts: lifts, rankingType: .total,
            verifiedOnly: false, currentUserID: nil
        )

        XCTAssertTrue(verified.isEmpty)
        XCTAssertEqual(all.count, 1)
    }

    @MainActor
    func testUnifiedCommunityFeedIsChronologicalAndSuppressesThreadEchoes() {
        let appState = AppState()
        let items = CommunityFeedBuilder.items(
            threads: appState.communityThreads,
            activities: appState.activities,
            lifts: appState.lifts,
            topic: .all
        )

        XCTAssertFalse(items.isEmpty)
        XCTAssertEqual(items.map(\.id), items.sorted { $0.createdAt > $1.createdAt }.map(\.id))
        XCTAssertFalse(items.contains { item in
            guard case .activity(let activity) = item else { return false }
            return activity.title.localizedCaseInsensitiveContains("started a thread") ||
                activity.title.localizedCaseInsensitiveContains("replied to")
        })
    }

    @MainActor
    func testCommunityBenchTopicUsesLinkedLiftData() {
        let appState = AppState()
        let items = CommunityFeedBuilder.items(
            threads: appState.communityThreads,
            activities: appState.activities,
            lifts: appState.lifts,
            topic: .bench
        )
        let liftByID = Dictionary(uniqueKeysWithValues: appState.lifts.map { ($0.id, $0) })

        XCTAssertFalse(items.isEmpty)
        for item in items {
            if case .activity(let activity) = item {
                XCTAssertEqual(activity.liftID.flatMap { liftByID[$0] }?.exerciseID, "bench")
            }
        }
    }

    @MainActor
    func testSubmittedLiftActivityRetainsLiftLink() {
        let appState = AppState()
        let lift = makeLift(userID: appState.currentProfile.id, weight: 405)

        appState.repository.addLift(lift)

        XCTAssertEqual(appState.activities.first?.liftID, lift.id)
    }
}
