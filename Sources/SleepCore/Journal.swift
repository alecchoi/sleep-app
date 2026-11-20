import Foundation

public struct PlanRevision: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var effectiveFrom: Date
    public var plan: BedtimePlan
    public init(id: UUID = UUID(), effectiveFrom: Date, plan: BedtimePlan) {
        self.id = id
        self.effectiveFrom = effectiveFrom
        self.plan = plan
    }
}

public enum MorningConstraint: String, Codable, CaseIterable, Sendable {
    case none = "Nothing unusual"
    case work = "Work or study"
    case caregiving = "Caregiving"
    case otherDevice = "Another device"
    case other = "Something else"
}

public struct MorningEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var window: NightWindow
    public var attemptedSleepAt: Date
    public var restfulness: Int
    public var constraint: MorningConstraint
    public var recordedAt: Date

    public init(
        id: UUID = UUID(), window: NightWindow, attemptedSleepAt: Date,
        restfulness: Int, constraint: MorningConstraint = .none, recordedAt: Date = Date()
    ) {
        self.id = id
        self.window = window
        self.attemptedSleepAt = attemptedSleepAt
        self.restfulness = restfulness
        self.constraint = constraint
        self.recordedAt = recordedAt
    }

    /// A positive delay measures bedtime procrastination, not time to fall asleep.
    public var delayMinutes: Double {
        max(0, attemptedSleepAt.timeIntervalSince(window.intendedBedtime) / 60)
    }

    public func validate() throws {
        guard (1...5).contains(restfulness) else { throw JournalError.invalidRestfulness }
        guard attemptedSleepAt <= recordedAt else { throw JournalError.futureAttempt }
        guard attemptedSleepAt >= window.start.addingTimeInterval(-12 * 3600),
              attemptedSleepAt < window.end.addingTimeInterval(12 * 3600) else {
            throw JournalError.invalidAttempt
        }
    }
}

public enum JournalError: String, Error, LocalizedError {
    case invalidRestfulness = "Choose how rested you feel from 1 to 5."
    case futureAttempt = "The time you tried to sleep cannot be in the future."
    case invalidAttempt = "Choose a time around the night you are checking in for."
    case unsupportedVersion = "This data was saved by a newer version of Sleep App."
    case invalidData = "Saved data could not be validated. Your original file has been preserved."
    public var errorDescription: String? { rawValue }
}

public struct ActivitySession: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var activity: QuietActivity
    /// This records a button press. It does not establish sleep or phone inactivity.
    public var finishedAt: Date
    public init(activity: QuietActivity, finishedAt: Date) {
        self.activity = activity
        self.finishedAt = finishedAt
    }
}

public struct AppSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var onboarded = false
    public var plan = BedtimePlan()
    public var protectionEnabled = false
    public var remindersEnabled = false
    public var breathingPreferences = BreathingPreferences()
    public var revisions: [PlanRevision] = []
    public var mornings: [MorningEntry] = []
    public var sessions: [ActivitySession] = []
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, onboarded, plan, protectionEnabled, remindersEnabled
        case breathingPreferences, revisions, mornings, sessions
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        onboarded = try values.decode(Bool.self, forKey: .onboarded)
        plan = try values.decode(BedtimePlan.self, forKey: .plan)
        protectionEnabled = try values.decode(Bool.self, forKey: .protectionEnabled)
        // Journals from the first build did not contain notification preferences.
        remindersEnabled = try values.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        // Earlier builds configured breathing inside each session.
        breathingPreferences = try values.decodeIfPresent(BreathingPreferences.self, forKey: .breathingPreferences)
            ?? BreathingPreferences()
        revisions = try values.decode([PlanRevision].self, forKey: .revisions)
        mornings = try values.decode([MorningEntry].self, forKey: .mornings)
        sessions = try values.decode([ActivitySession].self, forKey: .sessions)
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw JournalError.unsupportedVersion }
        try plan.validate()
        for revision in revisions { try revision.plan.validate() }
        for entry in mornings { try entry.validate() }
        guard Set(mornings.map(\.window.start)).count == mornings.count else {
            throw JournalError.invalidData
        }
    }
}

public enum NightHistory {
    /// Resolve the plan in force at cutoff, so later edits cannot move the goalpost.
    public static func recentNights(
        before now: Date, revisions: [PlanRevision],
        days: Int = 14, calendar: Calendar = .current
    ) -> [NightWindow] {
        let sorted = revisions.sorted { $0.effectiveFrom < $1.effectiveFrom }
        var nights: [NightWindow] = []
        for (index, revision) in sorted.enumerated() {
            let nextChange = index + 1 < sorted.count ? sorted[index + 1].effectiveFrom : .distantFuture
            for offset in (-days...0) {
                guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                      let window = revision.plan.window(startingOn: day, calendar: calendar),
                      window.start >= revision.effectiveFrom,
                      window.start < nextChange,
                      window.intendedBedtime < now else { continue }
                nights.append(window)
            }
        }
        return Array(Set(nights.map(\.start))).compactMap { start in
            nights.first { $0.start == start }
        }.sorted { $0.start > $1.start }
    }

    public static func averageDelay(_ entries: [MorningEntry]) -> Double? {
        guard !entries.isEmpty else { return nil }
        return entries.reduce(0) { $0 + $1.delayMinutes } / Double(entries.count)
    }
}

public struct JournalStore {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load() throws -> AppSnapshot {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppSnapshot() }
        let snapshot = try JSONDecoder.sleepApp.decode(AppSnapshot.self, from: Data(contentsOf: url))
        try snapshot.validate()
        return snapshot
    }

    public func save(_ snapshot: AppSnapshot) throws {
        try snapshot.validate()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder.sleepApp.encode(snapshot).write(to: url, options: .atomic)
    }

    public func delete() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

public extension JSONEncoder {
    static var sleepApp: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    static var sleepApp: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
