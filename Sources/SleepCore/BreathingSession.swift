import Foundation

public enum BreathingDuration: Int, Codable, CaseIterable, Identifiable, Sendable {
    case fiveMinutes = 5
    case tenMinutes = 10
    case twentyMinutes = 20

    public var id: Int { rawValue }
    public var seconds: TimeInterval { TimeInterval(rawValue * 60) }
    public var breathCount: Int { Int(seconds / BreathingSession.cycleDuration) }
}

public struct BreathingPreferences: Codable, Equatable, Sendable {
    public var duration: BreathingDuration
    public var hapticsEnabled: Bool

    public init(duration: BreathingDuration = .fiveMinutes, hapticsEnabled: Bool = true) {
        self.duration = duration
        self.hapticsEnabled = hapticsEnabled
    }
}

public enum BreathingPhase: Equatable, Sendable {
    case inhaling, exhaling
}

/// A finite guide, not a measurement of the user's respiration or sleep.
/// Callers supply a monotonic clock so wall-clock changes cannot alter the pace.
public struct BreathingSession: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case ready, running, paused, completed
    }

    public static let inhaleDuration: TimeInterval = 4
    public static let exhaleDuration: TimeInterval = 6
    public static let cycleDuration = inhaleDuration + exhaleDuration
    public static let settlingDuration: TimeInterval = 1.4

    public let duration: BreathingDuration
    public private(set) var status: Status = .ready
    private var accumulated: TimeInterval = 0
    private var startedAt: TimeInterval?

    public init(duration: BreathingDuration = .fiveMinutes) {
        self.duration = duration
    }

    public mutating func start(at time: TimeInterval) {
        guard time.isFinite, status == .ready || status == .paused else { return }
        startedAt = time
        status = .running
    }

    public mutating func advance(at time: TimeInterval) {
        guard status == .running, snapshot(at: time).isComplete else { return }
        accumulated = duration.seconds
        startedAt = nil
        status = .completed
    }

    public mutating func pause(at time: TimeInterval) {
        guard status == .running else { return }
        advance(at: time)
        guard status == .running else { return }
        // Preserve every held second, including a partial breath. Lifting a
        // finger freezes the timer and rhythm instead of rewinding either.
        accumulated = snapshot(at: time).elapsed
        startedAt = nil
        status = .paused
    }

    /// End by choice without inventing held time or completing unused breaths.
    /// Both early finishes and the timed endpoint are terminal for this session.
    public mutating func finish(at time: TimeInterval) {
        guard time.isFinite, status != .completed else { return }
        accumulated = snapshot(at: time).elapsed
        startedAt = nil
        status = .completed
    }

    public func snapshot(at time: TimeInterval) -> BreathingSnapshot {
        let runningTime: TimeInterval
        if status == .running, let startedAt, time.isFinite {
            runningTime = max(0, time - startedAt)
        } else {
            runningTime = 0
        }
        return BreathingSnapshot(
            elapsed: min(duration.seconds, accumulated + runningTime),
            duration: duration,
            isRunning: status == .running
        )
    }
}

public struct BreathingSnapshot: Equatable, Sendable {
    public let elapsed: TimeInterval
    public let duration: BreathingDuration
    public let isRunning: Bool

    public var isComplete: Bool { elapsed >= duration.seconds }
    public var secondsRemaining: Int { max(0, Int(ceil(duration.seconds - elapsed))) }
    public var completedBreaths: Int {
        min(duration.breathCount, Int(elapsed / BreathingSession.cycleDuration))
    }
    public var progress: Double { elapsed / duration.seconds }

    public var phase: BreathingPhase? {
        guard isRunning, !isComplete else { return nil }
        return cycleElapsed < BreathingSession.inhaleDuration ? .inhaling : .exhaling
    }

    public var phaseProgress: Double {
        switch phase {
        case .inhaling: return cycleElapsed / BreathingSession.inhaleDuration
        case .exhaling:
            return (cycleElapsed - BreathingSession.inhaleDuration) / BreathingSession.exhaleDuration
        case nil: return 0
        }
    }

    public var phaseRemaining: TimeInterval {
        switch phase {
        case .inhaling: return BreathingSession.inhaleDuration - cycleElapsed
        case .exhaling: return BreathingSession.cycleDuration - cycleElapsed
        case nil: return 0
        }
    }

    /// Expand and contract using the same clock as the text and haptics.
    public var expansion: Double {
        guard !isComplete else { return 0 }
        let inhaling = cycleElapsed < BreathingSession.inhaleDuration
        let progress = inhaling ? cycleElapsed / BreathingSession.inhaleDuration :
            (cycleElapsed - BreathingSession.inhaleDuration) / BreathingSession.exhaleDuration
        let eased = (1 - cos(.pi * progress)) / 2
        return inhaling ? eased : 1 - eased
    }

    private var cycleElapsed: TimeInterval {
        elapsed.truncatingRemainder(dividingBy: BreathingSession.cycleDuration)
    }
}
