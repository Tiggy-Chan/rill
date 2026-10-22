import AppKit
import AVFoundation

/// One desktop-level window per display, each showing whichever player it's given.
@MainActor
final class WallpaperController {
    var onVisibilityChange: (() -> Void)?
    var onScreensChange: (() -> Void)?

    private var windows: [String: WallpaperWindow] = [:]
    private var players: [String: AVPlayer] = [:]
    private var lastVisible: Set<String> = []

    var videoGravity: AVLayerVideoGravity = .resizeAspectFill {
        didSet { windows.values.forEach { $0.playerView.videoGravity = videoGravity } }
    }

    /// Display keys whose wallpaper is at least partly visible.
    var visibleDisplayKeys: Set<String> {
        Set(windows.compactMap { key, window in
            players[key] != nil && window.isVisible && window.occlusionState.contains(.visible) ? key : nil
        })
    }

    init() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onScreensChange?() }
        }
        center.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.visibilityMayHaveChanged() }
        }
    }

    /// `players` maps display keys to the player that display should show. Displays left out show nothing.
    func setPlayers(_ players: [String: AVPlayer]) {
        self.players = players
        var connected = Set<String>()
        for screen in NSScreen.screens {
            guard let key = screen.displayKey else { continue }
            connected.insert(key)
            guard let player = players[key] else {
                windows[key]?.orderOut(nil)
                continue
            }
            let window = windows[key] ?? WallpaperWindow(screen: screen)
            windows[key] = window
            // Resolution or arrangement changed.
            if window.frame != screen.frame {
                window.setFrame(screen.frame, display: true)
            }
            window.playerView.videoGravity = videoGravity
            if window.playerView.player !== player {
                window.playerView.player = player
            }
            window.orderFront(nil)
        }
        for key in windows.keys where !connected.contains(key) {
            windows.removeValue(forKey: key)?.orderOut(nil)
        }
        visibilityMayHaveChanged()
    }

    private func visibilityMayHaveChanged() {
        let visible = visibleDisplayKeys
        guard visible != lastVisible else { return }
        lastVisible = visible
        onVisibilityChange?()
    }
}
