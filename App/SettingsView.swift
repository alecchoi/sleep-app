import SwiftUI
import UniformTypeIdentifiers
import SleepCore

struct JournalDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: AppSheet?
    @State private var showReset = false
    @State private var export: JournalDocument?
    @State private var showExport = false
    var body: some View {
        NavigationStack {
            ZStack {
                NightBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Eyebrow(text: "MAKE IT YOURS")
                        Text("Your evening,\nyour way.").font(.system(.largeTitle, design: .default))
                        SleepCard {
                            VStack(spacing: 8) {
                                settingsButton("Bedtime plan", symbol: "moon", detail: model.plan.bedtime.display) { sheet = .plan }
                                Divider()
                                settingsButton("App protection", symbol: "shield", detail: "Manage") { sheet = .protection }
                            }
                        }
                        Eyebrow(text: "YOUR BREATHING ROUTINE")
                        SleepCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Picker("Session length", selection: Binding(
                                    get: { model.breathingPreferences.duration },
                                    set: { duration in
                                        var preferences = model.breathingPreferences
                                        preferences.duration = duration
                                        model.setBreathingPreferences(preferences)
                                    }
                                )) {
                                    ForEach(BreathingDuration.allCases) { duration in
                                        Text("\(duration.rawValue) minutes").tag(duration)
                                    }
                                }
                                .accessibilityIdentifier("settings.breathing.duration")
                                Divider()
                                Toggle("Vibration", isOn: Binding(
                                    get: { model.breathingPreferences.hapticsEnabled },
                                    set: { enabled in
                                        var preferences = model.breathingPreferences
                                        preferences.hapticsEnabled = enabled
                                        model.setBreathingPreferences(preferences)
                                    }
                                ))
                                .tint(SleepTheme.lavender)
                                .accessibilityIdentifier("settings.breathing.haptics")
                                Text("Saved for every night. Vibration plays on supported iPhones.")
                                    .font(.footnote).foregroundStyle(SleepTheme.secondary)
                                Divider()
                                settingsButton("How breathing works", symbol: "questionmark.circle", detail: "") {
                                    sheet = .breathingGuide
                                }
                                .accessibilityIdentifier("settings.breathing.guide")
                            }
                            .disabled(model.isUpdatingPreferences || !model.storageIsHealthy)
                        }
                        Eyebrow(text: "A GENTLE NUDGE")
                        SleepCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Wind-down reminder", isOn: Binding(
                                    get: { model.snapshot.remindersEnabled },
                                    set: { enabled in Task { await model.setRemindersEnabled(enabled) } }
                                ))
                                .disabled(model.isUpdatingPreferences)
                                .accessibilityHint("One quiet local notification on each selected night.")
                                Text(model.reminders.statusText)
                                    .font(.footnote).foregroundStyle(SleepTheme.secondary)
                                Text("No sound or badge. Delivery follows your notification and Focus settings.")
                                    .font(.footnote).foregroundStyle(SleepTheme.secondary)
                            }
                        }
                        Eyebrow(text: "YOUR DATA STAYS WITH YOU")
                        SleepCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Private by default").font(.headline)
                                Text("Your plan and check-ins are saved on this device. This build has no account, advertising, or analytics service.")
                                    .font(.subheadline).foregroundStyle(SleepTheme.secondary)
                                Button {
                                    if let data = model.exportData() {
                                        export = JournalDocument(data: data)
                                        showExport = true
                                    }
                                } label: { Label("Export my data", systemImage: "square.and.arrow.up") }
                                    .frame(minHeight: 44)
                                Button("Delete local data", role: .destructive) { showReset = true }
                                    .frame(minHeight: 44)
                                    .disabled(model.isUpdatingPreferences)
                            }
                        }
                        Text("Sleep App · First development build\nMade for a gentler end to the day.")
                            .font(.footnote).foregroundStyle(SleepTheme.secondary).lineSpacing(6)
                    }
                    .padding(24)
                    .frame(maxWidth: 540).frame(maxWidth: .infinity)
                }
            }
            .sheet(item: $sheet) { item in
                switch item {
                case .plan: EditPlanView(plan: model.plan)
                case .protection: ProtectionSetupView()
                case .windDown: WindDownView()
                case .breathingGuide: BreathingGuideView()
                }
            }
            .confirmationDialog("Delete all local Sleep App data?", isPresented: $showReset) {
                Button("Delete local data", role: .destructive) { model.resetLocalData() }
            } message: { Text("This removes your plan, breathing preferences, and check-ins, and turns off reminders and Sleep App protection.") }
            .fileExporter(isPresented: $showExport, document: export, contentType: .json,
                          defaultFilename: "SleepApp_Data") { result in
                if case .failure(let error) = result { model.errorMessage = error.localizedDescription }
            }
        }
    }

    private func settingsButton(_ title: String, symbol: String, detail: String,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: symbol).frame(width: 28).foregroundStyle(SleepTheme.lavender)
                Text(title)
                Spacer(minLength: 6)
                Text(detail).font(.footnote).foregroundStyle(SleepTheme.secondary)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(SleepTheme.secondary)
            }.padding(.vertical, 10).frame(minHeight: 44)
        }.buttonStyle(.plain).disabled(model.isUpdatingPreferences)
    }
}

struct EditPlanView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BedtimePlan
    // Intentional one-time edit buffer. Cancel does not mutate the saved plan.
    init(plan: BedtimePlan) { _draft = State(initialValue: plan) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PlanFields(plan: $draft)
                    PrimaryButton(title: "Save my evening") {
                        Task { if await model.savePlan(draft) { dismiss() } }
                    }
                    .disabled(model.isUpdatingPreferences)
                }.padding(24).frame(maxWidth: 540).frame(maxWidth: .infinity)
            }
            .background(SleepTheme.background)
            .navigationTitle("Your bedtime plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 390, minHeight: 680)
        #endif
    }
}
