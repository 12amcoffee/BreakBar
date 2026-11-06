import KeyboardShortcuts
import BreakBarCore

extension KeyboardShortcuts.Name {
    /// Start when idle, otherwise stop.
    static let startStop = Self("startStop")
    /// Answers whichever window is waiting: "Start resting" or "Start working".
    static let answerPrompt = Self("answerPrompt")
}

@MainActor
final class HotkeyManager {
    init(controller: TimerController) {
        KeyboardShortcuts.onKeyUp(for: .startStop) {
            Task { @MainActor in controller.toggle() }
        }
        KeyboardShortcuts.onKeyUp(for: .answerPrompt) {
            Task { @MainActor in
                let actions = controller.machine.available
                if actions.canStartRest { controller.send(.startRest) }
                else if actions.canStartWork { controller.send(.startWork) }
            }
        }
    }
}
