import CoreGraphics
import Foundation
import Testing
@testable import Rill

struct FramePickerTests {
    private func image(_ gray: (_ x: Int, _ y: Int) -> UInt8) throws -> CGImage {
        let width = 64, height = 36
        var pixels: [UInt8] = []
        pixels.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                pixels.append(gray(x, y))
            }
        }
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        return try #require(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
    }

    private let black = FramePicker.Stats(mean: 0, deviation: 0)
    private let flat = FramePicker.Stats(mean: 128, deviation: 0.5)
    private let dim = FramePicker.Stats(mean: 10, deviation: 8)
    private let good = FramePicker.Stats(mean: 100, deviation: 40)

    @Test func blackFrameIsNotUsable() throws {
        let stats = try #require(FramePicker.stats(of: try image { _, _ in 0 }))
        #expect(stats.mean < 1)
        #expect(!FramePicker.isUsable(stats))
    }

    @Test func flatGrayFrameIsNotUsable() throws {
        let stats = try #require(FramePicker.stats(of: try image { _, _ in 128 }))
        #expect(abs(stats.mean - 128) < 1)
        #expect(stats.deviation < 1)
        #expect(!FramePicker.isUsable(stats))
    }

    @Test func detailedFrameIsUsable() throws {
        let stats = try #require(FramePicker.stats(of: try image { x, y in (x + y) % 2 == 0 ? 0 : 200 }))
        #expect(abs(stats.mean - 100) < 2)
        #expect(stats.deviation > 90)
        #expect(FramePicker.isUsable(stats))
    }

    @Test func skipsABlackIntro() {
        #expect(FramePicker.choose(from: [black, black, good, good]) == 2)
    }

    @Test func keepsTheFirstFrameWhenItIsUsable() {
        #expect(FramePicker.choose(from: [good, good, black]) == 0)
    }

    @Test func skipsAFlatFill() {
        #expect(FramePicker.choose(from: [flat, good]) == 1)
    }

    @Test func fallsBackToTheMostVariedFrameWhenNoneIsUsable() {
        #expect(FramePicker.choose(from: [flat, dim, black]) == 1)
    }

    @Test func choosesNothingFromNothing() {
        #expect(FramePicker.choose(from: []) == nil)
    }

    @Test func samplesStartAtTheBeginningAndStayInsideTheVideo() {
        #expect(FramePicker.sampleFractions.first == 0)
        #expect(FramePicker.sampleFractions.allSatisfy { $0 >= 0 && $0 < 1 })
        #expect(FramePicker.sampleFractions == FramePicker.sampleFractions.sorted())
    }
}
