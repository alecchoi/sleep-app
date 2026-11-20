import Foundation

public enum ProtectionDecision: Equatable, Sendable {
    case unavailable
    case needsAuthorization
    case needsSelection
    case off
    case needsRegistration
    case scheduled(Date)
    case active(until: Date)
    case testing(until: Date)
    case overridden(until: Date)

    public static func evaluate(
        plan: BedtimePlan, now: Date, supported: Bool = true,
        authorized: Bool, selectionCount: Int, enabled: Bool,
        registered: Bool, overrideUntil: Date? = nil, testUntil: Date? = nil,
        calendar: Calendar = .current
    ) -> ProtectionDecision {
        guard supported else { return .unavailable }
        guard authorized else { return .needsAuthorization }
        guard selectionCount > 0 else { return .needsSelection }
        if let testUntil, testUntil > now { return .testing(until: testUntil) }
        guard enabled else { return .off }
        guard registered else { return .needsRegistration }
        if let window = plan.activeWindow(at: now, calendar: calendar) {
            if let overrideUntil, overrideUntil > now, overrideUntil <= window.end {
                return .overridden(until: overrideUntil)
            }
            return .active(until: window.end)
        }
        if let next = plan.nextWindow(after: now, calendar: calendar) {
            return .scheduled(next.start)
        }
        return .needsRegistration
    }

    public var shouldShield: Bool {
        switch self {
        case .active, .testing: return true
        default: return false
        }
    }
}
