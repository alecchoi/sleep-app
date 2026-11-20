import Foundation

public struct ClockTime: Codable, Equatable, Hashable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int = 0) {
        self.hour = hour
        self.minute = minute
    }

    public var isValid: Bool { (0..<24).contains(hour) && (0..<60).contains(minute) }
    public var totalMinutes: Int { hour * 60 + minute }

    public func adding(minutes: Int) -> ClockTime {
        let total = ((totalMinutes + minutes) % 1440 + 1440) % 1440
        return ClockTime(hour: total / 60, minute: total % 60)
    }

    public func date(on day: Date, calendar: Calendar = .current) -> Date? {
        guard isValid else { return nil }
        return calendar.nextDate(
            after: calendar.startOfDay(for: day).addingTimeInterval(-1),
            matching: DateComponents(hour: hour, minute: minute, second: 0),
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first, direction: .forward
        )
    }

    public static func from(_ date: Date, calendar: Calendar = .current) -> ClockTime {
        ClockTime(hour: calendar.component(.hour, from: date),
                  minute: calendar.component(.minute, from: date))
    }
}

public enum QuietActivity: String, Codable, CaseIterable, Sendable {
    case reading, breathing

    public var title: String { self == .reading ? "Quiet reading" : "Gentle breathing" }
    public var symbol: String { self == .reading ? "book.closed" : "wind" }
    public var subtitle: String {
        self == .reading ? "A few quiet pages, with a natural ending." :
            "Hold the wind and follow a gentle rhythm."
    }
}

public enum PlanError: String, Error, LocalizedError {
    case invalidTime = "Choose a valid bedtime and wake time."
    case noDays = "Choose at least one night."
    case invalidDays = "Choose valid days of the week."
    case invalidWindDown = "Choose a wind-down between 15 and 120 minutes."
    case invalidDuration = "The protection window must be shorter than 24 hours, with a different bedtime and wake time."
    public var errorDescription: String? { rawValue }
}

public struct BedtimePlan: Codable, Equatable, Sendable {
    public var bedtime: ClockTime
    public var wakeTime: ClockTime
    public var windDownMinutes: Int
    /// Calendar weekday values (Sunday = 1). A day names the day wind-down starts.
    public var weekdays: Set<Int>
    public var activity: QuietActivity
    public var readingID: String

    public init(
        bedtime: ClockTime = ClockTime(hour: 23),
        wakeTime: ClockTime = ClockTime(hour: 7),
        windDownMinutes: Int = 30,
        weekdays: Set<Int> = Set(1...7),
        activity: QuietActivity = .breathing,
        readingID: String = "harbor"
    ) {
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.windDownMinutes = windDownMinutes
        self.weekdays = weekdays
        self.activity = activity
        self.readingID = readingID
    }

    public var cutoff: ClockTime { bedtime.adding(minutes: -windDownMinutes) }
    public var bedtimeDayOffset: Int { cutoff.totalMinutes >= bedtime.totalMinutes ? 1 : 0 }
    public var endDayOffset: Int {
        bedtimeDayOffset + (wakeTime.totalMinutes <= bedtime.totalMinutes ? 1 : 0)
    }

    public func validate() throws {
        guard bedtime.isValid && wakeTime.isValid else { throw PlanError.invalidTime }
        guard !weekdays.isEmpty else { throw PlanError.noDays }
        guard weekdays.isSubset(of: Set(1...7)) else { throw PlanError.invalidDays }
        guard (15...120).contains(windDownMinutes) else { throw PlanError.invalidWindDown }
        let sleepMinutes = (wakeTime.totalMinutes - bedtime.totalMinutes + 1440) % 1440
        guard sleepMinutes > 0 && sleepMinutes + windDownMinutes < 1440 else {
            throw PlanError.invalidDuration
        }
    }

    public func window(startingOn day: Date, calendar: Calendar = .current) -> NightWindow? {
        guard (try? validate()) != nil,
              weekdays.contains(calendar.component(.weekday, from: day)),
              let start = cutoff.date(on: day, calendar: calendar),
              let bedtimeDay = calendar.date(byAdding: .day, value: bedtimeDayOffset, to: day),
              let intended = bedtime.date(on: bedtimeDay, calendar: calendar),
              let endDay = calendar.date(byAdding: .day, value: endDayOffset, to: day),
              let end = wakeTime.date(on: endDay, calendar: calendar),
              start < intended, intended < end else { return nil }
        return NightWindow(start: start, intendedBedtime: intended, end: end)
    }

    public func activeWindow(at date: Date, calendar: Calendar = .current) -> NightWindow? {
        for offset in [-1, 0] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date),
                  let window = window(startingOn: day, calendar: calendar) else { continue }
            if window.start <= date && date < window.end { return window }
        }
        return nil
    }

    public func nextWindow(after date: Date, calendar: Calendar = .current) -> NightWindow? {
        (0...8).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: date)
                .flatMap { window(startingOn: $0, calendar: calendar) }
        }.filter { $0.start > date }.min { $0.start < $1.start }
    }
}

public struct NightWindow: Codable, Equatable, Identifiable, Sendable {
    public let start: Date
    public let intendedBedtime: Date
    public let end: Date
    public var id: Date { start }

    public init(start: Date, intendedBedtime: Date, end: Date) {
        self.start = start
        self.intendedBedtime = intendedBedtime
        self.end = end
    }
}
