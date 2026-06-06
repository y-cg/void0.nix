#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix curl jq
# shellcheck shell=bash
#
# Bump viteplus to the latest vite-plus release on npm and refresh all
# @voidzero-dev/vite-plus-cli-* tarball hashes in viteplus/default.nix.
#
# Usage (from repo root):
#   nix develop
#   nix-update --flake viteplus
#
# Or run directly:
#   ./viteplus/update-viteplus.sh
#   VERSION=0.1.25 ./viteplus/update-viteplus.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX_FILE="$SCRIPT_DIR/default.nix"

version="${VERSION:-$(curl -fsSL https://registry.npmjs.org/vite-plus/latest | jq -r .version)}"
if [[ -z "$version" || "$version" == "null" ]]; then
  echo "error: could not resolve vite-plus version from npm registry" >&2
  exit 1
fi

echo "Updating viteplus to $version"

platforms=(
  linux-x64-gnu
  linux-arm64-gnu
  linux-x64-musl
  linux-arm64-musl
  darwin-x64
  darwin-arm64
)

hash_lines=""
for suffix in "${platforms[@]}"; do
  url="https://registry.npmjs.org/@voidzero-dev/vite-plus-cli-${suffix}/-/vite-plus-cli-${suffix}-${version}.tgz"
  echo "  prefetching $suffix"
  sha256=$(curl -fsSL "$url" | sha256sum | awk '{print $1}')
  sri=$(nix hash convert --to sri --hash-algo sha256 "$sha256")
  hash_lines+="        \"$suffix\" = \"$sri\";"$'\n'
done

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

awk -v version="$version" -v hashes="$hash_lines" '
  /^  version = / {
    print "  version = \"" version "\";"
    next
  }
  /# update-script: platform-hashes-begin/ {
    print
    printf "%s", hashes
    skip = 1
    next
  }
  skip && /# update-script: platform-hashes-end/ {
    print
    skip = 0
    next
  }
  !skip { print }
' "$NIX_FILE" >"$tmp"

mv "$tmp" "$NIX_FILE"
trap - EXIT

echo "Updated $NIX_FILE"
