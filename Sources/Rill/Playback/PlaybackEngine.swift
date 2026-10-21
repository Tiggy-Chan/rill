import AVFoundation

@MainActor
final class PlaybackEngine {
    let player: AVQueuePlayer
    private var looper: AVPlayerLooper?

    init() {
        player = AVQueuePlayer()
        player.isMuted = true
        // A wallpaper must never keep the display awake.
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    func load(_ url: URL) {
        looper?.disableLooping()
        player.removeAllItems()
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }
}
