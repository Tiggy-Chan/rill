import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A video passed at launch (Finder "Open With", `open -a`) arrives before this and wins.
        if model.video == nil {
            model.restoreLastVideo()
        }
        let controller = StatusItemController(model: model)
        statusItemController = controller
        model.onProblem = { [weak controller] in controller?.showPanel() }
        if model.video == nil {
            // Let the status item settle in the menu bar before anchoring the panel to it.
            Task { controller.showPanel() }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        model.setVideo(url)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItemController?.showPanel()
        return false
    }
}
