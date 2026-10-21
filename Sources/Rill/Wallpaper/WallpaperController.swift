import AppKit
import AVFoundation

@MainActor
final class WallpaperController {
    private let player: AVPlayer
    private var windows: [CGDirectDisplayID: WallpaperWindow] = [:]
    private var isShown = false

    var videoGravity: AVLayerVideoGravity = .resizeAspectFill {
        didSet { windows.values.forEach { $0.playerView.videoGravity = videoGravity } }
    }

    init(player: AVPlayer) {
        self.player = player
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncWithScreens() }
        }
    }

    func show() {
        isShown = true
        syncWithScreens()
    }

    func hide() {
        isShown = false
        windows.values.forEach { $0.orderOut(nil) }
    }

    private func syncWithScreens() {
        guard isShown else { return }
        var connected = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let id = screen.displayID else { continue }
            connected.insert(id)
            if let window = windows[id] {
                // Resolution or arrangement changed.
                if window.frame != screen.frame {
                    window.setFrame(screen.frame, display: true)
                }
            } else {
                let window = WallpaperWindow(screen: screen, player: player)
                window.playerView.videoGravity = videoGravity
                windows[id] = window
            }
            windows[id]?.orderFront(nil)
        }
        for id in windows.keys where !connected.contains(id) {
            windows.removeValue(forKey: id)?.orderOut(nil)
        }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
