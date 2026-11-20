import SwiftUI

enum AppSheet: String, Identifiable {
    case windDown, protection, plan, breathingGuide
    var id: String { rawValue }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var finishedAt: Date?
    @State private var quietUntil: Date?
    var body: some View {
        @Bindable var model = model
        Group {
            if !model.storageIsHealthy {
                // Recovery must remain reachable without overwriting damaged data.
                SettingsView()
            } else if finishedAt != nil {
                QuietEndingView()
            } else {
                TabView(selection: $tab) {
                    BreathingHomeView(onDone: finishNight)
                        .tabItem { Label("Breathe", systemImage: "wind") }.tag(0)
                    MorningsView().tabItem { Label("Mornings", systemImage: "sun.max") }.tag(1)
                    SettingsView().tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(2)
                }
            }
        }
        .foregroundStyle(SleepTheme.text)
        .background(SleepTheme.background)
        .animation(.easeIn(duration: 0.4), value: finishedAt != nil)
        .onChange(of: scenePhase) {
            // Locking and reopening the phone keeps tonight's quiet ending.
            // The next visit after the saved wake time restores morning access,
            // including when the person finished after midnight.
            if scenePhase == .active, let quietUntil, Date() >= quietUntil {
                self.finishedAt = nil
                self.quietUntil = nil
                tab = 0
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            repeat {
                await model.refreshServices()
                do { try await Task.sleep(for: .seconds(30)) }
                catch { return }
            } while !Task.isCancelled
        }
        .alert("A little attention needed", isPresented: Binding(
            get: { finishedAt == nil && model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func finishNight() {
        guard finishedAt == nil else { return }
        let finishedAt = Date()
        self.finishedAt = finishedAt
        quietUntil = Calendar.current.nextDate(
            after: finishedAt,
            matching: DateComponents(hour: model.plan.wakeTime.hour, minute: model.plan.wakeTime.minute),
            matchingPolicy: .nextTimePreservingSmallerComponents
        )
        model.finishActivity()
    }
}

private struct BreathingHomeView: View {
    @Environment(AppModel.self) private var model
    let onDone: () -> Void

    var body: some View {
        ZStack {
            NightBackground()
            BreathingView(preferences: model.breathingPreferences, onDone: onDone)
        }
    }
}
