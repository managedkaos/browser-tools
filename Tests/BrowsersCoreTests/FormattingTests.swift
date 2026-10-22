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

    // MARK: Header

    @Test func headerWiderThanDataSetsColumnWidths() {
        let output = formatTable([["a", "b", "c"]], header: ["NAME", "BUNDLE ID", "PATH"])
        let expected = """
            NAME  BUNDLE ID  PATH
            ----  ---------  ----
            a     b          c
            """
        #expect(output == expected)
    }

    @Test func dataWiderThanHeaderSetsColumnWidths() {
        let output = formatTable(
            [["Safari", "com.apple.Safari", "/Applications/Safari.app"]],
            header: ["NAME", "BUNDLE ID", "PATH"]
        )
        let expected = """
            NAME    BUNDLE ID         PATH
            ------  ----------------  ------------------------
            Safari  com.apple.Safari  /Applications/Safari.app
            """
        #expect(output == expected)
    }

    @Test func emptyRowsWithHeaderIsEmptyString() {
        #expect(formatTable([], header: ["NAME", "PATH"]) == "")
    }

    @Test func browsersTableHeaderIsOptIn() {
        let browsers = [Browser(name: "Safari", bundleId: "com.apple.Safari", path: "/Applications/Safari.app")]
        #expect(formatBrowsersTable(browsers) == "Safari  com.apple.Safari  /Applications/Safari.app")
        let expected = """
            NAME    BUNDLE ID         PATH
            ------  ----------------  ------------------------
            Safari  com.apple.Safari  /Applications/Safari.app
            """
        #expect(formatBrowsersTable(browsers, header: true) == expected)
    }

    // MARK: Truncation

    @Test func truncateMiddleKeepsStartAndTail() {
        let path = "/Users/Michael.Jenkins/Applications/Orion.app"
        let result = truncateMiddle(path, to: 20)
        #expect(result == "/Users…ons/Orion.app")
        #expect(result.count == 20)
    }

    @Test func truncateMiddleLeavesFittingStringsAlone() {
        #expect(truncateMiddle("short", to: 10) == "short")
        #expect(truncateMiddle("exact", to: 5) == "exact")
    }

    @Test func truncateMiddleEdgeCases() {
        #expect(truncateMiddle("abcdef", to: 1) == "…")
        #expect(truncateMiddle("abcdef", to: 0) == "")
        #expect(truncateMiddle("abcdef", to: 2) == "…f")
    }

    @Test func shrinkColumnIsTruncatedToFitMaxWidthAndUnderlineFollows() {
        let output = formatTable(
            [["A", "B", "/very/long/path/to/Thing.app"]],
            header: ["NAME", "BUNDLE ID", "PATH"],
            maxWidth: 40,
            shrinkColumn: 2
        )
        let expected = """
            NAME  BUNDLE ID  PATH
            ----  ---------  -----------------------
            A     B          /very/l…th/to/Thing.app
            """
        #expect(output == expected)
        #expect(output.split(separator: "\n").last?.count == 40)
    }

    @Test func nothingIsTruncatedWhenContentFits() {
        let rows = [["A", "B", "/short/Thing.app"]]
        #expect(
            formatTable(rows, maxWidth: 120, shrinkColumn: 2) == formatTable(rows)
        )
    }

    @Test func nonShrinkColumnsAreNeverTruncatedAndFloorWins() {
        let name = "Orion - Managed Kaos"
        let bundleId = "com.kagi.kagimacOS.9CFD2257-9734-4F7C-BBCC-8E6AA8A192CA"
        let path = "/Users/Michael.Jenkins/Applications/Orion/Orion Profiles/9CFD2257-9734-4F7C-BBCC-8E6AA8A192CA/Orion - Managed Kaos.app"
        // Terminal narrower than name + bundle ID alone.
        let output = formatTable([[name, bundleId, path]], maxWidth: 60, shrinkColumn: 2)
        let expected = name + "  " + bundleId + "  " + truncateMiddle(path, to: minimumShrinkWidth)
        #expect(output == expected)
        #expect(output.hasSuffix("Kaos.app"))
        #expect(output.contains("…"))
    }

    @Test func longPathIsFittedToTerminalWidthKeepingAppName() {
        let name = "Orion - Managed Kaos"
        let bundleId = "com.kagi.kagimacOS.9CFD2257-9734-4F7C-BBCC-8E6AA8A192CA"
        let path = "/Users/Michael.Jenkins/Applications/Orion/Orion Profiles/9CFD2257-9734-4F7C-BBCC-8E6AA8A192CA/Orion - Managed Kaos.app"
        let browsers = [Browser(name: name, bundleId: bundleId, path: path)]
        let lines = formatBrowsersTable(browsers, header: true, maxWidth: 120)
            .split(separator: "\n").map(String.init)
        #expect(lines.count == 3)
        #expect(lines[1].count == 120)  // underline spans the fitted table
        #expect(lines[2].count == 120)
        #expect(lines[2].hasSuffix("Orion - Managed Kaos.app"))
        #expect(lines[2].contains("…"))
        #expect(lines[2].hasPrefix(name + "  " + bundleId + "  "))
    }

    // MARK: Width resolution

    @Test func fittedWidthOnlyAppliesToTerminalsThatReportAWidth() {
        #expect(fittedWidth(isTerminal: true, terminalWidth: 100, noTruncate: false) == 100)
        #expect(fittedWidth(isTerminal: false, terminalWidth: 100, noTruncate: false) == nil)
        #expect(fittedWidth(isTerminal: true, terminalWidth: 100, noTruncate: true) == nil)
        #expect(fittedWidth(isTerminal: true, terminalWidth: nil, noTruncate: false) == nil)
        #expect(fittedWidth(isTerminal: true, terminalWidth: 0, noTruncate: false) == nil)
    }

    // MARK: Markdown

    @Test func markdownTableIsAlignedWithAlwaysOnHeader() {
        let browsers = [
            Browser(name: "Safari", bundleId: "com.apple.Safari", path: "/Applications/Safari.app")
        ]
        let expected = """
            | NAME   | BUNDLE ID        | PATH                     |
            | ------ | ---------------- | ------------------------ |
            | Safari | com.apple.Safari | /Applications/Safari.app |
            """
        #expect(formatBrowsersMarkdown(browsers) == expected)
    }

    @Test func emptyMarkdownTableIsHeaderOnly() {
        let expected = """
            | NAME | BUNDLE ID | PATH |
            | ---- | --------- | ---- |
            """
        #expect(formatBrowsersMarkdown([]) == expected)
    }

    @Test func markdownEscapesSpecialCharacters() {
        #expect(
            escapeMarkdownCell("a|b_c*d`e\\f<g>[h]~i") == "a\\|b\\_c\\*d\\`e\\\\f\\<g\\>\\[h\\]\\~i"
        )
        #expect(escapeMarkdownCell("Plain Name.app") == "Plain Name.app")
    }

    @Test func markdownColumnsStayAlignedWithEscapedCells() {
        let output = formatMarkdownTable(
            [["a|b", "snake_case", "x"], ["longer name", "y", "z"]],
            header: ["A", "B", "C"]
        )
        let lines = output.split(separator: "\n").map(String.init)
        #expect(lines.count == 4)
        #expect(Set(lines.map(\.count)).count == 1)  // every line is the same width
        #expect(lines[2].contains("a\\|b"))
        #expect(lines[2].contains("snake\\_case"))
        // Only escaped pipes plus the 4 column delimiters per row.
        #expect(lines[2].filter { $0 == "|" }.count == 4 + 1)
    }

    @Test func markdownIsNeverTruncated() {
        let path = String(repeating: "/very/long", count: 30) + "/Thing.app"
        let output = formatBrowsersMarkdown([Browser(name: "T", bundleId: "t.t", path: path)])
        #expect(output.contains(path.replacingOccurrences(of: "_", with: "\\_")))
        #expect(!output.contains("…"))
    }

    // MARK: Bundle ID only

    private var sampleBrowsers: [Browser] {
        [
            Browser(name: "Arc", bundleId: "company.thebrowser.Browser", path: "/Applications/Arc.app"),
            Browser(name: "Safari", bundleId: "com.apple.Safari", path: "/Applications/Safari.app"),
        ]
    }

    @Test func idOnlyTablePipedIsBareIDsOneLineEach() {
        #expect(
            formatBrowsersTable(sampleBrowsers, idOnly: true)
                == "company.thebrowser.Browser\ncom.apple.Safari"
        )
    }

    @Test func idOnlyTableOnTerminalHasHeaderAndIsNeverShortened() {
        let expected = """
            BUNDLE ID
            --------------------------
            company.thebrowser.Browser
            com.apple.Safari
            """
        // A tiny maxWidth must not shorten bundle IDs.
        #expect(formatBrowsersTable(sampleBrowsers, header: true, maxWidth: 10, idOnly: true) == expected)
    }

    @Test func idOnlyMarkdownIsAOneColumnTable() {
        let expected = """
            | BUNDLE ID                  |
            | -------------------------- |
            | company.thebrowser.Browser |
            | com.apple.Safari           |
            """
        #expect(formatBrowsersMarkdown(sampleBrowsers, idOnly: true) == expected)
    }

    @Test func idOnlyJSONKeepsTheBundleIdKey() throws {
        let expected = """
            [
              {
                "bundleId" : "company.thebrowser.Browser"
              },
              {
                "bundleId" : "com.apple.Safari"
              }
            ]
            """
        #expect(try formatBrowsersJSON(sampleBrowsers, idOnly: true) == expected)
    }

    @Test func fullJSONIsUnchangedWithoutIdOnly() throws {
        #expect(try formatBrowsersJSON(sampleBrowsers) == encodeJSON(sampleBrowsers))
    }

    @Test func emptyIdOnlyOutputs() throws {
        #expect(formatBrowsersTable([], idOnly: true) == "")
        #expect(formatBrowsersMarkdown([], idOnly: true).hasPrefix("| BUNDLE ID |"))
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
