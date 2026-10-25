import Foundation
import Testing

@testable import Rill

struct ContainerKindTests {
    @Test func recognizesMatroskaByEBMLMagic() {
        var data = Data([0x1A, 0x45, 0xDF, 0xA3])
        data.append(Data(repeating: 0x42, count: 20))
        #expect(ContainerKind.sniff(data) == .matroska)
        #expect(ContainerKind.sniff(data).needsConversion)
    }

    @Test func recognizesAVIByRIFFHeader() {
        let data = Data("RIFF".utf8) + Data([0x24, 0x08, 0, 0]) + Data("AVI ".utf8) + Data(repeating: 0, count: 8)
        #expect(ContainerKind.sniff(data) == .avi)
    }

    @Test func ignoresOtherRIFFFiles() {
        let data = Data("RIFF".utf8) + Data([0x24, 0x08, 0, 0]) + Data("WAVE".utf8) + Data(repeating: 0, count: 8)
        #expect(ContainerKind.sniff(data) == .unknown)
    }

    @Test func recognizesMP4ByFTYP() {
        let data = Data([0, 0, 0, 0x18]) + Data("ftyp".utf8) + Data("isom".utf8) + Data(repeating: 0, count: 8)
        #expect(ContainerKind.sniff(data) == .mp4Family)
        #expect(!ContainerKind.sniff(data).needsConversion)
    }

    @Test func recognizesQuickTimeByLeadingAtom() {
        let data = Data([0, 0, 0, 0x18]) + Data("moov".utf8) + Data(repeating: 0, count: 8)
        #expect(ContainerKind.sniff(data) == .quickTime)
    }

    @Test func recognizesFLV() {
        let data = Data([0x46, 0x4C, 0x56, 0x01]) + Data(repeating: 0, count: 8)
        #expect(ContainerKind.sniff(data) == .flv)
    }

    @Test func treatsGarbageAndShortFilesAsUnknown() {
        #expect(ContainerKind.sniff(Data(repeating: 0x7F, count: 64)) == .unknown)
        #expect(ContainerKind.sniff(Data([0x1A, 0x45])) == .unknown)
        #expect(ContainerKind.sniff(Data()) == .unknown)
    }
}

struct RemuxCacheTests {
    @Test func cacheCountsOnlyWhileTheSourceIsTheSizeItWasMadeFrom() {
        let path = "/tmp/somewhere.mp4"
        #expect(RemuxStore.cacheIsCurrent(
            recordedCachePath: path, recordedSourceSize: 100, currentSourceSize: 100, cacheFileExists: true))
        #expect(!RemuxStore.cacheIsCurrent(
            recordedCachePath: path, recordedSourceSize: 100, currentSourceSize: 999, cacheFileExists: true))
        #expect(!RemuxStore.cacheIsCurrent(
            recordedCachePath: path, recordedSourceSize: 100, currentSourceSize: 100, cacheFileExists: false))
        #expect(!RemuxStore.cacheIsCurrent(
            recordedCachePath: nil, recordedSourceSize: 100, currentSourceSize: 100, cacheFileExists: true))
        #expect(!RemuxStore.cacheIsCurrent(
            recordedCachePath: path, recordedSourceSize: nil, currentSourceSize: 100, cacheFileExists: true))
        #expect(!RemuxStore.cacheIsCurrent(
            recordedCachePath: path, recordedSourceSize: 100, currentSourceSize: nil, cacheFileExists: true))
    }
}

struct LibraryItemCodingTests {
    @Test func decodesItemsPersistedBeforeConversionExisted() throws {
        let id = UUID().uuidString
        let json = #"{"id":"\#(id)","name":"a.mp4","bookmark":"AAAA"}"#
        let item = try JSONDecoder().decode(LibraryItem.self, from: Data(json.utf8))
        #expect(item.convertedPath == nil)
        #expect(item.convertedFromSize == nil)
    }
}
