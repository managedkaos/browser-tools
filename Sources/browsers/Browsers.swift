import ArgumentParser
import BrowsersCore

@main
struct Browsers: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "browsers",
        abstract: "Tools for working with web browsers on macOS.",
        discussion: "Running `browsers` with no subcommand is the same as `browsers list`.",
        version: browsersVersion,
        subcommands: [List.self, ListProfiles.self],
        defaultSubcommand: List.self
    )
}
