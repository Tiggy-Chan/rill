import Foundation

/// Holds sandbox access to a user-chosen file for as long as the instance lives.
final class SecurityScopedAccess {
    let url: URL
    private let started: Bool

    init(_ url: URL) {
        self.url = url
        started = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if started {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
