import ArgumentParser
import BrowsersCore

struct ListProfiles: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-profiles",
        abstract: "List browser profiles as folder, display name and signed-in account.",
        discussion: """
            Shows Google Chrome by default. Use the PROFILE NAME (display name) as \
            the profile in finicky.js. On a terminal the table has a header row; \
            piped output does not.
            """
    )

    @Flag(name: .long, help: "Show Google Chrome Canary instead of Google Chrome.")
    var canary = false

    @Option(
        name: .long,
        help: "Show another registered browser by name, or 'all' for every registered browser.",
        completion: .list(ProfileRegistry.standard().browserArgumentValues)
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
        let registry = ProfileRegistry.standard()
        let selection = try registry.select(canary: canary, browser: browser)
        let groups = try registry.collect(selection)
        if json {
            print(try formatProfilesJSON(groups))
        } else if markdown {
            print(formatProfilesMarkdown(groups))
        } else {
            print(formatProfilesTable(groups, header: stdoutIsTerminal))
        }
    }
}
