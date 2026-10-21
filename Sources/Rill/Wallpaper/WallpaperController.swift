import AppKit
import AVFoundation

@MainActor
final class WallpaperController {
    private let player: AVPlayer
    private var windows: [WallpaperWindow] = []

    var videoGravity: AVLayerVideoGravity = .resizeAspectFill {
        didSet { windows.forEach { $0.playerView.videoGravity = videoGravity } }
    }

    init(player: AVPlayer) {
        self.player = player
    }

    func show() {
        if windows.isEmpty {
            windows = NSScreen.screens.map { screen in
                let window = WallpaperWindow(screen: screen, player: player)
                window.playerView.videoGravity = videoGravity
                return window
            }
        }
        windows.forEach { $0.orderFront(nil) }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
    }
}
