import Foundation

enum StoredVideo: Equatable {
    case none
    case available(URL)
    case missing(name: String)
}

struct SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let videoBookmark = "videoBookmark"
        static let videoName = "videoName"
        static let volume = "volume"
        static let isMuted = "isMuted"
        static let fillMode = "fillMode"
        static let pauseWhenSavingPower = "pauseWhenSavingPower"
    }

    var pauseWhenSavingPower: Bool {
        get { defaults.object(forKey: Key.pauseWhenSavingPower) == nil ? true : defaults.bool(forKey: Key.pauseWhenSavingPower) }
        nonmutating set { defaults.set(newValue, forKey: Key.pauseWhenSavingPower) }
    }

    var volume: Float {
        get { defaults.object(forKey: Key.volume) == nil ? 0.6 : defaults.float(forKey: Key.volume) }
        nonmutating set { defaults.set(newValue, forKey: Key.volume) }
    }

    var isMuted: Bool {
        get { defaults.object(forKey: Key.isMuted) == nil ? true : defaults.bool(forKey: Key.isMuted) }
        nonmutating set { defaults.set(newValue, forKey: Key.isMuted) }
    }

    var fillMode: FillMode {
        get { defaults.string(forKey: Key.fillMode).flatMap(FillMode.init(rawValue:)) ?? .fill }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.fillMode) }
    }

    /// Stores a security-scoped bookmark, the only way a sandboxed app can reopen the file after relaunch.
    func saveVideo(_ url: URL?) {
        guard let url else {
            defaults.removeObject(forKey: Key.videoBookmark)
            defaults.removeObject(forKey: Key.videoName)
            return
        }
        defaults.set(url.lastPathComponent, forKey: Key.videoName)
        let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(bookmark, forKey: Key.videoBookmark)
    }

    func loadVideo() -> StoredVideo {
        let name = defaults.string(forKey: Key.videoName)
        guard let data = defaults.data(forKey: Key.videoBookmark) else {
            return name.map { .missing(name: $0) } ?? .none
        }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return .missing(name: name ?? "")
        }
        let access = SecurityScopedAccess(url)
        // Bookmarks follow files into the Trash; treat that as gone.
        guard !url.pathComponents.contains(".Trash"), FileManager.default.fileExists(atPath: url.path) else {
            return .missing(name: name ?? url.lastPathComponent)
        }
        if isStale || url.lastPathComponent != name {
            saveVideo(access.url)
        }
        return .available(url)
    }
}
