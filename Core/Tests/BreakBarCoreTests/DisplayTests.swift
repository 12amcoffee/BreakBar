import XCTest
@testable import BreakBarCore

final class DisplayTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testFormatClock() {
        XCTAssertEqual(formatClock(0), "00:00")
        XCTAssertEqual(formatClock(65), "01:05")
        XCTAssertEqual(formatClock(45 * 60), "45:00")
        XCTAssertEqual(formatClock(-3), "00:00")
    }

    func testIdleHasNoTitle() {
        XCTAssertNil(TimerMachine().menuBarTitle(at: t0))
        XCTAssertEqual(TimerMachine().icon, .idle)
    }

    func testWorkCountdownStartsAtFullLength() {
        var m = TimerMachine(); m.handle(.start, at: t0)
        XCTAssertEqual(m.menuBarTitle(at: t0), "45:00")
        XCTAssertEqual(m.menuBarTitle(at: t0.addingTimeInterval(0.4)), "45:00")
        XCTAssertEqual(m.menuBarTitle(at: t0.addingTimeInterval(61)), "43:59")
        XCTAssertEqual(m.icon, .working)
    }

    func testWaitingToRestCountsUpWithPlus() {
        var m = TimerMachine(); m.handle(.start, at: t0)
        let end = t0.addingTimeInterval(45 * 60); m.handle(.tick, at: end)
        XCTAssertEqual(m.icon, .waitingToRest)
        XCTAssertEqual(m.menuBarTitle(at: end.addingTimeInterval(83)), "+01:23")
    }

    func testSnoozedTitle() {
        var m = TimerMachine(); m.handle(.start, at: t0)
        let end = t0.addingTimeInterval(45 * 60); m.handle(.tick, at: end)
        m.handle(.snooze, at: end)
        XCTAssertEqual(m.menuBarTitle(at: end.addingTimeInterval(15)), "01:45")
        XCTAssertEqual(m.icon, .snoozed)
    }

    func testPausedTitle() {
        var m = TimerMachine(); m.handle(.start, at: t0)
        m.handle(.pause, at: t0.addingTimeInterval(60))
        XCTAssertEqual(m.menuBarTitle(at: t0.addingTimeInterval(500)), "44:00")
    }

    func testSessionProgress() {
        var m = TimerMachine()
        XCTAssertEqual(m.sessionProgress, .session(current: 1, of: 4))
        m.handle(.start, at: t0); m.handle(.tick, at: t0.addingTimeInterval(45 * 60))
        XCTAssertEqual(m.sessionProgress, .done(1, of: 4, longBreakNext: false))
        m.handle(.skip, at: t0.addingTimeInterval(46 * 60))
        XCTAssertEqual(m.sessionProgress, .session(current: 2, of: 4))
    }

    func testSessionProgressLongBreakAndPostponed() {
        var s = TimerSettings(); s.sessionsPerSet = 1
        var m = TimerMachine(settings: s)
        m.handle(.start, at: t0); m.handle(.tick, at: t0.addingTimeInterval(45 * 60))
        XCTAssertEqual(m.sessionProgress, .longBreak)

        s.delayLongBreak = true
        var d = TimerMachine(settings: s)
        d.handle(.start, at: t0); d.handle(.tick, at: t0.addingTimeInterval(45 * 60))
        XCTAssertEqual(d.sessionProgress, .done(1, of: 1, longBreakNext: true))
        d.handle(.skip, at: t0.addingTimeInterval(46 * 60))
        XCTAssertEqual(d.sessionProgress, .longBreakAfterThisSession)
    }

    func testAvailableActions() {
        var m = TimerMachine()
        XCTAssertEqual(m.available, AvailableActions())
        m.handle(.start, at: t0)
        XCTAssertTrue(m.available.canPause)
        XCTAssertFalse(m.available.canSkip)
        m.handle(.tick, at: t0.addingTimeInterval(45 * 60))
        XCTAssertTrue(m.available.canStartRest && m.available.canSnooze && m.available.canSkip)
        m.handle(.startRest, at: t0.addingTimeInterval(46 * 60))
        XCTAssertTrue(m.available.canExtend && m.available.canSkip && m.available.canPause)
    }

    func testSnoozeUnavailableAtLimit() {
        var s = TimerSettings(); s.maxSnoozesPerBreak = 1
        var m = TimerMachine(settings: s)
        m.handle(.start, at: t0)
        var now = t0.addingTimeInterval(45 * 60); m.handle(.tick, at: now)
        m.handle(.snooze, at: now)
        now = now.addingTimeInterval(121); m.handle(.tick, at: now)
        XCTAssertFalse(m.available.canSnooze)
    }
}

