import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate, NSWindowDelegate, NSDraggingDestination {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var localMonitor: Any?
    private var globalMonitor: Any?

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        configurePopover()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePanel),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }

    func showPanel(attempt: Int = 0) {
        guard let button = statusItem.button, !popover.isShown else { return }
        guard let window = button.window, window.frame.height > 0 else {
            // Right after launch the status item has no frame yet, so there is nothing to anchor to.
            if attempt < 15 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.showPanel(attempt: attempt + 1)
                }
            }
            return
        }
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        startMonitoringOutsideEvents()
    }

    @objc func closePanel() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    // MARK: - Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Rill")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "Rill"
        button.target = self
        button.action = #selector(togglePanel)
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])

        // NSWindow forwards dragging-destination calls to its delegate.
        button.window?.registerForDraggedTypes([.fileURL])
        button.window?.delegate = self
    }

    private func configurePopover() {
        let panel = PanelView(
            model: model,
            chooseVideo: { [weak self] in self?.chooseVideo() },
            quit: { NSApp.terminate(nil) }
        )
        let host = NSHostingController(rootView: panel)
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        // Closing is managed explicitly so clicking the menu bar icon toggles instead of reopening.
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.delegate = self
    }

    // MARK: - Actions

    @objc private func togglePanel() {
        if popover.isShown {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func chooseVideo() {
        closePanel()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择一段视频作为桌面壁纸"
        panel.prompt = "设为壁纸"
        panel.directoryURL = model.video?.url.deletingLastPathComponent()
        NSApp.activate()
        if panel.runModal() == .OK, let url = panel.url {
            model.setVideo(url)
        }
    }

    // MARK: - Outside click handling

    private func startMonitoringOutsideEvents() {
        stopMonitoringOutsideEvents()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    self.closePanel()
                    return nil
                }
                return event
            }
            let popoverWindow = self.popover.contentViewController?.view.window
            if event.window !== popoverWindow && event.window !== self.statusItem.button?.window {
                self.closePanel()
            }
            return event
        }
    }

    private func stopMonitoringOutsideEvents() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
    }

    func popoverDidClose(_ notification: Notification) {
        stopMonitoringOutsideEvents()
    }

    // MARK: - Drop a video onto the menu bar icon

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard videoURL(from: sender) != nil else { return [] }
        statusItem.button?.highlight(true)
        return .copy
    }

    func draggingExited(_ sender: NSDraggingInfo?) {
        statusItem.button?.highlight(false)
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        statusItem.button?.highlight(false)
        guard let url = videoURL(from: sender) else { return false }
        model.setVideo(url)
        return true
    }

    private func videoURL(from info: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: [UTType.movie.identifier],
        ]
        let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
        return urls?.first
    }
}
