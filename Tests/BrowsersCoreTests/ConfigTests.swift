import Foundation
import Testing

@testable import BrowsersCore

@Suite struct ConfigTests {
    private func tempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("browsers-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func parsesExcludeLists() throws {
        let config = try ConfigLoader.parse("""
            exclude:
              bundleIds: [com.example.helper]
              pathContains:
                - /Helpers/
            """)
        #expect(config.exclusionRules == ExclusionRules(
            bundleIds: ["com.example.helper"], pathContains: ["/Helpers/"]
        ))
    }

    @Test func emptyAndCommentOnlyDocumentsAreEmptyConfigs() throws {
        #expect(try ConfigLoader.parse("") == .empty)
        #expect(try ConfigLoader.parse("# nothing here\n") == .empty)
    }

    @Test func missingKeysAreFine() throws {
        #expect(try ConfigLoader.parse("exclude: {}\n").exclusionRules == .none)
    }

    @Test func malformedYAMLIsAnError() {
        #expect(throws: BrowsersError.self) {
            try ConfigLoader.parse("exclude: [unterminated")
        }
    }

    @Test func wrongTypesAreAnError() {
        #expect(throws: BrowsersError.self) {
            try ConfigLoader.parse("exclude:\n  bundleIds: not-a-list\n")
        }
    }

    @Test func defaultPathUsesXDGWhenAbsolute() {
        let home = URL(fileURLWithPath: "/Users/me")
        let path = ConfigLoader.defaultPath(environment: ["XDG_CONFIG_HOME": "/custom/cfg"], home: home)
        #expect(path.path == "/custom/cfg/browsers/config.yaml")
    }

    @Test func defaultPathFallsBackToHomeDotConfig() {
        let home = URL(fileURLWithPath: "/Users/me")
        #expect(ConfigLoader.defaultPath(environment: [:], home: home).path
            == "/Users/me/.config/browsers/config.yaml")
        // Empty and relative XDG values are ignored, per the XDG spec.
        #expect(ConfigLoader.defaultPath(environment: ["XDG_CONFIG_HOME": ""], home: home).path
            == "/Users/me/.config/browsers/config.yaml")
        #expect(ConfigLoader.defaultPath(environment: ["XDG_CONFIG_HOME": "rel"], home: home).path
            == "/Users/me/.config/browsers/config.yaml")
    }

    @Test func missingDefaultFileIsEmptyConfig() throws {
        let home = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        #expect(try ConfigLoader.load(explicitPath: nil, environment: [:], home: home) == .empty)
    }

    @Test func missingExplicitFileIsAnError() throws {
        let home = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        #expect(throws: BrowsersError.self) {
            try ConfigLoader.load(
                explicitPath: home.appendingPathComponent("nope.yaml").path,
                environment: [:], home: home
            )
        }
    }

    @Test func loadsDefaultFileFromXDGLocation() throws {
        let xdg = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: xdg) }
        let dir = xdg.appendingPathComponent("browsers")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "exclude:\n  bundleIds: [com.example.helper]\n"
            .write(to: dir.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        let config = try ConfigLoader.load(
            explicitPath: nil,
            environment: ["XDG_CONFIG_HOME": xdg.path],
            home: URL(fileURLWithPath: "/nonexistent")
        )
        #expect(config.exclusionRules.bundleIds == ["com.example.helper"])
    }

    @Test func malformedFileReportsItsPath() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("bad.yaml")
        try "exclude: [oops".write(to: file, atomically: true, encoding: .utf8)
        do {
            _ = try ConfigLoader.load(explicitPath: file.path, environment: [:], home: dir)
            Issue.record("expected an error")
        } catch let error as BrowsersError {
            #expect(error.localizedDescription.contains(file.path))
        }
    }
}
