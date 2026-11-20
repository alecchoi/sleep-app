import SwiftUI
import SleepCore
#if os(iOS)
import UIKit
#endif

struct BreathingView: View {
    let preferences: BreathingPreferences
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var haptics = BreathHaptics()
    @State private var session: BreathingSession
    @State private var phase = BreathingPhase.inhaling
    @State private var isHolding = false
    @State private var isEnding = false
    @State private var previousIdleTimerState: Bool?

    init(preferences: BreathingPreferences, onDone: @escaping () -> Void) {
        self.preferences = preferences
        self.onDone = onDone
        // Seed each new session once from the saved duration. A paused session
        // keeps its exact progress rather than being reset by a view update.
        _session = State(initialValue: BreathingSession(duration: preferences.duration))
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 550
            let diameter = min(320, min(geometry.size.width - 48, max(200, geometry.size.height * 0.5)))
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: compact ? 12 : 24)
                    Text("Let the day go.")
                        .font(compact ? .title2 : .title).multilineTextAlignment(.center)
                        .opacity(isEnding ? 0 : 1)
                    Text("Hold to breathe. Release to pause.")
                        .font(.subheadline).foregroundStyle(SleepTheme.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.bottom, compact ? 24 : 36)
                        .opacity(isEnding ? 0 : 1)

