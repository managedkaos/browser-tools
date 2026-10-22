import Foundation

/// Whether stdout is an interactive terminal (not a pipe or a file).
var stdoutIsTerminal: Bool { isatty(STDOUT_FILENO) != 0 }

/// The terminal's width in columns: the kernel's answer for stdout first, then
/// the `COLUMNS` environment variable. Nil when neither gives a usable value.
func terminalWidth() -> Int? {
    var size = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0, size.ws_col > 0 {
        return Int(size.ws_col)
    }
    if let columns = ProcessInfo.processInfo.environment["COLUMNS"],
        let width = Int(columns), width > 0
    {
        return width
    }
    return nil
}
