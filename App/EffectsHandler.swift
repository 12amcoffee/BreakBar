import Combine
import BreakBarCore

/// Carries out the machine's effects: sounds and notifications.
/// A notification is only sent when no window already tells you the same thing.
@MainActor
final class EffectsHandler {
    private let controller: TimerController
    private let sounds = SoundPlayer()
    private let notifications = NotificationManager()
    private var cancellable: AnyCancellable?

    init(controller: TimerController) {
        self.controller = controller
        notifications.onSkip = { [weak controller] in
            // "Skip" on a notification only makes sense while resting.
            if case .resting = controller?.machine.state { controller?.send(.skip) }
        }
        controller.onEffects = { [weak self] effects in self?.handle(effects) }
        cancellable = controller.$machine.sink { [weak self] machine in self?.sounds.apply(machine.settings) }
    }

    private func handle(_ effects: [TimerEffect]) {
        let machine = controller.machine
        let s = machine.settings
        for effect in effects {
            switch effect {
            case .playWindup, .playDing, .startTicking, .stopTicking:
                sounds.play(effect, settings: s)
            case .notifyRestStarted(let kind):
                if s.notificationsEnabled, case .resting = machine.state { notifications.restStarted(long: kind == .long) }
            case .notifyRestEnded:
                if s.notificationsEnabled, !isWaitingForWork(machine.state) { notifications.restEnded() }
            }
        }
    }

    private func isWaitingForWork(_ state: TimerState) -> Bool {
        if case .awaitingWork = state { return true }
        return false
    }

    func previewSound(_ sound: SoundPlayer.PreviewSound) {
        sounds.preview(sound, settings: controller.settings)
    }
}
