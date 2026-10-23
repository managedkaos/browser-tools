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
make install              # installs to ~/.local/bin, plus shell completions
make install PREFIX=/usr/local
```

Tab completion for bash, zsh and fish needs a one-time shell setup; see
[Shell completions](#shell-completions).

## Usage

### `browsers` / `browsers list`

Lists installed web browsers, meaning apps registered with macOS to open
`https` URLs, as name, bundle ID and path. Bundle IDs can be used in
`finicky.js`. Running `browsers` with no subcommand is the same as
`browsers list`.

```
$ browsers
NAME           BUNDLE ID                   PATH
-------------  --------------------------  ------------------------
Arc            company.thebrowser.Browser  /Applications/Arc.app
Brave Browser  com.brave.Browser           /Applications/Brave Browser.app
Safari         com.apple.Safari            /Applications/Safari.app
```

On a terminal the table has a header row, and a `PATH` too long for the window
is shortened in the middle with `…` (the start and the `.app` name are kept;
`NAME` and `BUNDLE ID` are never shortened). When output is piped or redirected
there is no header and nothing is shortened, so scripts see plain rows.

| Flag | Meaning |
|---|---|
| `-a`, `--all` | Show everything Launch Services reports, ignoring built-in and user filters (still sorted) |
| `--json` | Print JSON (`name`, `bundleId`, `path`) instead of a table. Never shortened |
| `--markdown` | Print a Markdown table (always with a header row, never shortened). Cannot be combined with `--json` |
| `--id`, `--bundle-id` | Print only the bundle ID column, in any output mode (see below) |
| `--no-truncate` | On a terminal, show full paths instead of shortening them to fit |
| `--config <path>` | Read configuration from this file instead of the default |
| `--no-config` | Ignore the user configuration file |

By default the following are hidden: non-browser link handlers (Finicky,
Codex, cmux, iTerm2), updater copies (`/EdgeUpdater/`), Playwright test
builds (`/playwright/`), and duplicate bundle IDs (first one wins).

`--id` (alias `--bundle-id`) keeps only the bundle ID column and applies to
every output mode, so scripts need no `awk` or `jq`:

| Command | Output |
|---|---|
| `browsers --id \| …` | One bare bundle ID per line, no header (a terminal gets a `BUNDLE ID` header) |
| `browsers --id --markdown` | A one-column `BUNDLE ID` table |
| `browsers --id --json` | `[{"bundleId": "…"}, …]`, the same key as the full JSON |

Bundle IDs are never shortened, and `--id` works with `--all` and the
configuration flags.

### `browsers list-profiles`

Lists profiles as folder, display name and signed-in account. Use the
`PROFILE NAME` column (the display name) as the profile in `finicky.js`. With
no flags it shows Google Chrome.

```
$ browsers list-profiles
== Google Chrome
FOLDER     PROFILE NAME  ACCOUNT
---------  ------------  --------------
Default    Work          me@example.com
Profile 1  Personal      me@gmail.com
```

As with `browsers list`, the header row appears only on a terminal; piped
output has just the rows.

| Flag | Meaning |
|---|---|
| `--canary` | Show Google Chrome Canary |
| `--browser <name>` | Show another registered browser by name, or `all` for every registered browser |
| `--json` | Print JSON (`browser`, `browserName`, `folder`, `name`, `account`; missing values are `null`) |
| `--markdown` | Print Markdown instead of a table: a `## Browser` heading and a table per browser. Cannot be combined with `--json` |

`--canary` and `--browser` cannot be combined. Registered browsers today are
`chrome` and `canary`. With `--browser all`, browsers that have no profile
data on this machine are skipped. When you name a browser explicitly, missing
data is an error.

### Shell completions

`browsers` can complete subcommands, flags and some values (`--browser`
completes `chrome`, `canary` and `all`; `--config` completes YAML files) in
bash, zsh and fish. The completion scripts come from the CLI itself:

```sh
browsers --generate-completion-script bash   # or zsh, fish
```

The shell is detected from `$SHELL` when you leave it out. `browsers --help`
also mentions this flag. Pick the section below that matches how you installed
`browsers`, then open a new terminal window.

#### Homebrew

`brew install` puts the completion files in place for all three shells, but
your shell still has to look in Homebrew's directories.

- **zsh**: add this to `~/.zshrc`, *before* `compinit`:

  ```sh
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
  autoload -Uz compinit && compinit
  ```

