import ArgumentParser
import BrowsersCore

struct ListExtensions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-extensions",
        abstract: "List installed browser extensions by profile.",
        discussion: """
            Shows Google Chrome by default. Use --browser all to scan all supported
            browsers. On a terminal the table has a header row. Piped output omits
            the column labels.
            """
    )

    @Flag(name: .long, help: "Show Google Chrome Canary instead of Google Chrome.")
    var canary = false

    @Option(
        name: .long,
        help: "Show another supported browser by name, or 'all' for every supported browser."
    )
    var browser: String?

    @Flag(name: .long, help: "Print JSON instead of a table.")
    var json = false

    @Flag(name: .long, help: "Print a Markdown table instead of a plain table.")
    var markdown = false

    func validate() throws {
        if canary && browser != nil {
            throw ValidationError("--canary and --browser cannot be used together")
        }
        if json && markdown {
            throw ValidationError("--json and --markdown cannot be used together")
        }
    }

    func run() throws {
        let groups = try collectExtensions(canary: canary, browser: browser)
        if json {
            print(try formatExtensionsJSON(groups))
        } else if markdown {
            print(formatExtensionsMarkdown(groups))
        } else {
            print(formatExtensionsTable(groups, header: stdoutIsTerminal))
        }
    }
}
