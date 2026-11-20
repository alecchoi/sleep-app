import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import SleepCore

final class ProtectionSessionTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-11-19T04:00:00Z")!
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func decision(_ session: ProtectionSession, at date: Date? = nil,
                          authorized: Bool = true, count: Int = 2) -> ProtectionDecision {
        session.decision(plan: BedtimePlan(), now: date ?? now, authorized: authorized,
                         selectionCount: count, calendar: calendar)
    }

    func testTurningOffEndsNightlyProtectionAndRunningTest() {
        var session = ProtectionSession(enabled: true, registered: true,
                                        testUntil: now.addingTimeInterval(1200))
        XCTAssertTrue(decision(session).shouldShield)
        session.disable()
        XCTAssertEqual(decision(session), .off)
        // A late callback and the next selected night cannot reactivate it.
        session.expireTest(at: now.addingTimeInterval(1200))
        XCTAssertFalse(decision(session, at: now.addingTimeInterval(86400)).shouldShield)
    }

    func testOldEndCallbackCannotCancelReplacementTest() {
        let oldEnd = now.addingTimeInterval(1200)
        let replacementEnd = oldEnd.addingTimeInterval(600)
        var session = ProtectionSession(testUntil: replacementEnd)
        session.expireTest(at: oldEnd)
        XCTAssertEqual(decision(session, at: oldEnd), .testing(until: replacementEnd))
        session.expireTest(at: replacementEnd)
        XCTAssertEqual(decision(session, at: replacementEnd), .off)
    }

    func testStoppingTestRestoresCurrentNightInsteadOfUnlockingIt() {
        var session = ProtectionSession(enabled: true, registered: true,
                                        testUntil: now.addingTimeInterval(1200))
        session.testUntil = nil
        let end = BedtimePlan().activeWindow(at: now, calendar: calendar)!.end
        XCTAssertEqual(decision(session), .active(until: end))
    }

    func testExpiredTestRestoresExistingNightOverride() {
        let overrideEnd = now.addingTimeInterval(3600)
        let testEnd = now.addingTimeInterval(1200)
        var session = ProtectionSession(enabled: true, registered: true,
                                        overrideUntil: overrideEnd, testUntil: testEnd)
        XCTAssertEqual(decision(session), .testing(until: testEnd))
        session.expireTest(at: testEnd)
        XCTAssertEqual(decision(session, at: testEnd), .overridden(until: overrideEnd))
        session.disable()
        session.enabled = true
        session.registered = true
        XCTAssertTrue(decision(session, at: testEnd).shouldShield)
    }

    func testRevokedPermissionOrEmptySelectionReleasesRunningTest() {
        let session = ProtectionSession(enabled: true, registered: true,
                                        testUntil: now.addingTimeInterval(1200))
        XCTAssertFalse(decision(session, authorized: false).shouldShield)
        XCTAssertFalse(decision(session, count: 0).shouldShield)
    }
}
