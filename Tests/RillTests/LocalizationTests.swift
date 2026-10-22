import Foundation
import Testing

struct LocalizationTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static func table(_ language: String) throws -> [String: String] {
        let url = root.appending(path: "Resources/\(language).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    }

    private static func sourceKeys() throws -> Set<String> {
        let source = try String(contentsOf: root.appending(path: "Sources/Rill/UI/Strings.swift"), encoding: .utf8)
        let regex = try Regex(#"String\(localized: "((?:[^"\\]|\\.)*)"\)"#)
        return Set(source.matches(of: regex).compactMap { match in
            (match.output[1].substring.map(String.init))?
                .replacing(#/\\\(\w+\)/#, with: "%@")
        })
    }

    @Test(arguments: ["en", "zh-Hans"])
    func everySourceStringIsTranslated(language: String) throws {
        let keys = try Self.sourceKeys()
        #expect(!keys.isEmpty)
        let missing = keys.subtracting(try Self.table(language).keys)
        #expect(missing.isEmpty, "Missing in \(language): \(missing.sorted())")
    }

    @Test(arguments: ["en", "zh-Hans"])
    func tablesHaveNoUnusedEntries(language: String) throws {
        let unused = Set(try Self.table(language).keys).subtracting(try Self.sourceKeys())
        #expect(unused.isEmpty, "Unused in \(language): \(unused.sorted())")
    }

    @Test func translationsKeepTheirPlaceholders() throws {
        let zh = try Self.table("zh-Hans")
        for (key, value) in zh {
            #expect(key.components(separatedBy: "%@").count == value.components(separatedBy: "%@").count, "\(key)")
        }
    }
}
