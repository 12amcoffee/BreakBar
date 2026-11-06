import Foundation

/// The whole timer as one value. Feed it events, get back effects.
/// No timers, no UI: the caller supplies `now`, which makes it trivial to test.
public struct TimerMachine: Equatable, Sendable {
    public private(set) var state: TimerState = .idle
    /// Work sessions completed in the current set (0 ..< sessionsPerSet).
    public private(set) var completedSessions = 0
    /// True once a long break has been postponed by "delay long break".
    public private(set) var longBreakPostponed = false
    /// Last time the user was "around": used for the inactivity reset.
    public private(set) var lastActive: Date?
    public var settings: TimerSettings

    /// A tick later than this after the end time means the Mac slept: give up, don't advance.
    public static let overrunLimit: TimeInterval = 60

    public init(settings: TimerSettings = TimerSettings(),
                completedSessions: Int = 0,
                longBreakPostponed: Bool = false,
                lastActive: Date? = nil) {
        self.settings = settings.clamped()
        self.completedSessions = completedSessions
        self.longBreakPostponed = longBreakPostponed
        self.lastActive = lastActive
    }

    // MARK: Entry point

    @discardableResult
    public mutating func handle(_ event: TimerEvent, at now: Date) -> [TimerEffect] {
        let wasIdle = state == .idle
        var fx: [TimerEffect] = []

        switch event {
        case .start:      fx = onStart(now)
        case .stop:       fx = goIdle()
        case .tick:       fx = onTick(now)
        case .startRest:  fx = onStartRest(now)
        case .startWork:  fx = onStartWork(now)
        case .snooze:     fx = onSnooze(now)
        case .skip:       fx = onSkip(now)
        case .extend:     fx = onExtend(now)
        case .pause:      fx = onPause(now)
        case .resume:     fx = onResume(now)
        case .resetSet:   resetSet()
        }

        if !(wasIdle && state == .idle) { lastActive = now }
        return fx
    }

    // MARK: Transitions

    private mutating func onStart(_ now: Date) -> [TimerEffect] {
        guard state == .idle else { return [] }
        if inactiveTooLong(since: lastActive, now) { resetSet() }
        return beginWork(now)
    }

    private mutating func goIdle() -> [TimerEffect] {
        guard state != .idle else { return [] }
        let wasWorking = isWorkPhase
        state = .idle
        return wasWorking ? [.stopTicking] : []
    }

    private mutating func onTick(_ now: Date) -> [TimerEffect] {
        switch state {
        case .idle:
            return []

        case .working(let endsAt):
            if now < endsAt { return [] }
            if now.timeIntervalSince(endsAt) > Self.overrunLimit { return goIdle() }  // slept: not counted
            return finishWork(now)

        case .resting(_, let endsAt):
            if now < endsAt { return [] }
            if now.timeIntervalSince(endsAt) > Self.overrunLimit { return goIdle() }
            return finishRest(now)

        case .snoozed(let kind, let until, let snoozes):
            if inactiveTooLong(since: until.addingTimeInterval(-snoozeSeconds), now) { return abandon() }
            if now >= until { state = .awaitingRest(kind: kind, since: now, snoozes: snoozes) }
            return []

        case .awaitingRest(_, let since, _), .awaitingWork(_, let since), .paused(_, _, let since):
            return inactiveTooLong(since: since, now) ? abandon() : []
        }
    }

    private mutating func onStartRest(_ now: Date) -> [TimerEffect] {
        switch state {
        case .awaitingRest(let kind, _, _), .snoozed(let kind, _, _):
            state = .resting(kind: kind, endsAt: now.addingTimeInterval(restSeconds(kind)))
        default: break
        }
        return []
    }

    private mutating func onStartWork(_ now: Date) -> [TimerEffect] {
        guard case .awaitingWork = state else { return [] }
        return beginWork(now)
    }

    private mutating func onSnooze(_ now: Date) -> [TimerEffect] {
        guard settings.snoozeEnabled, case .awaitingRest(let kind, _, let snoozes) = state,
              snoozes < settings.maxSnoozesPerBreak else { return [] }
        state = .snoozed(kind: kind, until: now.addingTimeInterval(snoozeSeconds), snoozes: snoozes + 1)
        return []
    }

