import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import SleepCore

final class ScheduleTests: XCTestCase {
    private func calendar(_ zone: String = "America/New_York") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    func testOvernightBoundaryAndEndAreExclusive() throws {
        let plan = BedtimePlan()
        let cal = calendar()
        XCTAssertNil(plan.activeWindow(at: date("2026-11-19T03:29:59Z"), calendar: cal))
        let window = try XCTUnwrap(plan.activeWindow(at: date("2026-11-19T03:30:00Z"), calendar: cal))
        XCTAssertEqual(window.intendedBedtime, date("2026-11-19T04:00:00Z"))
        XCTAssertEqual(window.end, date("2026-11-19T12:00:00Z"))
        XCTAssertNil(plan.activeWindow(at: window.end, calendar: cal))
    }

    func testAfterMidnightBedtimeBelongsToCutoffDay() throws {
        let plan = BedtimePlan(bedtime: ClockTime(hour: 0, minute: 15), weekdays: [2])
        let cal = calendar()
        let window = try XCTUnwrap(plan.window(startingOn: date("2026-11-17T01:00:00Z"), calendar: cal))
        XCTAssertEqual(window.start, date("2026-11-17T04:45:00Z"))
        XCTAssertEqual(window.intendedBedtime, date("2026-11-17T05:15:00Z"))
        XCTAssertEqual(window.end, date("2026-11-17T12:00:00Z"))
        XCTAssertNil(plan.window(startingOn: date("2026-11-17T17:00:00Z"), calendar: cal))
    }

    func testDaySelectionAndNextWeek() throws {
        let plan = BedtimePlan(weekdays: [6])
        let next = try XCTUnwrap(plan.nextWindow(after: date("2026-11-21T13:00:00Z"), calendar: calendar()))
        XCTAssertEqual(next.start, date("2026-11-28T03:30:00Z"))
    }

    func testDaytimeSchedule() throws {
        let plan = BedtimePlan(bedtime: ClockTime(hour: 9), wakeTime: ClockTime(hour: 17))
        let window = try XCTUnwrap(plan.activeWindow(at: date("2026-11-19T15:00:00Z"), calendar: calendar()))
        XCTAssertEqual(window.start, date("2026-11-19T13:30:00Z"))
        XCTAssertEqual(window.end, date("2026-11-19T22:00:00Z"))
    }

    func testSpringForwardKeepsLocalWakeTime() throws {
        let cal = calendar()
        let window = try XCTUnwrap(BedtimePlan().window(startingOn: date("2026-03-07T17:00:00Z"), calendar: cal))
        XCTAssertEqual(cal.component(.hour, from: window.end), 7)
        XCTAssertEqual(window.end.timeIntervalSince(window.start), 7.5 * 3600)
    }

    func testFallBackKeepsLocalWakeTime() throws {
        let cal = calendar()
        let window = try XCTUnwrap(BedtimePlan().window(startingOn: date("2026-10-31T16:00:00Z"), calendar: cal))
        XCTAssertEqual(cal.component(.hour, from: window.end), 7)
        XCTAssertEqual(window.end.timeIntervalSince(window.start), 9.5 * 3600)
    }

    func testMissingDSTClockTimeMovesForward() throws {
        let cal = calendar()
        let plan = BedtimePlan(bedtime: ClockTime(hour: 2, minute: 30), wakeTime: ClockTime(hour: 10))
        let window = try XCTUnwrap(plan.window(startingOn: date("2026-03-08T17:00:00Z"), calendar: cal))
        XCTAssertEqual(cal.component(.hour, from: window.intendedBedtime), 3)
        XCTAssertEqual(cal.component(.minute, from: window.intendedBedtime), 30)
    }

    func testLocalTimezoneChangesTheSchedule() throws {
        let plan = BedtimePlan()
        let now = date("2026-11-19T04:00:00Z")
        XCTAssertNotNil(plan.activeWindow(at: now, calendar: calendar()))
        XCTAssertNil(plan.activeWindow(at: now, calendar: calendar("America/Los_Angeles")))
    }

    func testInvalidPlansAreRejected() {
        XCTAssertThrowsError(try BedtimePlan(weekdays: []).validate())
        XCTAssertThrowsError(try BedtimePlan(weekdays: [8]).validate())
        XCTAssertThrowsError(try BedtimePlan(windDownMinutes: 5).validate())
        XCTAssertThrowsError(try BedtimePlan(bedtime: ClockTime(hour: 25)).validate())
        XCTAssertThrowsError(try BedtimePlan(wakeTime: ClockTime(hour: 23)).validate())
        XCTAssertThrowsError(try BedtimePlan(wakeTime: ClockTime(hour: 22, minute: 50)).validate())
    }
}
