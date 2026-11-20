import Foundation

/// A weekly, local-time reminder. It shares the plan's cutoff-day convention.
public struct WindDownReminder: Identifiable, Equatable, Sendable {
    public let weekday: Int
    public let time: ClockTime
    public let activity: QuietActivity
    public var id: String { "sleepapp.winddown.\(weekday)" }
    public var dateComponents: DateComponents {
        DateComponents(hour: time.hour, minute: time.minute, weekday: weekday)
    }
    public static let identifiers = (1...7).map { "sleepapp.winddown.\($0)" }

    public static func schedule(for plan: BedtimePlan) throws -> [WindDownReminder] {
        try plan.validate()
        return plan.weekdays.sorted().map {
            WindDownReminder(weekday: $0, time: plan.cutoff, activity: plan.activity)
        }
    }
}