    /// Skip never touches the session counter (a skipped long break was already reset when it was chosen).
    private mutating func onSkip(_ now: Date) -> [TimerEffect] {
        switch state {
        case .awaitingRest, .snoozed, .resting, .awaitingWork: return beginWork(now)
        default: return []
        }
    }

    private mutating func onExtend(_ now: Date) -> [TimerEffect] {
        guard settings.extendEnabled else { return [] }
        let extra = TimeInterval(settings.extendMinutes * 60)
        switch state {
        case .resting(let kind, let endsAt):
            state = .resting(kind: kind, endsAt: endsAt.addingTimeInterval(extra))
        case .awaitingWork(let kind, _):
            state = .resting(kind: kind, endsAt: now.addingTimeInterval(extra))
        default: break
        }
        return []
    }

    private mutating func onPause(_ now: Date) -> [TimerEffect] {
        guard settings.pauseEnabled else { return [] }
        switch state {
        case .working(let endsAt):
            state = .paused(phase: .work, remaining: max(0, endsAt.timeIntervalSince(now)), since: now)
            return [.stopTicking]
        case .resting(let kind, let endsAt):
            state = .paused(phase: .rest(kind), remaining: max(0, endsAt.timeIntervalSince(now)), since: now)
            return []
        default: return []
        }
    }

    private mutating func onResume(_ now: Date) -> [TimerEffect] {
        guard case .paused(let phase, let remaining, _) = state else { return [] }
        switch phase {
        case .work:
            state = .working(endsAt: now.addingTimeInterval(remaining))
            return [.startTicking]
        case .rest(let kind):
            state = .resting(kind: kind, endsAt: now.addingTimeInterval(remaining))
            return []
        }
    }

    // MARK: Helpers

    private mutating func beginWork(_ now: Date) -> [TimerEffect] {
        state = .working(endsAt: now.addingTimeInterval(TimeInterval(settings.workMinutes * 60)))
        return [.playWindup, .startTicking]
    }

    private mutating func finishWork(_ now: Date) -> [TimerEffect] {
        completedSessions += 1
        let kind = chooseRestKind()
        switch settings.effectiveWhenWorkEnds {
        case .startRestAutomatically:
            state = .resting(kind: kind, endsAt: now.addingTimeInterval(restSeconds(kind)))
        case .showRestWindow:
            state = .awaitingRest(kind: kind, since: now, snoozes: 0)
        }
        return [.stopTicking, .playDing, .notifyRestStarted(kind)]
    }

    private mutating func finishRest(_ now: Date) -> [TimerEffect] {
        guard case .resting(let kind, _) = state else { return [] }
        var fx: [TimerEffect] = [.notifyRestEnded]
        switch settings.effectiveWhenRestEnds {
        case .startWorkAutomatically: fx += beginWork(now)
        case .showWorkWindow:         state = .awaitingWork(kind: kind, since: now)
        case .stopTimer:              state = .idle
        }
        return fx
    }

    /// Decides short vs long when work ends, and updates the counter.
    private mutating func chooseRestKind() -> RestKind {
        let due = completedSessions >= settings.sessionsPerSet
        if due && settings.delayLongBreak && !longBreakPostponed {
            longBreakPostponed = true
            return .short
        }
        if due {
            completedSessions = 0          // long break starts: the set is over (also if it is skipped)
            longBreakPostponed = false
            return .long
        }
        return .short
    }

    /// The user walked away from a prompt: stop and start a fresh set.
    private mutating func abandon() -> [TimerEffect] {
        resetSet()
        return goIdle()
    }

    public mutating func resetSet() {
        completedSessions = 0
        longBreakPostponed = false
    }

    private func inactiveTooLong(since: Date?, _ now: Date) -> Bool {
        guard let since else { return false }
        return now.timeIntervalSince(since) > TimeInterval(settings.inactivityResetMinutes * 60)
    }

    private var isWorkPhase: Bool {
        if case .working = state { return true }
        return false
    }
    private var snoozeSeconds: TimeInterval { TimeInterval(settings.snoozeMinutes * 60) }
    private func restSeconds(_ kind: RestKind) -> TimeInterval {
        TimeInterval((kind == .long ? settings.longRestMinutes : settings.shortRestMinutes) * 60)
    }
}
