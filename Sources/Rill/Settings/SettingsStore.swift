import AppKit

struct SavedWallpaper: Codable, Equatable {
    var url: URL
    var scaling: Int?
    var allowClipping: Bool?

    init(url: URL, options: [NSWorkspace.DesktopImageOptionKey: Any]?) {
        self.url = url
        scaling = options?[.imageScaling] as? Int
        allowClipping = options?[.allowClipping] as? Bool
    }

    var options: [NSWorkspace.DesktopImageOptionKey: Any] {
        var options: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
        if let scaling { options[.imageScaling] = scaling }
        if let allowClipping { options[.allowClipping] = allowClipping }
        return options
    }
}

struct SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let library = "library"
        static let currentItem = "currentItem"
        static let displayVideos = "displayVideos"
        static let rotationInterval = "rotationInterval"
        static let shuffle = "shuffle"
        static let syncLockScreen = "syncLockScreen"
        static let savedWallpapers = "savedWallpapers"
        static let pauseShortcut = "pauseShortcut"
        static let nextShortcut = "nextShortcut"
        static let volume = "volume"
        static let isMuted = "isMuted"
        static let fillMode = "fillMode"
        static let pauseWhenSavingPower = "pauseWhenSavingPower"
        // Single-video settings from before the library existed.
        static let legacyBookmark = "videoBookmark"
        static let legacyName = "videoName"
        static let legacyPath = "videoPath"
    }

    var library: [LibraryItem] {
        get {
            if let items: [LibraryItem] = decode(Key.library) { return items }
            guard let bookmark = defaults.data(forKey: Key.legacyBookmark) else { return [] }
            let item = LibraryItem(id: UUID(), name: defaults.string(forKey: Key.legacyName) ?? "", bookmark: bookmark)
            encode([item], Key.library)
            defaults.set(item.id.uuidString, forKey: Key.currentItem)
            [Key.legacyBookmark, Key.legacyName, Key.legacyPath].forEach(defaults.removeObject(forKey:))
            return [item]
        }
        nonmutating set { encode(newValue, Key.library) }
    }

    var currentItemID: UUID? {
        get { defaults.string(forKey: Key.currentItem).flatMap(UUID.init(uuidString:)) }
        nonmutating set { defaults.set(newValue?.uuidString, forKey: Key.currentItem) }
    }

    var displayVideos: [String: UUID] {
        get { decode(Key.displayVideos) ?? [:] }
        nonmutating set { encode(newValue, Key.displayVideos) }
    }

    var rotationInterval: RotationInterval {
        get { RotationInterval(rawValue: defaults.integer(forKey: Key.rotationInterval)) ?? .never }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.rotationInterval) }
    }

    var shuffle: Bool {
        get { defaults.bool(forKey: Key.shuffle) }
        nonmutating set { defaults.set(newValue, forKey: Key.shuffle) }
    }

    var syncLockScreen: Bool {
        get { defaults.bool(forKey: Key.syncLockScreen) }
        nonmutating set { defaults.set(newValue, forKey: Key.syncLockScreen) }
    }

    /// The user's own wallpaper per display, saved before Rill first replaces it.
    var savedWallpapers: [String: SavedWallpaper] {
        get { decode(Key.savedWallpapers) ?? [:] }
        nonmutating set { encode(newValue, Key.savedWallpapers) }
    }

    var pauseShortcut: KeyShortcut? {
        get { decode(Key.pauseShortcut) }
        nonmutating set { encode(newValue, Key.pauseShortcut) }
    }

    var nextShortcut: KeyShortcut? {
        get { decode(Key.nextShortcut) }
        nonmutating set { encode(newValue, Key.nextShortcut) }
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

    private func decode<T: Decodable>(_ key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    private func encode<T: Encodable>(_ value: T?, _ key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
