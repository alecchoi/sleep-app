import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import SleepCore

final class ReminderTests: XCTestCase {
    func testReminderUsesCutoffDayAcrossMidnight() throws {
        let plan = BedtimePlan(bedtime: ClockTime(hour: 0, minute: 15), weekdays: [2, 6])
        let reminders = try WindDownReminder.schedule(for: plan)
        XCTAssertEqual(reminders.count, 2)
        let monday = try XCTUnwrap(reminders.first)
        XCTAssertEqual(monday.id, "sleepapp.winddown.2")
        XCTAssertEqual(monday.dateComponents.weekday, 2)
        XCTAssertEqual(monday.dateComponents.hour, 23)
        XCTAssertEqual(monday.dateComponents.minute, 45)
        XCTAssertNil(monday.dateComponents.timeZone)
        XCTAssertEqual(reminders.last?.weekday, 6)
    }

    func testInvalidReminderPlanIsRejected() {
        XCTAssertThrowsError(try WindDownReminder.schedule(for: BedtimePlan(weekdays: [])))
    }

    func testFirstBuildJournalMigratesWithoutLosingData() throws {
        var original = AppSnapshot()
        original.onboarded = true
        original.plan.activity = .breathing
        let data = try JSONEncoder.sleepApp.encode(original)
        var oldJSON = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        oldJSON.removeValue(forKey: "remindersEnabled")
        let migrated = try JSONDecoder.sleepApp.decode(
            AppSnapshot.self, from: JSONSerialization.data(withJSONObject: oldJSON)
        )
        XCTAssertEqual(migrated, original)
        XCTAssertFalse(migrated.remindersEnabled)
        var enabled = migrated
        enabled.remindersEnabled = true
        XCTAssertEqual(try JSONDecoder.sleepApp.decode(AppSnapshot.self, from: JSONEncoder.sleepApp.encode(enabled)), enabled)
    }
}
