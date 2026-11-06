import Foundation
import BreakBarCore

/// Owns the TimerMachine, drives it once a second, and saves/restores settings and the set counter.
/// The machine knows nothing about clocks or storage; this class supplies both.
@MainActor
final class TimerController: ObservableObject {
    @Published private(set) var machine: TimerMachine
    /// Updated every tick so views showing a countdown redraw.
    @Published private(set) var now = Date()

    /// Called with the effects of each event (sounds and notifications are wired up here later).
    var onEffects: (([TimerEffect]) -> Void)?

    private let defaults: UserDefaults
    private var ticker: Timer?

    private enum Key {
        static let settings = "timerSettings"
        static let completed = "completedSessions"
        static let postponed = "longBreakPostponed"
        static let lastActive = "lastActive"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var settings = TimerSettings()
        if let data = defaults.data(forKey: Key.settings),
           let saved = try? JSONDecoder().decode(TimerSettings.self, from: data) {
            settings = saved
        }
        machine = TimerMachine(
            settings: settings,
            completedSessions: defaults.integer(forKey: Key.completed),
            longBreakPostponed: defaults.bool(forKey: Key.postponed),
            lastActive: defaults.object(forKey: Key.lastActive) as? Date
        )
        startTicker()
    }

    var settings: TimerSettings {
        get { machine.settings }
        set {
            machine.settings = newValue.clamped()
            save()
        }
    }

    func send(_ event: TimerEvent) {
        now = Date()
        let effects = machine.handle(event, at: now)
        save()
        if !effects.isEmpty { onEffects?(effects) }
    }

    /// Start when idle, otherwise stop (the popover's main button and the hotkey).
    func toggle() {
        send(machine.state == .idle ? .start : .stop)
    }

    private func startTicker() {
        // .common mode keeps the timer firing while a menu or popover is tracking the mouse.
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.send(.tick) }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func save() {
        if let data = try? JSONEncoder().encode(machine.settings) {
            defaults.set(data, forKey: Key.settings)
        }
        defaults.set(machine.completedSessions, forKey: Key.completed)
        defaults.set(machine.longBreakPostponed, forKey: Key.postponed)
        defaults.set(machine.lastActive, forKey: Key.lastActive)
    }
}
