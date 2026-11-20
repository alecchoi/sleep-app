import SwiftUI

@main
struct SleepApp: App {
    @State private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(SleepTheme.lavender)
                #if os(macOS)
                .frame(minWidth: 390, idealWidth: 430, minHeight: 740, idealHeight: 880)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 430, height: 880)
        #endif
    }
}
