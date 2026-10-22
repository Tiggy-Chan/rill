import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(model: AppModel) {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab(L10n.general, symbol: "gearshape", content: GeneralSettingsView(model: model)))
        tabs.addTabViewItem(Self.tab(L10n.library, symbol: "film.stack", content: LibrarySettingsView(model: model)))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(tab: Int? = nil) {
        guard let window else { return }
        if let tab, let tabs = contentViewController as? NSTabViewController, tabs.tabViewItems.indices.contains(tab) {
            tabs.selectedTabViewItemIndex = tab
        }
        NSApp.activate()
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
    }

    private static func tab(_ title: String, symbol: String, content: some View) -> NSTabViewItem {
        let host = NSHostingController(rootView: content.frame(width: 480))
        host.sizingOptions = .preferredContentSize
        // The tab view controller shows the selected tab's title as the window title.
        host.title = title
        let item = NSTabViewItem(viewController: host)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}
