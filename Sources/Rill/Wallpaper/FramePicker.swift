import AVFoundation
import CoreGraphics

/// Picks the still that stands in for a video on the lock screen: the first sampled frame that isn't
/// black or blank, so a clip that fades in from black doesn't give a black lock screen.
enum FramePicker {
    struct Stats: Equatable {
        /// Average brightness, 0...255.
        var mean: Double
        /// How much brightness varies across the frame, 0...255. Flat frames score near 0.
        var deviation: Double
    }

    /// Positions in the video to try, as fractions of its duration, in order of preference.
    static let sampleFractions: [Double] = [0, 0.1, 0.25, 0.5, 0.75]

    static func isUsable(_ stats: Stats) -> Bool {
        stats.mean >= 24 && stats.deviation >= 6
    }

    /// The earliest usable frame, or the most varied one when none is usable.
    static func choose(from stats: [Stats]) -> Int? {
        if let index = stats.firstIndex(where: isUsable) {
            return index
        }
        return stats.indices.max { stats[$0].deviation < stats[$1].deviation }
    }

    static func stats(of image: CGImage) -> Stats? {
        let width = 64, height = 36
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        let count = Double(pixels.count)
        let mean = pixels.reduce(0.0) { $0 + Double($1) } / count
        let variance = pixels.reduce(0.0) { $0 + (Double($1) - mean) * (Double($1) - mean) } / count
        return Stats(mean: mean, deviation: variance.squareRoot())
    }

    /// Scores small versions of the sample frames, then returns the chosen one at full size.
    nonisolated static func bestFrame(of asset: AVAsset) async -> CGImage? {
        let seconds = (try? await asset.load(.duration))?.seconds ?? 0
        let times: [CMTime] = seconds.isFinite && seconds > 0
            ? sampleFractions.map { CMTime(seconds: min($0, 0.99) * seconds, preferredTimescale: 600) }
            : [.zero]

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 320)

        var scores: [Stats] = []
        var scoredTimes: [CMTime] = []
        for time in times {
            guard let image = try? await generator.image(at: time).image, let score = stats(of: image) else {
                continue
            }
            scores.append(score)
            scoredTimes.append(time)
        }
        guard let index = choose(from: scores) else { return nil }

        generator.maximumSize = .zero
        return try? await generator.image(at: scoredTimes[index]).image
    }
}
