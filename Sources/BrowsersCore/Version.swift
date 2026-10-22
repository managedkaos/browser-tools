#if !os(macOS)
#error("browsers supports macOS only")
#endif

/// Single source of truth for the release version.
/// `scripts/release.sh` reads this line, so keep the format intact.
public let browsersVersion = "2026.10.22"
