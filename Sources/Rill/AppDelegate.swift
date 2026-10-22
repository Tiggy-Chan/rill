import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusItemController: StatusItemController?
    private lazy var settingsWindow = SettingsWindowController(model: model)

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Before any "Open With" files arrive, so they're added to the saved library rather than replacing it.
        model.restore()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = StatusItemController(model: model, openSettings: { [weak self] in self?.settingsWindow.show() })
        statusItemController = controller
        model.onProblem = { [weak controller] in controller?.showPanel() }
        #if DEBUG
        if CommandLine.arguments.contains("-RillOpenSettings") {
            let tab = UserDefaults.standard.integer(forKey: "RillSettingsTab")
            Task { settingsWindow.show(tab: tab) }
        }
        #endif
        if model.video == nil || model.problem != nil {
            // Let the status item settle in the menu bar before anchoring the panel to it.
            Task { controller.showPanel() }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        model.addVideos(urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItemController?.showPanel()
        return false
    }
}
