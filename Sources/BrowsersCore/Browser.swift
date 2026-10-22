import AppKit
import Foundation

/// An application registered with macOS to open https URLs.
public struct Browser: Codable, Equatable, Sendable {
    public var name: String
    public var bundleId: String
    public var path: String

    public init(name: String, bundleId: String, path: String) {
        self.name = name
        self.bundleId = bundleId
        self.path = path
    }
}

/// Source of installed browsers. Abstracted so tests can use a fake.
public protocol BrowserLocator: Sendable {
    func installedBrowsers() -> [Browser]
}

/// Asks Launch Services which apps can open https URLs.
public struct WorkspaceBrowserLocator: BrowserLocator {
    public init() {}

    public func installedBrowsers() -> [Browser] {
        guard let probe = URL(string: "https://example.com") else { return [] }
        return NSWorkspace.shared.urlsForApplications(toOpen: probe).map { url in
            Browser(
                name: url.deletingPathExtension().lastPathComponent,
                bundleId: Bundle(url: url)?.bundleIdentifier ?? "?",
                path: url.path
            )
        }
    }
}
