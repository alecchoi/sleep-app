import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import SleepCore

final class JournalTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-11-19T13:00:00Z")!
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/New_York")!
        return value
    }
    private func window() -> NightWindow {
        BedtimePlan().window(startingOn: now.addingTimeInterval(-86400), calendar: calendar)!
    }

    func testPositiveDelayAndEarlyBedtime() {
        let night = window()
        let entry = MorningEntry(window: night, attemptedSleepAt: night.intendedBedtime.addingTimeInterval(22*60), restfulness: 3, recordedAt: now)
        XCTAssertEqual(entry.delayMinutes, 22)
        let early = MorningEntry(window: night, attemptedSleepAt: night.intendedBedtime.addingTimeInterval(-15*60), restfulness: 3, recordedAt: now)
        XCTAssertEqual(early.delayMinutes, 0)
    }

    func testMissingEntriesDoNotBecomeSuccessfulNights() {
        XCTAssertNil(NightHistory.averageDelay([]))
    }

    func testLaterPlanEditCannotChangeLastNightsTarget() throws {
        let old = PlanRevision(effectiveFrom: now.addingTimeInterval(-3*86400), plan: BedtimePlan())
        let changed = PlanRevision(effectiveFrom: now.addingTimeInterval(-3600),
                                   plan: BedtimePlan(bedtime: ClockTime(hour: 1)))
        let night = try XCTUnwrap(NightHistory.recentNights(before: now, revisions: [old, changed], calendar: calendar).first)
        XCTAssertEqual(calendar.component(.hour, from: night.intendedBedtime), 23)
    }

    func testNoRetroactivePlansBeforeSetup() {
        let revision = PlanRevision(effectiveFrom: now, plan: BedtimePlan())
        XCTAssertTrue(NightHistory.recentNights(before: now, revisions: [revision], calendar: calendar).isEmpty)
    }

    func testFutureAttemptAndInvalidRatingAreRejected() {
        XCTAssertThrowsError(try MorningEntry(window: window(), attemptedSleepAt: now.addingTimeInterval(60), restfulness: 3, recordedAt: now).validate())
        XCTAssertThrowsError(try MorningEntry(window: window(), attemptedSleepAt: now, restfulness: 0, recordedAt: now).validate())
    }

    func testAtomicRoundtripAndDeletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JournalStore(url: directory.appendingPathComponent("journal.json"))
        XCTAssertEqual(try store.load(), AppSnapshot())
        var snapshot = AppSnapshot()
        snapshot.onboarded = true
        snapshot.revisions = [PlanRevision(effectiveFrom: now, plan: snapshot.plan)]
        snapshot.mornings = [MorningEntry(window: window(), attemptedSleepAt: window().intendedBedtime, restfulness: 4, recordedAt: now)]
        try store.save(snapshot)
        XCTAssertEqual(try store.load(), snapshot)
        try store.delete()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url.path))
    }

    func testCorruptFileIsPreserved() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = Data("not valid JSON".utf8)
        try data.write(to: url)
        XCTAssertThrowsError(try JournalStore(url: url).load())
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

    func testSavedBreathingPreferencesAreLoadedForEveryDuration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JournalStore(url: directory.appendingPathComponent("journal.json"))
        for duration in BreathingDuration.allCases {
            for hapticsEnabled in [true, false] {
                var snapshot = AppSnapshot()
                snapshot.breathingPreferences = BreathingPreferences(duration: duration, hapticsEnabled: hapticsEnabled)
                try store.save(snapshot)
                let reloaded = try store.load()
                XCTAssertEqual(reloaded.breathingPreferences, snapshot.breathingPreferences)
                let session = BreathingSession(duration: reloaded.breathingPreferences.duration)
                XCTAssertEqual(session.snapshot(at: 0).secondsRemaining, duration.rawValue * 60)
                XCTAssertEqual(session.status, .ready)
            }
        }
    }

    func testOldJournalDefaultsBreathingPreferencesAndPreservesHistory() throws {
        var original = AppSnapshot()
        original.onboarded = true
        original.plan.activity = .reading
        original.sessions = [ActivitySession(activity: .reading, finishedAt: now)]
        original.revisions = [PlanRevision(effectiveFrom: now, plan: original.plan)]
        var oldJSON = try JSONSerialization.jsonObject(with: JSONEncoder.sleepApp.encode(original)) as! [String: Any]
        oldJSON.removeValue(forKey: "breathingPreferences")
        let migrated = try JSONDecoder.sleepApp.decode(
            AppSnapshot.self, from: JSONSerialization.data(withJSONObject: oldJSON)
        )
        XCTAssertEqual(migrated, original)
        XCTAssertEqual(migrated.breathingPreferences.duration, .fiveMinutes)
        XCTAssertTrue(migrated.breathingPreferences.hapticsEnabled)
    }
}
