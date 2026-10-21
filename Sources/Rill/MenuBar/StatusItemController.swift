import AppKit
import UniformTypeIdentifiers

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let pauseItem: NSMenuItem

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        pauseItem = NSMenuItem(title: "暂停", action: #selector(togglePause), keyEquivalent: "p")
        super.init()

        let image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Rill")
        image?.isTemplate = true
        statusItem.button?.image = image

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let chooseItem = NSMenuItem(title: "选择视频…", action: #selector(chooseVideo), keyEquivalent: "o")
        chooseItem.target = self
        pauseItem.target = self

        menu.addItem(chooseItem)
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 Rill", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        pauseItem.title = model.isPaused ? "继续播放" : "暂停"
        pauseItem.isEnabled = model.videoURL != nil
    }

    @objc private func chooseVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择一段视频作为桌面壁纸"
        NSApp.activate()
        if panel.runModal() == .OK, let url = panel.url {
            model.setVideo(url)
        }
    }

    @objc private func togglePause() {
        model.togglePause()
    }
}
