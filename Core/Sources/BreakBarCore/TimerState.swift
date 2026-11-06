import Foundation

public enum RestKind: String, Codable, Sendable { case short, long }

/// The part of a timed phase that survives a pause.
public enum TimedPhase: Equatable, Sendable {
    case work
    case rest(RestKind)
}

/// Where the timer is right now. Each case carries only what it needs.
public enum TimerState: Equatable, Sendable {
    case idle
    case working(endsAt: Date)
    /// Work finished; the Rest window is up, waiting for "Start resting".
    case awaitingRest(kind: RestKind, since: Date, snoozes: Int)
    /// "Snooze" pressed; the window comes back at `until`.
    case snoozed(kind: RestKind, until: Date, snoozes: Int)
    case resting(kind: RestKind, endsAt: Date)
    /// Rest finished; the Start working window is up.
    case awaitingWork(kind: RestKind, since: Date)
    case paused(phase: TimedPhase, remaining: TimeInterval, since: Date)
}

public enum TimerEvent: Equatable, Sendable {
    case start                  // idle -> working
    case stop                   // any -> idle
    case tick                   // call about once a second
    case startRest              // "Start resting" button
    case startWork              // "Start working" button
    case snooze
    case skip                   // skip the rest (or skip the wait) and go to work
    case extend                 // + extendMinutes
    case pause, resume
    case resetSet
}

/// Things the app layer must do (sound, notification). Windows are driven by `state`.
public enum TimerEffect: Equatable, Sendable {
    case playWindup, startTicking, stopTicking, playDing
    case notifyRestStarted(RestKind)   // also sent when the Rest window appears
    case notifyRestEnded
}

extension TimerState {
    /// Short stable name, used by the event log.
    public var name: String {
        switch self {
        case .idle: return "idle"
        case .working: return "working"
        case .awaitingRest: return "awaitingRest"
        case .snoozed: return "snoozed"
        case .resting(let kind, _): return kind == .long ? "restingLong" : "resting"
        case .awaitingWork: return "awaitingWork"
        case .paused: return "paused"
        }
    }
}
