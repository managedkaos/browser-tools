import ArgumentParser
import BrowsersCore

struct ConfigOptions: ParsableArguments {
    @Option(
        name: .long,
        help: "Read configuration from this file instead of the default.",
        completion: .file(extensions: ["yaml", "yml"])
    )
    var config: String?

    @Flag(name: .long, help: "Ignore the user configuration file.")
    var noConfig = false

    func exclusionRules() throws -> ExclusionRules {
        if noConfig { return .builtIn }
        let loaded = try ConfigLoader.load(explicitPath: config)
        return ExclusionRules.builtIn.merging(loaded.exclusionRules)
    }

    func validate() throws {
        if noConfig && config != nil {
            throw ValidationError("--config and --no-config cannot be used together")
        }
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List installed web browsers as name, bundle ID and path.",
        discussion: """
            Shows apps registered with macOS to open https URLs. Bundle IDs can be \
            used in finicky.js. Non-browser link handlers, updater copies and test \
            builds are hidden; use --all to show everything.

            On a terminal the table has a header row and long paths are shortened \
            to fit the window (use --no-truncate to see them in full). Piped and \
            --json output has no header and is never shortened. --markdown prints \
            a complete Markdown table.

            --id (or --bundle-id) prints only the bundle ID column in any output \
            mode: bare IDs, one per line, when piped; a one-column table with \
            --markdown; objects with only "bundleId" with --json.

            User exclusions are read from ~/.config/browsers/config.yaml \
            (or $XDG_CONFIG_HOME/browsers/config.yaml).
            """
    )

    @Flag(name: [.short, .long], help: "Show all registered apps, ignoring built-in and user filters.")
    var all = false

    @Flag(name: .long, help: "Print JSON instead of a table.")
    var json = false

    @Flag(name: .long, help: "Print a Markdown table instead of a plain table.")
    var markdown = false

    @Flag(
        name: [.customLong("id"), .customLong("bundle-id")],
        help: "Print only the bundle ID column."
    )
    var idOnly = false

    @Flag(
        name: .long,
        help: "Show full paths instead of shortening them to fit the terminal."
    )
    var noTruncate = false

    @OptionGroup var configOptions: ConfigOptions

    func validate() throws {
        if json && markdown {
            throw ValidationError("--json and --markdown cannot be used together")
        }
    }

    func run() throws {
        // --all ignores every filter, so a broken config must not get in the way.
        let rules: ExclusionRules = all ? .none : try configOptions.exclusionRules()
        let browsers = selectBrowsers(from: WorkspaceBrowserLocator(), rules: rules, all: all)
        if json {
            print(try formatBrowsersJSON(browsers, idOnly: idOnly))
            return
        }
        if markdown {
            // Markdown is always complete: no terminal fitting, never truncated.
            print(formatBrowsersMarkdown(browsers, idOnly: idOnly))
            return
        }
        let isTerminal = stdoutIsTerminal
        let maxWidth = fittedWidth(
            isTerminal: isTerminal, terminalWidth: isTerminal ? terminalWidth() : nil,
            noTruncate: noTruncate
        )
        print(formatBrowsersTable(browsers, header: isTerminal, maxWidth: maxWidth, idOnly: idOnly))
    }
}
