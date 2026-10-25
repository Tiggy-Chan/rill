import Carbon.HIToolbox
import Foundation
import Testing
@testable import Rill

struct RotationTests {
    let a = UUID(), b = UUID(), c = UUID()

    @Test func emptyLibraryHasNothingNext() {
        #expect(Rotation.next(after: nil, in: [], shuffle: false) == nil)
    }

    @Test func startsAtTheFirstItemWhenNothingIsShowing() {
        #expect(Rotation.next(after: nil, in: [a, b, c], shuffle: false) == a)
        #expect(Rotation.next(after: UUID(), in: [a, b, c], shuffle: true) == a)
    }

    @Test func advancesInOrderAndWraps() {
        #expect(Rotation.next(after: a, in: [a, b, c], shuffle: false) == b)
        #expect(Rotation.next(after: c, in: [a, b, c], shuffle: false) == a)
    }

    @Test func singleItemStaysPut() {
        #expect(Rotation.next(after: a, in: [a], shuffle: true) == a)
    }

    @Test func shuffleNeverRepeatsTheCurrentItem() {
        for pick in 0..<2 {
            let next = Rotation.next(after: b, in: [a, b, c], shuffle: true, randomIndex: { _ in pick })
            #expect(next != b)
            #expect([a, c].contains(next))
        }
    }
}

struct DisplayAssignmentTests {
    let main = UUID(), other = UUID()

    @Test func everyDisplayShowsTheMainVideoByDefault() {
        let result = DisplayAssignment.resolve(displays: ["L", "R"], overrides: [:], mainItem: main, available: [main])
        #expect(result == ["L": main, "R": main])
    }

    @Test func aDisplaysOwnChoiceWins() {
        let result = DisplayAssignment.resolve(
            displays: ["L", "R"], overrides: ["R": other], mainItem: main, available: [main, other]
        )
        #expect(result == ["L": main, "R": other])
    }

    @Test func unavailableChoicesFallBackToTheMainVideo() {
        let result = DisplayAssignment.resolve(displays: ["R"], overrides: ["R": other], mainItem: main, available: [main])
        #expect(result == ["R": main])
    }

    @Test func overridesForDisconnectedDisplaysAreIgnored() {
        let result = DisplayAssignment.resolve(
            displays: ["L"], overrides: ["gone": other], mainItem: main, available: [main, other]
        )
        #expect(result == ["L": main])
    }

    @Test func displaysWithoutAnyVideoAreLeftOut() {
        let result = DisplayAssignment.resolve(displays: ["L", "R"], overrides: ["R": other], mainItem: nil, available: [other])
        #expect(result == ["R": other])
    }
}

struct SettingsMigrationTests {
    private func freshDefaults() -> UserDefaults {
        let name = "rill.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func singleVideoBecomesALibraryOfOne() throws {
        let defaults = freshDefaults()
        let bookmark = Data([1, 2, 3])
        defaults.set(bookmark, forKey: "videoBookmark")
        defaults.set("rain.mp4", forKey: "videoName")
        defaults.set("/old/path/rain.mp4", forKey: "videoPath")

        let store = SettingsStore(defaults: defaults)
        let library = store.library
        let item = try #require(library.first)
        #expect(library.count == 1)
        #expect(item.name == "rain.mp4")
        #expect(item.bookmark == bookmark)
        #expect(store.currentItemID == item.id)
        #expect(defaults.object(forKey: "videoBookmark") == nil)
        #expect(defaults.object(forKey: "videoPath") == nil)
        // Reading again returns the stored library rather than migrating twice.
        #expect(store.library == library)
    }

    @Test func noSavedVideoMeansAnEmptyLibrary() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(store.library.isEmpty)
        #expect(store.currentItemID == nil)
    }

    @Test func newSettingsRoundTrip() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(store.rotationInterval == .never)
        #expect(store.syncLockScreen == false)
        store.rotationInterval = .oneHour
        store.shuffle = true
        let id = UUID()
        store.displayVideos = ["display": id]
        #expect(store.rotationInterval == .oneHour)
        #expect(store.shuffle)
        #expect(store.displayVideos == ["display": id])
    }
}
