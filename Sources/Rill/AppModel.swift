import AppKit
import AVFoundation
import Observation
import ServiceManagement

struct VideoInfo: Equatable {
    let id: UUID
    let name: String
    var pixelSize: CGSize?
    var duration: Double?

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
        case .fill: L10n.fill
        case .fit: L10n.fit
        case .stretch: L10n.stretch
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
        case .user: L10n.paused
        case .screensAsleep: L10n.pausedDisplaysAsleep
        case .sessionInactive: L10n.pausedScreenLocked
        case .hidden: L10n.pausedCovered
        case .battery: L10n.pausedOnBattery
        case .lowPower: L10n.pausedLowPower
        }
    }
}

@MainActor
@Observable
final class AppModel {
    private(set) var library: [LibraryItem] = []
    /// The main video: shown on every display without its own choice, and the one rotation advances.
    private(set) var currentItemID: UUID?
    private(set) var video: VideoInfo?
    private(set) var previewPlayer: AVPlayer?
    private(set) var displays: [DisplayInfo] = []
    private(set) var displayOverrides: [String: UUID] = [:]

    /// The user's own pause; system conditions are tracked separately in `autoPauseReason`.
    private(set) var isPaused = false
    private(set) var autoPauseReason: PauseReason?
    private(set) var problem: String?
    private(set) var launchAtLogin: SMAppService.Status = SMAppService.mainApp.status

    var pauseWhenSavingPower = true {
        didSet {
            settings.pauseWhenSavingPower = pauseWhenSavingPower
            updatePlayback()
        }
    }

    var isMuted = true {
        didSet {
            settings.isMuted = isMuted
            applyAudio()
        }
    }

    var volume: Float = 0.6 {
        didSet {
            settings.volume = volume
            applyAudio()
        }
    }

    var fillMode: FillMode = .fill {
        didSet {
            wallpaper.videoGravity = fillMode.videoGravity
            settings.fillMode = fillMode
        }
    }

    var rotationInterval: RotationInterval = .never {
        didSet {
            settings.rotationInterval = rotationInterval
            scheduleRotation()
        }
    }

    var shuffle = false {
        didSet { settings.shuffle = shuffle }
    }

    var syncLockScreen = false {
        didSet {
            settings.syncLockScreen = syncLockScreen
            if syncLockScreen {
                updateLockScreen()
            } else {
                lockScreen.restore()
            }
        }
    }

    var status: PlaybackStatus {
        guard video != nil else { return .idle }
        if isPaused { return .paused }
        if let autoPauseReason { return .autoPaused(autoPauseReason) }
        return .playing
    }

    var canShowNext: Bool { playableIDs.count > 1 }

    /// Called when something needs the user's attention, e.g. a video that can't be played.
    @ObservationIgnored var onProblem: (() -> Void)?

    private struct ActivePlayer {
        let engine: PlaybackEngine
        let access: SecurityScopedAccess
    }

    private let settings: SettingsStore
    private let wallpaper = WallpaperController()
    private let monitor = SystemMonitor()
    private let lockScreen: LockScreenSync
    @ObservationIgnored private var resolvedURLs: [UUID: URL] = [:]
    @ObservationIgnored private var active: [UUID: ActivePlayer] = [:]
    @ObservationIgnored private var assignment: [String: UUID] = [:]
    @ObservationIgnored private var metadataTask: Task<Void, Never>?
    @ObservationIgnored private var rotationTimer: Timer?

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        lockScreen = LockScreenSync(settings: settings)
        // Property observers don't run during init, so apply stored values directly.
        isMuted = settings.isMuted
        volume = settings.volume
        fillMode = settings.fillMode
        pauseWhenSavingPower = settings.pauseWhenSavingPower
        rotationInterval = settings.rotationInterval
        shuffle = settings.shuffle
        syncLockScreen = settings.syncLockScreen
        wallpaper.videoGravity = fillMode.videoGravity

