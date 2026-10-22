import Foundation
import Testing

@testable import BrowsersCore

@Suite struct ProfilesTests {
    /// Creates `<root>/Google/<dir>/Local State` for each entry and returns root.
    private func makeAppSupport(_ files: [String: String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browsers-tests-\(UUID().uuidString)")
        for (directory, contents) in files {
            let dir = root.appendingPathComponent(directory)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try contents.write(
                to: dir.appendingPathComponent("Local State"), atomically: true, encoding: .utf8
            )
        }
        return root
    }

    private let sample = """
        {"profile": {"info_cache": {
          "Profile 10": {"name": "Ten", "user_name": "ten@example.com"},
          "Profile 2": {"name": "Two"},
          "Default": {"name": "Person 1", "user_name": "me@example.com"},
          "Profile 1": {"name": "", "user_name": ""}
        }}}
        """

    @Test func loadsProfilesWithNaturalSortAndMissingFieldsAsNil() throws {
        let root = try makeAppSupport(["Google/Chrome": sample])
        defer { try? FileManager.default.removeItem(at: root) }
        let provider = ChromiumProfileProvider(
            id: "chrome", displayName: "Google Chrome",
            dataDirectory: root.appendingPathComponent("Google/Chrome")
        )
        let profiles = try provider.loadProfiles()
        #expect(profiles.map(\.folder) == ["Default", "Profile 1", "Profile 2", "Profile 10"])
        #expect(profiles[0] == Profile(folder: "Default", name: "Person 1", account: "me@example.com"))
        #expect(profiles[1] == Profile(folder: "Profile 1", name: nil, account: nil))
        #expect(profiles[2] == Profile(folder: "Profile 2", name: "Two", account: nil))
    }

    @Test func missingProfileSectionMeansNoProfiles() throws {
        let root = try makeAppSupport(["Google/Chrome": "{}"])
        defer { try? FileManager.default.removeItem(at: root) }
        let registry = ProfileRegistry.standard(applicationSupport: root)
        let groups = try registry.collect(try registry.select(canary: false, browser: nil))
        #expect(groups.first?.profiles == [])
    }

    @Test func malformedJSONIsAnError() throws {
        let root = try makeAppSupport(["Google/Chrome": "{not json"])
        defer { try? FileManager.default.removeItem(at: root) }
        let registry = ProfileRegistry.standard(applicationSupport: root)
        #expect(throws: BrowsersError.self) {
            try registry.collect(try registry.select(canary: false, browser: nil))
        }
    }

    @Test func defaultSelectionIsChromeOnly() throws {
        let registry = ProfileRegistry.standard(applicationSupport: URL(fileURLWithPath: "/x"))
        let selection = try registry.select(canary: false, browser: nil)
        #expect(selection.providers.map(\.id) == ["chrome"])
        #expect(selection.explicit)
    }

    @Test func canaryFlagSelectsCanary() throws {
        let registry = ProfileRegistry.standard(applicationSupport: URL(fileURLWithPath: "/x"))
        #expect(try registry.select(canary: true, browser: nil).providers.map(\.id) == ["canary"])
    }

    @Test func browserOptionSelectsByNameOrAll() throws {
        let registry = ProfileRegistry.standard(applicationSupport: URL(fileURLWithPath: "/x"))
        #expect(try registry.select(canary: false, browser: "canary").providers.map(\.id) == ["canary"])
        let all = try registry.select(canary: false, browser: "all")
        #expect(all.providers.map(\.id) == ["chrome", "canary"])
        #expect(!all.explicit)
    }

