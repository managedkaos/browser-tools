import Foundation
import Yams

/// User configuration, e.g. `~/.config/browsers/config.yaml`:
///
///     exclude:
///       bundleIds: [com.example.helper]
///       pathContains: [/SomeUpdater/]
public struct Config: Decodable, Equatable, Sendable {
    public struct Exclude: Decodable, Equatable, Sendable {
        public var bundleIds: [String]?
        public var pathContains: [String]?
    }

    public var exclude: Exclude?

    public init(exclude: Exclude? = nil) {
        self.exclude = exclude
    }

    public static let empty = Config()

    /// The user's exclusions as rules, ready to merge with the built-ins.
    public var exclusionRules: ExclusionRules {
        ExclusionRules(
            bundleIds: Set(exclude?.bundleIds ?? []),
            pathContains: exclude?.pathContains ?? []
        )
    }
}

public enum ConfigLoader {
    /// Default config location: `$XDG_CONFIG_HOME/browsers/config.yaml` when
    /// set to an absolute path, otherwise `~/.config/browsers/config.yaml`.
    public static func defaultPath(environment: [String: String], home: URL) -> URL {
        if let xdg = environment["XDG_CONFIG_HOME"], xdg.hasPrefix("/") {
            return URL(fileURLWithPath: xdg).appendingPathComponent("browsers/config.yaml")
        }
        return home.appendingPathComponent(".config/browsers/config.yaml")
    }

    /// Loads the config. A missing default file yields an empty config; a
    /// missing explicit file, or any unreadable/malformed file, is an error.
    public static func load(
        explicitPath: String?,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> Config {
        let url: URL
        if let explicitPath {
            url = URL(fileURLWithPath: (explicitPath as NSString).expandingTildeInPath)
        } else {
            url = defaultPath(environment: environment, home: home)
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            if explicitPath != nil {
                throw BrowsersError.configUnreadable(path: url.path, reason: "file does not exist")
            }
            return .empty
        }

        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw BrowsersError.configUnreadable(path: url.path, reason: error.localizedDescription)
        }
        return try parse(text, path: url.path)
    }

    public static func parse(_ text: String, path: String = "<config>") throws -> Config {
        do {
            // An empty or comment-only document is valid and means "no settings".
            guard try Yams.compose(yaml: text) != nil else { return .empty }
            return try YAMLDecoder().decode(Config.self, from: text)
        } catch {
            throw BrowsersError.configInvalid(path: path, reason: describe(error))
        }
    }

    private static func describe(_ error: Error) -> String {
        if let decoding = error as? DecodingError {
            switch decoding {
            case let .typeMismatch(_, context), let .valueNotFound(_, context),
                 let .keyNotFound(_, context), let .dataCorrupted(context):
                let location = context.codingPath.map(\.stringValue).joined(separator: ".")
                return location.isEmpty
                    ? context.debugDescription
                    : "\(location): \(context.debugDescription)"
            @unknown default:
                break
            }
        }
        return String(describing: error)
    }
}
