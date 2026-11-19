import Foundation

public struct BrowserExtension: Encodable, Equatable, Sendable {
    public let browser: String
    public let browserName: String
    public let folder: String
    public let id: String
    public let name: String
    public let version: String
}

public struct BrowserExtensions: Equatable, Sendable {
    public let browserName: String
    public let extensions: [BrowserExtension]
}

public func collectExtensions(
    canary: Bool, browser: String?,
    applicationSupport: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support")
) throws -> [BrowserExtensions] {
    let chromium = ProfileRegistry.standard(applicationSupport: applicationSupport).providers
        .compactMap { $0 as? ChromiumProfileProvider } + [
            ("edge", "Microsoft Edge", "Microsoft Edge"),
            ("brave", "Brave", "BraveSoftware/Brave-Browser"),
            ("chromium", "Chromium", "Chromium"),
            ("vivaldi", "Vivaldi", "Vivaldi"),
        ].map { id, name, path in
            ChromiumProfileProvider(
                id: id, displayName: name,
                dataDirectory: applicationSupport.appendingPathComponent(path)
            )
        }
    if canary && browser != nil { throw BrowsersError.conflictingBrowserSelection }
    let requested = canary ? "canary" : (browser ?? "chrome")
    let selected = requested.lowercased()
    let all = selected == "all"
    let ids = chromium.map(\.id) + ["firefox"]
    guard all || ids.contains(selected) else {
        throw BrowsersError.unknownBrowser(name: requested, valid: ids)
    }

    var groups: [BrowserExtensions] = []
    for provider in chromium where all || provider.id == selected {
        do {
            let profiles = try provider.loadProfiles()
            let extensions = try profiles.flatMap { profile in
                try chromiumExtensions(provider: provider, folder: profile.folder)
            }
            groups.append(BrowserExtensions(browserName: provider.displayName, extensions: extensions))
        } catch BrowsersError.profileDataNotFound where all {
            continue
        }
    }
    if all || selected == "firefox" {
        do {
            let directory = applicationSupport.appendingPathComponent("Firefox")
            groups.append(BrowserExtensions(
                browserName: "Firefox", extensions: try firefoxExtensions(in: directory)
            ))
        } catch BrowsersError.profileDataNotFound where all {
            return groups
        }
    }
    return groups
}

private struct ExtensionManifest: Decodable {
    let name: String?
    let version: String?
    let default_locale: String?
    let theme: IgnoredValue?
    let app: IgnoredValue?

    struct IgnoredValue: Decodable {
        init(from decoder: any Decoder) throws {}
    }
}

private struct ChromiumPreferences: Decodable {
    struct Extensions: Decodable {
        struct Settings: Decodable {
            let manifest: ExtensionManifest?
            let path: String?
            let location: Int?
        }
        let settings: [String: Settings]?
    }
    let extensions: Extensions?
}

private func readExtensionData<Value: Decodable>(
    _ type: Value.Type, at url: URL, browser: String
) throws -> Value? {
    do {
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    } catch CocoaError.fileReadNoSuchFile {
        return nil
    } catch {
        throw BrowsersError.profileDataInvalid(
            browser: browser, path: url.path, reason: error.localizedDescription
        )
    }
}

private func chromiumExtensions(
    provider: ChromiumProfileProvider, folder: String
) throws -> [BrowserExtension] {
    let profile = provider.dataDirectory.appendingPathComponent(folder)
    var settings: [String: ChromiumPreferences.Extensions.Settings] = [:]
    for file in ["Preferences", "Secure Preferences"] {
        let preferences = try readExtensionData(
            ChromiumPreferences.self, at: profile.appendingPathComponent(file),
            browser: provider.displayName
        )
        settings.merge(preferences?.extensions?.settings ?? [:]) { _, secure in secure }
    }
    // Chromium manifest locations 5 and 10 are browser components.
    return settings.keys.sorted().compactMap { id in
        guard let entry = settings[id], let path = entry.path, !path.isEmpty,
              entry.location != 5, entry.location != 10 else { return nil }
        let directory = path.hasPrefix("/")
            ? URL(fileURLWithPath: path)
            : profile.appendingPathComponent("Extensions").appendingPathComponent(path)
        let manifest = entry.manifest ?? (try? JSONDecoder().decode(
            ExtensionManifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        ))
        guard manifest?.theme == nil, manifest?.app == nil else { return nil }
        return BrowserExtension(
            browser: provider.id, browserName: provider.displayName, folder: folder,
            id: id, name: chromiumName(manifest, in: directory) ?? id,
            version: manifest?.version ?? ""
        )
    }
}

