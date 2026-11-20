import SwiftUI
import SleepCore

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var draft = BedtimePlan()
    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Label("SLEEP APP", systemImage: "moon").font(.caption.weight(.semibold)).tracking(2)
                        Spacer()
                        Text("\(step + 1) of 2").font(.caption).foregroundStyle(SleepTheme.secondary)
                    }
                    .padding(.top, 20)
                    if step == 0 { welcome }
                    else { schedule }
                    if step > 0 {
                        Button("Back") { move(to: step - 1) }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(SleepTheme.secondary)
                            .buttonStyle(.plain)
                    }
                    if !model.storageIsHealthy {
                        Button("Reset local data", role: .destructive) { showReset = true }
                            .frame(minHeight: 44)
                    }
                }
                .padding(28)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { draft = model.plan }
        .confirmationDialog("Delete all local Sleep App data?", isPresented: $showReset) {
            Button("Delete local data", role: .destructive) { model.resetLocalData() }
        }
    }
    @State private var showReset = false

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            MoonIllustration().padding(.top, 10)
            Text("Your night,\nback to you.")
                .font(.system(.largeTitle, design: .default).weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Text("A little space between the feed and sleep. Set your bedtime, take a few unhurried breaths, and let the day end.")
                .font(.body).foregroundStyle(SleepTheme.secondary).lineSpacing(5)
            PrimaryButton(title: "Make room for rest", symbol: "arrow.right") { move(to: 1) }
            Text("No account. No streak to keep. Your own pace.")
                .font(.footnote).foregroundStyle(SleepTheme.secondary)
        }
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("When does\nyour day end?").font(.system(.largeTitle, design: .default))
            Text("Make a plan for when you want to try sleeping. You can change it anytime.")
                .foregroundStyle(SleepTheme.secondary)
            PlanFields(plan: $draft)
            PrimaryButton(title: "Save my evening", symbol: "moon") {
                Task { _ = await model.savePlan(draft, completeSetup: true) }
            }
            .disabled(model.isUpdatingPreferences)
            Text("Your breathing routine is ready. You can make it yours in Settings anytime.")
                .font(.footnote).foregroundStyle(SleepTheme.secondary)
        }
    }

    private func move(to step: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { self.step = step }
    }
}

struct PlanFields: View {
    @Binding var plan: BedtimePlan
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SleepCard {
                VStack(spacing: 10) {
                    ClockPicker(title: "Try sleeping at", time: $plan.bedtime)
                    Divider()
                    ClockPicker(title: "Wake up at", time: $plan.wakeTime)
                    Divider()
                    Picker("Wind-down", selection: $plan.windDownMinutes) {
                        ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                            Text("\(minutes) minutes before").tag(minutes)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            Eyebrow(text: "NIGHTS THAT FIT YOUR LIFE")
            WeekdayPicker(days: $plan.weekdays)
            Text("Days refer to when wind-down starts. Your current time zone is used.")
                .font(.footnote).foregroundStyle(SleepTheme.secondary)
        }
    }
}
