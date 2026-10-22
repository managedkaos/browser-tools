import ArgumentParser
import BrowsersCore

struct ConfigOptions: ParsableArguments {
    @Option(name: .long, help: "Read configuration from this file instead of the default.")
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

            User exclusions are read from ~/.config/browsers/config.yaml \
            (or $XDG_CONFIG_HOME/browsers/config.yaml).
            """
    )

    @Flag(name: [.short, .long], help: "Show all registered apps, ignoring built-in and user filters.")
    var all = false

    @Flag(name: .long, help: "Print JSON instead of a table.")
    var json = false

    @OptionGroup var configOptions: ConfigOptions

    func run() throws {
        // --all ignores every filter, so a broken config must not get in the way.
        let rules: ExclusionRules = all ? .none : try configOptions.exclusionRules()
        let browsers = selectBrowsers(from: WorkspaceBrowserLocator(), rules: rules, all: all)
        print(json ? try encodeJSON(browsers) : formatBrowsersTable(browsers))
    }
}
