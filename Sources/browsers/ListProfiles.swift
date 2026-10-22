import ArgumentParser
import BrowsersCore

struct ListProfiles: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-profiles",
        abstract: "List browser profiles as folder, display name and signed-in account.",
        discussion: """
            Shows Google Chrome by default. Use the display name as the profile \
            in finicky.js.
            """
    )

    @Flag(name: .long, help: "Show Google Chrome Canary instead of Google Chrome.")
    var canary = false

    @Option(
        name: .long,
        help: "Show another registered browser by name, or 'all' for every registered browser."
    )
    var browser: String?

    @Flag(name: .long, help: "Print JSON instead of a table.")
    var json = false

    func validate() throws {
        if canary && browser != nil {
            throw ValidationError("--canary and --browser cannot be used together")
        }
    }

    func run() throws {
        let registry = ProfileRegistry.standard()
        let selection = try registry.select(canary: canary, browser: browser)
        let groups = try registry.collect(selection)
        print(json ? try formatProfilesJSON(groups) : formatProfilesTable(groups))
    }
}
