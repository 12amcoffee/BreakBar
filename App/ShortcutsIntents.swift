import AppIntents
import BreakBarCore

// Actions for the Shortcuts app. Build a shortcut that turns on a Focus (Do Not Disturb)
// together with "Start timer", then run it from the menu bar, a hotkey or an automation.
// Apps cannot switch Focus on their own; Shortcuts is Apple's way to do it.

private func run(_ event: TimerEvent) async -> some IntentResult {
    await MainActor.run { TimerController.shared.send(event) }
    return .result()
}

struct StartTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start timer"
    static let description = IntentDescription("Starts a work session.")
    func perform() async throws -> some IntentResult { await run(.start) }
}

struct StopTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop timer"
    static let description = IntentDescription("Stops the timer.")
    func perform() async throws -> some IntentResult { await run(.stop) }
}

struct SkipIntent: AppIntent {
    static let title: LocalizedStringResource = "Skip rest"
    static let description = IntentDescription("Skips the current rest and starts working.")
    func perform() async throws -> some IntentResult { await run(.skip) }
}

struct StartRestIntent: AppIntent {
    static let title: LocalizedStringResource = "Start resting"
    static let description = IntentDescription("Answers the Rest window.")
    func perform() async throws -> some IntentResult { await run(.startRest) }
}

struct StartWorkIntent: AppIntent {
    static let title: LocalizedStringResource = "Start working"
    static let description = IntentDescription("Answers the Start working window.")
    func perform() async throws -> some IntentResult { await run(.startWork) }
}

struct BreakBarShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartTimerIntent(), phrases: ["Start \(.applicationName)"],
                    shortTitle: "Start timer", systemImageName: "play.fill")
        AppShortcut(intent: StopTimerIntent(), phrases: ["Stop \(.applicationName)"],
                    shortTitle: "Stop timer", systemImageName: "stop.fill")
        AppShortcut(intent: StartRestIntent(), phrases: ["Start resting with \(.applicationName)"],
                    shortTitle: "Start resting", systemImageName: "cup.and.saucer.fill")
        AppShortcut(intent: StartWorkIntent(), phrases: ["Start working with \(.applicationName)"],
                    shortTitle: "Start working", systemImageName: "hourglass")
        AppShortcut(intent: SkipIntent(), phrases: ["Skip rest with \(.applicationName)"],
                    shortTitle: "Skip rest", systemImageName: "forward.fill")
    }
}
