import CRemux
import Foundation

enum RemuxOutcome: Equatable {
    case done
    /// The video codec can't be copied into MP4 (only H.264 and HEVC can); ASCII detail from the C layer.
    case unsupportedVideoCodec(String)
    case failed(String)
}

/// Where converted copies live and how their freshness is judged.
enum RemuxStore {
    /// Bumped whenever the converter's output changes in a way that makes
    /// existing copies worse than useless (e.g. a timestamp fix); items saved
    /// by an older converter re-convert automatically.
    static let formatVersion = 2

    /// …/Application Support/Rill/Remux — inside the app container, so no
    /// extra sandbox grants are needed to write or replay the copies.
    static func cacheURL(for id: UUID) -> URL {
        URL.applicationSupportDirectory
            .appending(path: "Rill/Remux/\(id.uuidString).mp4")
    }

    /// Pure freshness rule, kept free of file I/O so tests can pin it down: a
    /// copy counts while its file exists and the source is the size it was
    /// made from.
    static func cacheIsCurrent(
        recordedCachePath: String?,
        recordedSourceSize: Int?,
        currentSourceSize: Int?,
        cacheFileExists: Bool
    ) -> Bool {
        guard recordedCachePath != nil,
              let recordedSourceSize,
              let currentSourceSize,
              cacheFileExists
        else { return false }
        return recordedSourceSize == currentSourceSize
    }

    /// Deletes the copy (and any half-written leftover) belonging to a removed item.
    static func discardCache(for id: UUID) {
        let cache = cacheURL(for: id)
        try? FileManager.default.removeItem(at: cache)
        try? FileManager.default.removeItem(at: cache.appendingPathExtension("part"))
    }

    /// Sweeps copies whose library item is gone.
    static func removeOrphans(keeping ids: Set<UUID>) {
        let directory = cacheURL(for: UUID()).deletingLastPathComponent()
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names {
            let stem = (name as NSString).deletingPathExtension
            guard let id = UUID(uuidString: stem), !ids.contains(id) else { continue }
            try? FileManager.default.removeItem(at: directory.appending(path: name))
        }
    }
}

/// Stream-copies a container AVFoundation cannot open into an MP4 next to the
/// app's other derived files. The C call blocks for as long as the copy takes,
/// so it runs on a utility queue rather than a cooperative thread.
enum Remuxer {
    nonisolated static func convert(source: URL, to destination: URL) async -> RemuxOutcome {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                // The copy reads the source under sandbox access held for its duration.
                let access = SecurityScopedAccess(source)
                let partial = destination.appendingPathExtension("part")
                try? FileManager.default.createDirectory(
                    at: partial.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try? FileManager.default.removeItem(at: partial)
                defer { try? FileManager.default.removeItem(at: partial) }

                var detail = [CChar](repeating: 0, count: 256)
                let code = source.path.withCString { src in
                    partial.path.withCString { dst in
                        detail.withUnsafeMutableBufferPointer { buffer in
                            rill_remux(src, dst, buffer.baseAddress, buffer.count)
                        }
                    }
                }
                let message = String(cString: detail)
                switch code {
                case Int32(RILL_REMUX_OK):
                    do {
                        try? FileManager.default.removeItem(at: destination)
                        try FileManager.default.moveItem(at: partial, to: destination)
                        continuation.resume(returning: .done)
                    } catch {
                        continuation.resume(returning: .failed("rename: \(error.localizedDescription)"))
                    }
                case Int32(RILL_REMUX_UNSUPPORTED_CODEC):
                    continuation.resume(returning: .unsupportedVideoCodec(message))
                default:
                    continuation.resume(returning: .failed(message.isEmpty ? "av error \(code)" : message))
                }
            }
        }
    }
}