- **bash**: install `bash-completion@2` (`brew install bash-completion@2`) and
  follow the instructions it prints, which add a `source` line for
  `bash_completion.sh` to `~/.bashrc` or `~/.bash_profile`.
- **fish**: nothing to do if fish itself came from Homebrew, because it already
  searches Homebrew's `share/fish/vendor_completions.d`. Otherwise use the
  manual option below.

#### `make install`

`make install` writes the completion files next to the binary, under the same
`PREFIX` (default `~/.local`), and `make uninstall` removes them:

| Shell | File |
|---|---|
| bash | `$PREFIX/share/bash-completion/completions/browsers` |
| zsh | `$PREFIX/share/zsh/site-functions/_browsers` |
| fish | `$PREFIX/share/fish/vendor_completions.d/browsers.fish` |

Your shell may not look there by default:

- **zsh**: add this to `~/.zshrc`, *before* `compinit` (use your `PREFIX` if it
  is not `~/.local`; `/usr/local/share/zsh/site-functions` is already searched):

  ```sh
  fpath=(~/.local/share/zsh/site-functions $fpath)
  autoload -Uz compinit && compinit
  ```

- **bash**: needs [bash-completion](https://github.com/scop/bash-completion)
  v2 (`brew install bash-completion@2`, then source it from your rc file). It
  loads `~/.local/share/bash-completion/completions/browsers` on demand. For a
  different `PREFIX`, use the manual option below.
- **fish**: nothing to do for the default `PREFIX`, because fish searches
  `~/.local/share/fish/vendor_completions.d`. For a different `PREFIX`, use
  the manual option below.

#### Manual (no files installed by make or Homebrew)

- **bash**: add to `~/.bashrc` (or `~/.bash_profile`). `eval` is used because
  `source <(...)` does not work in the macOS system bash 3.2:

  ```sh
  eval "$(browsers --generate-completion-script bash)"
  ```

- **zsh**: add to `~/.zshrc`, *after* `compinit`:

  ```sh
  autoload -Uz compinit && compinit
  source <(browsers --generate-completion-script zsh)
  ```

- **fish**:

  ```sh
  mkdir -p ~/.config/fish/completions
  browsers --generate-completion-script fish > ~/.config/fish/completions/browsers.fish
  ```

#### Troubleshooting

- Nothing completes in zsh: run `rm -f ~/.zcompdump*` and start a new shell so
  `compinit` rebuilds its cache. Check that the directory holding `_browsers`
  appears in `echo $fpath` (one item per line: `print -l $fpath`).
- Completions go stale after an upgrade that adds flags or subcommands:
  regenerate the file (`make install` again, or re-run the redirect above).
  The `eval` and `source <(...)` lines always generate fresh scripts.
- The completions were checked with bash 3.2 (the macOS system bash), bash 5
  (Homebrew), zsh 5.9 and fish, by calling the completion functions directly
  (bash, fish) and with real TAB presses (zsh).

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
make check-completions   # smoke-test shell completions and install/uninstall
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

The workflow then:

1. Fails if the tag does not match `browsersVersion`.
2. Runs the tests and `make release`.
3. Creates a GitHub release with generated notes, `browsers-macos-universal.tar.gz`
   and `checksums.txt`.
4. Calls the tap's reusable workflow
   ([`managedkaos/homebrew-tap`](https://github.com/managedkaos/homebrew-tap),
   `update-formula.yml`), which opens a pull request that updates
   `Formula/browsers.rb` with the new tag and checksum. Merge that PR to
   publish the new version to Homebrew.

The asset name intentionally has no version in it: the tap's update script
keeps the filename and only rewrites the tag in the formula URL.

### One-time setup

- Add the repository secrets `TAP_APP_ID` and `TAP_APP_PRIVATE_KEY` (the
  GitHub App that can open pull requests on the tap) to this repo.
- Add `Formula/browsers.rb` from this repo to the tap's `Formula/` directory
  once. Its placeholder sha256 is replaced by the first automated update.

To build the same tarball locally, run `make release`. It builds arm64 and
x86_64 separately, merges them with `lipo`, ad-hoc signs the result, verifies it
(both architectures present, only system libraries linked, signature valid,
`--version` matches, x86_64 slice runs under Rosetta when available), and
writes `dist/browsers-macos-universal.tar.gz` plus `dist/checksums.txt`.

Homebrew downloads are not quarantined, so notarization is not required.
