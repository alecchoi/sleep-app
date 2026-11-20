import Foundation
import Observation
import UserNotifications
import SleepCore

enum ReminderError: Error, LocalizedError {
    case permissionDenied
    case unavailable
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notifications are off. You can allow them in your device settings, or keep starting your routine from Tonight."
        case .unavailable:
            return "Reminders are available when running the app bundle."
        }
    }
}

@Observable @MainActor
final class ReminderController {
    private(set) var statusText = "Off. Start your routine anytime."
    private(set) var scheduledCount = 0
    private let reminderBody = "Take a few unhurried breaths. The rest can wait."
    private var center: UNUserNotificationCenter { .current() }
    private var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    func configure(plan: BedtimePlan, enabled: Bool, requestPermission: Bool = false) async throws {
        guard isAvailable else {
            statusText = "Start your routine anytime from Tonight."
            if enabled { throw ReminderError.unavailable }
            return
        }
        guard enabled else {
            removePending()
            statusText = "Off. Start your routine anytime."
            return
        }
        let reminders = try WindDownReminder.schedule(for: plan)
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined && requestPermission {
            _ = try await center.requestAuthorization(options: [.alert])
            settings = await center.notificationSettings()
        }
        guard settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional else {
            removePending()
            statusText = "Notifications are off in your device settings."
            throw ReminderError.permissionDenied
        }
        do {
            for reminder in reminders {
                let content = UNMutableNotificationContent()
                content.title = "A little room for rest"
                content.body = reminderBody
                content.sound = nil
                content.interruptionLevel = .passive
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: reminder.dateComponents, repeats: true
                )
                try await center.add(UNNotificationRequest(
                    identifier: reminder.id, content: content, trigger: trigger
                ))
            }
            let wanted = Set(reminders.map(\.id))
            center.removePendingNotificationRequests(
                withIdentifiers: WindDownReminder.identifiers.filter { !wanted.contains($0) }
            )
            scheduledCount = reminders.count
            statusText = "A quiet reminder at \(plan.cutoff.display) on your selected nights."
        } catch {
            removePending()
            statusText = "The reminder could not be scheduled. You can try again."
            throw error
        }
    }

    func refresh(plan: BedtimePlan, enabled: Bool) async {
        guard isAvailable else { return }
        if !enabled {
            removePending()
            statusText = "Off. Start your routine anytime."
            return
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional else {
            removePending()
            statusText = "Notifications are off in your device settings."
            return
        }
        do {
            let expected = try WindDownReminder.schedule(for: plan)
            let pending = await center.pendingNotificationRequests()
                .filter { WindDownReminder.identifiers.contains($0.identifier) }
            let matches = pending.count == expected.count && expected.allSatisfy { reminder in
                pending.contains { request in
                    guard request.identifier == reminder.id,
                          let trigger = request.trigger as? UNCalendarNotificationTrigger else { return false }
                    let components = trigger.dateComponents
                    return components.weekday == reminder.weekday &&
                        components.hour == reminder.time.hour &&
                        components.minute == reminder.time.minute && trigger.repeats &&
                        request.content.body == reminderBody
                }
            }
            if !matches { try await configure(plan: plan, enabled: true) }
            else {
                scheduledCount = pending.count
                statusText = "A quiet reminder at \(plan.cutoff.display) on your selected nights."
            }
        } catch { statusText = error.localizedDescription }
    }

    func removePending() {
        guard isAvailable else { return }
        center.removePendingNotificationRequests(withIdentifiers: WindDownReminder.identifiers)
        center.removeDeliveredNotifications(withIdentifiers: WindDownReminder.identifiers)
        scheduledCount = 0
    }
}
