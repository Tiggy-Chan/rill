import Testing
@testable import Rill

struct PlaybackPolicyTests {
    @Test func playsWhenNothingBlocksPlayback() {
        #expect(PlaybackPolicy.pauseReason(for: PlaybackConditions()) == nil)
    }

    @Test func userPauseTakesPrecedenceOverEverything() {
        let conditions = PlaybackConditions(
            userPaused: true,
            screensAsleep: true,
            sessionActive: false,
            wallpaperVisible: false,
            onBattery: true,
            lowPowerMode: true
        )
        #expect(PlaybackPolicy.pauseReason(for: conditions) == .user)
    }

    @Test(arguments: [
        (PlaybackConditions(screensAsleep: true), PauseReason.screensAsleep),
        (PlaybackConditions(sessionActive: false), PauseReason.sessionInactive),
        (PlaybackConditions(wallpaperVisible: false), PauseReason.hidden),
        (PlaybackConditions(onBattery: true), PauseReason.battery),
        (PlaybackConditions(lowPowerMode: true), PauseReason.lowPower),
    ])
    func eachSystemConditionPausesOnItsOwn(conditions: PlaybackConditions, expected: PauseReason) {
        #expect(PlaybackPolicy.pauseReason(for: conditions) == expected)
    }

    @Test func powerSavingConditionsAreIgnoredWhenTheSettingIsOff() {
        let conditions = PlaybackConditions(onBattery: true, lowPowerMode: true, pauseWhenSavingPower: false)
        #expect(PlaybackPolicy.pauseReason(for: conditions) == nil)
    }

    @Test func powerSavingSettingDoesNotOverrideOtherReasons() {
        let conditions = PlaybackConditions(wallpaperVisible: false, pauseWhenSavingPower: false)
        #expect(PlaybackPolicy.pauseReason(for: conditions) == .hidden)
    }

    @Test func batteryIsReportedBeforeLowPowerMode() {
        let conditions = PlaybackConditions(onBattery: true, lowPowerMode: true)
        #expect(PlaybackPolicy.pauseReason(for: conditions) == .battery)
    }

    @Test func sleepingScreensAreReportedBeforeACoveredWallpaper() {
        let conditions = PlaybackConditions(screensAsleep: true, wallpaperVisible: false)
        #expect(PlaybackPolicy.pauseReason(for: conditions) == .screensAsleep)
    }
}
