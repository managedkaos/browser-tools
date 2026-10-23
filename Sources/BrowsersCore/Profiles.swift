import Foundation

/// One browser profile as recorded by the browser itself.
public struct Profile: Equatable, Sendable {
    public var folder: String
    public var name: String?
    public var account: String?

    public init(folder: String, name: String?, account: String?) {
        self.folder = folder
        self.name = name
        self.account = account
    }
}

/// A source of profiles for one browser. Add a new browser by registering
/// another provider; Chromium-family browsers only need data (see below).
public protocol ProfileProvider: Sendable {
    /// Short key used on the command line, e.g. `chrome`.
    var id: String { get }
    /// Human-readable name, e.g. `Google Chrome`.
    var displayName: String { get }
    /// Reads profiles, throwing `BrowsersError.profileDataNotFound` when the
    /// browser has no profile data on this machine.
    func loadProfiles() throws -> [Profile]
}

/// Reads profiles from a Chromium-style `Local State` file.
public struct ChromiumProfileProvider: ProfileProvider {
    public let id: String
    public let displayName: String
    /// Directory containing `Local State`.
    public let dataDirectory: URL

    public init(id: String, displayName: String, dataDirectory: URL) {
        self.id = id
        self.displayName = displayName
        self.dataDirectory = dataDirectory
    }

    private struct LocalState: Decodable {
        struct ProfileSection: Decodable {
            struct Info: Decodable {
                let name: String?
                let userName: String?
                enum CodingKeys: String, CodingKey {
                    case name
                    case userName = "user_name"
                }
            }
            let infoCache: [String: Info]?
            enum CodingKeys: String, CodingKey { case infoCache = "info_cache" }
        }
        let profile: ProfileSection?
    }

    public func loadProfiles() throws -> [Profile] {
        let url = dataDirectory.appendingPathComponent("Local State")
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw BrowsersError.profileDataNotFound(browser: displayName, path: url.path)
        }
        do {
            let data = try Data(contentsOf: url)
            let state = try JSONDecoder().decode(LocalState.self, from: data)
            let cache = state.profile?.infoCache ?? [:]
            return cache
                .map { folder, info in
                    Profile(
                        folder: folder,
                        name: info.name.flatMap { $0.isEmpty ? nil : $0 },
                        account: info.userName.flatMap { $0.isEmpty ? nil : $0 }
                    )
                }
                .sorted { $0.folder.compare($1.folder, options: .numeric) == .orderedAscending }
        } catch {
            throw BrowsersError.profileDataInvalid(
                browser: displayName, path: url.path, reason: error.localizedDescription
            )
        }
    }
}

/// Profiles for one browser, ready to print.
public struct BrowserProfiles: Equatable, Sendable {
    public var browserId: String
    public var browserName: String
    public var profiles: [Profile]
}

/// The set of known profile providers, in display order.
public struct ProfileRegistry: Sendable {
    public let providers: [any ProfileProvider]

    public init(providers: [any ProfileProvider]) {
        self.providers = providers
    }

    /// Chromium-family browsers are data-only: add an entry here.
    public static func standard(
        applicationSupport: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
    ) -> ProfileRegistry {
        let chromium: [(id: String, name: String, directory: String)] = [
            ("chrome", "Google Chrome", "Google/Chrome"),
            ("canary", "Google Chrome Canary", "Google/Chrome Canary"),
        ]
        return ProfileRegistry(providers: chromium.map {
            ChromiumProfileProvider(
                id: $0.id,
                displayName: $0.name,
                dataDirectory: applicationSupport.appendingPathComponent($0.directory)
            )
        })
    }

    public var ids: [String] { providers.map(\.id) }

    /// Values `--browser` accepts: every registered ID plus `all`. Used for
    /// shell completion, so it stays in sync with the registry.
    public var browserArgumentValues: [String] { ids + ["all"] }

    /// Which providers to query, and whether the user asked for them by name.
    public struct Selection: Sendable {
        public let providers: [any ProfileProvider]
        /// When true, a provider without data is an error rather than skipped.
        public let explicit: Bool
    }

    /// No flags selects Chrome, `--canary` selects Canary, and
    /// `--browser <id|all>` selects a registered provider or all of them.
    public func select(canary: Bool, browser: String?) throws -> Selection {
        if canary && browser != nil { throw BrowsersError.conflictingBrowserSelection }
        let requested = canary ? "canary" : (browser ?? "chrome")
        if requested.lowercased() == "all" {
            return Selection(providers: providers, explicit: false)
        }
        guard let provider = providers.first(where: { $0.id == requested.lowercased() }) else {
            throw BrowsersError.unknownBrowser(name: requested, valid: ids)
        }
        return Selection(providers: [provider], explicit: true)
    }

    public func collect(_ selection: Selection) throws -> [BrowserProfiles] {
        var results: [BrowserProfiles] = []
        for provider in selection.providers {
            do {
                let profiles = try provider.loadProfiles()
                results.append(BrowserProfiles(
                    browserId: provider.id, browserName: provider.displayName, profiles: profiles
                ))
            } catch BrowsersError.profileDataNotFound where !selection.explicit {
                continue
            }
        }
        return results
    }
}

// MARK: - Output

private struct ProfileRecord: Encodable {
    let browser: String
    let browserName: String
    let folder: String
    let name: String?
    let account: String?

    // Always emit name/account, using null when missing, so the shape is stable.
    enum CodingKeys: String, CodingKey { case browser, browserName, folder, name, account }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(browser, forKey: .browser)
        try container.encode(browserName, forKey: .browserName)
        try container.encode(folder, forKey: .folder)
        try container.encode(name, forKey: .name)
        try container.encode(account, forKey: .account)
    }
}

public let profilesTableHeader = ["FOLDER", "PROFILE NAME", "ACCOUNT"]

/// - Parameter header: Include the column labels and underline under each
///   browser banner. Browsers without profiles print only the banner.
public func formatProfilesTable(_ groups: [BrowserProfiles], header: Bool = false) -> String {
    groups.map { group in
        let rows = group.profiles.map { [$0.folder, $0.name ?? "-", $0.account ?? "-"] }
        let banner = "== \(group.browserName)"
        return rows.isEmpty
            ? banner + "\n"
            : banner + "\n" + formatTable(rows, header: header ? profilesTableHeader : nil) + "\n"
    }.joined(separator: "\n")
}

/// Markdown: a `## Browser` heading per browser, then its table. Browsers
/// without profiles get only the heading.
public func formatProfilesMarkdown(_ groups: [BrowserProfiles]) -> String {
    groups.map { group in
        let heading = "## \(escapeMarkdownCell(group.browserName))"
        let rows = group.profiles.map { [$0.folder, $0.name ?? "-", $0.account ?? "-"] }
        return rows.isEmpty
            ? heading + "\n"
            : heading + "\n\n" + formatMarkdownTable(rows, header: profilesTableHeader) + "\n"
    }.joined(separator: "\n")
}

public func formatProfilesJSON(_ groups: [BrowserProfiles]) throws -> String {
    let records = groups.flatMap { group in
        group.profiles.map {
            ProfileRecord(
                browser: group.browserId, browserName: group.browserName,
                folder: $0.folder, name: $0.name, account: $0.account
            )
        }
    }
    return try encodeJSON(records)
}