                    Button {} label: {
                        BreathOrb(session: session, isHolding: isHolding,
                                  isSettling: isEnding, reduceMotion: reduceMotion, diameter: diameter)
                    }
                    .buttonStyle(BreathHoldStyle(onPressedChange: setHolding))
                    .disabled(isEnding || session.status == .completed)
                    .accessibilityLabel("Hold to breathe")
                    .accessibilityValue(displayCue)
                    .accessibilityHint("Keep your finger down through breathing in and out. Lift to pause. With VoiceOver, double-tap and hold.")
                    .accessibilityIdentifier("breathing.hold")
                    .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: isHolding) { _, held in
                        held && preferences.hapticsEnabled && haptics.isSupported
                    }

                    VStack(spacing: 12) {
                        Text(displayCue).font(.title3.weight(.medium))
                            .foregroundStyle(SleepTheme.lavender)
                            .accessibilityIdentifier("breathing.phase")
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            sessionReadout(session.snapshot(at: uptime))
                        }
                    }
                    .padding(.top, compact ? 20 : 28)
                    .opacity(isEnding ? 0 : 1)
                    Spacer(minLength: compact ? 12 : 24)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: 500)
                .frame(minHeight: geometry.size.height)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(isEnding)
                .animation(.easeOut(duration: 0.3), value: isEnding)
            }
        }
        .safeAreaInset(edge: .bottom) { controls }
        #if os(iOS)
        .toolbar(isEnding ? .hidden : .automatic, for: .tabBar)
        #endif
        .task { if preferences.hapticsEnabled { haptics.prepare() } }
        .task(id: session.status) { await guideSession() }
        .task(id: isEnding) {
            guard isEnding else { return }
            do { try await Task.sleep(for: .seconds(BreathingSession.settlingDuration)) }
            catch { return }
            guard !Task.isCancelled else { return }
            haptics.stop()
            onDone()
        }
        .onChange(of: preferences.duration) {
            // Settings can update an unstarted home session. A held or paused
            // session retains its current duration and exact progress.
            if !isEnding, session.status == .ready { session = BreathingSession(duration: preferences.duration) }
        }
        .onChange(of: preferences.hapticsEnabled) {
            if preferences.hapticsEnabled && !isEnding {
                haptics.prepare()
                playCurrentPhase()
            } else { haptics.stop() }
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                pause()
                haptics.stop()
            } else if preferences.hapticsEnabled && !isEnding { haptics.prepare() }
        }
        .onDisappear {
            pause()
            haptics.stop()
        }
    }

    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    private var displayCue: String {
        switch session.status {
        case .ready: return "Hold to begin"
        case .paused: return "Hold to continue"
        case .completed: return "Breathe naturally"
        case .running: return phase == .inhaling ? "Breathe in" : "Breathe out"
        }
    }

    @ViewBuilder private func sessionReadout(_ snapshot: BreathingSnapshot) -> some View {
        VStack(spacing: 8) {
            Text("\(snapshot.secondsRemaining / 60):\(String(format: "%02d", snapshot.secondsRemaining % 60)) remaining")
                .font(.caption.monospacedDigit()).foregroundStyle(SleepTheme.secondary)
                .accessibilityLabel("\(snapshot.secondsRemaining / 60) minutes and \(snapshot.secondsRemaining % 60) seconds remaining")
                .accessibilityIdentifier("breathing.remaining")
            ProgressView(value: snapshot.progress)
                .tint(SleepTheme.lavender)
                .accessibilityLabel("Session progress")
                .padding(.top, 8)
        }
        .frame(maxWidth: 180)
    }

    private func cue(for snapshot: BreathingSnapshot) -> String {
        if snapshot.isComplete { return "Breathe naturally" }
        switch snapshot.phase {
        case .inhaling: return "Breathe in"
        case .exhaling: return "Breathe out"
        case nil: return session.status == .paused ? "Hold to continue" : "Hold to begin"
        }
    }

    private var controls: some View {
        Button("Done for tonight") { finish() }
        .font(.footnote).foregroundStyle(SleepTheme.lavender)
        .frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityHint("End here and put your phone down.")
        .accessibilityIdentifier("breathing.done")
        .opacity(isEnding ? 0 : 1)
        .disabled(isEnding)
        .accessibilityHidden(isEnding)
        .animation(.easeOut(duration: 0.3), value: isEnding)
        .frame(height: 52)
        .padding(.horizontal, 28).padding(.vertical, 8)
        .frame(maxWidth: 500).frame(maxWidth: .infinity)
    }

    private func setHolding(_ pressed: Bool) {
        guard !isEnding else { return }
        if pressed {
            guard !isHolding, scenePhase == .active,
                  session.status != .completed else { return }
            isHolding = true
            session.start(at: uptime)
            phase = session.snapshot(at: uptime).phase ?? .inhaling
            keepScreenAwake(true)
            // Begin feedback on touch-down, without a long-press delay or
            // waiting for the asynchronous phase scheduler to start.
            playCurrentPhase()
        } else {
            pause()
        }
    }

    private func pause() {
        guard !isEnding else { return }
        session.pause(at: uptime)
        // A lift at the endpoint must finish too, even if it arrives before
        // the phase scheduler's final callback.
        if session.status == .completed { finish(); return }
        isHolding = false
        haptics.pause()
        keepScreenAwake(false)
    }

    private func finish() {
        guard !isEnding else { return }
        session.finish(at: uptime)
        isEnding = true
        isHolding = false
        haptics.settle(duration: BreathingSession.settlingDuration)
        keepScreenAwake(false)
    }

    @MainActor private func guideSession() async {
        guard isHolding, session.status == .running else { return }
        // Re-sample a monotonic clock at phase boundaries so delays do not
        // accumulate into an increasingly slow rhythm.
        var lastPlayedPhase: BreathingPhase? = phase
        while !Task.isCancelled, isHolding, session.status == .running {
            session.advance(at: uptime)
            if session.status == .completed { finish(); return }
            guard session.status == .running else { return }
            let snapshot = session.snapshot(at: uptime)
            phase = snapshot.phase ?? .inhaling
            if snapshot.phase != lastPlayedPhase {
                playCurrentPhase()
                lastPlayedPhase = snapshot.phase
            }
            announce(cue(for: snapshot))
            do { try await Task.sleep(for: .seconds(max(0.01, snapshot.phaseRemaining))) }
            catch { return }
        }
    }

    private func playCurrentPhase() {
        let snapshot = session.snapshot(at: uptime)
        guard !isEnding, isHolding, scenePhase == .active, preferences.hapticsEnabled, let phase = snapshot.phase else { return }
        haptics.play(inhaling: phase == .inhaling, duration: snapshot.phaseRemaining,
                     progress: snapshot.phaseProgress)
    }

    private func announce(_ text: String) {
        #if os(iOS)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
        #endif
    }

    private func keepScreenAwake(_ awake: Bool) {
        #if os(iOS)
        if awake {
            if previousIdleTimerState == nil {
                previousIdleTimerState = UIApplication.shared.isIdleTimerDisabled
            }
            UIApplication.shared.isIdleTimerDisabled = true
        } else if let previousIdleTimerState {
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimerState
            self.previousIdleTimerState = nil
        }
        #endif
    }
}

private struct BreathHoldStyle: ButtonStyle {
    let onPressedChange: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.circle)
            .onChange(of: configuration.isPressed) { _, pressed in
                onPressedChange(pressed)
            }
    }
}

