import AppKit
import SwiftUI

/// Our own window instead of SwiftUI's Settings scene: opening that scene from a menu bar
/// app differs between macOS versions, while a plain NSWindow behaves the same everywhere.
@MainActor
final class SettingsWindowController {
    private let controller: TimerController
    private let effects: EffectsHandler
    private let prompts: PromptPresenter
    private var window: NSWindow?

    init(controller: TimerController, effects: EffectsHandler, prompts: PromptPresenter) {
        self.controller = controller
        self.effects = effects
        self.prompts = prompts
    }

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(controller: controller, effects: effects, preview: { [prompts] in prompts.showPreview($0) })))
            w.title = String(localized: "Settings")
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.titlebarAppearsTransparent = true      // let the warm background run up behind the title
            w.backgroundColor = .bbSurface
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)   // menu bar apps are not frontmost by default
        window?.makeKeyAndOrderFront(nil)
    }
}
