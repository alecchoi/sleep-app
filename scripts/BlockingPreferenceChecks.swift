import Foundation
import SleepCore

@main enum BlockingPreferenceChecks {
    @MainActor static func main() async throws {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--data-directory"), arguments.count > index + 1 else {
            fatalError("A private test data directory is required")
        }
        let base = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        let store = JournalStore(url: base.appendingPathComponent("journal.json"))
        let files = FileManager.default
        let defaultsName = "com.sleepapp.preference-checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            try? files.removeItem(at: base)
            defaults.removePersistentDomain(forName: defaultsName)
        }

        func require(_ value: Bool, _ message: String) {
            if !value { fatalError(message) }
        }
        func seed() throws {
            try? files.removeItem(at: base)
            var initial = AppSnapshot()
            initial.protectionEnabled = true
            try store.save(initial)
        }

        try seed()
        let model = AppModel(defaults: defaults)
        require(model.snapshot.protectionEnabled, "Fixture must start with protection enabled")
        // Replace this test's data directory with a file to force an atomic-save
        // failure, without changing permissions or touching a user's journal.
        try files.removeItem(at: base)
        try Data("unwritable test destination".utf8).write(to: base)
        model.setProtectionEnabled(false)
        require(!model.snapshot.protectionEnabled, "Off must survive a failed journal write")
        require(!model.protection.enabled, "Failed saving must not reactivate protection")
        require(model.errorMessage != nil, "The unsaved preference must be reported")
        print("PASS explicit off survives journal write failure")

        try seed()
        let restored = AppModel(defaults: defaults)
        // The preview's protection service is off. Refresh must reconcile an
        // older journal that still says on, and persist the effective off state.
        restored.refreshProtection()
        require(!restored.snapshot.protectionEnabled, "Refresh must reflect the service's off state")
        require(try !store.load().protectionEnabled, "Reconciled off must be saved for relaunch")
        print("PASS stale enabled preference reconciles to an inactive service")

        try seed()
        var legacy = try store.load()
        legacy.plan.activity = .reading
        legacy.sessions = [ActivitySession(activity: .reading, finishedAt: Date(timeIntervalSince1970: 1_000))]
        legacy.revisions = [PlanRevision(effectiveFrom: Date(timeIntervalSince1970: 500), plan: legacy.plan)]
        try store.save(legacy)
        defaults.set(false, forKey: "breathingHapticsEnabled")
        let migrated = AppModel(defaults: defaults)
        require(migrated.plan.activity == .breathing, "Existing readers must get the breathing routine")
        require(!migrated.breathingPreferences.hapticsEnabled, "Previously disabled vibration must remain disabled")
        require(migrated.snapshot.sessions == legacy.sessions, "Reading history must be retained")
        require(migrated.snapshot.revisions == legacy.revisions, "Historical bedtime plans must not change")
        require(try store.load().plan.activity == .breathing, "Current routine migration must persist")
        require(defaults.object(forKey: "breathingHapticsEnabled") == nil, "Successful migration must consume the legacy preference")
        migrated.finishActivity()
        require(migrated.snapshot.sessions.last?.activity == .breathing, "New completions must record breathing")
        print("PASS returning readers migrate with vibration and history preserved")

        let preferences = BreathingPreferences(duration: .twentyMinutes, hapticsEnabled: false)
        require(migrated.setBreathingPreferences(preferences), "Preferences must save")
        let relaunched = AppModel(defaults: defaults)
        require(relaunched.breathingPreferences == preferences, "Preferences must survive relaunch")
        var editedPlan = relaunched.plan
        editedPlan.bedtime = ClockTime(hour: 22)
        let planSaved = await relaunched.savePlan(editedPlan)
        require(planSaved, "A bedtime edit must save")
        require(try store.load().breathingPreferences == preferences, "A bedtime edit must retain breathing preferences")
        let exported = try JSONDecoder.sleepApp.decode(AppSnapshot.self, from: relaunched.exportData()!)
        require(exported.breathingPreferences == preferences, "Data export must include preferences")
        print("PASS breathing preferences survive relaunch, bedtime edits, and export")

        try files.removeItem(at: base)
        try Data("unwritable test destination".utf8).write(to: base)
        require(!relaunched.setBreathingPreferences(BreathingPreferences()), "A failed save must report failure")
        require(relaunched.breathingPreferences == preferences, "Failed saving must retain the last saved choices")
        require(relaunched.errorMessage != nil, "A failed preference write must be visible")
        print("PASS failed breathing preference save preserves prior choices")

        try seed()
        let reset = AppModel(defaults: defaults)
        require(reset.setBreathingPreferences(preferences), "Reset fixture preferences must save")
        reset.resetLocalData()
        require(reset.breathingPreferences == BreathingPreferences(), "Reset must clear saved breathing preferences")
        require(AppModel(defaults: defaults).breathingPreferences == BreathingPreferences(), "Reset defaults must survive relaunch")
        print("PASS local data deletion resets breathing preferences")
        print("6 app preference checks; 0 failures (preview service, no live Screen Time)")
    }
}
