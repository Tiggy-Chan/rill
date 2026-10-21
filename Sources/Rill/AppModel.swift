import AVFoundation
import Observation

struct VideoInfo: Equatable {
    let url: URL
    var pixelSize: CGSize?
    var duration: Double?

    var name: String { url.lastPathComponent }

    var summary: String {
        var parts: [String] = []
        if let pixelSize {
            parts.append("\(Int(pixelSize.width)) × \(Int(pixelSize.height))")
        }
        if let duration, duration.isFinite {
            parts.append(Duration.seconds(duration.rounded()).formatted(.time(pattern: .minuteSecond)))
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

enum FillMode: String, CaseIterable, Identifiable {
    case fill, fit, stretch

    var id: Self { self }

    var title: String {
        switch self {
        case .fill: "填充"
        case .fit: "适应"
        case .stretch: "拉伸"
        }
    }

    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fill: .resizeAspectFill
        case .fit: .resizeAspect
        case .stretch: .resize
        }
    }
}

enum PlaybackStatus: Equatable {
    case idle
    case playing
    case paused
    case autoPaused(PauseReason)
}

extension PauseReason {
    var explanation: String {
        switch self {
        case .user: "已暂停"
        case .screensAsleep: "显示器已休眠"
        case .sessionInactive: "屏幕已锁定"
        case .hidden: "壁纸被窗口完全遮挡"
        case .battery: "正在使用电池"
        case .lowPower: "低电量模式已开启"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    private(set) var video: VideoInfo?
    /// The user's own pause; system conditions are tracked separately in `autoPauseReason`.
    private(set) var isPaused = false
    private(set) var autoPauseReason: PauseReason?
    private(set) var problem: String?

    var pauseWhenSavingPower = true {
        didSet {
            settings.pauseWhenSavingPower = pauseWhenSavingPower
            updatePlayback()
        }
    }

    var isMuted = true {
        didSet {
            engine.player.isMuted = isMuted
            settings.isMuted = isMuted
        }
    }

    var volume: Float = 0.6 {
        didSet {
            engine.player.volume = volume
            settings.volume = volume
        }
    }

    var fillMode: FillMode = .fill {
        didSet {
            wallpaper.videoGravity = fillMode.videoGravity
            settings.fillMode = fillMode
        }
    }

    var status: PlaybackStatus {
        guard video != nil else { return .idle }
        if isPaused { return .paused }
        if let autoPauseReason { return .autoPaused(autoPauseReason) }
        return .playing
    }

    var player: AVPlayer { engine.player }

    private let settings: SettingsStore
    private let engine: PlaybackEngine
    private let wallpaper: WallpaperController
    private let monitor: SystemMonitor
    @ObservationIgnored private var metadataTask: Task<Void, Never>?

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        engine = PlaybackEngine()
        wallpaper = WallpaperController(player: engine.player)
        monitor = SystemMonitor()
        // Property observers don't run during init, so apply stored values directly.
        isMuted = settings.isMuted
        volume = settings.volume
        fillMode = settings.fillMode
        pauseWhenSavingPower = settings.pauseWhenSavingPower
        engine.player.isMuted = isMuted
        engine.player.volume = volume
        wallpaper.videoGravity = fillMode.videoGravity

        monitor.onChange = { [weak self] in self?.updatePlayback() }
        wallpaper.onVisibilityChange = { [weak self] in self?.updatePlayback() }
    }

    func restoreLastVideo() {
        switch settings.loadVideo() {
        case .none:
            break
        case .available(let url):
            setVideo(url)
        case .missing(let name):
            problem = "找不到上次使用的视频「\(name)」，它可能被移动或删除了。"
        }
    }

    func setVideo(_ url: URL) {
        engine.load(url)
        video = VideoInfo(url: url)
        isPaused = false
        problem = nil
        settings.saveVideo(url)
        wallpaper.show()
        updatePlayback()
        loadMetadata(for: url)
    }

    func clearVideo() {
        metadataTask?.cancel()
        engine.unload()
        wallpaper.hide()
        video = nil
        isPaused = false
        autoPauseReason = nil
        problem = nil
        settings.saveVideo(nil)
    }

    func togglePause() {
        guard video != nil else { return }
        isPaused.toggle()
        updatePlayback()
    }

    func toggleMute() {
        if isMuted && volume == 0 {
            volume = 0.5
        }
        isMuted.toggle()
    }

    private func updatePlayback() {
        guard video != nil else {
            autoPauseReason = nil
            return
        }
        let conditions = PlaybackConditions(
            userPaused: isPaused,
            screensAsleep: monitor.screensAsleep,
            sessionActive: monitor.isSessionActive,
            wallpaperVisible: wallpaper.isVisible,
            onBattery: monitor.isOnBattery,
            lowPowerMode: monitor.isLowPowerMode,
            pauseWhenSavingPower: pauseWhenSavingPower
        )
        let reason = PlaybackPolicy.pauseReason(for: conditions)
        autoPauseReason = reason == .user ? nil : reason
        if reason == nil {
            engine.play()
        } else {
            engine.pause()
        }
    }

    private func loadMetadata(for url: URL) {
        metadataTask?.cancel()
        metadataTask = Task { [weak self] in
            let asset = AVURLAsset(url: url)
            let duration = try? await asset.load(.duration)
            var pixelSize: CGSize?
            if let track = try? await asset.loadTracks(withMediaType: .video).first,
               let geometry = try? await track.load(.naturalSize, .preferredTransform) {
                let rect = CGRect(origin: .zero, size: geometry.0).applying(geometry.1)
                pixelSize = CGSize(width: abs(rect.width), height: abs(rect.height))
            }
            guard !Task.isCancelled, let self, self.video?.url == url else { return }
            self.video?.pixelSize = pixelSize
            self.video?.duration = duration.map(CMTimeGetSeconds)
        }
    }
}
