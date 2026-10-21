import Foundation

@MainActor
final class AppModel {
    private(set) var videoURL: URL?
    private(set) var isPaused = false

    private let engine: PlaybackEngine
    private let wallpaper: WallpaperController

    init() {
        engine = PlaybackEngine()
        wallpaper = WallpaperController(player: engine.player)
    }

    func setVideo(_ url: URL) {
        engine.load(url)
        videoURL = url
        isPaused = false
        wallpaper.show()
        applyPlaybackState()
    }

    func togglePause() {
        guard videoURL != nil else { return }
        isPaused.toggle()
        applyPlaybackState()
    }

    private func applyPlaybackState() {
        if isPaused {
            engine.pause()
        } else {
            engine.play()
        }
    }
}
