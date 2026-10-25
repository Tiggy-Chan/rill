import Foundation

// Every user-facing string. Keys are the English text; translations live in Resources/*.lproj.
// Interpolate only Strings so each placeholder is %@ (LocalizationTests relies on this).
enum L10n {
    // Status
    static var notSet: String { String(localized: "Not Set") }
    static var playing: String { String(localized: "Playing") }
    static var paused: String { String(localized: "Paused") }
    static var autoPaused: String { String(localized: "Auto-Paused") }

    static var pausedDisplaysAsleep: String { String(localized: "Paused while the displays are asleep") }
    static var pausedScreenLocked: String { String(localized: "Paused while the screen is locked") }
    static var pausedCovered: String { String(localized: "Paused while windows cover the wallpaper") }
    static var pausedOnBattery: String { String(localized: "Paused while on battery power") }
    static var pausedLowPower: String { String(localized: "Paused while Low Power Mode is on") }

    // Playback controls
    static var pause: String { String(localized: "Pause") }
    static var resume: String { String(localized: "Resume") }
    static var mute: String { String(localized: "Mute") }
    static var unmute: String { String(localized: "Unmute") }
    static var volume: String { String(localized: "Volume") }

    static var scaling: String { String(localized: "Scaling") }
    static var fill: String { String(localized: "Fill") }
    static var fit: String { String(localized: "Fit") }
    static var stretch: String { String(localized: "Stretch") }

    // Options
    static var pauseOnBattery: String { String(localized: "Pause on battery or in Low Power Mode") }
    static var launchAtLogin: String { String(localized: "Launch at login") }
    static var allowInSystemSettings: String { String(localized: "Allow Rill in System Settings…") }

    // Video
    static var chooseVideo: String { String(localized: "Choose Video…") }
    static var changeVideo: String { String(localized: "Change Video…") }
    static var changeVideoShort: String { String(localized: "Change Video") }
    static var chooseAVideo: String { String(localized: "Choose a Video") }
    static var orDropOnIcon: String { String(localized: "or drop one on the menu bar icon") }
    static var remove: String { String(localized: "Remove") }
    static var removeHelp: String { String(localized: "Remove this video from your library") }
    static var quit: String { String(localized: "Quit") }

    static var openPanelMessage: String { String(localized: "Choose videos for your desktop wallpaper") }
    static var setAsWallpaper: String { String(localized: "Set as Wallpaper") }

    // Settings
    static var settings: String { String(localized: "Settings…") }
    static var general: String { String(localized: "General") }
    static var language: String { String(localized: "Language") }
    static var relaunchToApply: String { String(localized: "Relaunch Rill to use the new language.") }
    static var relaunchNow: String { String(localized: "Relaunch") }

    static func systemLanguage(_ name: String) -> String {
        String(localized: "System Default (\(name))")
    }

    // Library, rotation, displays, lock screen
    static var locale: Locale { Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en") }
    static var never: String { String(localized: "Never") }
    static var nextVideo: String { String(localized: "Next Video") }
    static var syncLockScreen: String { String(localized: "Show the video on the lock screen") }
    static var syncLockScreenDetail: String { String(localized: "Sets a still from the video as your macOS wallpaper, which the lock screen shows. Your own wallpaper comes back when you turn this off.") }
    static var cantRestoreWallpaper: String { String(localized: "Couldn't restore your original wallpaper.") }
    static var library: String { String(localized: "Library") }
    static var libraryEmpty: String { String(localized: "Add videos to rotate between them or show a different one on each display.") }
    static var videos: String { String(localized: "Videos") }
    static var addVideos: String { String(localized: "Add Videos…") }
    static var changeVideoEvery: String { String(localized: "Change video") }
    static var shuffle: String { String(localized: "Shuffle") }
    static var rotationFooter: String { String(localized: "Videos don't change while the wallpaper is paused or hidden.") }
    static var sameAsMain: String { String(localized: "Same as Main Video") }
    static var displays: String { String(localized: "Displays") }
    static var displaysFooter: String { String(localized: "Only the main video plays sound.") }
    static var show: String { String(localized: "Show") }
    static var removeFromLibrary: String { String(localized: "Remove from Library") }

    static func cantSetLockScreen(_ reason: String) -> String {
        String(localized: "Couldn't update the lock screen wallpaper: \(reason)")
    }

    // Problems
    static func cantFindLastVideo(_ name: String) -> String {
        String(localized: "Can't find “\(name)”, the video you used last time. It may have been moved or deleted.")
    }

    static func cantPlay(_ name: String) -> String {
        String(localized: "Can't play “\(name)”. The file may be damaged or in an unsupported format.")
    }

    static func cantChangeLaunchAtLogin(_ reason: String) -> String {
        String(localized: "Couldn't change Launch at Login: \(reason)")
    }
}
