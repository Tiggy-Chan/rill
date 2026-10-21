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
        static let videoPath = "videoPath"
        static let volume = "volume"
        static let isMuted = "isMuted"
        static let fillMode = "fillMode"
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

    func saveVideo(_ url: URL?) {
        guard let url else {
            defaults.removeObject(forKey: Key.videoBookmark)
            defaults.removeObject(forKey: Key.videoPath)
            return
        }
        defaults.set(url.path, forKey: Key.videoPath)
        // A bookmark keeps following the file if the user renames or moves it.
        let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(bookmark, forKey: Key.videoBookmark)
    }

    func loadVideo() -> StoredVideo {
        if let data = defaults.data(forKey: Key.videoBookmark) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI, .withoutMounting],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), isUsable(url) {
                if isStale || url.path != defaults.string(forKey: Key.videoPath) {
                    saveVideo(url)
                }
                return .available(url)
            }
        }
        guard let path = defaults.string(forKey: Key.videoPath) else { return .none }
        let url = URL(fileURLWithPath: path)
        return isUsable(url) ? .available(url) : .missing(name: url.lastPathComponent)
    }

    private func isUsable(_ url: URL) -> Bool {
        // Bookmarks follow files into the Trash; treat that as gone.
        !url.pathComponents.contains(".Trash") && FileManager.default.fileExists(atPath: url.path)
    }
}
