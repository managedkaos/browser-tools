import ArgumentParser
import BrowsersCore

@main
struct Browsers: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "browsers",
        abstract: "Tools for working with web browsers on macOS.",
        discussion: """
            Running `browsers` with no subcommand is the same as `browsers list`.

            Tab completion: `browsers --generate-completion-script <bash|zsh|fish>` \
            prints a completion script (the shell is detected from $SHELL if omitted). \
            See "Shell completions" in the README for install steps.
            """,
        version: browsersVersion,
        subcommands: [List.self, ListProfiles.self],
        defaultSubcommand: List.self
    )
}
