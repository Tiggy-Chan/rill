import Foundation
import UniformTypeIdentifiers

/// What container a video file actually is, judged by its first bytes: file
/// extensions lie, and downloads are full of MKVs named ".mp4".
enum ContainerKind: Equatable {
    /// Extensions of containers AVFoundation cannot open; Rill converts these to MP4.
    static let convertibleExtensions: Set<String> = ["mkv", "webm", "avi", "flv"]

    case mp4Family
    case quickTime
    case matroska
    case avi
    case flv
    case unknown

    var needsConversion: Bool {
        switch self {
        case .matroska, .avi, .flv: true
        case .mp4Family, .quickTime, .unknown: false
        }
    }

    /// File types pickers and drop targets should accept: anything the system
    /// calls a movie, plus the convertible extensions which often carry no
    /// declared UTType of their own.
    static var openPanelTypes: [UTType] {
        var types: [UTType] = [.movie]
        for ext in convertibleExtensions.sorted() {
            if let type = UTType(filenameExtension: ext), !types.contains(type) {
                types.append(type)
            }
        }
        return types
    }

    /// True when `url` looks like a video Rill can take in.
    static func isAcceptable(_ url: URL) -> Bool {
        if convertibleExtensions.contains(url.pathExtension.lowercased()) { return true }
        return UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) ?? false
    }

    static func sniff(url: URL) -> ContainerKind {
        guard
            let handle = try? FileHandle(forReadingFrom: url),
            let head = try? handle.read(upToCount: 64)
        else { return .unknown }
        try? handle.close()
        return sniff(head)
    }

    static func sniff(_ head: Data) -> ContainerKind {
        let bytes = [UInt8](head.prefix(64))
        func fourCC(_ offset: Int) -> String {
            guard offset + 4 <= bytes.count else { return "" }
            return String(decoding: bytes[offset..<offset + 4], as: UTF8.self)
        }
        // EBML magic: Matroska and WebM.
        if bytes.starts(with: [0x1A, 0x45, 0xDF, 0xA3]) { return .matroska }
        if fourCC(0) == "RIFF" && fourCC(8) == "AVI " { return .avi }
        if bytes.starts(with: [0x46, 0x4C, 0x56]) { return .flv }
        if fourCC(4) == "ftyp" { return .mp4Family }
        // Classic QuickTime files open straight into one of these atoms.
        switch fourCC(4) {
        case "moov", "mdat", "wide", "free", "skip", "pnot": return .quickTime
        default: return .unknown
        }
    }
}
