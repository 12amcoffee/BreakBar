import SwiftUI
import BreakBarCore

@main
struct BreakBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // The app lives in the menu bar; the Settings scene is a required placeholder.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var effects: EffectsHandler?
    private var hotkeys: HotkeyManager?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = TimerController.shared
        let effects = EffectsHandler(controller: controller)
        self.effects = effects
        hotkeys = HotkeyManager(controller: controller)
        statusItemController = StatusItemController(controller: controller, effects: effects)
    }

    /// `open breakbar://startRest` etc. (see URLCommand for the full list)
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            switch URLCommand(url: url) {
            case .toggle: TimerController.shared.toggle()
            case .event(let event): TimerController.shared.send(event)
            case nil: NSLog("BreakBar: unknown URL command %@", url.absoluteString)
            }
        }
    }
}