private struct BreathOrb: View {
    let session: BreathingSession
    let isHolding: Bool
    let isSettling: Bool
    let reduceMotion: Bool
    let diameter: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: session.status != .running || reduceMotion)) { _ in
            let snapshot = session.snapshot(at: ProcessInfo.processInfo.systemUptime)
            let expansion = isSettling ? 0 : snapshot.expansion
            ZStack {
                Circle().stroke(SleepTheme.lavender.opacity(isHolding ? 0.55 : 0.1), lineWidth: isHolding ? 2 : 1)
                    .animation(holdAnimation, value: isHolding)
                Circle().stroke(SleepTheme.lavender.opacity(0.08), lineWidth: 1).padding(diameter * 0.076)
                Circle()
                    .fill(SleepTheme.lavender.opacity(0.06 + expansion * 0.08))
                    .padding(diameter * 0.076)
                Circle()
                    .fill(RadialGradient(colors: [SleepTheme.lavender.opacity(0.8), SleepTheme.lavender.opacity(0.2)],
                                         center: .center, startRadius: 0, endRadius: diameter * 0.44))
                    .overlay(Circle().stroke(SleepTheme.lavender.opacity(0.65), lineWidth: 1))
                    .frame(width: diameter * 0.79, height: diameter * 0.79)
                    .scaleEffect(reduceMotion ? 0.85 : 0.65 + expansion * 0.37)
                    .opacity(reduceMotion ? 0.8 : 0.65 + expansion * 0.35)
                Image(systemName: "wind")
                    .font(.system(size: diameter * 0.14, weight: .ultraLight))
                    .foregroundStyle(SleepTheme.text)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(isHolding && !reduceMotion ? 0.985 : 1)
            .animation(holdAnimation, value: isHolding)
            .opacity(isSettling ? 0 : 1)
            .animation(.easeOut(duration: reduceMotion ? 0.3 : BreathingSession.settlingDuration), value: isSettling)
        }
        .accessibilityHidden(true)
    }

    private var holdAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return .easeOut(duration: isSettling ? BreathingSession.settlingDuration : 0.12)
    }
}

struct BreathingGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Hold, breathe, let the day go.").font(.title2)
                    Text("Keep your finger on the wind icon through each inhale and exhale. The timer starts when you touch it. Lift your finger to pause; hold again to continue from the same point.")
                    Text("Follow the expanding and shrinking circle. On supported iPhones, vibration builds as you breathe in and softens as you breathe out. You can turn vibration off in Settings.")
                    Text("Your session length and vibration preference are saved automatically for every night. You can finish whenever you feel ready.")
                    Text("Keep each breath gentle, without forcing a deep breath or holding it. If you feel light-headed or short of breath, stop and breathe normally.")
                    Text("A gentle, steady pace").font(.title2)
                    Text("Four seconds in and six seconds out makes six breaths a minute. Slow breathing has been studied for relaxation and bedtime use. This exact rhythm is a practical guide, not a proven best ratio for sleep.")
                    Text("Why five minutes?").font(.headline)
                    Text("It is a short starting point. Research has not established the best bedtime duration or number of breaths. A small sleep study used 20 minutes at six breaths a minute; five-minute breathwork research supports some mood benefits, but did not show improved sleep. Choose 10 or 20 minutes if comfortable.")
                    Text("What we can say").font(.headline)
                    Text("Slow breathing may help you unwind. Evidence for sleep benefits is still mixed, and this app's breathing guide has not been clinically tested. The timer counts guided cycles, not your actual breaths or whether you fall asleep.")
                    Link("Five-minute slow-breathing study · 2021",
                         destination: URL(string: "https://doi.org/10.1038/s41598-021-98736-9")!)
                    Link("Paced breathing and insomnia · Tsai et al., 2015",
                         destination: URL(string: "https://doi.org/10.1111/psyp.12333")!)
                    Link("Presleep breathing pilot · Kuula et al., 2020",
                         destination: URL(string: "https://doi.org/10.1038/s41598-020-64218-7")!)
                    Link("Five-minute breathwork trial · Yilmaz Balban et al., 2023",
                         destination: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC9873947/")!)
                    Link("Slow breathing and sleep review · Eide et al., 2026",
                         destination: URL(string: "https://doi.org/10.1016/j.smrv.2026.102284")!)
                    Link("Breath-ratio comparison trial · 2023",
                         destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/36871835/")!)
                }
                .padding(28).frame(maxWidth: 580).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(SleepTheme.background)
            .foregroundStyle(SleepTheme.text)
            .tint(SleepTheme.lavender)
            .navigationTitle("How breathing works")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } } }
        }
    }
}
