import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import SleepCore

final class BreathingTests: XCTestCase {
    func testCanFinishBeforeStartingWithoutInventingBreaths() {
        var session = BreathingSession()
        session.finish(at: 100)
        session.start(at: 200)
        let ended = session.snapshot(at: 1_000)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(ended.elapsed, 0)
        XCTAssertEqual(ended.completedBreaths, 0)
        XCTAssertFalse(ended.isRunning)
        XCTAssertNil(ended.phase)
    }

    func testEarlyFinishFreezesEveryPhaseAndCannotResume() {
        for elapsed: TimeInterval in [1, 3.5, 4, 6, 9.5] {
            var session = BreathingSession()
            session.start(at: 100)
            let before = session.snapshot(at: 100 + elapsed)
            session.finish(at: 100 + elapsed)
            session.start(at: 20_000)
            session.pause(at: 30_000)
            session.advance(at: 40_000)
            session.finish(at: 50_000)
            let ended = session.snapshot(at: 100_000)
            XCTAssertEqual(session.status, .completed)
            XCTAssertEqual(ended.elapsed, before.elapsed)
            XCTAssertEqual(ended.completedBreaths, before.completedBreaths)
            XCTAssertEqual(ended.expansion, before.expansion)
            XCTAssertEqual(ended.progress, before.progress)
            XCTAssertFalse(ended.isRunning)
            XCTAssertNil(ended.phase)
        }
    }

