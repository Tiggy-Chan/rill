import AVFoundation

@MainActor
final class PlaybackEngine {
    let player: AVQueuePlayer
    private var looper: AVPlayerLooper?

    init() {
        player = AVQueuePlayer()
        player.isMuted = true
        player.allowsExternalPlayback = false
        // A wallpaper must never keep the display awake.
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    func load(_ url: URL) {
        unload()
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }

    func unload() {
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }
}
