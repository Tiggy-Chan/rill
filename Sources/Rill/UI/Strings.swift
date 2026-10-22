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
    static var removeHelp: String { String(localized: "Turn off the video wallpaper and show the system wallpaper") }
    static var quit: String { String(localized: "Quit") }

    static var openPanelMessage: String { String(localized: "Choose a video for your desktop wallpaper") }
    static var setAsWallpaper: String { String(localized: "Set as Wallpaper") }

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
