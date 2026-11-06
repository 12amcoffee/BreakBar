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
public enum PromptWindowStyle: String, Codable, CaseIterable, Sendable {
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

    // Sounds (0 = off, 1 = full volume). Quiet by default: this app is meant for libraries.
    public var windupVolume = 0.0
    public var dingVolume = 0.5
    public var tickingVolume = 0.0
    public var notificationsEnabled = true

    // Presentation
    public var windowStyle = PromptWindowStyle.small
    public var showTimerInMenuBar = true

    public init() {}

    /// Tolerant decoding: a missing key (older save, newer app) falls back to its default
    /// instead of making the whole settings blob unreadable.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = TimerSettings()
        workMinutes = try c.decodeIfPresent(Int.self, forKey: .workMinutes) ?? d.workMinutes
        shortRestMinutes = try c.decodeIfPresent(Int.self, forKey: .shortRestMinutes) ?? d.shortRestMinutes
        longRestMinutes = try c.decodeIfPresent(Int.self, forKey: .longRestMinutes) ?? d.longRestMinutes
        sessionsPerSet = try c.decodeIfPresent(Int.self, forKey: .sessionsPerSet) ?? d.sessionsPerSet
        whenWorkEnds = try c.decodeIfPresent(WhenWorkEnds.self, forKey: .whenWorkEnds) ?? d.whenWorkEnds
        whenRestEnds = try c.decodeIfPresent(WhenRestEnds.self, forKey: .whenRestEnds) ?? d.whenRestEnds
        continuousCycles = try c.decodeIfPresent(Bool.self, forKey: .continuousCycles) ?? d.continuousCycles
        pauseEnabled = try c.decodeIfPresent(Bool.self, forKey: .pauseEnabled) ?? d.pauseEnabled
        extendEnabled = try c.decodeIfPresent(Bool.self, forKey: .extendEnabled) ?? d.extendEnabled
        extendMinutes = try c.decodeIfPresent(Int.self, forKey: .extendMinutes) ?? d.extendMinutes
        snoozeEnabled = try c.decodeIfPresent(Bool.self, forKey: .snoozeEnabled) ?? d.snoozeEnabled
        snoozeMinutes = try c.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? d.snoozeMinutes
        maxSnoozesPerBreak = try c.decodeIfPresent(Int.self, forKey: .maxSnoozesPerBreak) ?? d.maxSnoozesPerBreak
        delayLongBreak = try c.decodeIfPresent(Bool.self, forKey: .delayLongBreak) ?? d.delayLongBreak
        inactivityResetMinutes = try c.decodeIfPresent(Int.self, forKey: .inactivityResetMinutes) ?? d.inactivityResetMinutes
        windupVolume = try c.decodeIfPresent(Double.self, forKey: .windupVolume) ?? d.windupVolume
        dingVolume = try c.decodeIfPresent(Double.self, forKey: .dingVolume) ?? d.dingVolume
        tickingVolume = try c.decodeIfPresent(Double.self, forKey: .tickingVolume) ?? d.tickingVolume
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? d.notificationsEnabled
        windowStyle = try c.decodeIfPresent(PromptWindowStyle.self, forKey: .windowStyle) ?? d.windowStyle
        showTimerInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showTimerInMenuBar) ?? d.showTimerInMenuBar
    }

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
        s.windupVolume = min(max(windupVolume, 0), 1)
        s.dingVolume = min(max(dingVolume, 0), 1)
        s.tickingVolume = min(max(tickingVolume, 0), 1)
        return s
    }

    var effectiveWhenWorkEnds: WhenWorkEnds {
        continuousCycles ? .startRestAutomatically : whenWorkEnds
    }
    var effectiveWhenRestEnds: WhenRestEnds {
        continuousCycles ? .startWorkAutomatically : whenRestEnds
    }
}
