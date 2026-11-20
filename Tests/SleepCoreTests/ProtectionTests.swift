import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import SleepCore

final class ProtectionTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-11-19T04:00:00Z")!
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }
    private func decision(authorized: Bool = true, count: Int = 2, enabled: Bool = true,
                          registered: Bool = true, override: Date? = nil,
                          test: Date? = nil, supported: Bool = true) -> ProtectionDecision {
        .evaluate(plan: BedtimePlan(), now: now, supported: supported, authorized: authorized,
                  selectionCount: count, enabled: enabled, registered: registered,
                  overrideUntil: override, testUntil: test, calendar: calendar)
    }
    func testUnavailableIsNeverPresentedAsProtection() {
        XCTAssertEqual(decision(supported: false), .unavailable)
        XCTAssertFalse(decision(supported: false).shouldShield)
    }
    func testPermissionSelectionAndRegistrationAreRequired() {
        XCTAssertEqual(decision(authorized: false), .needsAuthorization)
        XCTAssertEqual(decision(count: 0), .needsSelection)
        XCTAssertEqual(decision(registered: false), .needsRegistration)
        XCTAssertEqual(decision(enabled: false), .off)
    }
    func testActiveNightShields() { XCTAssertTrue(decision().shouldShield) }
    func testCurrentNightOverrideAndExpiration() {
        XCTAssertFalse(decision(override: now.addingTimeInterval(3600)).shouldShield)
        XCTAssertTrue(decision(override: now.addingTimeInterval(-1)).shouldShield)
    }
    func testOverrideCannotLeakIntoFutureNight() {
        XCTAssertTrue(decision(override: now.addingTimeInterval(86400)).shouldShield)
    }
    func testTestProtectionCanRunWithNightlyProtectionOff() {
        XCTAssertTrue(decision(enabled: false, test: now.addingTimeInterval(1200)).shouldShield)
        XCTAssertFalse(decision(enabled: false, test: now.addingTimeInterval(-1)).shouldShield)
    }
}
