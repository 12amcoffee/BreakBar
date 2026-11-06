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
    private var cancellables = Set<AnyCancellable>()

    private static let digitFont = NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)

    init(controller: TimerController) {
        self.controller = controller
        super.init()

        popover.behavior = .transient
        let hosting = NSHostingController(
            rootView: PopoverView(controller: controller, closePopover: { [weak self] in self?.popover.performClose(nil) })
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
        let symbol = Self.symbolName(machine.icon)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: machine.icon.accessibilityLabel)

        // "Show timer in menu bar" setting arrives in the Settings step; for now always show it.
        if let title = machine.menuBarTitle(at: now) {
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
        case .idle: return "timer"
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
        case .idle: return "BreakBar, idle"
        case .working: return "Working"
        case .paused: return "Paused"
        case .waitingToRest: return "Waiting to start rest"
        case .snoozed: return "Rest snoozed"
        case .shortRest: return "Short rest"
        case .longRest: return "Long rest"
        case .waitingToWork: return "Waiting to start work"
        }
    }
}
