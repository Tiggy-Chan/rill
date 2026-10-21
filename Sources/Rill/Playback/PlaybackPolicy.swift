enum PauseReason: Equatable, CaseIterable {
    case user
    case screensAsleep
    case sessionInactive
    case hidden
    case battery
    case lowPower
}

struct PlaybackConditions: Equatable {
    var userPaused = false
    var screensAsleep = false
    var sessionActive = true
    var wallpaperVisible = true
    var onBattery = false
    var lowPowerMode = false
    var pauseWhenSavingPower = true
}

enum PlaybackPolicy {
    /// Returns why playback should be paused, or nil if it should play.
    static func pauseReason(for conditions: PlaybackConditions) -> PauseReason? {
        if conditions.userPaused { return .user }
        if conditions.screensAsleep { return .screensAsleep }
        if !conditions.sessionActive { return .sessionInactive }
        if !conditions.wallpaperVisible { return .hidden }
        if conditions.pauseWhenSavingPower {
            if conditions.onBattery { return .battery }
            if conditions.lowPowerMode { return .lowPower }
        }
        return nil
    }
}
