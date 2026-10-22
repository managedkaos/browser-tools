import Testing

@testable import BrowsersCore

struct FakeLocator: BrowserLocator {
    var browsers: [Browser]
    func installedBrowsers() -> [Browser] { browsers }
}

private func browser(_ name: String, _ id: String, _ path: String? = nil) -> Browser {
    Browser(name: name, bundleId: id, path: path ?? "/Applications/\(name).app")
}

@Suite struct BrowserSelectionTests {
    @Test func builtInExcludesDropKnownNonBrowsers() {
        let locator = FakeLocator(browsers: [
            browser("Safari", "com.apple.Safari"),
            browser("Finicky", "se.johnste.finicky"),
            browser("Codex", "com.openai.codex"),
            browser("cmux", "com.cmuxterm.app"),
            browser("iTerm", "com.googlecode.iterm2"),
        ])
        let result = selectBrowsers(from: locator, rules: .builtIn, all: false)
        #expect(result.map(\.bundleId) == ["com.apple.Safari"])
    }

    @Test func builtInExcludesDropUpdaterAndPlaywrightPaths() {
        let locator = FakeLocator(browsers: [
            browser("Edge", "com.microsoft.edgemac"),
            browser("Edge Updater", "com.microsoft.EdgeUpdater",
                    "/Library/Application Support/Microsoft/EdgeUpdater/apps/Edge.app"),
            browser("Chromium", "org.chromium.Chromium",
                    "/Users/me/Library/Caches/ms-playwright/playwright/chromium/Chromium.app"),
        ])
        let result = selectBrowsers(from: locator, rules: .builtIn, all: false)
        #expect(result.map(\.name) == ["Edge"])
    }

    @Test func duplicateBundleIdsKeepFirstSeen() {
        let locator = FakeLocator(browsers: [
            browser("Chrome", "com.google.Chrome", "/Applications/Chrome.app"),
            browser("Chrome", "com.google.Chrome", "/Volumes/Backup/Chrome.app"),
        ])
        let result = selectBrowsers(from: locator, rules: .builtIn, all: false)
        #expect(result.map(\.path) == ["/Applications/Chrome.app"])
    }

    @Test func sortIsCaseInsensitive() {
        let locator = FakeLocator(browsers: [
            browser("firefox", "org.mozilla.firefox"),
            browser("Arc", "company.thebrowser.Browser"),
            browser("Brave", "com.brave.Browser"),
        ])
        let result = selectBrowsers(from: locator, rules: .none, all: false)
        #expect(result.map(\.name) == ["Arc", "Brave", "firefox"])
    }

    @Test func allBypassesFiltersAndDedupeButStillSorts() {
        let locator = FakeLocator(browsers: [
            browser("Safari", "com.apple.Safari"),
            browser("Finicky", "se.johnste.finicky"),
            browser("Finicky", "se.johnste.finicky", "/tmp/Finicky.app"),
        ])
        let result = selectBrowsers(from: locator, rules: .builtIn, all: true)
        #expect(result.map(\.name) == ["Finicky", "Finicky", "Safari"])
    }

    @Test func mergedRulesExcludeUserEntriesAndKeepBuiltIns() {
        let user = ExclusionRules(bundleIds: ["com.example.helper"], pathContains: ["/Helpers/"])
        let rules = ExclusionRules.builtIn.merging(user)
        #expect(rules.excludes(browser("Helper", "com.example.helper")))
        #expect(rules.excludes(browser("X", "x.y", "/Helpers/X.app")))
        #expect(rules.excludes(browser("Finicky", "se.johnste.finicky")))
        #expect(!rules.excludes(browser("Safari", "com.apple.Safari")))
    }

    @Test func emptyPathFragmentDoesNotExcludeEverything() {
        let rules = ExclusionRules(pathContains: [""])
        #expect(!rules.excludes(browser("Safari", "com.apple.Safari")))
    }
}
