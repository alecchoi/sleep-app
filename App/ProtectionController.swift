import Foundation
import Observation
import SleepCore
#if os(iOS) && !SLEEPAPP_PREVIEW && !targetEnvironment(simulator)
import Combine
import FamilyControls
import DeviceActivity
import ManagedSettings
#endif

enum ProtectionError: String, Error, LocalizedError {
    case unavailable = "App blocking requires the full iPhone app with Screen Time access. This preview cannot restrict other apps."
    case authorization = "Allow Screen Time access before enabling app protection."
    case selection = "Choose the distracting apps or websites you want to protect."
    case sharedStorage = "The App Group is not configured. Check signing for the app and its extensions."
    case noActiveWindow = "There is no active protection window to pause."
    var errorDescription: String? { rawValue }
}

@Observable @MainActor
final class ProtectionController {
    private(set) var decision: ProtectionDecision = .unavailable
    private(set) var issue: String?
    private(set) var enabled = false
    #if os(iOS) && !SLEEPAPP_PREVIEW && !targetEnvironment(simulator)
    var selection = FamilyActivitySelection()
    @ObservationIgnored private let center = DeviceActivityCenter()
    @ObservationIgnored private var restoredSelection = false
    @ObservationIgnored private var authorizationObserver: AnyCancellable?
    private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    var isSupported: Bool { true }
    var isAuthorized: Bool { authorizationStatus == .approved }
    var selectionCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    init() {
        authorizationObserver = AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.authorizationChanged(status) }
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        guard isAuthorized else { throw ProtectionError.authorization }
    }

    func saveSelection() throws {
        try SharedDeviceStore().saveSelection(selection)
        restoredSelection = true
    }

    func configure(plan: BedtimePlan, enabled: Bool) throws {
        // Off must work even with an invalid plan or unavailable App Group.
        // Invalidate persisted intent before stopMonitoring delivers end callbacks.
        guard enabled else {
            deactivate(shared: try? SharedDeviceStore())
            decision = .off
            issue = nil
            return
        }
        do {
            try plan.validate()
            let shared = try SharedDeviceStore()
            guard isAuthorized else { throw ProtectionError.authorization }
            if !restoredSelection {
                selection = try shared.loadSelection()
                restoredSelection = true
            }
            guard selectionCount > 0 else { throw ProtectionError.selection }
            try shared.savePlan(plan)
            try shared.saveSelection(selection)
            shared.timeZoneIdentifier = TimeZone.current.identifier
            shared.enabled = true
            shared.overrideUntil = nil
            shared.registered = false
            center.stopMonitoring(SharedDeviceStore.nightNames)
            for day in plan.weekdays.sorted() {
                let endDay = ((day - 1 + plan.endDayOffset) % 7) + 1
                let schedule = DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: plan.cutoff.hour, minute: plan.cutoff.minute, weekday: day),
                    intervalEnd: DateComponents(hour: plan.wakeTime.hour, minute: plan.wakeTime.minute, weekday: endDay),
                    repeats: true
                )
                try center.startMonitoring(SharedDeviceStore.name(for: day), during: schedule)
            }
            shared.registered = true
            self.enabled = true
            issue = nil
            try shared.reconcile()
            refresh(plan: plan, enabled: true)
        } catch {
            // Include authorization, selection and storage failures in cleanup.
            deactivate(shared: try? SharedDeviceStore())
            decision = .needsRegistration
            issue = error.localizedDescription
            throw error
        }
    }

    func refresh(plan: BedtimePlan, enabled: Bool) {
        do {
            authorizationChanged(AuthorizationCenter.shared.authorizationStatus)
            let shared = try SharedDeviceStore()
            let authorized = isAuthorized
            if !authorized {
                if shared.wasAuthorized {
                    // Revoked authorizations invalidate the opaque selection tokens.
                    selection = FamilyActivitySelection()
                    try shared.saveSelection(selection)
                    restoredSelection = true
                }
                shared.wasAuthorized = false
                deactivate(shared: shared)
            } else {
                if !restoredSelection {
                    selection = try shared.loadSelection()
                    restoredSelection = true
                }
                shared.wasAuthorized = true
                let expected = Set(plan.weekdays.map(SharedDeviceStore.name(for:)))
                let present = Set(center.activities)
                let storedPlan = try shared.loadPlan()
                // A journal rollback or failed save must not leave restrictions
                // enabled in the extension while this screen claims they are off.
                if !enabled && shared.enabled { deactivate(shared: shared) }
                if selectionCount == 0 { deactivate(shared: shared) }
                shared.expireTest()
                if !present.contains(SharedDeviceStore.testName) { shared.testUntil = nil }
                // Persisted off wins over an older journal preference, including
                // after a failed journal write or an authorization revocation.
                if enabled && shared.enabled && selectionCount > 0 &&
                    (!shared.registered ||
                     expected != present.intersection(Set(SharedDeviceStore.nightNames)) || storedPlan != plan ||
                     shared.timeZoneIdentifier != TimeZone.current.identifier) {
                    try configure(plan: plan, enabled: true)
                    return
                }
            }
            self.enabled = enabled && shared.enabled
            try shared.reconcile()
            decision = shared.session.decision(plan: plan, now: Date(), authorized: authorized,
                                               selectionCount: selectionCount)
            issue = nil
        } catch {
            deactivate(shared: try? SharedDeviceStore())
            decision = .needsRegistration
            issue = error.localizedDescription
        }
    }

    func startTest(plan: BedtimePlan) throws {
        guard isAuthorized else { throw ProtectionError.authorization }
        guard selectionCount > 0 else { throw ProtectionError.selection }
        let shared = try SharedDeviceStore()
        try shared.savePlan(plan)
        try shared.saveSelection(selection)
        // DeviceActivity date components have whole-second precision. Persist the
        // same deadline so a callback at that second cannot appear premature.
        let start = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        let end = start.addingTimeInterval(20 * 60)
        let calendar = Calendar.current
        // Clear the previous deadline before stopping its monitoring interval.
        shared.testUntil = nil
        center.stopMonitoring([SharedDeviceStore.testName])
        shared.testUntil = end
        do {
            try center.startMonitoring(SharedDeviceStore.testName, during: DeviceActivitySchedule(
                intervalStart: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start),
                intervalEnd: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end),
                repeats: false
            ))
            try shared.reconcile()
            refresh(plan: plan, enabled: enabled)
        } catch {
            shared.testUntil = nil
            center.stopMonitoring([SharedDeviceStore.testName])
            try? shared.reconcile()
            refresh(plan: plan, enabled: enabled)
            throw error
        }
    }

    func stopTest(plan: BedtimePlan) throws {
        let shared = try SharedDeviceStore()
        shared.testUntil = nil
        center.stopMonitoring([SharedDeviceStore.testName])
        try shared.reconcile()
        refresh(plan: plan, enabled: enabled)
    }

    func overrideTonight(plan: BedtimePlan) throws {
        guard let window = plan.activeWindow(at: Date()) else { throw ProtectionError.noActiveWindow }
        let shared = try SharedDeviceStore()
        shared.testUntil = nil
        shared.overrideUntil = window.end
        center.stopMonitoring([SharedDeviceStore.testName])
        try shared.reconcile()
        refresh(plan: plan, enabled: enabled)
    }

    func reset() throws {
        // Stop enforcement even if shared storage has become unavailable.
        deactivate(shared: try? SharedDeviceStore())
        if let shared = try? SharedDeviceStore() { shared.reset() }
        selection = FamilyActivitySelection()
        restoredSelection = true
        enabled = false
        decision = .needsAuthorization
        issue = nil
    }
    func suspendForStorageError() {
        deactivate(shared: try? SharedDeviceStore())
        decision = .off
        issue = "Your local data needs recovery. App protection is off."
    }

    private func deactivate(shared: SharedDeviceStore?) {
        shared?.disable()
        center.stopMonitoring(SharedDeviceStore.allNames)
        ManagedSettingsStore(named: SharedDeviceStore.settingsName).clearAllSettings()
        enabled = false
    }

    private func authorizationChanged(_ status: AuthorizationStatus) {
        guard status != authorizationStatus else { return }
        authorizationStatus = status
        guard status != .approved else { return }
        let shared = try? SharedDeviceStore()
        // Apple invalidates all previously selected tokens on revocation.
        selection = FamilyActivitySelection()
        restoredSelection = true
        try? shared?.saveSelection(selection)
        shared?.wasAuthorized = false
        deactivate(shared: shared)
        decision = .needsAuthorization
        issue = nil
    }
    #else
    var isSupported: Bool { false }
    var isAuthorized: Bool { false }
    var selectionCount: Int { 0 }
    func requestAuthorization() async throws { throw ProtectionError.unavailable }
    func saveSelection() throws {}
    func configure(plan: BedtimePlan, enabled: Bool) throws {
        if enabled { throw ProtectionError.unavailable }
        self.enabled = false
    }
    func refresh(plan: BedtimePlan, enabled: Bool) { decision = .unavailable }
    func startTest(plan: BedtimePlan) throws { throw ProtectionError.unavailable }
    func stopTest(plan: BedtimePlan) throws {}
    func overrideTonight(plan: BedtimePlan) throws {}
    func reset() throws { enabled = false; issue = nil; decision = .unavailable }
    func suspendForStorageError() { decision = .unavailable }
    #endif
}
