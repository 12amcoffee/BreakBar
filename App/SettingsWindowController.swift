import AppKit
import SwiftUI

/// Our own window instead of SwiftUI's Settings scene: opening that scene from a menu bar
/// app differs between macOS versions, while a plain NSWindow behaves the same everywhere.
@MainActor
final class SettingsWindowController {
    private let controller: TimerController
    private let effects: EffectsHandler
    private var window: NSWindow?

    init(controller: TimerController, effects: EffectsHandler) {
        self.controller = controller
        self.effects = effects
    }

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(controller: controller, effects: effects)))
            w.title = String(localized: "Settings")
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)   // menu bar apps are not frontmost by default
        window?.makeKeyAndOrderFront(nil)
    }
}
