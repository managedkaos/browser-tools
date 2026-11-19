import Foundation
import Testing

@testable import BrowsersCore

@Test func listsInstalledExtensionsAcrossBrowserProfiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("browsers-extensions-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }

    let files = [
        "Google/Chrome/Local State": """
            {"profile":{"info_cache":{"Default":{},"Profile 1":{}}}}
            """,
        "Google/Chrome/Default/Preferences": """
            {"extensions":{"settings":{"sample":{
                "path":"sample/1", "manifest":{"name":"Old name","version":"1"}
            }}}}
            """,
        "Google/Chrome/Default/Secure Preferences": """
            {"extensions":{"settings":{
                "sample":{"path":"sample/2","disable_reasons":[1]},
                "component":{"path":"component/1","location":5}
            }}}
            """,
        "Google/Chrome/Default/Extensions/sample/2/manifest.json": """
            {"name":"__MSG_extensionName__","version":"2","default_locale":"en"}
            """,
        "Google/Chrome/Default/Extensions/sample/2/_locales/en/messages.json": """
            {"extensionname":{"message":"Example | Tool"}}
            """,
        "Firefox/profiles.ini": """
            [Profile0]
            Name=Work
            IsRelative=1
            Path=Profiles/work
            """,
        "Firefox/Profiles/work/extensions.json": """
            {"addons":[
                {"id":"sample@example.org","type":"extension","version":"3",
                 "active":false,"defaultLocale":{"name":"Firefox Tool"}},
                {"id":"theme@example.org","type":"theme","version":"1"}
            ]}
            """,
    ]
    for (path, contents) in files {
        let file = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try contents.write(to: file, atomically: true, encoding: .utf8)
    }

    let groups = try collectExtensions(canary: false, browser: "all", applicationSupport: root)
    let records = groups.flatMap(\.extensions)
    #expect(groups.map(\.browserName) == ["Google Chrome", "Firefox"])
    #expect(records.map(\.folder) == ["Default", "work"])
    #expect(records.map(\.name) == ["Example | Tool", "Firefox Tool"])
    #expect(records.map(\.version) == ["2", "3"])
    #expect(!formatExtensionsTable(groups).contains("EXTENSION NAME"))
    #expect(formatExtensionsTable(groups, header: true).contains("EXTENSION NAME"))
    #expect(formatExtensionsMarkdown(groups).contains("Example \\| Tool"))
    let json = try formatExtensionsJSON(groups)
    let decoded = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: String]]
    #expect(decoded?.compactMap { $0["id"] } == ["sample", "sample@example.org"])
}
