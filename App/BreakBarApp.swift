import SwiftUI

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
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(controller: TimerController())
    }
}
