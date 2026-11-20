import Foundation
import Observation
import SleepCore
#if os(iOS) && !SLEEPAPP_PREVIEW && !targetEnvironment(simulator)
import FamilyControls
#endif

@Observable @MainActor
final class AppModel {
    private(set) var snapshot: AppSnapshot
    let protection = ProtectionController()
    let reminders = ReminderController()
    private(set) var now = Date()
    private(set) var isUpdatingPreferences = false
    var errorMessage: String?
    private(set) var storageIsHealthy = true
    @ObservationIgnored private let store: JournalStore
    @ObservationIgnored private let defaults: UserDefaults

    var plan: BedtimePlan { snapshot.plan }
    var breathingPreferences: BreathingPreferences { snapshot.breathingPreferences }
    var onboarded: Bool { snapshot.onboarded }
    var mornings: [MorningEntry] { snapshot.mornings.sorted { $0.window.start > $1.window.start } }
    var pendingNights: [NightWindow] {
        NightHistory.recentNights(before: now, revisions: snapshot.revisions)
            .filter { night in !snapshot.mornings.contains { $0.window.start == night.start } }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let arguments = ProcessInfo.processInfo.arguments
        let base: URL
        #if DEBUG
        if let index = arguments.firstIndex(of: "--data-directory"), arguments.count > index + 1 {
            base = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        } else {
            base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SleepApp", isDirectory: true)
        }
        #else
        base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SleepApp", isDirectory: true)
        #endif
        store = JournalStore(url: base.appendingPathComponent("journal.json"))
        do { snapshot = try store.load() }
        catch {
            snapshot = AppSnapshot()
            storageIsHealthy = false
            errorMessage = "Your saved data could not be opened. The original file is preserved. You can export it or reset local data in Settings. \(error.localizedDescription)"
        }
        guard storageIsHealthy else { return }
        let legacyHaptics = defaults.object(forKey: "breathingHapticsEnabled") as? Bool
        var migrated = snapshot
        // Retain historical readings in the journal while making the current
        // routine breathing-only for both new and returning users.
        migrated.plan.activity = .breathing
        if let legacyHaptics { migrated.breathingPreferences.hapticsEnabled = legacyHaptics }
        if migrated != snapshot || legacyHaptics != nil {
            snapshot = migrated
            do {
                try store.save(migrated)
                defaults.removeObject(forKey: "breathingHapticsEnabled")
            } catch {
                errorMessage = "Your routine preferences could not be saved. \(error.localizedDescription)"
            }
        }
    }

