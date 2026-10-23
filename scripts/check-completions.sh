#!/usr/bin/env bash
# Smoke-test shell completion support:
#   - the built-in --generate-completion-script works for bash, zsh and fish
#   - the generated bash/zsh scripts parse
#   - --browser values and --config file filters made it into the scripts
#   - `browsers --help` advertises the flag
#   - `make install` / `make uninstall` create and remove the completion files
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
    echo "check-completions: $*" >&2
    exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> Building"
swift build >/dev/null
bin="$(swift build --show-bin-path)/browsers"

echo "==> Generating scripts"
for shell in bash zsh fish; do
    "$bin" --generate-completion-script "$shell" > "$tmp/script.$shell"
    [[ -s "$tmp/script.$shell" ]] || fail "empty $shell completion script"
done

echo "==> Checking syntax"
bash -n "$tmp/script.bash" || fail "bash script does not parse"
if command -v zsh >/dev/null 2>&1; then
    zsh -n "$tmp/script.zsh" || fail "zsh script does not parse"
else
    echo "    zsh not installed; skipped"
fi
if command -v fish >/dev/null 2>&1; then
    fish --no-execute "$tmp/script.fish" || fail "fish script does not parse"
else
    echo "    fish not installed; skipped"
fi

echo "==> Checking argument values"
for shell in bash zsh fish; do
    for value in chrome canary all; do
        grep -q "$value" "$tmp/script.$shell" || fail "$shell script is missing --browser value '$value'"
    done
done
grep -q 'yaml' "$tmp/script.zsh" || fail "zsh script is missing the --config yaml filter"

echo "==> Checking --help"
"$bin" --help | grep -q -e '--generate-completion-script' \
    || fail "'browsers --help' does not mention --generate-completion-script"

echo "==> Checking install/uninstall round trip"
prefix="$tmp/prefix"
files=(
    "$prefix/bin/browsers"
    "$prefix/share/bash-completion/completions/browsers"
    "$prefix/share/zsh/site-functions/_browsers"
    "$prefix/share/fish/vendor_completions.d/browsers.fish"
)
make install PREFIX="$prefix" >/dev/null
for f in "${files[@]}"; do
    [[ -s "$f" ]] || fail "make install did not create $f"
done
make uninstall PREFIX="$prefix" >/dev/null
for f in "${files[@]}"; do
    [[ ! -e "$f" ]] || fail "make uninstall did not remove $f"
done

echo "All completion checks passed."
