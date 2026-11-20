import SwiftUI
import SleepCore

struct TonightView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: AppSheet?
    var body: some View {
        NavigationStack {
            ZStack {
                NightBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Eyebrow(text: "SLEEP APP")
                            Spacer()
                            Image(systemName: "sparkle").foregroundStyle(SleepTheme.lavender)
                                .accessibilityHidden(true)
                        }
                        .padding(.top, 12)
                        Text("The day\ncan wait.")
                            .font(.system(.largeTitle, design: .default))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("A softer landing for your evening.")
                            .foregroundStyle(SleepTheme.secondary)
                        MoonIllustration(compact: true).frame(maxWidth: .infinity)
                        SleepCard {
                            HStack(alignment: .top) {
                                timeColumn("TRY SLEEPING AT", time: model.plan.bedtime.display, symbol: "moon")
                                Spacer(minLength: 12)
                                timeColumn("WAKE UP AT", time: model.plan.wakeTime.display, symbol: "sun.horizon")
                            }
                            Divider().padding(.vertical, 10)
                            Text("Wind-down starts at \(model.plan.cutoff.display)")
                                .font(.footnote).foregroundStyle(SleepTheme.secondary)
                        }

                        Button { sheet = .protection } label: {
                            ProtectionSummary(decision: model.protection.decision, issue: model.protection.issue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Open app selection and protection settings.")
                        .accessibilityIdentifier("protection.open")

                        VStack(alignment: .leading, spacing: 14) {
                            Eyebrow(text: "YOUR QUIET MOMENT")
                            HStack(spacing: 16) {
                                Image(systemName: "wind")
                                    .font(.title2).foregroundStyle(SleepTheme.lavender)
                                    .frame(width: 50, height: 56)
                                    .background(SleepTheme.card, in: .rect(cornerRadius: 16))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("A little room to breathe")
                                        .font(.headline)
                                    Text("Hold, breathe, let the day go.")
                                        .font(.footnote).foregroundStyle(SleepTheme.secondary)
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                    .padding(24)
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 10) {
                        PrimaryButton(title: "Begin wind-down", symbol: "moon.stars") { sheet = .windDown }
                        Text("You can stop whenever you feel ready.")
                            .font(.caption).foregroundStyle(SleepTheme.secondary)
                    }
                    .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 12)
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)
                    .background(SleepTheme.background)
                }
            }
            .navigationTitle("")
            .sheet(item: $sheet) { item in
                switch item {
                case .windDown: WindDownView()
                case .protection: ProtectionSetupView()
                case .plan: EditPlanView(plan: model.plan)
                case .breathingGuide: BreathingGuideView()
                }
            }
        }
    }

    private func timeColumn(_ title: String, time: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(.caption2).weight(.medium))
                .tracking(1).foregroundStyle(SleepTheme.secondary)
            Label(time, systemImage: symbol).font(.title3.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ProtectionSummary: View {
    let decision: ProtectionDecision
    let issue: String?
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: active ? "checkmark.shield" : "shield")
                .foregroundStyle(active ? SleepTheme.mint : SleepTheme.lavender)
                .font(.title3)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(issue ?? detail).font(.footnote).foregroundStyle(SleepTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(SleepTheme.secondary)
        }
        .padding(16)
        .background(SleepTheme.card.opacity(0.7), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
    private var active: Bool { issue == nil && decision.shouldShield }
    private var title: String {
        if issue != nil { return "Protection needs attention" }
        switch decision {
        case .unavailable: return "Choose apps to block"
        case .needsAuthorization, .needsSelection: return "Set up app protection"
        case .off: return "App protection is off"
        case .needsRegistration: return "Protection needs setup"
        case .scheduled: return "Your night is scheduled"
        case .active: return "App protection applied"
        case .testing: return "Testing app protection"
        case .overridden: return "Protection paused for this night"
        }
    }
    private var detail: String {
        switch decision {
        case .unavailable: return "App selection requires the full iPhone build."
        case .needsAuthorization: return "Choose which apps to leave until morning."
        case .needsSelection: return "Screen Time allowed. Now choose your apps."
        case .off: return "Your breathing routine is ready."
        case .needsRegistration: return "Open settings to finish configuration."
        case .scheduled(let date): return "Wind-down starts \(date.formatted(date: .abbreviated, time: .shortened))."
        case .active(let date): return "Selected apps protected until \(date.formatted(date: .omitted, time: .shortened))."
        case .testing(let date): return "Scheduled to end at \(date.formatted(date: .omitted, time: .shortened))."
        case .overridden(let date): return "This window ends at \(date.formatted(date: .omitted, time: .shortened))."
        }
    }
}
