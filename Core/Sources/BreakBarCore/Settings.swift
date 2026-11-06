import Foundation

/// What happens when a work session ends.
public enum WhenWorkEnds: String, Codable, CaseIterable, Sendable {
    case startRestAutomatically
    case showRestWindow
}

/// What happens when a rest ends.
public enum WhenRestEnds: String, Codable, CaseIterable, Sendable {
    case startWorkAutomatically
    case showWorkWindow
    case stopTimer          // TomatoBar's "Stop after break"
}

/// How a Rest / Start working prompt is shown.
public enum WindowStyle: String, Codable, CaseIterable, Sendable {
    case small, maximised, fullScreen, banner
}

/// Every user-configurable value that affects the timer logic.
public struct TimerSettings: Codable, Equatable, Sendable {
    // Durations (minutes)
    public var workMinutes = 45
    public var shortRestMinutes = 10
    public var longRestMinutes = 20
    public var sessionsPerSet = 4

    // Transitions
    public var whenWorkEnds = WhenWorkEnds.showRestWindow
    public var whenRestEnds = WhenRestEnds.showWorkWindow
    /// Work -> rest -> work with no prompts. Overrides both settings above.
    public var continuousCycles = false

    // Optional controls
    public var pauseEnabled = true
    public var extendEnabled = true
    public var extendMinutes = 5
    public var snoozeEnabled = true
    public var snoozeMinutes = 2
    public var maxSnoozesPerBreak = 3

    // Long-break counter
    /// When a long break is due, take a short one now and the long one after the next session.
    public var delayLongBreak = false
    /// Idle/unanswered longer than this starts a fresh set.
    public var inactivityResetMinutes = 60

    public init() {}

    public static let workRange = 1...180
    public static let restRange = 1...180
    public static let setRange = 1...12

    /// Returns a copy with every value forced into a sane range.
    public func clamped() -> TimerSettings {
        var s = self
        s.workMinutes = min(max(workMinutes, 1), 180)
        s.shortRestMinutes = min(max(shortRestMinutes, 1), 180)
        s.longRestMinutes = min(max(longRestMinutes, 1), 180)
        s.sessionsPerSet = min(max(sessionsPerSet, 1), 12)
        s.extendMinutes = min(max(extendMinutes, 1), 60)
        s.snoozeMinutes = min(max(snoozeMinutes, 1), 60)
        s.maxSnoozesPerBreak = min(max(maxSnoozesPerBreak, 1), 20)
        s.inactivityResetMinutes = min(max(inactivityResetMinutes, 5), 1440)
        return s
    }

    var effectiveWhenWorkEnds: WhenWorkEnds {
        continuousCycles ? .startRestAutomatically : whenWorkEnds
    }
    var effectiveWhenRestEnds: WhenRestEnds {
        continuousCycles ? .startWorkAutomatically : whenRestEnds
    }
}
