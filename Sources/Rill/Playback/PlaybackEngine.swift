import AVFoundation

@MainActor
final class PlaybackEngine {
    let player: AVQueuePlayer
    var onFailure: (() -> Void)?

    private var looper: AVPlayerLooper?
    private var statusObservation: NSKeyValueObservation?

    init() {
        player = AVQueuePlayer()
        player.isMuted = true
        player.allowsExternalPlayback = false
        // A wallpaper must never keep the display awake.
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    func load(_ url: URL) {
        unload()
        let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        statusObservation = looper.observe(\.status, options: [.initial, .new]) { [weak self] looper, _ in
            guard looper.status == .failed else { return }
            Task { @MainActor in self?.onFailure?() }
        }
        self.looper = looper
    }

    func unload() {
        statusObservation = nil
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
