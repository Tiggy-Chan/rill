import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Sets a still frame of each display's video as the macOS wallpaper, which the lock screen also shows.
@MainActor
final class LockScreenSync {
    var onError: ((String) -> Void)?

    private let settings: SettingsStore
    private var task: Task<Void, Never>?
    private var applied: [String: URL] = [:]

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// `videos` maps display keys to the video showing there.
    func update(videos: [String: URL]) {
        guard videos != applied else { return }
        applied = videos
        task?.cancel()
        task = Task { [weak self] in
            var frames: [URL: URL] = [:]
            for video in Set(videos.values) {
                if let frame = await Self.exportFrame(of: video) {
                    frames[video] = frame
                }
            }
            guard !Task.isCancelled, let self else { return }
            self.setWallpapers(videos.compactMapValues { frames[$0] })
        }
    }

    func restore() {
        task?.cancel()
        applied = [:]
        var saved = settings.savedWallpapers
        for screen in NSScreen.screens {
            guard let key = screen.displayKey, let original = saved[key] else { continue }
            do {
                try NSWorkspace.shared.setDesktopImageURL(original.url, for: screen, options: original.options)
                saved[key] = nil
            } catch {
                onError?(L10n.cantRestoreWallpaper)
            }
        }
        settings.savedWallpapers = saved
        // Displays that aren't connected still use a frame; keep their files until they're restored.
        if saved.isEmpty {
            Self.removeFrames(keeping: [])
        }
    }

    private func setWallpapers(_ frames: [String: URL]) {
        var saved = settings.savedWallpapers
        for screen in NSScreen.screens {
            guard let key = screen.displayKey, let frame = frames[key] else { continue }
            if saved[key] == nil, let current = NSWorkspace.shared.desktopImageURL(for: screen) {
                saved[key] = SavedWallpaper(url: current, options: NSWorkspace.shared.desktopImageOptions(for: screen))
            }
            do {
                try NSWorkspace.shared.setDesktopImageURL(frame, for: screen, options: [
                    .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                    .allowClipping: true,
                ])
            } catch {
                onError?(L10n.cantSetLockScreen(error.localizedDescription))
            }
        }
        settings.savedWallpapers = saved
        Self.removeFrames(keeping: Set(frames.values))
    }

    private nonisolated static var framesDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "LockScreen", directoryHint: .isDirectory)
    }

    private nonisolated static func exportFrame(of video: URL) async -> URL? {
        let access = SecurityScopedAccess(video)
        defer { withExtendedLifetime(access) {} }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.appliesPreferredTrackTransform = true
        guard let image = try? await generator.image(at: .zero).image else { return nil }

        try? FileManager.default.createDirectory(at: framesDirectory, withIntermediateDirectories: true)
        // A new name each time: macOS caches wallpapers by path and ignores changes to the same file.
        let url = framesDirectory.appending(path: "\(UUID().uuidString).heic")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.heic.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? url : nil
    }

    private static func removeFrames(keeping kept: Set<URL>) {
        let keptNames = Set(kept.map(\.lastPathComponent))
        let files = (try? FileManager.default.contentsOfDirectory(at: framesDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where !keptNames.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
