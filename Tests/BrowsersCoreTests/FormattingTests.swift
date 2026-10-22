import Testing

@testable import BrowsersCore

@Suite struct FormattingTests {
    @Test func tableAlignsColumnsWithTwoSpaceGapAndNoTrailingPadding() {
        let output = formatTable([
            ["Safari", "com.apple.Safari", "/Applications/Safari.app"],
            ["Arc", "company.thebrowser.Browser", "/Applications/Arc.app"],
        ])
        let expected = """
            Safari  com.apple.Safari            /Applications/Safari.app
            Arc     company.thebrowser.Browser  /Applications/Arc.app
            """
        #expect(output == expected)
    }

    @Test func emptyTableIsEmptyString() {
        #expect(formatTable([]) == "")
    }

    @Test func browsersJSONMatchesGoldenOutput() throws {
        let json = try encodeJSON([
            Browser(name: "Safari", bundleId: "com.apple.Safari", path: "/Applications/Safari.app")
        ])
        let expected = """
            [
              {
                "bundleId" : "com.apple.Safari",
                "name" : "Safari",
                "path" : "/Applications/Safari.app"
              }
            ]
            """
        #expect(json == expected)
    }

    @Test func emptyBrowsersJSONIsEmptyArray() throws {
        #expect(try encodeJSON([Browser]()) == "[\n\n]")
    }
}
