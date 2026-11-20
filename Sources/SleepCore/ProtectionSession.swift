import Foundation

/// Enforcement intent shared by the app and its background monitor.
/// A test may run with nightly protection off, but an explicit off action ends both.
public struct ProtectionSession: Equatable, Sendable {
    public var enabled: Bool
    public var registered: Bool
    public var overrideUntil: Date?
    public var testUntil: Date?

    public init(enabled: Bool = false, registered: Bool = false,
                overrideUntil: Date? = nil, testUntil: Date? = nil) {
        self.enabled = enabled
        self.registered = registered
        self.overrideUntil = overrideUntil
        self.testUntil = testUntil
    }

    public mutating func disable() {
        enabled = false
        registered = false
        overrideUntil = nil
        testUntil = nil
    }

    /// Stopping or replacing monitoring can deliver a late intervalDidEnd.
    /// Only the current deadline can end the current test.
    public mutating func expireTest(at now: Date) {
        if let testUntil, testUntil <= now { self.testUntil = nil }
    }

    public func decision(plan: BedtimePlan, now: Date, authorized: Bool,
                         selectionCount: Int, calendar: Calendar = .current) -> ProtectionDecision {
        .evaluate(plan: plan, now: now, authorized: authorized,
                  selectionCount: selectionCount, enabled: enabled, registered: registered,
                  overrideUntil: overrideUntil, testUntil: testUntil, calendar: calendar)
    }
}
