import AppKit

@MainActor
enum VideoPicker {
    /// Shows an open panel for one or more videos. Returns nil when cancelled.
    static func run() -> [URL]? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = L10n.openPanelMessage
        panel.prompt = L10n.setAsWallpaper
        NSApp.activate()
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return nil }
        return panel.urls
    }
}