    @discardableResult
    func savePlan(_ proposedPlan: BedtimePlan, completeSetup: Bool = false) async -> Bool {
        guard !isUpdatingPreferences else { return false }
        isUpdatingPreferences = true
        defer { isUpdatingPreferences = false }
        var plan = proposedPlan
        plan.activity = .breathing
        do {
            try plan.validate()
            guard storageIsHealthy else { throw JournalError.invalidData }
            var updated = snapshot
            if updated.revisions.isEmpty || updated.plan != plan {
                updated.revisions.append(PlanRevision(effectiveFrom: Date(), plan: plan))
            }
            updated.plan = plan
            if completeSetup { updated.onboarded = true }
            if updated.protectionEnabled {
                do { try protection.configure(plan: plan, enabled: true) }
                catch {
                    updated.protectionEnabled = false
                    errorMessage = "Your bedtime plan is saved. App protection needs attention: \(error.localizedDescription)"
                }
            }
            if updated.remindersEnabled {
                do { try await reminders.configure(plan: plan, enabled: true) }
                catch {
                    updated.remindersEnabled = false
                    errorMessage = "Your bedtime plan is saved. The reminder is off: \(error.localizedDescription)"
                }
            }
            // Preserve check-ins or activity completions made while scheduling awaited the OS.
            updated.mornings = snapshot.mornings
            updated.sessions = snapshot.sessions
            try store.save(updated)
            snapshot = updated
            now = Date()
            return true
        } catch {
            if storageIsHealthy {
                try? protection.configure(plan: snapshot.plan, enabled: snapshot.protectionEnabled)
                await reminders.refresh(plan: snapshot.plan, enabled: snapshot.remindersEnabled)
            } else {
                protection.suspendForStorageError()
                reminders.removePending()
            }
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func setBreathingPreferences(_ preferences: BreathingPreferences) -> Bool {
        guard !isUpdatingPreferences else { return false }
        do {
            guard storageIsHealthy else { throw JournalError.invalidData }
            var updated = snapshot
            updated.breathingPreferences = preferences
            try store.save(updated)
            snapshot = updated
            // A successful settings change supersedes a legacy migration that
            // may previously have failed to write.
            defaults.removeObject(forKey: "breathingHapticsEnabled")
            return true
        } catch {
            errorMessage = "Your breathing preferences could not be saved. \(error.localizedDescription)"
            return false
        }
    }

    func refreshProtection() {
        guard storageIsHealthy else { protection.suspendForStorageError(); return }
        protection.refresh(plan: plan, enabled: snapshot.protectionEnabled)
        if snapshot.protectionEnabled && !protection.enabled {
            var updated = snapshot
            updated.protectionEnabled = false
            snapshot = updated
            do { try store.save(updated) }
            catch { errorMessage = "App protection is off. The preference could not be saved: \(error.localizedDescription)" }
        }
    }

    func refreshServices() async {
        now = Date()
        guard !isUpdatingPreferences else { return }
        isUpdatingPreferences = true
        defer { isUpdatingPreferences = false }
        refreshProtection()
        if storageIsHealthy {
            await reminders.refresh(plan: plan, enabled: snapshot.remindersEnabled)
        } else { reminders.removePending() }
    }

    func setRemindersEnabled(_ enabled: Bool) async {
        guard !isUpdatingPreferences else { return }
        isUpdatingPreferences = true
        defer { isUpdatingPreferences = false }
        do {
            guard storageIsHealthy else { throw JournalError.invalidData }
            try await reminders.configure(plan: plan, enabled: enabled, requestPermission: enabled)
            var updated = snapshot
            updated.remindersEnabled = enabled
            try store.save(updated)
            snapshot = updated
        } catch {
            if storageIsHealthy {
                await reminders.refresh(plan: plan, enabled: snapshot.remindersEnabled)
            } else { reminders.removePending() }
            errorMessage = error.localizedDescription
        }
    }

    func setProtectionEnabled(_ enabled: Bool) {
        guard !isUpdatingPreferences else { return }
        if !enabled {
            // An explicit off action must never roll back into a block merely
            // because the journal cannot be written. Shared intent is also off.
            do {
                try protection.configure(plan: plan, enabled: false)
                var updated = snapshot
                updated.protectionEnabled = false
                snapshot = updated
                if storageIsHealthy { try store.save(updated) }
            } catch {
                errorMessage = "App protection is off. The preference could not be saved: \(error.localizedDescription)"
            }
            return
        }
        do {
            guard storageIsHealthy else { throw JournalError.invalidData }
            try protection.configure(plan: plan, enabled: enabled)
            var updated = snapshot
            updated.protectionEnabled = enabled
            do { try store.save(updated); snapshot = updated }
            catch {
                // Roll back enforcement if saving the user's preference fails.
                try? protection.configure(plan: plan, enabled: snapshot.protectionEnabled)
                throw error
            }
        } catch { errorMessage = error.localizedDescription }
    }

    #if os(iOS) && !SLEEPAPP_PREVIEW && !targetEnvironment(simulator)
    @discardableResult
    func updateSelectedApps(_ selection: FamilyActivitySelection) -> Bool {
        guard !isUpdatingPreferences else { return false }
        guard storageIsHealthy else { errorMessage = JournalError.invalidData.localizedDescription; return false }
        let previous = protection.selection
        protection.selection = selection
        do {
            try protection.saveSelection()
            if protection.selectionCount == 0 {
                // Removing the last target is a valid edit and ends any test.
                try protection.configure(plan: plan, enabled: false)
                var updated = snapshot
                updated.protectionEnabled = false
                try store.save(updated)
                snapshot = updated
            } else if snapshot.protectionEnabled {
                try protection.configure(plan: plan, enabled: true)
            }
            refreshProtection()
            return true
        } catch {
            protection.selection = previous
            try? protection.saveSelection()
            if snapshot.protectionEnabled { try? protection.configure(plan: plan, enabled: true) }
            refreshProtection()
            errorMessage = error.localizedDescription
            return false
        }
    }
    #endif

    @discardableResult
    func recordMorning(_ entry: MorningEntry) -> Bool {
        do {
            guard storageIsHealthy else { throw JournalError.invalidData }
            try entry.validate()
            var updated = snapshot
            updated.mornings.removeAll { $0.window.start == entry.window.start }
            updated.mornings.append(entry)
            try store.save(updated)
            snapshot = updated
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func finishActivity() {
        do {
            guard storageIsHealthy else { throw JournalError.invalidData }
            var updated = snapshot
            updated.sessions.append(ActivitySession(activity: .breathing, finishedAt: Date()))
            try store.save(updated)
            snapshot = updated
        } catch { errorMessage = error.localizedDescription }
    }

    func resetLocalData() {
        guard !isUpdatingPreferences else { return }
        do {
            try protection.reset()
            reminders.removePending()
            try store.delete()
            defaults.removeObject(forKey: "readerFontSize")
            defaults.removeObject(forKey: "breathingHapticsEnabled")
            snapshot = AppSnapshot()
            storageIsHealthy = true
        } catch { errorMessage = error.localizedDescription }
    }

    func exportData() -> Data? {
        do {
            // Permit exporting a damaged original file without overwriting it.
            if !storageIsHealthy { return try Data(contentsOf: store.url) }
            return try JSONEncoder.sleepApp.encode(snapshot)
        } catch { errorMessage = error.localizedDescription; return nil }
    }
}
