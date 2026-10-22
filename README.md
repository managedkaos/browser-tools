# Browser Tools

A suite of tools to work with web browsers on macOS, shipped as a single
Swift CLI named `browsers`.

Requires macOS 14 (Sonoma) or later.

## Install

With Homebrew (from the `managedkaos` tap):

```sh
brew install managedkaos/<tap>/browsers
```

From source (needs the Xcode Command Line Tools):

```sh
make install              # installs to ~/.local/bin
make install PREFIX=/usr/local
```

## Usage

### `browsers` / `browsers list`

Lists installed web browsers, meaning apps registered with macOS to open
`https` URLs, as name, bundle ID and path. Bundle IDs can be used in
`finicky.js`. Running `browsers` with no subcommand is the same as
`browsers list`.

```
$ browsers
Arc            company.thebrowser.Browser  /Applications/Arc.app
Brave Browser  com.brave.Browser           /Applications/Brave Browser.app
Safari         com.apple.Safari            /Applications/Safari.app
```

| Flag | Meaning |
|---|---|
| `-a`, `--all` | Show everything Launch Services reports, ignoring built-in and user filters (still sorted) |
| `--json` | Print JSON (`name`, `bundleId`, `path`) instead of a table |
| `--config <path>` | Read configuration from this file instead of the default |
| `--no-config` | Ignore the user configuration file |

By default the following are hidden: non-browser link handlers (Finicky,
Codex, cmux, iTerm2), updater copies (`/EdgeUpdater/`), Playwright test
builds (`/playwright/`), and duplicate bundle IDs (first one wins).

### `browsers list-profiles`

Lists profiles as folder, display name and signed-in account. Use the display
name as the profile in `finicky.js`. With no flags it shows Google Chrome.

```
$ browsers list-profiles
== Google Chrome
Default    Work      me@example.com
Profile 1  Personal  me@gmail.com
```

| Flag | Meaning |
|---|---|
| `--canary` | Show Google Chrome Canary |
| `--browser <name>` | Show another registered browser by name, or `all` for every registered browser |
| `--json` | Print JSON (`browser`, `browserName`, `folder`, `name`, `account`; missing values are `null`) |

`--canary` and `--browser` cannot be combined. Registered browsers today are
`chrome` and `canary`. With `--browser all`, browsers that have no profile
data on this machine are skipped. When you name a browser explicitly, missing
data is an error.

### Shell completions

```sh
browsers --generate-completion-script zsh    # or bash, fish
```

Homebrew installs completions automatically.

## Configuration

Optional YAML file at `~/.config/browsers/config.yaml`
(`$XDG_CONFIG_HOME/browsers/config.yaml` when `XDG_CONFIG_HOME` is an absolute
path). Entries are added to the built-in exclusions; they do not replace them.

```yaml
exclude:
  # Hide apps by bundle ID (exact match)
  bundleIds:
    - com.example.helper
  # Hide apps whose path contains any of these substrings
  pathContains:
    - /SomeUpdater/
```

A missing default file is fine. A missing file passed with `--config`, or any
malformed file, is an error. `--all` and `--no-config` skip the file.

## `finicky.js` example

```js
export default {
  defaultBrowser: "com.apple.Safari",          // bundle ID from `browsers`
  handlers: [
    {
      match: "*.example.com/*",
      browser: { name: "com.google.Chrome", profile: "Work" },  // display name from `browsers list-profiles`
    },
  ],
};
```

## Roadmap

Profile support for other browsers (Edge, Brave, Arc, Firefox, Safari) is
planned. Chromium-family browsers only need an entry in `ProfileRegistry`
(`Sources/BrowsersCore/Profiles.swift`); others implement `ProfileProvider`.

## Development

```sh
make help      # list targets
make build     # debug build
make test      # run the tests (Swift Testing)
make run ARGS="list-profiles --canary"
```

The version lives in one place: `Sources/BrowsersCore/Version.swift`.

## Releasing

Releases are built and published by GitHub Actions
(`.github/workflows/release.yml`) when a `v*` tag is pushed. CI
(`.github/workflows/ci.yml`) runs `make test` on every push.

1. Bump `browsersVersion` in `Sources/BrowsersCore/Version.swift` and commit.
2. Tag with the same version and push the tag:
   ```sh
   git tag vX.Y.Z && git push origin vX.Y.Z
   ```
   The workflow fails if the tag does not match `browsersVersion`. Otherwise it
   runs the tests, runs `make release`, and creates a GitHub release with
   generated notes plus `browsers-X.Y.Z-macos-universal.tar.gz` and its
   `.sha256` file. The sha256 is also shown in the job summary.
3. Update `Formula/browsers.rb`: set the `url` to the new release asset and
   `sha256` to the value from the release's `.sha256` file.
4. Copy `Formula/browsers.rb` into your tap repository's `Formula/` directory,
   then commit and push it there. Check it first with
   `brew style` and `brew audit --strict <tap>/browsers`.

To build the same tarball locally, run `make release`. It builds arm64 and
x86_64 separately, merges them with `lipo`, ad-hoc signs the result, verifies it
(both architectures present, only system libraries linked, signature valid,
`--version` matches, x86_64 slice runs under Rosetta when available), and
writes `dist/browsers-X.Y.Z-macos-universal.tar.gz` plus a `.sha256` file.

Homebrew downloads are not quarantined, so notarization is not required.
