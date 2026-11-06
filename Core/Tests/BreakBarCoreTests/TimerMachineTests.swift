import XCTest
@testable import BreakBarCore

final class TimerMachineTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    func min(_ m: Double) -> TimeInterval { m * 60 }

    /// 45/10/20, 4 per set, Rest window on, work window on.
    func makeMachine(_ tweak: (inout TimerSettings) -> Void = { _ in }) -> TimerMachine {
        var s = TimerSettings()
        tweak(&s)
        return TimerMachine(settings: s)
    }

    /// Runs one full work session and returns the time work ended.
    @discardableResult
    func finishWork(_ m: inout TimerMachine, from start: Date) -> Date {
        m.handle(.start, at: start)
        let end = start.addingTimeInterval(min(Double(m.settings.workMinutes)))
        m.handle(.tick, at: end)
        return end
    }

    // MARK: Basics

    func testStartBeginsWorkWithSounds() {
        var m = makeMachine()
        let fx = m.handle(.start, at: t0)
        XCTAssertEqual(m.state, .working(endsAt: t0.addingTimeInterval(45 * 60)))
        XCTAssertEqual(fx, [.playWindup, .startTicking])
    }

    func testTickBeforeEndDoesNothing() {
        var m = makeMachine()
        m.handle(.start, at: t0)
        XCTAssertEqual(m.handle(.tick, at: t0.addingTimeInterval(60)), [])
    }

    func testWorkEndShowsRestWindow() {
        var m = makeMachine()
        let end = finishWork(&m, from: t0)
        XCTAssertEqual(m.state, .awaitingRest(kind: .short, since: end, snoozes: 0))
        XCTAssertEqual(m.completedSessions, 1)
    }

    func testWorkEndEmitsDingAndNotification() {
        var m = makeMachine()
        m.handle(.start, at: t0)
        let fx = m.handle(.tick, at: t0.addingTimeInterval(45 * 60))
        XCTAssertEqual(fx, [.stopTicking, .playDing, .notifyRestStarted(.short)])
    }

    func testAutoRestStartsImmediately() {
        var m = makeMachine { $0.whenWorkEnds = .startRestAutomatically }
        let end = finishWork(&m, from: t0)
        XCTAssertEqual(m.state, .resting(kind: .short, endsAt: end.addingTimeInterval(10 * 60)))
    }

    func testStartRestButtonStartsRestTimerFromClick() {
        var m = makeMachine()
        let end = finishWork(&m, from: t0)
        let click = end.addingTimeInterval(90)
        m.handle(.startRest, at: click)
        XCTAssertEqual(m.state, .resting(kind: .short, endsAt: click.addingTimeInterval(10 * 60)))
    }

    func testStopGoesIdleAndKeepsCounter() {
        var m = makeMachine()
        finishWork(&m, from: t0)
        m.handle(.stop, at: t0.addingTimeInterval(3000))
        XCTAssertEqual(m.state, .idle)
        XCTAssertEqual(m.completedSessions, 1)
    }

    func testStopDuringWorkStopsTicking() {
        var m = makeMachine()
        m.handle(.start, at: t0)
        XCTAssertEqual(m.handle(.stop, at: t0.addingTimeInterval(10)), [.stopTicking])
    }

    // MARK: Rest end

    func testRestEndShowsWorkWindowByDefault() {
        var m = makeMachine { $0.whenWorkEnds = .startRestAutomatically }
        let end = finishWork(&m, from: t0)
        let restEnd = end.addingTimeInterval(600)
        let fx = m.handle(.tick, at: restEnd)
        XCTAssertEqual(m.state, .awaitingWork(kind: .short, since: restEnd))
        XCTAssertEqual(fx, [.notifyRestEnded])
    }

    func testRestEndAutoStartsWork() {
        var m = makeMachine { $0.whenWorkEnds = .startRestAutomatically; $0.whenRestEnds = .startWorkAutomatically }
        let end = finishWork(&m, from: t0)
        let fx = m.handle(.tick, at: end.addingTimeInterval(600))
        XCTAssertEqual(fx, [.notifyRestEnded, .playWindup, .startTicking])
        if case .working = m.state {} else { XCTFail("expected working, got \(m.state)") }
    }

    func testRestEndStopTimer() {
        var m = makeMachine { $0.whenWorkEnds = .startRestAutomatically; $0.whenRestEnds = .stopTimer }
        let end = finishWork(&m, from: t0)
        m.handle(.tick, at: end.addingTimeInterval(600))
        XCTAssertEqual(m.state, .idle)
    }

    func testContinuousCyclesOverridesBothWindows() {
        var m = makeMachine { $0.continuousCycles = true }   // windows would otherwise be on
        let end = finishWork(&m, from: t0)
        if case .resting = m.state {} else { XCTFail("expected resting, got \(m.state)") }
        m.handle(.tick, at: end.addingTimeInterval(600))
        if case .working = m.state {} else { XCTFail("expected working, got \(m.state)") }
    }

    func testStartWorkButton() {
        var m = makeMachine { $0.whenWorkEnds = .startRestAutomatically }
        let end = finishWork(&m, from: t0)
        m.handle(.tick, at: end.addingTimeInterval(600))
        let click = end.addingTimeInterval(700)
        let fx = m.handle(.startWork, at: click)
        XCTAssertEqual(m.state, .working(endsAt: click.addingTimeInterval(45 * 60)))
        XCTAssertEqual(fx, [.playWindup, .startTicking])
    }

    // MARK: Long break counter

    func testLongBreakAfterNSessions() {
        var m = makeMachine { $0.sessionsPerSet = 2; $0.whenWorkEnds = .startRestAutomatically; $0.whenRestEnds = .startWorkAutomatically }
        var now = t0
        m.handle(.start, at: now)
        now = now.addingTimeInterval(45 * 60); m.handle(.tick, at: now)          // session 1 -> short
        XCTAssertEqual(m.state, .resting(kind: .short, endsAt: now.addingTimeInterval(600)))
        now = now.addingTimeInterval(600); m.handle(.tick, at: now)              // -> working
        now = now.addingTimeInterval(45 * 60); m.handle(.tick, at: now)          // session 2 -> long
        XCTAssertEqual(m.state, .resting(kind: .long, endsAt: now.addingTimeInterval(20 * 60)))
        XCTAssertEqual(m.completedSessions, 0)                                     // set reset
    }

    func testSkippingLongBreakStillResetsSet() {
        var m = makeMachine { $0.sessionsPerSet = 1 }
        let end = finishWork(&m, from: t0)
        XCTAssertEqual(m.state, .awaitingRest(kind: .long, since: end, snoozes: 0))
        m.handle(.skip, at: end.addingTimeInterval(5))
        XCTAssertEqual(m.completedSessions, 0)
        if case .working = m.state {} else { XCTFail() }
    }

    func testSkipShortBreakKeepsCounter() {
        var m = makeMachine()
        let end = finishWork(&m, from: t0)
        m.handle(.skip, at: end.addingTimeInterval(5))
        XCTAssertEqual(m.completedSessions, 1)
    }

    func testDelayLongBreakPostponesOnce() {
        var m = makeMachine { $0.sessionsPerSet = 1; $0.delayLongBreak = true }
        var end = finishWork(&m, from: t0)
        XCTAssertEqual(m.state, .awaitingRest(kind: .short, since: end, snoozes: 0))   // postponed
        XCTAssertTrue(m.longBreakPostponed)
        m.handle(.skip, at: end)                                                       // back to work
        let work2 = end
        end = work2.addingTimeInterval(45 * 60)
        m.handle(.tick, at: end)
        XCTAssertEqual(m.state, .awaitingRest(kind: .long, since: end, snoozes: 0))    // now long
        XCTAssertFalse(m.longBreakPostponed)
        XCTAssertEqual(m.completedSessions, 0)
    }

    func testResetSetManual() {
        var m = makeMachine()
        finishWork(&m, from: t0)
        m.handle(.resetSet, at: t0)
        XCTAssertEqual(m.completedSessions, 0)
    }

    func testInactivityResetsSetOnNextStart() {
        var m = makeMachine()
        let end = finishWork(&m, from: t0)
        m.handle(.stop, at: end)
        m.handle(.start, at: end.addingTimeInterval(61 * 60))        // > 60 min later
        XCTAssertEqual(m.completedSessions, 0)
    }

    func testShortGapKeepsSet() {
        var m = makeMachine()
        let end = finishWork(&m, from: t0)
        m.handle(.stop, at: end)
        m.handle(.start, at: end.addingTimeInterval(30 * 60))
        XCTAssertEqual(m.completedSessions, 1)
    }

    func testUnansweredRestWindowGoesIdleAndResetsSet() {
        var m = makeMachine()
        let end = finishWork(&m, from: t0)
        m.handle(.tick, at: end.addingTimeInterval(61 * 60))
        XCTAssertEqual(m.state, .idle)
        XCTAssertEqual(m.completedSessions, 0)
    }

    // MARK: Snooze

    func testSnoozeThenWindowReturns() {
        var m = makeMachine()
        let end = finishWork(&m, from: t0)
        m.handle(.snooze, at: end)
        XCTAssertEqual(m.state, .snoozed(kind: .short, until: end.addingTimeInterval(120), snoozes: 1))
        m.handle(.tick, at: end.addingTimeInterval(119))
        if case .snoozed = m.state {} else { XCTFail() }
        let back = end.addingTimeInterval(121)
        m.handle(.tick, at: back)
        XCTAssertEqual(m.state, .awaitingRest(kind: .short, since: back, snoozes: 1))
    }

    func testSnoozeLimit() {
        var m = makeMachine { $0.maxSnoozesPerBreak = 2 }
        var now = finishWork(&m, from: t0)
        for _ in 0..<2 {
            m.handle(.snooze, at: now)
            now = now.addingTimeInterval(121)
            m.handle(.tick, at: now)
        }
        m.handle(.snooze, at: now)                                   // third: refused
        XCTAssertEqual(m.state, .awaitingRest(kind: .short, since: now, snoozes: 2))
    }

    func testSnoozeDisabled() {
        var m = makeMachine { $0.snoozeEnabled = false }
        let end = finishWork(&m, from: t0)
        m.handle(.snooze, at: end)
        XCTAssertEqual(m.state, .awaitingRest(kind: .short, since: end, snoozes: 0))
    }

    func testSnoozeDoesNotChangeCounter() {
        var m = makeMachine()
        let end = finishWork(&m, from: t0)
        m.handle(.snooze, at: end)
        XCTAssertEqual(m.completedSessions, 1)
    }

    func testStartRestFromSnoozedWorks() {
        var m = makeMachine()
        let end = finishWork(&m, from: t0)
        m.handle(.snooze, at: end)
        m.handle(.startRest, at: end.addingTimeInterval(30))
        if case .resting = m.state {} else { XCTFail("got \(m.state)") }
    }

    // MARK: Extend & skip

    func testExtendRest() {
        var m = makeMachine { $0.whenWorkEnds = .startRestAutomatically }
        let end = finishWork(&m, from: t0)
        m.handle(.extend, at: end.addingTimeInterval(100))
        XCTAssertEqual(m.state, .resting(kind: .short, endsAt: end.addingTimeInterval(600 + 300)))
        m.handle(.extend, at: end.addingTimeInterval(200))
        XCTAssertEqual(m.state, .resting(kind: .short, endsAt: end.addingTimeInterval(600 + 600)))
    }

    func testExtendFromWorkWindowReentersRest() {
        var m = makeMachine { $0.whenWorkEnds = .startRestAutomatically }
        let end = finishWork(&m, from: t0)
        let restEnd = end.addingTimeInterval(600)
        m.handle(.tick, at: restEnd)
        let click = restEnd.addingTimeInterval(20)
        m.handle(.extend, at: click)
        XCTAssertEqual(m.state, .resting(kind: .short, endsAt: click.addingTimeInterval(300)))
    }

    func testExtendDisabled() {
        var m = makeMachine { $0.whenWorkEnds = .startRestAutomatically; $0.extendEnabled = false }
        let end = finishWork(&m, from: t0)
        let before = m.state
        m.handle(.extend, at: end.addingTimeInterval(10))
        XCTAssertEqual(m.state, before)
    }

    func testSkipRestingGoesToWork() {
        var m = makeMachine { $0.whenWorkEnds = .startRestAutomatically }
        let end = finishWork(&m, from: t0)
        let fx = m.handle(.skip, at: end.addingTimeInterval(10))
        XCTAssertEqual(fx, [.playWindup, .startTicking])
        XCTAssertEqual(m.completedSessions, 1)
    }

    // MARK: Pause

    func testPauseAndResumeWork() {
        var m = makeMachine()
        m.handle(.start, at: t0)
        let p = t0.addingTimeInterval(600)
        XCTAssertEqual(m.handle(.pause, at: p), [.stopTicking])
        XCTAssertEqual(m.state, .paused(phase: .work, remaining: 35 * 60, since: p))
        let r = p.addingTimeInterval(5000)                            
        m.handle(.resume, at: r)
        XCTAssertEqual(m.state, .working(endsAt: r.addingTimeInterval(35 * 60)))
    }

    func testPauseDoesNotTick() {
        var m = makeMachine()
        m.handle(.start, at: t0)
        m.handle(.pause, at: t0.addingTimeInterval(10))
        m.handle(.tick, at: t0.addingTimeInterval(45 * 60 + 5))
        if case .paused = m.state {} else { XCTFail("got \(m.state)") }
    }

    func testPauseRestAndResume() {
        var m = makeMachine { $0.whenWorkEnds = .startRestAutomatically }
        let end = finishWork(&m, from: t0)
        let p = end.addingTimeInterval(100)
        m.handle(.pause, at: p)
        XCTAssertEqual(m.state, .paused(phase: .rest(.short), remaining: 500, since: p))
        let r = p.addingTimeInterval(60)
        XCTAssertEqual(m.handle(.resume, at: r), [])
        XCTAssertEqual(m.state, .resting(kind: .short, endsAt: r.addingTimeInterval(500)))
    }

    func testPauseDisabled() {
        var m = makeMachine { $0.pauseEnabled = false }
        m.handle(.start, at: t0)
        m.handle(.pause, at: t0.addingTimeInterval(5))
        if case .working = m.state {} else { XCTFail() }
    }

    func testPausedTooLongGoesIdle() {
        var m = makeMachine()
        m.handle(.start, at: t0)
        m.handle(.pause, at: t0.addingTimeInterval(5))
        m.handle(.tick, at: t0.addingTimeInterval(5 + 61 * 60))
        XCTAssertEqual(m.state, .idle)
    }

    // MARK: Sleep protection

    func testLateWorkTickAfterSleepGoesIdleWithoutCounting() {
        var m = makeMachine()
        m.handle(.start, at: t0)
        m.handle(.tick, at: t0.addingTimeInterval(45 * 60 + 61))
        XCTAssertEqual(m.state, .idle)
        XCTAssertEqual(m.completedSessions, 0)
    }

    func testSlightlyLateTickStillCounts() {
        var m = makeMachine()
        m.handle(.start, at: t0)
        m.handle(.tick, at: t0.addingTimeInterval(45 * 60 + 30))
        XCTAssertEqual(m.completedSessions, 1)
    }

    func testLateRestTickAfterSleepGoesIdle() {
        var m = makeMachine { $0.whenWorkEnds = .startRestAutomatically }
        let end = finishWork(&m, from: t0)
        m.handle(.tick, at: end.addingTimeInterval(600 + 120))
        XCTAssertEqual(m.state, .idle)
    }

    // MARK: Settings

    func testSettingsAreClamped() {
        var s = TimerSettings()
        s.workMinutes = 0; s.sessionsPerSet = 99; s.longRestMinutes = 999
        let c = s.clamped()
        XCTAssertEqual(c.workMinutes, 1)
        XCTAssertEqual(c.sessionsPerSet, 12)
        XCTAssertEqual(c.longRestMinutes, 180)
    }

    func testSettingsCodableRoundTrip() throws {
        var s = TimerSettings(); s.workMinutes = 50; s.delayLongBreak = true
        let back = try JSONDecoder().decode(TimerSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(s, back)
    }
}
