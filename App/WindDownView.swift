import SwiftUI

struct WindDownView: View {
    @Environment(AppModel.self) private var model
    @State private var finished = false
    var body: some View {
        NavigationStack {
            ZStack {
                NightBackground()
                if finished {
                    QuietEndingView()
                } else {
                    BreathingView(preferences: model.breathingPreferences, onDone: finish)
                }
            }
            .toolbar(.hidden, for: .automatic)
        }
        .interactiveDismissDisabled()
        .animation(.easeIn(duration: 0.4), value: finished)
        #if os(macOS)
        .frame(minWidth: 390, idealWidth: 430, minHeight: 740)
        #endif
    }
    private func finish() {
        guard !finished else { return }
        model.finishActivity()
        finished = true
    }
}

struct QuietEndingView: View {
    @AccessibilityFocusState private var messageIsFocused: Bool

    var body: some View {
        ZStack {
            SleepTheme.background.ignoresSafeArea()
            Text("The rest can wait.\nPut your phone down.")
                .font(.title2.weight(.regular))
                .foregroundStyle(SleepTheme.text)
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .fixedSize(horizontal: false, vertical: true)
                .padding(32)
                .frame(maxWidth: 500)
                .accessibilityFocused($messageIsFocused)
                .accessibilityIdentifier("breathing.goodnight")
        }
        .task { messageIsFocused = true }
    }
}
