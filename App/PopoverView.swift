import SwiftUI
import BreakBarCore

/// The popover opened from the menu bar: main button, set progress, contextual actions,
/// the three intervals, and the menu.
struct PopoverView: View {
    @ObservedObject var controller: TimerController
    let closePopover: () -> Void
    let openSettings: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var hoveringMainButton = false

    private var machine: TimerMachine { controller.machine }
    private var actions: AvailableActions { machine.available }
    private var palette: BBPalette { .surface(scheme) }

    /// The row of Pause / Snooze / Skip buttons only exists when there is something to show,
    /// so an idle popover has no empty gap.
    private var hasActions: Bool {
        actions.canPause || actions.canResume || actions.canSnooze || actions.canExtend || actions.canSkip
    }

    var body: some View {
        VStack(spacing: 10) {
            mainButton

            HStack(spacing: 10) {
                SessionDots(dots: machine.dots, palette: palette)
                progressText(machine.sessionProgress)
            }
            .font(.callout)
            .foregroundStyle(palette.secondaryText)

            if hasActions { contextualActions }

            IntervalsRow(controller: controller, palette: palette)

            Rectangle().fill(palette.line).frame(height: 1)

            VStack(spacing: 0) {
                MenuRow(title: "Reset set", palette: palette, enabled: machine.completedSessions > 0 || machine.longBreakPostponed) {
                    controller.send(.resetSet)
                }
                MenuRow(title: "Settings…", shortcutHint: "⌘,", key: ",", palette: palette) {
                    closePopover()
                    openSettings()
                }
                MenuRow(title: "About BreakBar", palette: palette) {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel()
                }
                MenuRow(title: "Quit", shortcutHint: "⌘Q", key: "q", palette: palette) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(12)
        .frame(width: 264)
        .foregroundStyle(palette.text)
        .background(palette.background)
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
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(BBButtonStyle(role: .primary, palette: palette, size: 13, fillWidth: true))
        .keyboardShortcut(.defaultAction)
        .onHover { hoveringMainButton = $0 }
    }

    @ViewBuilder private var mainButtonLabel: some View {
        if actions.canStartRest { Text("Start resting") }
        else if actions.canStartWork { Text("Start working") }
        else if machine.state == .idle { Text("Start") }
        else if hoveringMainButton { Text("Stop") }
        else { Text(verbatim: machine.menuBarTitle(at: controller.now) ?? "").monospacedDigit() }
    }

    // MARK: Contextual actions

    private var contextualActions: some View {
        let s = machine.settings
        return HStack(spacing: 8) {
            if actions.canPause { Button("Pause") { controller.send(.pause) } }
            if actions.canResume { Button("Resume") { controller.send(.resume) } }
            if actions.canSnooze { Button("Snooze \(s.snoozeMinutes) min") { controller.send(.snooze) } }
            if actions.canExtend { Button("+\(s.extendMinutes) min") { controller.send(.extend) } }
            if actions.canSkip { skipButton }
        }
        .buttonStyle(BBButtonStyle(role: .secondary, palette: palette, size: 12))
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

// MARK: - Intervals: three pills, one stepper

/// Work / short rest / long rest as three pills. Click a pill to open its stepper; click it again to fold it away.
private struct IntervalsRow: View {
    @ObservedObject var controller: TimerController
    let palette: BBPalette
    @State private var open: Interval?

    private enum Interval: CaseIterable, Identifiable {
        case work, short, long

        var id: Self { self }

        var keyPath: WritableKeyPath<TimerSettings, Int> {
            switch self {
            case .work: return \.workMinutes
            case .short: return \.shortRestMinutes
            case .long: return \.longRestMinutes
            }
        }

        var pillLabel: LocalizedStringKey {
            switch self {
            case .work: return "Work"
            case .short: return "Short"
            case .long: return "Long"
            }
        }

        var fullLabel: LocalizedStringKey {
            switch self {
            case .work: return "Work session"
            case .short: return "Short rest"
            case .long: return "Long rest"
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Interval.allCases) { interval in
                    IntervalPill(minutes: controller.settings[keyPath: interval.keyPath],
                                 label: interval.pillLabel,
                                 selected: open == interval,
                                 palette: palette) {
                        open = (open == interval) ? nil : interval
                    }
                }
            }
            if let interval = open {
                stepper(for: interval)
            }
        }
    }

    private func stepper(for interval: Interval) -> some View {
        let minutes = controller.settings[keyPath: interval.keyPath]
        return HStack(spacing: 8) {
            Text(interval.fullLabel)
            Spacer()
            StepButton(systemName: "minus", label: "Decrease", palette: palette) { adjust(interval, by: -1) }
            Text("\(minutes) min")
                .monospacedDigit()
                .frame(minWidth: 56)
            StepButton(systemName: "plus", label: "Increase", palette: palette) { adjust(interval, by: 1) }
        }
        .padding(.horizontal, 4)
    }

    private func adjust(_ interval: Interval, by delta: Int) {
        let current = controller.settings[keyPath: interval.keyPath]
        controller.settings[keyPath: interval.keyPath] = min(180, max(1, current + delta))   // the setter clamps and saves
    }
}

private struct IntervalPill: View {
    let minutes: Int
    let label: LocalizedStringKey
    let selected: Bool
    let palette: BBPalette
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(verbatim: String(minutes))
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 10.5))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(selected ? Color.ink.opacity(0.7) : palette.secondaryText)
            }
            .foregroundStyle(selected ? Color.ink : palette.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.tomato, lineWidth: selected ? 1.5 : 0)
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var background: Color {
        if selected { return .restPink }
        return hovering ? palette.hover : palette.control
    }
}

private struct StepButton: View {
    let systemName: String
    let label: LocalizedStringKey
    let palette: BBPalette
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(hovering ? palette.hover : palette.control, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .onHover { hovering = $0 }
    }
}

// MARK: - Menu rows

/// A text row that highlights on hover, like a menu item.
private struct MenuRow: View {
    let title: LocalizedStringKey
    var shortcutHint: String? = nil
    var key: KeyEquivalent? = nil
    let palette: BBPalette
    var enabled = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let shortcutHint {
                    Text(verbatim: shortcutHint).foregroundStyle(palette.secondaryText)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .foregroundStyle(enabled ? palette.text : palette.secondaryText)
            .background(hovering && enabled ? palette.hover : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
        .commandShortcut(key)
    }
}

private extension View {
    /// ⌘ + key, when there is a key.
    @ViewBuilder func commandShortcut(_ key: KeyEquivalent?) -> some View {
        if let key {
            self.keyboardShortcut(key, modifiers: .command)
        } else {
            self
        }
    }
}
