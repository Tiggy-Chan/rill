import AppKit
import AVFoundation

final class WallpaperWindow: NSWindow {
    let playerView: PlayerView

    init(screen: NSScreen, player: AVPlayer) {
        playerView = PlayerView(player: player)
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        // Just above the system wallpaper, below Finder's desktop icons (desktopWindow + 20).
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        isOpaque = true
        hasShadow = false
        backgroundColor = .black
        isReleasedWhenClosed = false
        animationBehavior = .none
        contentView = playerView
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
