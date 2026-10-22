import Foundation

/// Rules that hide non-browser link handlers, updater copies and test builds.
public struct ExclusionRules: Equatable, Sendable {
    public var bundleIds: Set<String>
    public var pathContains: [String]

    public init(bundleIds: Set<String> = [], pathContains: [String] = []) {
        self.bundleIds = bundleIds
        self.pathContains = pathContains
    }

    /// Rules built into the tool.
    public static let builtIn = ExclusionRules(
        bundleIds: [
            "se.johnste.finicky",
            "com.openai.codex",
            "com.cmuxterm.app",
            "com.googlecode.iterm2",
        ],
        pathContains: ["/EdgeUpdater/", "/playwright/"]
    )

    public static let none = ExclusionRules()

    /// Returns rules that exclude everything excluded by either side.
    public func merging(_ other: ExclusionRules) -> ExclusionRules {
        var merged = pathContains
        for fragment in other.pathContains where !merged.contains(fragment) {
            merged.append(fragment)
        }
        return ExclusionRules(
            bundleIds: bundleIds.union(other.bundleIds),
            pathContains: merged
        )
    }

    public func excludes(_ browser: Browser) -> Bool {
        if bundleIds.contains(browser.bundleId) { return true }
        return pathContains.contains { !$0.isEmpty && browser.path.contains($0) }
    }
}

/// Filters, dedupes (first seen wins, by bundle ID) and sorts browsers
/// case-insensitively by name. With `all`, filtering and dedupe are skipped.
public func selectBrowsers(
    from locator: some BrowserLocator,
    rules: ExclusionRules,
    all: Bool
) -> [Browser] {
    var browsers = locator.installedBrowsers()
    if !all {
        var seen = Set<String>()
        browsers = browsers.filter { browser in
            guard !rules.excludes(browser) else { return false }
            return seen.insert(browser.bundleId).inserted
        }
    }
    return browsers.sorted { lhs, rhs in
        let order = lhs.name.compare(rhs.name, options: [.caseInsensitive])
        if order != .orderedSame { return order == .orderedAscending }
        return lhs.path < rhs.path
    }
}
