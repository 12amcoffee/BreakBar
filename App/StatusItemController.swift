import AppKit
import Combine
import SwiftUI
import BreakBarCore

/// The menu bar item: icon + optional countdown, and the popover it opens.
@MainActor
final class StatusItemController: NSObject {
    private let controller: TimerController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let settingsWindow: SettingsWindowController
    private var cancellables = Set<AnyCancellable>()

    private static let digitFont = NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)

    init(controller: TimerController, effects: EffectsHandler, prompts: PromptPresenter) {
        self.controller = controller
        self.settingsWindow = SettingsWindowController(controller: controller, effects: effects, prompts: prompts)
        super.init()

        popover.behavior = .transient
        let hosting = NSHostingController(
            rootView: PopoverView(
                controller: controller,
                closePopover: { [weak self] in self?.popover.performClose(nil) },
                openSettings: { [weak self] in self?.settingsWindow.show() }
            )
        )
        hosting.sizingOptions = [.preferredContentSize]   // popover grows/shrinks with its content (macOS 13+)
        popover.contentViewController = hosting

        if let button = statusItem.button {
            button.imagePosition = .imageLeft
            button.target = self
            button.action = #selector(togglePopover)
        }

        // @Published emits the new value, so the sink never reads stale state.
        controller.$machine
            .combineLatest(controller.$now)
            .sink { [weak self] machine, now in self?.refresh(machine, now) }
            .store(in: &cancellables)
    }

    private func refresh(_ machine: TimerMachine, _ now: Date) {
        guard let button = statusItem.button else { return }
        if machine.icon == .idle, let glyph = NSImage(named: "MenuBarIcon") {
            // The BreakBar glyph (a template image, so macOS tints it for light and dark menu bars).
            glyph.isTemplate = true
            glyph.accessibilityDescription = machine.icon.accessibilityLabel
            button.image = glyph
        } else {
            let symbol = Self.symbolName(machine.icon)
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: machine.icon.accessibilityLabel)
        }

        if machine.settings.showTimerInMenuBar, let title = machine.menuBarTitle(at: now) {
            button.attributedTitle = NSAttributedString(string: " " + title, attributes: [.font: Self.digitFont])
        } else {
            button.attributedTitle = NSAttributedString(string: "")
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    static func symbolName(_ icon: MenuBarIcon) -> String {
        switch icon {
        case .idle: return "timer"        // fallback only; idle normally uses the MenuBarIcon glyph
        case .working: return "hourglass"
        case .paused: return "pause.circle.fill"
        case .waitingToRest: return "bell.fill"
        case .snoozed: return "zzz"
        case .shortRest: return "cup.and.saucer.fill"
        case .longRest: return "bed.double.fill"
        case .waitingToWork: return "bell.badge.fill"
        }
    }
}

private extension MenuBarIcon {
    var accessibilityLabel: String {
        switch self {
        case .idle: return String(localized: "Idle")
        case .working: return String(localized: "Working")
        case .paused: return String(localized: "Paused")
        case .waitingToRest: return String(localized: "Waiting to start rest")
        case .snoozed: return String(localized: "Rest snoozed")
        case .shortRest: return String(localized: "Short rest")
        case .longRest: return String(localized: "Long rest")
        case .waitingToWork: return String(localized: "Waiting to start work")
        }
    }
}
