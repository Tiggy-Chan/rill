import Foundation
import Testing
@testable import Rill

struct LocalizationTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static let languages: [String] = {
        let resources = root.appending(path: "Resources")
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: resources.path)) ?? []
        return entries.filter { $0.hasSuffix(".lproj") }.map { String($0.dropLast(6)) }.sorted()
    }()

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

    @Test func shipsEveryLanguageThePickerOffers() {
        #expect(Set(Self.languages) == Set(AppLanguage.order))
    }

    @Test func infoPlistDeclaresEveryLanguage() throws {
        let data = try Data(contentsOf: Self.root.appending(path: "Resources/Info.plist"))
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let declared = try #require(plist["CFBundleLocalizations"] as? [String])
        #expect(Set(declared) == Set(Self.languages))
    }

    @Test(arguments: languages)
    func everySourceStringIsTranslated(language: String) throws {
        let keys = try Self.sourceKeys()
        #expect(!keys.isEmpty)
        let missing = keys.subtracting(try Self.table(language).keys)
        #expect(missing.isEmpty, "Missing in \(language): \(missing.sorted())")
    }

    @Test(arguments: languages)
    func tableHasNoUnusedEntries(language: String) throws {
        let unused = Set(try Self.table(language).keys).subtracting(try Self.sourceKeys())
        #expect(unused.isEmpty, "Unused in \(language): \(unused.sorted())")
    }

    @Test(arguments: languages)
    func translationsKeepTheirPlaceholders(language: String) throws {
        for (key, value) in try Self.table(language) {
            #expect(
                key.components(separatedBy: "%@").count == value.components(separatedBy: "%@").count,
                "\(language): \(key)"
            )
        }
    }

    @Test(arguments: languages.filter { $0 != "en" })
    func nonEnglishTablesAreActuallyTranslated(language: String) throws {
        let table = try Self.table(language)
        let untouched = table.filter { $0.key == $0.value && $0.key.count > 8 }
        // A few long strings may legitimately match English, but not most of the table.
        #expect(untouched.count < table.count / 4, "\(language) looks untranslated: \(untouched.keys.sorted().prefix(5))")
    }
}
