import SwiftUI
import SleepCore
#if os(iOS) && !SLEEPAPP_PREVIEW && !targetEnvironment(simulator)
import FamilyControls
#endif

struct ProtectionSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var choosingApps = false
    @State private var authorizing = false
    @State private var confirmOverride = false
    @State private var setupError: String?
    @State private var selectionError: String?
    #if os(iOS) && !SLEEPAPP_PREVIEW && !targetEnvironment(simulator)
    @State private var draftSelection = FamilyActivitySelection()
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.largeTitle).foregroundStyle(SleepTheme.lavender)
                    Text("Choose what\ncan wait.")
                        .font(.system(.largeTitle, design: .default))
                    if model.protection.isSupported {
                        Text("Choose specific distracting apps and websites. Keep calls, alarms, transport, and other essential tools available by leaving them unselected.")
                            .font(.subheadline).foregroundStyle(SleepTheme.secondary)
                        nativeControls
                        ProtectionSummary(decision: model.protection.decision, issue: model.protection.issue)
                    } else {
                        SleepCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("App blocking requires the full iPhone app", systemImage: "lock.shield")
                                    .font(.headline)
                                Text("This preview cannot request Screen Time access or block other apps, even when installed on an iPhone. The full app lets you choose apps in Apple's private picker and blocks them during your wind-down schedule.")
                                    .font(.subheadline).foregroundStyle(SleepTheme.secondary)
                            }
                        }
                        SleepCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("How blocking works").font(.headline)
                                Text("1. Allow Screen Time access.\n2. Choose apps, categories, or websites.\n3. Enable nightly protection or run a 20-minute test.")
                                    .font(.subheadline).foregroundStyle(SleepTheme.secondary).lineSpacing(6)
                            }
                        }
                    }
                    Text(model.protection.isSupported ?
                         "You stay in control. You can change your selection or turn protection off anytime." :
                         "Start your quiet activity anytime from Tonight.")
                        .font(.footnote).foregroundStyle(SleepTheme.secondary)
                }
                .padding(24).frame(maxWidth: 540).frame(maxWidth: .infinity)
            }
            .background(SleepTheme.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { model.refreshProtection() }
            .alert("App selection needs attention", isPresented: Binding(
                get: { setupError != nil }, set: { if !$0 { setupError = nil } }
            )) {
                Button("OK") { setupError = nil }
            } message: { Text(setupError ?? "") }
            .confirmationDialog("Allow access for the rest of this night?", isPresented: $confirmOverride) {
                Button("Allow for this night") {
                    do { try model.protection.overrideTonight(plan: model.plan) }
                    catch { model.errorMessage = error.localizedDescription }
                }
            } message: {
                Text("Selected apps will be available for the rest of this protection window. Future scheduled nights stay enabled.")
            }
            #if os(iOS) && !SLEEPAPP_PREVIEW && !targetEnvironment(simulator)
            .sheet(isPresented: $choosingApps) { selectionSheet }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 390, minHeight: 640)
        #endif
    }

    @ViewBuilder private var nativeControls: some View {
        PrimaryButton(title: authorizing ? "Requesting access…" :
                      (model.protection.selectionCount == 0 ? "Choose apps to block" : "Change selected apps"),
                      symbol: "apps.iphone") { chooseApps() }
            .disabled(authorizing || model.isUpdatingPreferences)
            .accessibilityIdentifier("protection.chooseApps")
        if !model.protection.isAuthorized {
            Text("First, allow Screen Time access. Then choose your apps in Apple's private picker.")
                .font(.footnote).foregroundStyle(SleepTheme.secondary)
        } else if model.protection.selectionCount > 0 {
                Text("\(model.protection.selectionCount) selected items")
                    .font(.footnote).foregroundStyle(SleepTheme.secondary)
                Toggle("Nightly app protection", isOn: Binding(
                    get: { model.snapshot.protectionEnabled },
                    set: { model.setProtectionEnabled($0) }
                ))
                    .padding(.vertical, 8)
                    .disabled(model.isUpdatingPreferences)
                    .accessibilityIdentifier("protection.nightly")
                Text("Turning this off also ends any protection test. Your selected apps stay saved.")
                    .font(.footnote).foregroundStyle(SleepTheme.secondary)
                if case .testing = model.protection.decision {
                    Button("Stop protection test") {
                        do { try model.protection.stopTest(plan: model.plan) }
                        catch { model.errorMessage = error.localizedDescription }
                    }.frame(minHeight: 44)
                        .accessibilityIdentifier("protection.stopTest")
                } else {
                    Button("Test protection for 20 minutes") {
                        do { try model.protection.startTest(plan: model.plan) }
                        catch { model.errorMessage = error.localizedDescription }
                    }.frame(minHeight: 44)
                        .accessibilityIdentifier("protection.startTest")
                }
                Text("Open a selected app to check its shield. You can stop the test here anytime.")
                    .font(.footnote).foregroundStyle(SleepTheme.secondary)
                if case .active = model.protection.decision {
                    Button("I need access for this night") { confirmOverride = true }
                        .frame(minHeight: 44)
                }
        }
    }

    private func chooseApps() {
        guard model.protection.isSupported else { return }
        authorizing = true
        Task {
            defer { authorizing = false }
            do {
                if !model.protection.isAuthorized { try await model.protection.requestAuthorization() }
                model.refreshProtection()
                guard model.protection.isAuthorized else { throw ProtectionError.authorization }
                #if os(iOS) && !SLEEPAPP_PREVIEW && !targetEnvironment(simulator)
                draftSelection = model.protection.selection
                choosingApps = true
                #endif
            } catch { setupError = error.localizedDescription }
        }
    }

    #if os(iOS) && !SLEEPAPP_PREVIEW && !targetEnvironment(simulator)
    private var selectionSheet: some View {
        return NavigationStack {
            FamilyActivityPicker(selection: $draftSelection)
                .navigationTitle("Choose apps to block")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { choosingApps = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save selection") {
                            if model.updateSelectedApps(draftSelection) { choosingApps = false }
                            else {
                                selectionError = model.errorMessage
                                model.errorMessage = nil
                            }
                        }.disabled(model.isUpdatingPreferences)
                    }
                }
                .alert("Selection couldn't be saved", isPresented: Binding(
                    get: { selectionError != nil }, set: { if !$0 { selectionError = nil } }
                )) {
                    Button("OK") { selectionError = nil }
                } message: { Text(selectionError ?? "") }
        }
        .interactiveDismissDisabled()
    }
    #endif
}
