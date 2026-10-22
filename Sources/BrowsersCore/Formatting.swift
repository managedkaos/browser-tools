import Foundation

/// The narrowest a shrinkable column is ever squeezed to. When the terminal is
/// too narrow for even this, the floor wins and the line wraps instead.
public let minimumShrinkWidth = 20

private let columnGap = "  "

/// Shortens `string` to at most `width` characters by replacing the middle
/// with a single `…`, keeping the start and the tail. Strings that already fit
/// are returned unchanged. The tail gets about two thirds of the budget because
/// it identifies the value (for a path, the `Something.app` name).
public func truncateMiddle(_ string: String, to width: Int) -> String {
    guard string.count > width else { return string }
    guard width > 0 else { return "" }
    guard width > 1 else { return "…" }
    let keep = width - 1
    let head = keep / 3
    let tail = keep - head
    return String(string.prefix(head)) + "…" + String(string.suffix(tail))
}

/// Renders rows as left-aligned columns separated by two spaces, like
/// `column -t`. The last column is not padded.
///
/// - Parameters:
///   - header: Optional column labels. When given (and there are rows) the
///     output starts with the labels followed by a row of dashes.
///   - maxWidth: Total line width to fit, used together with `shrinkColumn`.
///   - shrinkColumn: The one column allowed to shrink (middle-truncated with
///     `…`) so the table fits `maxWidth`. Other columns are never truncated.
///     The column is never narrower than `minimumShrinkWidth`, even if that
///     means the line exceeds `maxWidth`.
public func formatTable(
    _ rows: [[String]],
    header: [String]? = nil,
    maxWidth: Int? = nil,
    shrinkColumn: Int? = nil
) -> String {
    guard let rowColumnCount = rows.map(\.count).max() else { return "" }
    let columnCount = max(rowColumnCount, header?.count ?? 0)

    var rows = rows
    var header = header
    var widths = [Int](repeating: 0, count: columnCount)
    for row in rows + (header.map { [$0] } ?? []) {
        for (index, cell) in row.enumerated() {
            widths[index] = max(widths[index], cell.count)
        }
    }

    if let maxWidth, let column = shrinkColumn, column < columnCount {
        let others = widths.enumerated().filter { $0.offset != column }.map(\.element).reduce(0, +)
        let gaps = columnGap.count * (columnCount - 1)
        let budget = max(minimumShrinkWidth, maxWidth - others - gaps)
        if widths[column] > budget {
            widths[column] = budget
            rows = rows.map { truncate($0, column: column, to: budget) }
            header = header.map { truncate($0, column: column, to: budget) }
        }
    }

    func render(_ row: [String]) -> String {
        row.enumerated().map { index, cell in
            index == row.count - 1
                ? cell
                : cell.padding(toLength: widths[index], withPad: " ", startingAt: 0)
        }.joined(separator: columnGap)
    }

    var lines: [String] = []
    if let header {
        lines.append(render(header))
        lines.append(render(widths.map { String(repeating: "-", count: $0) }))
    }
    lines.append(contentsOf: rows.map(render))
    return lines.joined(separator: "\n")
}

private func truncate(_ row: [String], column: Int, to width: Int) -> [String] {
    guard column < row.count else { return row }
    var row = row
    row[column] = truncateMiddle(row[column], to: width)
    return row
}

public let browsersTableHeader = ["NAME", "BUNDLE ID", "PATH"]

// MARK: - Markdown

/// Escapes characters that would be read as Markdown or would break a table
/// cell (`|`), so the text renders exactly as written.
public func escapeMarkdownCell(_ text: String) -> String {
    let special: Set<Character> = ["\\", "|", "`", "*", "_", "<", ">", "[", "]", "~"]
    var escaped = ""
    for character in text {
        if special.contains(character) { escaped.append("\\") }
        escaped.append(character)
    }
    return escaped
}

/// Renders a GitHub-flavoured Markdown table with the source columns padded so
/// it also reads well as plain text. The header is always present, even with no
/// rows, because a Markdown table is not valid without one. Cells are escaped;
/// callers pass raw values. Nothing is ever truncated.
public func formatMarkdownTable(_ rows: [[String]], header: [String]) -> String {
    let columnCount = header.count
    let cells = ([header] + rows).map { row in
        (0..<columnCount).map { index in
            index < row.count ? escapeMarkdownCell(row[index]) : ""
        }
    }
    // A delimiter cell needs at least three dashes to be recognised.
    var widths = [Int](repeating: 3, count: columnCount)
    for row in cells {
        for (index, cell) in row.enumerated() {
            widths[index] = max(widths[index], cell.count)
        }
    }

    func render(_ row: [String]) -> String {
        let padded = row.enumerated().map {
            $0.element.padding(toLength: widths[$0.offset], withPad: " ", startingAt: 0)
        }
        return "| " + padded.joined(separator: " | ") + " |"
    }

    let underline = widths.map { String(repeating: "-", count: $0) }
    return ([cells[0], underline] + cells.dropFirst()).map(render).joined(separator: "\n")
}

public func formatBrowsersMarkdown(_ browsers: [Browser], idOnly: Bool = false) -> String {
    formatMarkdownTable(
        idOnly ? browsers.map { [$0.bundleId] } : browsers.map { [$0.name, $0.bundleId, $0.path] },
        header: idOnly ? browsersIdHeader : browsersTableHeader
    )
}

public let browsersIdHeader = ["BUNDLE ID"]

/// JSON for `list`: full records, or with `idOnly` just `{"bundleId": ...}`
/// per browser (same key as the full output, so consumers can use one query).
public func formatBrowsersJSON(_ browsers: [Browser], idOnly: Bool = false) throws -> String {
    struct IDRecord: Encodable { let bundleId: String }
    return idOnly
        ? try encodeJSON(browsers.map { IDRecord(bundleId: $0.bundleId) })
        : try encodeJSON(browsers)
}

/// - Parameters:
///   - header: Include the column labels and underline.
///   - maxWidth: When set, `PATH` (the last column) is shortened to fit.
///   - idOnly: Only the bundle ID column. Bundle IDs are never shortened, so
///     `maxWidth` is ignored.
public func formatBrowsersTable(
    _ browsers: [Browser], header: Bool = false, maxWidth: Int? = nil, idOnly: Bool = false
) -> String {
    if idOnly {
        return formatTable(
            browsers.map { [$0.bundleId] }, header: header ? browsersIdHeader : nil
        )
    }
    return formatTable(
        browsers.map { [$0.name, $0.bundleId, $0.path] },
        header: header ? browsersTableHeader : nil,
        maxWidth: maxWidth,
        shrinkColumn: 2
    )
}

/// The line width to fit, or nil for "do not truncate". Only a terminal gets
/// fitted, and only when it reports a usable width and the user did not opt out.
public func fittedWidth(isTerminal: Bool, terminalWidth: Int?, noTruncate: Bool) -> Int? {
    guard isTerminal, !noTruncate, let terminalWidth, terminalWidth > 0 else { return nil }
    return terminalWidth
}

/// Pretty-printed JSON with sorted keys and unescaped slashes.
public func encodeJSON(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
}
