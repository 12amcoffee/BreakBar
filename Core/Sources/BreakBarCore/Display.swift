import Foundation

/// Which menu bar icon to show. The app maps these to SF Symbols.
public enum MenuBarIcon: Equatable, Sendable {
    case idle, working, paused, waitingToRest, snoozed, shortRest, longRest, waitingToWork
}

/// What the "Session 2 of 4" line says, before translation.
public enum SessionProgress: Equatable, Sendable {
    case session(current: Int, of: Int)
    case done(Int, of: Int, longBreakNext: Bool)
    case longBreak
    case longBreakAfterThisSession
}

/// Which buttons make sense right now. Shared by the popover and the Rest window.
public struct AvailableActions: Equatable, Sendable {
    public var canPause = false
    public var canResume = false
    public var canSkip = false
    public var canExtend = false
    public var canSnooze = false
    public var canStartRest = false
    public var canStartWork = false
}

/// "07:05" style clock. Minutes are not wrapped (a 90 min session shows "90:00").
public func formatClock(_ seconds: Int) -> String {
    let s = max(0, seconds)
    return String(format: "%02d:%02d", s / 60, s % 60)
}

extension TimerMachine {
    public var icon: MenuBarIcon {
        switch state {
        case .idle: return .idle
        case .working: return .working
        case .paused: return .paused
        case .awaitingRest: return .waitingToRest
        case .snoozed: return .snoozed
        case .resting(let kind, _): return kind == .long ? .longRest : .shortRest
        case .awaitingWork: return .waitingToWork
        }
    }

    /// Text next to the menu bar icon. Countdowns round up so a fresh 45 min session reads 45:00.
    /// Waiting states count *up* with a "+" so they are distinct from a running countdown.
    public func menuBarTitle(at now: Date) -> String? {
        func down(_ end: Date) -> String { formatClock(Int(end.timeIntervalSince(now).rounded(.up))) }
        func up(_ start: Date) -> String { "+" + formatClock(Int(now.timeIntervalSince(start))) }
        switch state {
        case .idle: return nil
        case .working(let end), .resting(_, let end): return down(end)
        case .awaitingRest(_, let since, _), .awaitingWork(_, let since): return up(since)
        case .snoozed(_, let until, _): return "z " + down(until)
        case .paused(_, let remaining, _): return "⏸ " + formatClock(Int(remaining.rounded(.up)))
        }
    }

    /// Progress toward the next long break. The app turns this into translated text.
    public var sessionProgress: SessionProgress {
        let n = settings.sessionsPerSet
        switch state {
        case .idle, .working, .paused(.work, _, _):
            return longBreakPostponed ? .longBreakAfterThisSession : .session(current: completedSessions + 1, of: n)
        case .awaitingRest(let kind, _, _), .snoozed(let kind, _, _),
             .resting(let kind, _), .awaitingWork(let kind, _), .paused(.rest(let kind), _, _):
            return kind == .long ? .longBreak : .done(completedSessions, of: n, longBreakNext: longBreakPostponed)
        }
    }

    public var available: AvailableActions {
        var a = AvailableActions()
        switch state {
        case .working:
            a.canPause = settings.pauseEnabled
        case .resting:
            a.canPause = settings.pauseEnabled
            a.canSkip = true
            a.canExtend = settings.extendEnabled
        case .paused:
            a.canResume = true
        case .awaitingRest(_, _, let snoozes):
            a.canStartRest = true
            a.canSkip = true
            a.canSnooze = settings.snoozeEnabled && snoozes < settings.maxSnoozesPerBreak
        case .snoozed:
            a.canStartRest = true
            a.canSkip = true
        case .awaitingWork:
            a.canStartWork = true
            a.canSkip = true
            a.canExtend = settings.extendEnabled
        case .idle:
            break
        }
        return a
    }
}