private func chromiumName(_ manifest: ExtensionManifest?, in directory: URL) -> String? {
    struct Message: Decodable { let message: String? }

    guard let name = manifest?.name, !name.isEmpty else { return nil }
    guard name.hasPrefix("__MSG_"), name.hasSuffix("__"), name.count > 8 else { return name }
    let key = name.dropFirst(6).dropLast(2)
    let messagesFile = directory.appendingPathComponent("_locales")
        .appendingPathComponent(manifest?.default_locale ?? "en")
        .appendingPathComponent("messages.json")
    let messages = try? JSONDecoder().decode(
        [String: Message].self, from: Data(contentsOf: messagesFile)
    )
    return messages?.first { $0.key.lowercased() == key.lowercased() }?.value.message
}

private struct FirefoxExtensionDatabase: Decodable {
    struct Addon: Decodable {
        struct Locale: Decodable { let name: String? }
        let id: String
        let type: String
        let version: String
        let visible: Bool?
        let hidden: Bool?
        let defaultLocale: Locale?
    }
    let addons: [Addon]
}

private func firefoxExtensions(in directory: URL) throws -> [BrowserExtension] {
    let ini = directory.appendingPathComponent("profiles.ini")
    let contents: String
    do {
        contents = try String(contentsOf: ini, encoding: .utf8)
    } catch CocoaError.fileReadNoSuchFile {
        throw BrowsersError.profileDataNotFound(browser: "Firefox", path: ini.path)
    }
    var profiles: [[String: String]] = []
    var inProfile = false
    for line in contents.split(whereSeparator: \.isNewline) {
        if line.hasPrefix("[") {
            inProfile = line.hasPrefix("[Profile")
            if inProfile { profiles.append([:]) }
        } else if inProfile, let equals = line.firstIndex(of: "=") {
            profiles[profiles.count - 1][String(line[..<equals])] = String(line[line.index(after: equals)...])
        }
    }

    return try profiles.compactMap { profile -> URL? in
        guard let path = profile["Path"], !path.isEmpty else { return nil }
        return profile["IsRelative"] == "0"
            ? URL(fileURLWithPath: path)
            : directory.appendingPathComponent(path)
    }.sorted { $0.path < $1.path }.flatMap { profile in
        let database = try readExtensionData(
            FirefoxExtensionDatabase.self, at: profile.appendingPathComponent("extensions.json"),
            browser: "Firefox"
        )
        return (database?.addons ?? [])
            .filter { $0.type == "extension" && $0.visible != false && $0.hidden != true }
            .sorted { $0.id < $1.id }
            .map {
                BrowserExtension(
                    browser: "firefox", browserName: "Firefox", folder: profile.lastPathComponent,
                    id: $0.id, name: $0.defaultLocale?.name ?? $0.id, version: $0.version
                )
            }
    }
}

private let extensionsHeader = ["FOLDER", "EXTENSION NAME", "VERSION", "EXTENSION ID"]

private func extensionRows(_ group: BrowserExtensions) -> [[String]] {
    group.extensions.map { item in
        [item.folder, item.name, item.version.isEmpty ? "-" : item.version, item.id].map {
            $0.components(separatedBy: .controlCharacters).joined(separator: " ")
        }
    }
}

public func formatExtensionsTable(_ groups: [BrowserExtensions], header: Bool = false) -> String {
    groups.map { group in
        let banner = "== \(group.browserName)"
        let rows = extensionRows(group)
        return rows.isEmpty
            ? banner + "\n"
            : banner + "\n" + formatTable(rows, header: header ? extensionsHeader : nil) + "\n"
    }.joined(separator: "\n")
}

public func formatExtensionsMarkdown(_ groups: [BrowserExtensions]) -> String {
    groups.map { group in
        let heading = "## \(escapeMarkdownCell(group.browserName))"
        let rows = extensionRows(group)
        return rows.isEmpty
            ? heading + "\n"
            : heading + "\n\n" + formatMarkdownTable(rows, header: extensionsHeader) + "\n"
    }.joined(separator: "\n")
}

public func formatExtensionsJSON(_ groups: [BrowserExtensions]) throws -> String {
    try encodeJSON(groups.flatMap(\.extensions))
}
