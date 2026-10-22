import Foundation

/// Renders rows as left-aligned columns separated by two spaces, like
/// `column -t`. The last column is not padded.
public func formatTable(_ rows: [[String]]) -> String {
    guard let columnCount = rows.map(\.count).max() else { return "" }
    var widths = [Int](repeating: 0, count: columnCount)
    for row in rows {
        for (index, cell) in row.enumerated() {
            widths[index] = max(widths[index], cell.count)
        }
    }
    return rows.map { row in
        row.enumerated().map { index, cell in
            index == row.count - 1
                ? cell
                : cell.padding(toLength: widths[index], withPad: " ", startingAt: 0)
        }.joined(separator: "  ")
    }.joined(separator: "\n")
}

public func formatBrowsersTable(_ browsers: [Browser]) -> String {
    formatTable(browsers.map { [$0.name, $0.bundleId, $0.path] })
}

/// Pretty-printed JSON with sorted keys and unescaped slashes.
public func encodeJSON(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
}
