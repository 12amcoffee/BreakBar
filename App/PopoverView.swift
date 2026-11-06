import SwiftUI
import BreakBarCore

/// The popover opened from the menu bar: main button, contextual actions, set progress.
struct PopoverView: View {
    @ObservedObject var controller: TimerController
    let closePopover: () -> Void
    let openSettings: () -> Void
    @State private var hoveringMainButton = false

    private var machine: TimerMachine { controller.machine }
    private var actions: AvailableActions { machine.available }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            mainButton

            progressText(machine.sessionProgress)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            contextualActions

            Divider()

            Button("Reset set") { controller.send(.resetSet) }
                .buttonStyle(.plain)
                .disabled(machine.completedSessions == 0 && !machine.longBreakPostponed)
                .help("Start counting sessions toward the next long break from zero")

            Button("Settings…") {
                closePopover()
                openSettings()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",")

            Button("About BreakBar") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel()
            }
            .buttonStyle(.plain)

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 260)
        .tint(.tomato)
    }

    // MARK: Main button

    /// Idle: "Start". Waiting for you: the prompt's action. Otherwise the clock, which turns into "Stop" on hover.
    private var mainButton: some View {
        Button {
            if actions.canStartRest { controller.send(.startRest) }
            else if actions.canStartWork { controller.send(.startWork) }
            else { controller.toggle() }
            closePopover()
        } label: {
            mainButtonLabel
                .font(.system(.body).monospacedDigit())
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .onHover { hoveringMainButton = $0 }
    }

    @ViewBuilder private var mainButtonLabel: some View {
        if actions.canStartRest { Text("Start resting") }
        else if actions.canStartWork { Text("Start working") }
        else if machine.state == .idle { Text("Start") }
        else if hoveringMainButton { Text("Stop") }
        else { Text(verbatim: machine.menuBarTitle(at: controller.now) ?? "") }
    }

    // MARK: Contextual actions

    @ViewBuilder private var contextualActions: some View {
        let s = machine.settings
        HStack {
            if actions.canPause { Button("Pause") { controller.send(.pause) } }
            if actions.canResume { Button("Resume") { controller.send(.resume) } }
            if actions.canSnooze { Button("Snooze \(s.snoozeMinutes) min") { controller.send(.snooze) } }
            if actions.canExtend { Button("+\(s.extendMinutes) min") { controller.send(.extend) } }
            if actions.canSkip { skipButton }
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var skipButton: some View {
        if case .awaitingWork = machine.state {
            Button("Skip") { controller.send(.skip) }
        } else {
            Button("Skip rest") { controller.send(.skip) }
        }
    }
}
