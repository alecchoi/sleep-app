#if os(iOS)
import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import SleepCore

enum SharedStoreError: Error, LocalizedError {
    case unavailable
    var errorDescription: String? {
        "The shared App Group is unavailable. Configure the same App Group for the app and all Screen Time extensions."
    }
}

/// Shared settings contain only the plan, opaque target tokens, and enforcement state.
/// Morning check-ins remain in the main app's private container.
final class SharedDeviceStore {
    private let defaults: UserDefaults
    static let settingsName = ManagedSettingsStore.Name("sleepapp.bedtime")
    static let nightNames = (1...7).map { name(for: $0) }
    static let testName = DeviceActivityName("sleepapp.protection-test")
    static var allNames: [DeviceActivityName] { nightNames + [testName] }
    static func name(for day: Int) -> DeviceActivityName { .init("sleepapp.night.\(day)") }

    init() throws {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "SleepAppGroupIdentifier") as? String,
              !group.isEmpty,
              FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
              let defaults = UserDefaults(suiteName: group) else { throw SharedStoreError.unavailable }
        self.defaults = defaults
    }

    var enabled: Bool {
        get { defaults.bool(forKey: "protection.enabled") }
        set { defaults.set(newValue, forKey: "protection.enabled") }
    }
    var registered: Bool {
        get { defaults.bool(forKey: "protection.registered") }
        set { defaults.set(newValue, forKey: "protection.registered") }
    }
    var wasAuthorized: Bool {
        get { defaults.bool(forKey: "protection.wasAuthorized") }
        set { defaults.set(newValue, forKey: "protection.wasAuthorized") }
    }
    var timeZoneIdentifier: String? {
        get { defaults.string(forKey: "protection.timeZone") }
        set { defaults.set(newValue, forKey: "protection.timeZone") }
    }
    var overrideUntil: Date? {
        get { defaults.object(forKey: "protection.overrideUntil") as? Date }
        set { defaults.set(newValue, forKey: "protection.overrideUntil") }
    }
    var testUntil: Date? {
        get { defaults.object(forKey: "protection.testUntil") as? Date }
        set { defaults.set(newValue, forKey: "protection.testUntil") }
    }

    // Retain the existing keys so installed builds keep their saved settings.
    var session: ProtectionSession {
        get { .init(enabled: enabled, registered: registered,
                    overrideUntil: overrideUntil, testUntil: testUntil) }
        set {
            enabled = newValue.enabled
            registered = newValue.registered
            overrideUntil = newValue.overrideUntil
            testUntil = newValue.testUntil
        }
    }

    func disable() {
        var updated = session
        updated.disable()
        session = updated
        clearShields()
    }

    func expireTest(now: Date = Date()) {
        var updated = session
        updated.expireTest(at: now)
        // Do not rewrite nightly intent from a background callback.
        testUntil = updated.testUntil
    }

    func savePlan(_ plan: BedtimePlan) throws {
        try plan.validate()
        defaults.set(try JSONEncoder().encode(plan), forKey: "protection.plan")
    }
    func loadPlan() throws -> BedtimePlan {
        guard let data = defaults.data(forKey: "protection.plan") else { return BedtimePlan() }
        let plan = try JSONDecoder().decode(BedtimePlan.self, from: data)
        try plan.validate()
        return plan
    }
    func saveSelection(_ selection: FamilyActivitySelection) throws {
        defaults.set(try JSONEncoder().encode(selection), forKey: "protection.selection")
    }
    func loadSelection() throws -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: "protection.selection") else { return FamilyActivitySelection() }
        return try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func reconcile(now: Date = Date()) throws {
        do {
            guard AuthorizationCenter.shared.authorizationStatus == .approved else {
                clearShields()
                return
            }
            let plan = try loadPlan()
            let selection = try loadSelection()
            let count = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
            let decision = session.decision(plan: plan, now: now, authorized: true, selectionCount: count)
            guard decision.shouldShield else { clearShields(); return }
            let settings = ManagedSettingsStore(named: Self.settingsName)
            settings.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            settings.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
            settings.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            settings.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        } catch {
            // A damaged configuration must never leave stale restrictions in place.
            clearShields()
            throw error
        }
    }

    func clearShields() {
        ManagedSettingsStore(named: Self.settingsName).clearAllSettings()
    }

    func reset() {
        clearShields()
        for key in ["enabled", "registered", "wasAuthorized", "timeZone", "overrideUntil", "testUntil", "plan", "selection"] {
            defaults.removeObject(forKey: "protection.\(key)")
        }
    }
}
#endif
