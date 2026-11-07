import AppKit
import SwiftUI
import BreakBarCore

/// A borderless panel that can take keyboard focus (so Esc works) and reports Esc.
final class PromptPanel: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onEscape?() }

    /// A borderless window does not turn Esc into `cancelOperation` by itself, so catch the key directly.
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {          // 53 = Esc
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

/// The actual AppKit windows for one style: one panel, or one per display for the full-screen overlay.
/// Panels float above other apps, follow you across Spaces and appear over full-screen apps.
@MainActor
final class PromptWindowSet {
    let style: PromptWindowStyle
    private var panels: [PromptPanel] = []

    init(style: PromptWindowStyle, model: PromptModel, onEscape: @escaping () -> Void) {
        self.style = style

        let active = Self.activeScreen()
        let screens = style == .fullScreen ? [active] + NSScreen.screens.filter { $0 != active } : [active]

        for screen in screens {
            let frame = Self.frame(for: style, on: screen)
            let panel = PromptPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                    backing: .buffered, defer: false)
            panel.onEscape = onEscape
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = style != .fullScreen
            panel.level = style == .fullScreen ? .screenSaver : (style == .banner ? .statusBar : .floating)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.isMovableByWindowBackground = style == .small
            panel.contentView = NSHostingView(rootView: PromptView(model: model, style: style))
            panels.append(panel)
        }
        show()
    }

    func close() {
        panels.forEach { $0.orderOut(nil); $0.close() }
        panels = []
    }

    // MARK: Showing

    private func show() {
        switch style {
        case .banner:
            guard let panel = panels.first else { return }
            let final = panel.frame
            panel.setFrame(final.offsetBy(dx: 0, dy: final.height + 30), display: false)   // start above the screen edge
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                panel.animator().setFrame(final, display: true)
                panel.animator().alphaValue = 1
            }
        case .small:
            panels.first?.orderFrontRegardless()          // click-only: never takes the keyboard from what you are typing
        case .maximised, .fullScreen:
            NSApp.activate(ignoringOtherApps: true)       // so Esc works straight away
            panels.first?.makeKeyAndOrderFront(nil)
            panels.dropFirst().forEach { $0.orderFrontRegardless() }
        }
    }

    // MARK: Geometry

    private static func activeScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private static func frame(for style: PromptWindowStyle, on screen: NSScreen) -> NSRect {
        let area = screen.visibleFrame
        switch style {
        case .small:
            let size = NSSize(width: 380, height: 330)
            return NSRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2, width: size.width, height: size.height)
        case .maximised:
            return area.insetBy(dx: 40, dy: 40)
        case .fullScreen:
            return screen.frame
        case .banner:
            let size = NSSize(width: 580, height: 76)
            return NSRect(x: area.maxX - size.width - 16, y: area.maxY - size.height - 12, width: size.width, height: size.height)
        }
    }
}