    func testPausedFinishKeepsOnlyHeldTime() {
        var session = BreathingSession()
        session.start(at: 100)
        session.pause(at: 127)
        session.finish(at: 10_000)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.snapshot(at: 20_000).elapsed, 27)
        XCTAssertEqual(session.snapshot(at: 20_000).completedBreaths, 2)
    }

    func testEndpointAndFinishRacePreserveOneTerminalSession() {
        var session = BreathingSession()
        session.start(at: 100)
        session.pause(at: 400) // A finger lift can beat the endpoint callback.
        session.finish(at: 400)
        session.advance(at: 500)
        session.finish(at: 600)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.snapshot(at: 1_000).elapsed, 300)
        XCTAssertEqual(session.snapshot(at: 1_000).completedBreaths, 30)
    }

    func testReadySessionWaitsForStart() {
        let session = BreathingSession()
        let snapshot = session.snapshot(at: 50_000)
        XCTAssertEqual(session.status, .ready)
        XCTAssertEqual(snapshot.secondsRemaining, 300)
        XCTAssertEqual(snapshot.completedBreaths, 0)
        XCTAssertNil(snapshot.phase)
    }

    func testFourSecondInhaleAndSixSecondExhaleHaveNoHold() {
        var session = BreathingSession()
        session.start(at: 100)
        XCTAssertEqual(session.snapshot(at: 100).phase, .inhaling)
        XCTAssertEqual(session.snapshot(at: 103.999).phase, .inhaling)
        XCTAssertEqual(session.snapshot(at: 104).phase, .exhaling)
        XCTAssertEqual(session.snapshot(at: 104).phaseRemaining, 6)
        XCTAssertEqual(session.snapshot(at: 109.999).phase, .exhaling)
        XCTAssertEqual(session.snapshot(at: 110).phase, .inhaling)
        XCTAssertEqual(session.snapshot(at: 110).completedBreaths, 1)
    }

    func testAnimationAndPhaseProgressShareTheClock() {
        var session = BreathingSession()
        session.start(at: 100)
        XCTAssertEqual(session.snapshot(at: 100).expansion, 0)
        XCTAssertTrue(abs(session.snapshot(at: 102).expansion - 0.5) < 0.000001)
        XCTAssertEqual(session.snapshot(at: 104).expansion, 1)
        XCTAssertTrue(abs(session.snapshot(at: 107).expansion - 0.5) < 0.000001)
        XCTAssertEqual(session.snapshot(at: 110).expansion, 0)
        XCTAssertEqual(session.snapshot(at: 107).phaseProgress, 0.5)
        XCTAssertEqual(session.snapshot(at: 107).phaseRemaining, 3)
    }

    func testDefaultCompletesAfterThirtyWholeBreaths() {
        var session = BreathingSession()
        session.start(at: 100)
        XCTAssertFalse(session.snapshot(at: 399.999).isComplete)
        session.advance(at: 400)
        let finished = session.snapshot(at: 100_000)
        XCTAssertEqual(session.status, .completed)
        XCTAssertTrue(finished.isComplete)
        XCTAssertEqual(finished.completedBreaths, 30)
        XCTAssertEqual(finished.secondsRemaining, 0)
        XCTAssertEqual(finished.progress, 1)
        XCTAssertNil(finished.phase)
        session.start(at: 100_001)
        XCTAssertEqual(session.status, .completed)
    }

    func testEveryDurationFinishesAtAnExhaleBoundary() {
        for duration in BreathingDuration.allCases {
            var session = BreathingSession(duration: duration)
            session.start(at: 1_000)
            XCTAssertEqual(session.snapshot(at: 1_000 + duration.seconds - 0.001).phase, .exhaling)
            session.advance(at: 1_000 + duration.seconds)
            let finished = session.snapshot(at: 50_000)
            XCTAssertEqual(finished.completedBreaths, duration.rawValue * 6)
            XCTAssertEqual(finished.elapsed, TimeInterval(duration.rawValue * 60))
            XCTAssertEqual(finished.secondsRemaining, 0)
            XCTAssertEqual(session.status, .completed)
        }
    }

    func testReleaseFreezesExactTimeAndResumesTheSamePhase() {
        var session = BreathingSession()
        session.start(at: 100)
        session.pause(at: 127) // Two complete cycles; an interrupted exhale.
        XCTAssertEqual(session.status, .paused)
        XCTAssertNil(session.snapshot(at: 20_000).phase)
        XCTAssertEqual(session.snapshot(at: 20_000).elapsed, 27)
        XCTAssertEqual(session.snapshot(at: 20_000).secondsRemaining, 273)
        XCTAssertTrue(abs(session.snapshot(at: 20_000).expansion - 0.5) < 0.000001)
        session.start(at: 20_000)
        XCTAssertEqual(session.snapshot(at: 20_000).phase, .exhaling)
        XCTAssertEqual(session.snapshot(at: 20_000).phaseRemaining, 3)
        XCTAssertEqual(session.snapshot(at: 20_003).phase, .inhaling)
        session.advance(at: 20_273)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.snapshot(at: 20_273).completedBreaths, 30)
    }

    func testRepeatedShortHoldsKeepAllHeldTimeAndNeverCountReleasedTime() {
        var session = BreathingSession()
        for press in 0..<20 {
            let pressedAt = TimeInterval(press * 100)
            session.start(at: pressedAt)
            session.pause(at: pressedAt + 0.5)
            XCTAssertEqual(session.snapshot(at: pressedAt + 99).elapsed, TimeInterval(press + 1) * 0.5)
        }
        let snapshot = session.snapshot(at: 50_000)
        XCTAssertEqual(snapshot.elapsed, 10)
        XCTAssertEqual(snapshot.completedBreaths, 1)
        XCTAssertEqual(snapshot.secondsRemaining, 290)
        XCTAssertEqual(session.status, .paused)
    }

    func testReleaseAtEachPhaseFreezesAnimationUntilTheNextPress() {
        for releaseTime: TimeInterval in [1, 3.5, 4, 6, 9.5] {
            var session = BreathingSession()
            session.start(at: 100)
            let beforeRelease = session.snapshot(at: 100 + releaseTime)
            session.pause(at: 100 + releaseTime)
            let paused = session.snapshot(at: 100_000)
            XCTAssertEqual(paused.elapsed, beforeRelease.elapsed)
            XCTAssertEqual(paused.expansion, beforeRelease.expansion)
            XCTAssertNil(paused.phase)
            session.pause(at: 200_000) // Duplicate release must not alter time.
            session.start(at: 300_000)
            let resumed = session.snapshot(at: 300_000)
            XCTAssertEqual(resumed.phase, beforeRelease.phase)
            XCTAssertEqual(resumed.phaseRemaining, beforeRelease.phaseRemaining)
            XCTAssertEqual(resumed.expansion, beforeRelease.expansion)
        }
    }

    func testDelayedUpdatesDoNotStretchTheRhythmOrSession() {
        var session = BreathingSession()
        session.start(at: 100)
        session.advance(at: 246.5)
        XCTAssertEqual(session.snapshot(at: 246.5).phase, .exhaling)
        XCTAssertEqual(session.snapshot(at: 246.5).phaseRemaining, 3.5)
        XCTAssertEqual(session.snapshot(at: 246.5).completedBreaths, 14)
        session.advance(at: 100_000)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.snapshot(at: 100_000).elapsed, 300)
    }

    func testDuplicateStartAndInvalidTimesCannotRestartTheSession() {
        var session = BreathingSession()
        session.start(at: .nan)
        XCTAssertEqual(session.status, .ready)
        session.start(at: 100)
        session.start(at: 105)
        XCTAssertEqual(session.snapshot(at: 110).completedBreaths, 1)
        XCTAssertEqual(session.snapshot(at: 90).elapsed, 0)
        XCTAssertEqual(session.snapshot(at: .infinity).elapsed, 0)
        session.pause(at: 400)
        XCTAssertEqual(session.status, .completed)
    }
}
