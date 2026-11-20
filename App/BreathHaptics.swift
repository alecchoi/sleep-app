import Foundation
import Observation
import SleepCore
#if os(iOS)
import CoreHaptics
#endif

@Observable @MainActor
final class BreathHaptics {
    #if os(iOS)
    @ObservationIgnored private var engine: CHHapticEngine?
    @ObservationIgnored private var player: (any CHHapticPatternPlayer)?
    @ObservationIgnored private var envelope: Envelope?
    var isSupported: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }

    func prepare() {
        guard isSupported else { return }
        do {
            if engine == nil {
                let newEngine = try CHHapticEngine()
                newEngine.playsHapticsOnly = true
                newEngine.isAutoShutdownEnabled = true
                newEngine.resetHandler = { [weak self] in
                    Task { @MainActor in
                        self?.player = nil
                        self?.envelope = nil
                        self?.engine = nil
                    }
                }
                engine = newEngine
            }
            try engine?.start()
        } catch { engine = nil }
    }

    func play(inhaling: Bool, duration: TimeInterval, progress: Double = 0) {
        guard isSupported, duration > 0 else { return }
        stopPlayer()
        prepare()
        guard let engine else { return }
        do {
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ], relativeTime: 0, duration: duration + BreathingSession.settlingDuration)
            let progress = Float(min(1, max(0, progress)))
            let initialIntensity: Float = inhaling ? 0.18 + 0.62 * progress : 0.8 - 0.62 * progress
            let finalIntensity: Float = inhaling ? 0.8 : 0.18
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: initialIntensity),
                .init(relativeTime: duration, value: finalIntensity),
                .init(relativeTime: duration + BreathingSession.settlingDuration, value: 0)
            ], relativeTime: 0)
            let pattern = try CHHapticPattern(events: [event], parameterCurves: [curve])
            let newPlayer = try engine.makePlayer(with: pattern)
            player = newPlayer
            try newPlayer.start(atTime: CHHapticTimeImmediate)
            envelope = Envelope(startedAt: ProcessInfo.processInfo.systemUptime, duration: duration,
                                initial: initialIntensity, final: finalIntensity)
        } catch { stopPlayer() }
    }

    func settle(duration: TimeInterval) {
        // Fade only an already-playing pattern; finishing a paused or unstarted
        // session must never create a new vibration or a completion pulse.
        guard duration > 0, let player, let engine, let envelope else { return }
        let intensity = envelope.intensity(at: ProcessInfo.processInfo.systemUptime)
        do {
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: intensity),
                .init(relativeTime: duration, value: 0)
            ], relativeTime: 0)
            try player.scheduleParameterCurve(curve, atTime: CHHapticTimeImmediate)
            try player.stop(atTime: engine.currentTime + duration)
            self.envelope = nil
        } catch { stop() }
    }

    func pause() {
        // Keep the engine warm for a quick re-press. Its auto-shutdown handles
        // longer idle periods without keeping a pattern playing.
        stopPlayer()
    }

    func stop() {
        pause()
        engine?.stop(completionHandler: nil)
    }

    private func stopPlayer() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        envelope = nil
    }

    private struct Envelope {
        let startedAt: TimeInterval
        let duration: TimeInterval
        let initial: Float
        let final: Float

        func intensity(at time: TimeInterval) -> Float {
            let elapsed = max(0, time - startedAt)
            if elapsed <= duration {
                return initial + (final - initial) * Float(elapsed / duration)
            }
            return final * Float(max(0, 1 - (elapsed - duration) / BreathingSession.settlingDuration))
        }
    }
    #else
    var isSupported: Bool { false }
    func prepare() {}
    func pause() {}
    func settle(duration: TimeInterval) {}
    func play(inhaling: Bool, duration: TimeInterval, progress: Double = 0) {}
    func stop() {}
    #endif
}
