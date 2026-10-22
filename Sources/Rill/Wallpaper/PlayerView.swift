import AppKit
import AVFoundation

final class PlayerView: NSView {
    private let playerLayer = AVPlayerLayer()

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    var videoGravity: AVLayerVideoGravity {
        get { playerLayer.videoGravity }
        set { playerLayer.videoGravity = newValue }
    }

    init(player: AVPlayer?, cornerRadius: CGFloat = 0) {
        super.init(frame: .zero)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = NSColor.black.cgColor
        playerLayer.cornerRadius = cornerRadius
        playerLayer.cornerCurve = .continuous
        playerLayer.masksToBounds = cornerRadius > 0
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func makeBackingLayer() -> CALayer {
        playerLayer
    }

    // Purely visual: let clicks reach whatever hosts the view.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
