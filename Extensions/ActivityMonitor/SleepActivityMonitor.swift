import DeviceActivity
import Foundation
import ManagedSettings

final class SleepActivityMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        reconcile()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == SharedDeviceStore.testName {
            // stopMonitoring also sends this callback. An old callback must not
            // erase the deadline of a test the user has just restarted.
            if let shared = try? SharedDeviceStore() { shared.expireTest() }
        }
        reconcile()
    }

    private func reconcile() {
        do { try SharedDeviceStore().reconcile() }
        catch {
            ManagedSettingsStore(named: .init("sleepapp.bedtime")).clearAllSettings()
        }
    }
}