final class CommandAndNameTests: XCTestCase {
    func testURLCommands() {
        XCTAssertEqual(URLCommand(url: URL(string: "breakbar://startRest")!), .event(.startRest))
        XCTAssertEqual(URLCommand(url: URL(string: "BreakBar://TOGGLE")!), .toggle)
        XCTAssertEqual(URLCommand(url: URL(string: "breakbar://startStop")!), .toggle)
        XCTAssertNil(URLCommand(url: URL(string: "breakbar://nonsense")!))
        XCTAssertNil(URLCommand(url: URL(string: "other://start")!))
    }

    func testStateNames() {
        XCTAssertEqual(TimerState.idle.name, "idle")
        XCTAssertEqual(TimerState.resting(kind: .long, endsAt: Date()).name, "restingLong")
    }

    func testVolumesAreClampedAndDefaultsQuiet() {
        var s = TimerSettings()
        XCTAssertEqual(s.tickingVolume, 0); XCTAssertEqual(s.windupVolume, 0)
        s.dingVolume = 7; s.tickingVolume = -1
        XCTAssertEqual(s.clamped().dingVolume, 1); XCTAssertEqual(s.clamped().tickingVolume, 0)
    }
}

final class DotsTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testDotsWhileWorkingOnSecondSession() {
        var m = TimerMachine()
        m.handle(.start, at: t0); m.handle(.tick, at: t0.addingTimeInterval(45 * 60))   // session 1 done
        m.handle(.skip, at: t0.addingTimeInterval(46 * 60))                             // now working on session 2
        XCTAssertEqual(m.dots, DotProgress(done: 1, hasCurrent: true, total: 4))
    }

    func testDotsWhileWaitingToRest() {
        var m = TimerMachine()
        m.handle(.start, at: t0); m.handle(.tick, at: t0.addingTimeInterval(45 * 60))
        XCTAssertEqual(m.dots, DotProgress(done: 1, hasCurrent: false, total: 4))
    }

    func testDotsDuringLongBreakAreAllDone() {
        var s = TimerSettings(); s.sessionsPerSet = 2
        var m = TimerMachine(settings: s)
        var now = t0
        for _ in 0..<2 {
            m.handle(.start, at: now); now = now.addingTimeInterval(45 * 60); m.handle(.tick, at: now)
            if m.state != .idle, m.available.canSkip { m.handle(.skip, at: now) }
            m.handle(.stop, at: now)
        }
        XCTAssertEqual(m.sessionProgress, .session(current: 1, of: 2))   // the set restarted after the long break
        XCTAssertEqual(m.dots, DotProgress(done: 0, hasCurrent: true, total: 2))
    }

    func testDotsIdleAtStartOfSet() {
        XCTAssertEqual(TimerMachine().dots, DotProgress(done: 0, hasCurrent: true, total: 4))
    }

    func testDotsNeverExceedTotal() {
        var s = TimerSettings(); s.sessionsPerSet = 1; s.delayLongBreak = true
        var m = TimerMachine(settings: s)
        m.handle(.start, at: t0); m.handle(.tick, at: t0.addingTimeInterval(45 * 60))   // postponed: completed == total
        let d = m.dots
        XCTAssertLessThanOrEqual(d.done, d.total)
    }
}