    @Test func canaryAndBrowserConflict() {
        let registry = ProfileRegistry.standard(applicationSupport: URL(fileURLWithPath: "/x"))
        #expect(throws: BrowsersError.conflictingBrowserSelection) {
            try registry.select(canary: true, browser: "chrome")
        }
    }

    @Test func unknownBrowserListsValidNames() {
        let registry = ProfileRegistry.standard(applicationSupport: URL(fileURLWithPath: "/x"))
        do {
            _ = try registry.select(canary: false, browser: "netscape")
            Issue.record("expected an error")
        } catch let error as BrowsersError {
            #expect(error == .unknownBrowser(name: "netscape", valid: ["chrome", "canary"]))
            #expect(error.localizedDescription.contains("chrome, canary, all"))
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test func missingDataIsSkippedForAllButAnErrorWhenExplicit() throws {
        let root = try makeAppSupport(["Google/Chrome": sample])  // no Canary
        defer { try? FileManager.default.removeItem(at: root) }
        let registry = ProfileRegistry.standard(applicationSupport: root)

        let all = try registry.collect(try registry.select(canary: false, browser: "all"))
        #expect(all.map(\.browserId) == ["chrome"])

        #expect(throws: BrowsersError.self) {
            try registry.collect(try registry.select(canary: true, browser: nil))
        }
    }

    @Test func tableOutputMatchesOriginalLayout() {
        let groups = [BrowserProfiles(
            browserId: "chrome", browserName: "Google Chrome",
            profiles: [
                Profile(folder: "Default", name: "Person 1", account: "me@example.com"),
                Profile(folder: "Profile 1", name: nil, account: nil),
            ]
        )]
        let expected = """
            == Google Chrome
            Default    Person 1  me@example.com
            Profile 1  -         -

            """
        #expect(formatProfilesTable(groups) == expected)
    }

    @Test func tableOutputWithHeader() {
        let groups = [BrowserProfiles(
            browserId: "chrome", browserName: "Google Chrome",
            profiles: [
                Profile(folder: "Default", name: "Person 1", account: "me@example.com"),
                Profile(folder: "Profile 1", name: nil, account: nil),
            ]
        )]
        let expected = """
            == Google Chrome
            FOLDER     PROFILE NAME  ACCOUNT
            ---------  ------------  --------------
            Default    Person 1      me@example.com
            Profile 1  -             -

            """
        #expect(formatProfilesTable(groups, header: true) == expected)
    }

    @Test func headerRepeatsPerBrowserAndEmptyGroupsPrintOnlyTheBanner() {
        let groups = [
            BrowserProfiles(
                browserId: "chrome", browserName: "Google Chrome",
                profiles: [Profile(folder: "Default", name: "Work", account: "a@b.co")]
            ),
            BrowserProfiles(browserId: "canary", browserName: "Google Chrome Canary", profiles: []),
            BrowserProfiles(
                browserId: "other", browserName: "Other",
                profiles: [Profile(folder: "Default", name: "Work", account: "a@b.co")]
            ),
        ]
        let expected = """
            == Google Chrome
            FOLDER   PROFILE NAME  ACCOUNT
            -------  ------------  -------
            Default  Work          a@b.co

            == Google Chrome Canary

            == Other
            FOLDER   PROFILE NAME  ACCOUNT
            -------  ------------  -------
            Default  Work          a@b.co

            """
        #expect(formatProfilesTable(groups, header: true) == expected)
    }

    @Test func markdownHasHeadingPerBrowserAndHeadingOnlyForEmptyGroups() {
        let groups = [
            BrowserProfiles(
                browserId: "chrome", browserName: "Google Chrome",
                profiles: [Profile(folder: "Default", name: "Work", account: "a@b.co")]
            ),
            BrowserProfiles(browserId: "canary", browserName: "Google Chrome Canary", profiles: []),
        ]
        let expected = """
            ## Google Chrome

            | FOLDER  | PROFILE NAME | ACCOUNT |
            | ------- | ------------ | ------- |
            | Default | Work         | a@b.co  |

            ## Google Chrome Canary

            """
        #expect(formatProfilesMarkdown(groups) == expected)
    }

    @Test func markdownUsesDashForMissingValues() {
        let groups = [BrowserProfiles(
            browserId: "chrome", browserName: "Google Chrome",
            profiles: [Profile(folder: "Profile 1", name: nil, account: nil)]
        )]
        #expect(formatProfilesMarkdown(groups).contains("| Profile 1 | -            | -       |"))
    }

    @Test func jsonOutputUsesNullForMissingFields() throws {
        let groups = [BrowserProfiles(
            browserId: "chrome", browserName: "Google Chrome",
            profiles: [Profile(folder: "Profile 1", name: nil, account: nil)]
        )]
        let json = try formatProfilesJSON(groups)
        #expect(json.contains("\"browser\" : \"chrome\""))
        #expect(json.contains("\"folder\" : \"Profile 1\""))
        #expect(json.contains("\"name\" : null"))
        #expect(json.contains("\"account\" : null"))
    }
}