        monitor.onChange = { [weak self] in self?.updatePlayback() }
        wallpaper.onVisibilityChange = { [weak self] in self?.updatePlayback() }
        wallpaper.onScreensChange = { [weak self] in self?.applyAssignments() }
        lockScreen.onError = { [weak self] message in self?.problem = message }
        // Covers a quit or crash between turning sync off and the original wallpaper coming back.
        if !syncLockScreen && !settings.savedWallpapers.isEmpty {
            lockScreen.restore()
        }
    }

    // MARK: - Library

    func restore() {
        var items: [LibraryItem] = []
        var missing: [String] = []
        for var item in settings.library {
            if let url = item.resolve() {
                resolvedURLs[item.id] = url
                items.append(item)
            } else {
                missing.append(item.name)
            }
        }
        library = items
        settings.library = items
        displayOverrides = settings.displayVideos.filter { resolvedURLs[$0.value] != nil }
        let saved = settings.currentItemID
        currentItemID = saved.flatMap { resolvedURLs[$0] != nil ? $0 : nil } ?? library.first?.id
        if let name = missing.first {
            problem = L10n.cantFindLastVideo(name)
        }
        currentDidChange()
    }

    /// Adds videos that aren't in the library yet and shows the first of `urls`.
    func addVideos(_ urls: [URL]) {
        var firstID: UUID?
        for url in urls {
            let path = url.standardizedFileURL.path
            if let existing = resolvedURLs.first(where: { $0.value.standardizedFileURL.path == path })?.key {
                firstID = firstID ?? existing
                continue
            }
            guard let item = LibraryItem(url: url) else { continue }
            library.append(item)
            resolvedURLs[item.id] = url
            firstID = firstID ?? item.id
        }
        settings.library = library
        if let firstID {
            select(firstID)
        }
    }

    func select(_ id: UUID) {
        guard resolvedURLs[id] != nil else { return }
        currentItemID = id
        isPaused = false
        problem = nil
        currentDidChange()
    }

    func remove(_ id: UUID) {
        library.removeAll { $0.id == id }
        resolvedURLs[id] = nil
        displayOverrides = displayOverrides.filter { $0.value != id }
        settings.library = library
        settings.displayVideos = displayOverrides
        if currentItemID == id {
            currentItemID = library.first?.id
            isPaused = false
        }
        currentDidChange()
    }

    func removeCurrent() {
        if let currentItemID {
            remove(currentItemID)
        }
    }

    func showNext() {
        guard let next = Rotation.next(after: currentItemID, in: playableIDs, shuffle: shuffle), next != currentItemID else {
            return
        }
        select(next)
    }

    func setVideo(_ id: UUID?, forDisplay display: String) {
        displayOverrides[display] = id
        settings.displayVideos = displayOverrides
        applyAssignments()
    }

    private var playableIDs: [UUID] {
        library.map(\.id).filter { resolvedURLs[$0] != nil }
    }

    private func currentDidChange() {
        settings.currentItemID = currentItemID
        video = currentItemID.flatMap { id in
            library.first { $0.id == id }.map { VideoInfo(id: id, name: $0.name) }
        }
        loadMetadata()
        scheduleRotation()
        applyAssignments()
    }

    // MARK: - Playback

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

    private func applyAssignments() {
        let screens = NSScreen.screens
        displays = screens.compactMap { screen in
            screen.displayKey.map { DisplayInfo(id: $0, name: screen.localizedName) }
        }
        assignment = DisplayAssignment.resolve(
            displays: displays.map(\.id),
            overrides: displayOverrides,
            mainItem: currentItemID,
            available: Set(resolvedURLs.keys)
        )

        // One engine per distinct video: displays showing the same video share its decoder.
        var needed = Set(assignment.values)
        if let currentItemID, resolvedURLs[currentItemID] != nil {
            needed.insert(currentItemID)
        }
        for id in active.keys where !needed.contains(id) {
            active.removeValue(forKey: id)?.engine.unload()
        }
        for id in needed where active[id] == nil {
            guard let url = resolvedURLs[id] else { continue }
            let access = SecurityScopedAccess(url)
            let engine = PlaybackEngine()
            engine.onFailure = { [weak self] in self?.handlePlaybackFailure(id) }
            engine.load(url)
            active[id] = ActivePlayer(engine: engine, access: access)
        }

        previewPlayer = currentItemID.flatMap { active[$0]?.engine.player }
        applyAudio()
        wallpaper.setPlayers(assignment.compactMapValues { active[$0]?.engine.player })
        updatePlayback()
        updateLockScreen()
    }

    /// Only the main video can be heard, so several displays never play over each other.
    private func applyAudio() {
        for (id, player) in active {
            player.engine.player.isMuted = isMuted || id != currentItemID
            player.engine.player.volume = volume
        }
    }

    private func updatePlayback() {
        guard video != nil else {
            autoPauseReason = nil
            return
        }
        let visible = wallpaper.visibleDisplayKeys
        func conditions(visible: Bool) -> PlaybackConditions {
            PlaybackConditions(
                userPaused: isPaused,
                screensAsleep: monitor.screensAsleep,
                sessionActive: monitor.isSessionActive,
                wallpaperVisible: visible,
                onBattery: monitor.isOnBattery,
                lowPowerMode: monitor.isLowPowerMode,
                pauseWhenSavingPower: pauseWhenSavingPower
            )
        }
        let reason = PlaybackPolicy.pauseReason(for: conditions(visible: !visible.isEmpty))
        autoPauseReason = reason == .user ? nil : reason

        // Each video pauses on its own when every display showing it is covered.
        for (id, player) in active {
            let shownSomewhereVisible = assignment.contains { $0.value == id && visible.contains($0.key) }
            if PlaybackPolicy.pauseReason(for: conditions(visible: shownSomewhereVisible)) == nil {
                player.engine.play()
            } else {
                player.engine.pause()
            }
        }
    }

    private func handlePlaybackFailure(_ id: UUID) {
        guard let name = library.first(where: { $0.id == id })?.name else { return }
        // Also forgets the file, so the next launch doesn't retry it.
        remove(id)
        problem = L10n.cantPlay(name)
        onProblem?()
    }

    private func loadMetadata() {
        metadataTask?.cancel()
        guard let id = currentItemID, let url = resolvedURLs[id] else { return }
        metadataTask = Task { [weak self] in
            let metadata = await Self.readMetadata(of: url)
            guard !Task.isCancelled, let self, self.video?.id == id else { return }
            self.video?.pixelSize = metadata.pixelSize
            self.video?.duration = metadata.duration
        }
    }

    private struct Metadata: Sendable {
        var pixelSize: CGSize?
        var duration: Double?
    }

    /// Runs off the main actor so an AVAssetTrack, which older SDKs don't mark Sendable, never crosses an isolation boundary.
    private nonisolated static func readMetadata(of url: URL) async -> Metadata {
        let access = SecurityScopedAccess(url)
        defer { withExtendedLifetime(access) {} }
        let asset = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        var pixelSize: CGSize?
        if let track = try? await asset.loadTracks(withMediaType: .video).first,
           let geometry = try? await track.load(.naturalSize, .preferredTransform) {
            let rect = CGRect(origin: .zero, size: geometry.0).applying(geometry.1)
            pixelSize = CGSize(width: abs(rect.width), height: abs(rect.height))
        }
        return Metadata(pixelSize: pixelSize, duration: duration.map(CMTimeGetSeconds))
    }

    // MARK: - Rotation

    private func scheduleRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        guard rotationInterval != .never else { return }
        let timer = Timer(timeInterval: TimeInterval(rotationInterval.rawValue), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                // Nobody is watching a paused or hidden wallpaper; don't load new videos for it.
                guard let self, self.status == .playing else { return }
                self.showNext()
            }
        }
        timer.tolerance = min(60, TimeInterval(rotationInterval.rawValue) / 10)
        RunLoop.main.add(timer, forMode: .common)
        rotationTimer = timer
    }

    // MARK: - Lock screen

    private func updateLockScreen() {
        guard syncLockScreen else { return }
        let videos = assignment.compactMapValues { resolvedURLs[$0] }
        if videos.isEmpty {
            lockScreen.restore()
        } else {
            lockScreen.update(videos: videos)
        }
    }

    // MARK: - Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            problem = L10n.cantChangeLaunchAtLogin(error.localizedDescription)
        }
        refreshLaunchAtLogin()
    }

    /// Login items can be changed in System Settings while the app runs, so re-read when the panel opens.
    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
