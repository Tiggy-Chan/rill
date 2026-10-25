import AppKit

struct LibraryItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    /// Security-scoped bookmark: the only way a sandboxed app can reopen the file after relaunch.
    var bookmark: Data
    /// MP4 copy playback uses when the container needs converting, with the source
    /// size it was made from so replacing the source file invalidates the copy.
    var convertedPath: String?
    var convertedFromSize: Int?
    /// Which converter wrote the copy; bump to force a rebuild after a fix.
    var convertedVersion: Int?

    init(id: UUID, name: String, bookmark: Data) {
        self.id = id
        self.name = name
        self.bookmark = bookmark
    }

    init?(url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return nil }
        self.init(id: UUID(), name: url.lastPathComponent, bookmark: bookmark)
    }

    /// Returns nil when the file is gone. Refreshes a stale bookmark and the name in place.
    mutating func resolve() -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope, .withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        let access = SecurityScopedAccess(url)
        // Bookmarks follow files into the Trash; treat that as gone.
        guard !url.pathComponents.contains(".Trash"), FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        if isStale, let fresh = try? access.url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            bookmark = fresh
        }
        name = url.lastPathComponent
        return url
    }
}

enum Rotation {
    /// The item to show after `current`. Shuffle never repeats the current item when there is a choice.
    static func next(
        after current: UUID?,
        in ids: [UUID],
        shuffle: Bool,
        randomIndex: (Int) -> Int = { Int.random(in: 0..<$0) }
    ) -> UUID? {
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else { return ids.first }
        guard ids.count > 1 else { return current }
        if shuffle {
            var others = ids
            others.remove(at: index)
            return others[randomIndex(others.count)]
        }
        return ids[(index + 1) % ids.count]
    }
}

enum RotationInterval: Int, CaseIterable, Identifiable {
    case never = 0
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    case threeHours = 10_800
    case sixHours = 21_600
    case oneDay = 86_400

    var id: Int { rawValue }

    var title: String {
        guard self != .never else { return L10n.never }
        let unit: Duration.UnitsFormatStyle.Unit = rawValue >= 86_400 ? .days : rawValue >= 3600 ? .hours : .minutes
        return Duration.seconds(rawValue).formatted(.units(allowed: [unit], width: .wide).locale(L10n.locale))
    }
}

enum DisplayAssignment {
    /// Which library item each display shows. A display's own choice wins; otherwise it shows the main video.
    static func resolve(
        displays: [String],
        overrides: [String: UUID],
        mainItem: UUID?,
        available: Set<UUID>
    ) -> [String: UUID] {
        var result: [String: UUID] = [:]
        for display in displays {
            if let id = overrides[display], available.contains(id) {
                result[display] = id
            } else if let mainItem, available.contains(mainItem) {
                result[display] = mainItem
            }
        }
        return result
    }
}

struct DisplayInfo: Identifiable, Equatable {
    /// Stable display UUID, so per-display choices survive reboots and reconnection.
    let id: String
    let name: String
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    var displayKey: String? {
        guard let id = displayID, let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else {
            return nil
        }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
