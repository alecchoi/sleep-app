// A small host-only runner for the exact XCTest cases when the Command Line
// Tools SDK has no XCTest. Xcode and CI run these same files with XCTest.
import Foundation

class XCTestCase {}

enum CheckResults {
    static var failures: [String] = []
    static func fail(_ message: String, file: StaticString, line: UInt) {
        failures.append("\(file):\(line): \(message)")
    }
}

func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool,
                   file: StaticString = #filePath, line: UInt = #line) {
    do {
        if try !expression() { CheckResults.fail("Expected true", file: file, line: line) }
    } catch { CheckResults.fail("\(error)", file: file, line: line) }
}
func XCTAssertFalse(_ expression: @autoclosure () throws -> Bool,
                    file: StaticString = #filePath, line: UInt = #line) {
    do {
        if try expression() { CheckResults.fail("Expected false", file: file, line: line) }
    } catch { CheckResults.fail("\(error)", file: file, line: line) }
}
func XCTAssertEqual<T: Equatable>(_ lhs: @autoclosure () throws -> T,
                                  _ rhs: @autoclosure () throws -> T,
                                  file: StaticString = #filePath, line: UInt = #line) {
    do {
        let a = try lhs(), b = try rhs()
        if a != b { CheckResults.fail("\(a) != \(b)", file: file, line: line) }
    } catch { CheckResults.fail("\(error)", file: file, line: line) }
}
func XCTAssertNil<T>(_ value: @autoclosure () throws -> T?,
                     file: StaticString = #filePath, line: UInt = #line) {
    do {
        if try value() != nil { CheckResults.fail("Expected nil", file: file, line: line) }
    } catch { CheckResults.fail("\(error)", file: file, line: line) }
}
func XCTAssertNotNil<T>(_ value: @autoclosure () throws -> T?,
                        file: StaticString = #filePath, line: UInt = #line) {
    do {
        if try value() == nil { CheckResults.fail("Expected a value", file: file, line: line) }
    } catch { CheckResults.fail("\(error)", file: file, line: line) }
}
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T,
                             file: StaticString = #filePath, line: UInt = #line) {
    do {
        _ = try expression()
        CheckResults.fail("Expected an error", file: file, line: line)
    } catch {}
}
func XCTUnwrap<T>(_ value: @autoclosure () throws -> T?,
                  file: StaticString = #filePath, line: UInt = #line) throws -> T {
    if let result = try value() { return result }
    CheckResults.fail("Required value missing", file: file, line: line)
    throw NSError(domain: "SleepCoreChecks", code: 1)
}

