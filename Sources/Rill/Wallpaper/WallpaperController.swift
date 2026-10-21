import AppKit
import AVFoundation

@MainActor
final class WallpaperController {
    private let player: AVPlayer
    private var windows: [WallpaperWindow] = []

    init(player: AVPlayer) {
        self.player = player
    }

    func show() {
        if windows.isEmpty {
            windows = NSScreen.screens.map { WallpaperWindow(screen: $0, player: player) }
        }
        windows.forEach { $0.orderFront(nil) }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
    }
}
