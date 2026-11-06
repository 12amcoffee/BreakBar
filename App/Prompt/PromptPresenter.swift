import AppKit
import Combine
import BreakBarCore

/// Decides when the Rest / Start working window is on screen, and answers its buttons.
///
/// Rules:
/// - It appears when the timer starts waiting for you (awaitingRest, awaitingWork).
/// - After "Start resting" it stays up as a countdown (until Hide / Esc / rest ends).
/// - Snooze, pause, work, idle: no window.
/// - Closing it (Close / Hide / Esc) never changes the timer; the menu bar still shows the waiting state.
@MainActor
final class PromptPresenter {
    private let controller: TimerController
    private let model = PromptModel(spec: PromptSpec(kind: .rest, progress: .longBreak))
    private var live: PromptWindowSet?
    private var preview: PromptWindowSet?
    private var previewTimer: Timer?
    private var visible = false
    private var lastTag: String?
    private var cancellable: AnyCancellable?

    init(controller: TimerController) {
        self.controller = controller
        model.handlers = PromptHandlers(
            primary: { [weak self] in
                guard let self else { return }
                self.controller.send(self.model.spec.kind == .rest ? .startRest : .startWork)
            },
            snooze: { [weak self] in self?.controller.send(.snooze) },
            extend: { [weak self] in self?.controller.send(.extend) },
            skip: { [weak self] in self?.controller.send(.skip) },
            hide: { [weak self] in self?.hideLive() }
        )
        cancellable = controller.$machine.sink { [weak self] machine in self?.update(machine) }
    }

    // MARK: Live window

    private func update(_ machine: TimerMachine) {
        let tag = machine.state.name.hasPrefix("resting") ? "resting" : machine.state.name
        if tag != lastTag {
            lastTag = tag
            switch tag {
            case "awaitingRest", "awaitingWork": visible = true      // newly waiting for you
            case "resting": break                                     // keep whatever it was
            default: visible = false
            }
        }
        guard visible, let spec = PromptSpec(machine: machine) else {
            closeLive()
            return
        }
        model.spec = spec
        let style = machine.settings.windowStyle
        if live?.style != style {
            live?.close()
            live = PromptWindowSet(style: style, model: model, onEscape: { [weak self] in self?.hideLive() })
        }
    }

    private func hideLive() {
        visible = false
        closeLive()
    }

    private func closeLive() {
        live?.close()
        live = nil
    }

    // MARK: Preview (Settings > Windows)

    /// Shows a style with sample data. Nothing here touches the timer.
    func showPreview(_ style: WindowStyle) {
        closePreview()
        let spec = PromptSpec(kind: .rest, progress: .done(2, of: 4, longBreakNext: false),
                              snoozeMinutes: controller.settings.snoozeMinutes, canSkip: true)
        let close: () -> Void = { [weak self] in self?.closePreview() }
        let model = PromptModel(spec: spec, handlers: PromptHandlers(primary: close, snooze: close, extend: close, skip: close, hide: close))
        preview = PromptWindowSet(style: style, model: model, onEscape: close)
        // A preview must never linger, least of all the full-screen one.
        previewTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { _ in
            Task { @MainActor in close() }
        }
    }

    private func closePreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        preview?.close()
        preview = nil
    }
}
