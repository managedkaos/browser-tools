#!/usr/bin/env bash
# Build a universal (arm64 + x86_64) release binary and package it for a
# GitHub Release / Homebrew formula. Output lands in dist/:
#   browsers-macos-universal.tar.gz   (asset name has no version on purpose)
#   checksums.txt                     (sha256sum format, read by the tap workflow)
#
# The asset name must not embed the version: the tap's update script keeps the
# asset filename and only rewrites the release tag in the formula URL.
#
# Each architecture is built separately and merged with lipo, which works with
# just the Command Line Tools (a multi-arch `swift build` needs full Xcode).
set -euo pipefail

cd "$(dirname "$0")/.."

BINARY=browsers
MIN_MACOS=14.0
ARCHES=(arm64 x86_64)

VERSION="$(sed -n 's/^public let browsersVersion = "\(.*\)"$/\1/p' Sources/BrowsersCore/Version.swift)"
if [[ -z "$VERSION" ]]; then
    echo "release: could not read version from Sources/BrowsersCore/Version.swift" >&2
    exit 1
fi

DIST=dist
NAME="${BINARY}-macos-universal"
STAGE="${DIST}/${NAME}"
TARBALL="${DIST}/${NAME}.tar.gz"

rm -rf "$DIST"
mkdir -p "$STAGE"

slices=()
for arch in "${ARCHES[@]}"; do
    echo "==> Building ${arch}"
    swift build -c release --triple "${arch}-apple-macosx${MIN_MACOS}"
    bin_dir="$(swift build -c release --triple "${arch}-apple-macosx${MIN_MACOS}" --show-bin-path)"
    slices+=("${bin_dir}/${BINARY}")
done

echo "==> Merging with lipo"
lipo -create "${slices[@]}" -output "${STAGE}/${BINARY}"

# lipo invalidates the linker's ad-hoc signature and Apple Silicon requires one.
echo "==> Ad-hoc signing"
codesign --force --sign - "${STAGE}/${BINARY}"

echo "==> Verifying"
archs="$(lipo -archs "${STAGE}/${BINARY}")"
for arch in "${ARCHES[@]}"; do
    if [[ " ${archs} " != *" ${arch} "* ]]; then
        echo "release: missing architecture ${arch} (found: ${archs})" >&2
        exit 1
    fi
done

codesign --verify --strict "${STAGE}/${BINARY}"

# Only system libraries may be linked: anything else would not be portable.
bad="$(otool -L "${STAGE}/${BINARY}" | grep -E '^[[:space:]]' | awk '{print $1}' \
    | grep -v -E '^(/usr/lib/|/System/Library/)' || true)"
if [[ -n "$bad" ]]; then
    echo "release: binary links non-system libraries:" >&2
    echo "$bad" >&2
    exit 1
fi

reported="$("${STAGE}/${BINARY}" --version)"
if [[ "$reported" != "$VERSION" ]]; then
    echo "release: binary reports '${reported}', expected '${VERSION}'" >&2
    exit 1
fi

# Run the x86_64 slice too when Rosetta is available.
if arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    x86_reported="$(arch -x86_64 "${STAGE}/${BINARY}" --version)"
    if [[ "$x86_reported" != "$VERSION" ]]; then
        echo "release: x86_64 slice reports '${x86_reported}', expected '${VERSION}'" >&2
        exit 1
    fi
    echo "    x86_64 slice ran under Rosetta"
else
    echo "    Rosetta not available; x86_64 slice not executed"
fi

cp LICENSE README.md "$STAGE"/
tar -C "$DIST" -czf "$TARBALL" "$NAME"
rm -rf "$STAGE"

# sha256sum format ("<hash>  <filename>"), as expected by the tap workflow.
(cd "$DIST" && shasum -a 256 "$(basename "$TARBALL")" > checksums.txt)
SHA="$(awk '{print $1}' "${DIST}/checksums.txt")"

echo
echo "Version: ${VERSION}"
echo "Archs:   ${archs}"
echo "Tarball: ${TARBALL}"
echo "SHA256:  ${SHA}"