@main enum CoreCheckRunner {
    static func main() {
        let schedule = ScheduleTests(), journal = JournalTests(), protection = ProtectionTests()
        let reminders = ReminderTests()
        let breathing = BreathingTests()
        let session = ProtectionSessionTests()
        let cases: [(String, () throws -> Void)] = [
            ("overnight boundaries", schedule.testOvernightBoundaryAndEndAreExclusive),
            ("after-midnight bedtime and weekdays", schedule.testAfterMidnightBedtimeBelongsToCutoffDay),
            ("next selected night", schedule.testDaySelectionAndNextWeek),
            ("daytime schedules", schedule.testDaytimeSchedule),
            ("spring daylight saving", schedule.testSpringForwardKeepsLocalWakeTime),
            ("fall daylight saving", schedule.testFallBackKeepsLocalWakeTime),
            ("missing daylight-saving clock time", schedule.testMissingDSTClockTimeMovesForward),
            ("local timezone", schedule.testLocalTimezoneChangesTheSchedule),
            ("invalid schedules", schedule.testInvalidPlansAreRejected),
            ("positive bedtime delay", journal.testPositiveDelayAndEarlyBedtime),
            ("missing check-ins", journal.testMissingEntriesDoNotBecomeSuccessfulNights),
            ("historical planned bedtime", journal.testLaterPlanEditCannotChangeLastNightsTarget),
            ("no retroactive plan", journal.testNoRetroactivePlansBeforeSetup),
            ("check-in validation", journal.testFutureAttemptAndInvalidRatingAreRejected),
            ("storage roundtrip and deletion", journal.testAtomicRoundtripAndDeletion),
            ("corrupt-file preservation", journal.testCorruptFileIsPreserved),
            ("saved breathing preferences and session duration", journal.testSavedBreathingPreferencesAreLoadedForEveryDuration),
            ("old breathing preferences and history migration", journal.testOldJournalDefaultsBreathingPreferencesAndPreservesHistory),
            ("unsupported protection", protection.testUnavailableIsNeverPresentedAsProtection),
            ("authorization, selection and registration", protection.testPermissionSelectionAndRegistrationAreRequired),
            ("active-night protection", protection.testActiveNightShields),
            ("current-night override", protection.testCurrentNightOverrideAndExpiration),
            ("override cannot leak into next night", protection.testOverrideCannotLeakIntoFutureNight),
            ("bounded protection test", protection.testTestProtectionCanRunWithNightlyProtectionOff),
            ("off releases nightly and test shields", session.testTurningOffEndsNightlyProtectionAndRunningTest),
            ("old callback preserves replacement test", session.testOldEndCallbackCannotCancelReplacementTest),
            ("stop test resumes active night", session.testStoppingTestRestoresCurrentNightInsteadOfUnlockingIt),
            ("test expiry restores override", session.testExpiredTestRestoresExistingNightOverride),
            ("revocation or empty selection releases test", session.testRevokedPermissionOrEmptySelectionReleasesRunningTest),
            ("reminder cutoff day across midnight", reminders.testReminderUsesCutoffDayAcrossMidnight),
            ("invalid reminder plan", reminders.testInvalidReminderPlanIsRejected),
            ("first-build journal migration", reminders.testFirstBuildJournalMigratesWithoutLosingData),
            ("breathing waits for start", breathing.testReadySessionWaitsForStart),
            ("finish before starting without invented breaths", breathing.testCanFinishBeforeStartingWithoutInventingBreaths),
            ("early finish is terminal in every phase", breathing.testEarlyFinishFreezesEveryPhaseAndCannotResume),
            ("paused finish excludes released time", breathing.testPausedFinishKeepsOnlyHeldTime),
            ("endpoint and finish race stays terminal", breathing.testEndpointAndFinishRacePreserveOneTerminalSession),
            ("breathing phase boundaries without holds", breathing.testFourSecondInhaleAndSixSecondExhaleHaveNoHold),
            ("breathing animation synchronization", breathing.testAnimationAndPhaseProgressShareTheClock),
            ("finite thirty-breath session", breathing.testDefaultCompletesAfterThirtyWholeBreaths),
            ("all breathing session durations", breathing.testEveryDurationFinishesAtAnExhaleBoundary),
            ("hold release freezes timer and phase", breathing.testReleaseFreezesExactTimeAndResumesTheSamePhase),
            ("short holds accumulate exact active time", breathing.testRepeatedShortHoldsKeepAllHeldTimeAndNeverCountReleasedTime),
            ("hold release freezes animation", breathing.testReleaseAtEachPhaseFreezesAnimationUntilTheNextPress),
            ("breathing timing without accumulated drift", breathing.testDelayedUpdatesDoNotStretchTheRhythmOrSession),
            ("breathing duplicate starts and invalid time", breathing.testDuplicateStartAndInvalidTimesCannotRestartTheSession)
        ]
        for (name, run) in cases {
            let previousFailures = CheckResults.failures.count
            do { try run() }
            catch { CheckResults.failures.append("\(name): \(error)") }
            print("\(CheckResults.failures.count == previousFailures ? "PASS" : "FAIL") \(name)")
        }
        print("\n\(cases.count) cases; \(CheckResults.failures.count) failures")
        for failure in CheckResults.failures { print(failure) }
        exit(CheckResults.failures.isEmpty ? 0 : 1)
    }
}
