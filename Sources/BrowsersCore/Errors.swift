import Foundation

/// User-facing errors. ArgumentParser prints `localizedDescription` to stderr
/// and exits non-zero.
public enum BrowsersError: Error, LocalizedError, Equatable {
    case configUnreadable(path: String, reason: String)
    case configInvalid(path: String, reason: String)
    case unknownBrowser(name: String, valid: [String])
    case conflictingBrowserSelection
    case profileDataNotFound(browser: String, path: String)
    case profileDataInvalid(browser: String, path: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case let .configUnreadable(path, reason):
            return "cannot read config file \(path): \(reason)"
        case let .configInvalid(path, reason):
            return "invalid config file \(path): \(reason)"
        case let .unknownBrowser(name, valid):
            let names = (valid + ["all"]).joined(separator: ", ")
            return "unknown browser '\(name)'. Valid values: \(names)"
        case .conflictingBrowserSelection:
            return "--canary and --browser cannot be used together"
        case let .profileDataNotFound(browser, path):
            return "no profile data found for \(browser) (expected \(path))"
        case let .profileDataInvalid(browser, path, reason):
            return "cannot parse profile data for \(browser) at \(path): \(reason)"
        }
    }
}
